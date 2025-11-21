import 'dart:async';
import 'dart:isolate';
import 'dart:io';

import 'drivers/db_driver.dart';
import 'drivers/mssql_connection_driver.dart';
import 'windows_odbc/odbc_driver.dart';

// DB 작업 요청 메시지 타입
enum DbIsolateAction {
  connect,
  query,
  queryWithParams,
  write,
  writeWithParams,
  disconnect,
}

class DbIsolateBootstrapMessage {
  final SendPort commandPort;
  final SendPort logPort;
  const DbIsolateBootstrapMessage({
    required this.commandPort,
    required this.logPort,
  });
}

class DbIsolateRequest {
  final DbIsolateAction action;
  final Map<String, dynamic> payload;
  final SendPort replyTo;
  DbIsolateRequest(this.action, this.payload, this.replyTo);
}

class DbIsolateResponse {
  final bool success;
  final dynamic result;
  final String? error;
  DbIsolateResponse({required this.success, this.result, this.error});
}

Future<void> dbIsolateMain(DbIsolateBootstrapMessage bootstrap) async {
  final port = ReceivePort();
  bootstrap.commandPort.send(port.sendPort);
  final logPort = bootstrap.logPort;

  void log(String message) {
    try {
      logPort.send(message);
    } catch (_) {
      // ignore
    }
    try {
      stdout.writeln('[LM] [DbIsolate] $message');
    } catch (_) {
      // ignore stdout failures
    }
  }

  DbDriver? driver;
  await for (final msg in port) {
    if (msg is! DbIsolateRequest) {
      continue;
    }
    try {
      switch (msg.action) {
        case DbIsolateAction.connect:
          final drv = driver ??= _createDriver(log);
          final ok = await drv.connect(
            ip: msg.payload['ip'],
            port: msg.payload['port'],
            databaseName: msg.payload['databaseName'],
            username: msg.payload['username'],
            password: msg.payload['password'],
            timeoutInSeconds: msg.payload['timeoutInSeconds'] ?? 15,
          );
          msg.replyTo.send(DbIsolateResponse(success: ok, result: ok));
          break;
        case DbIsolateAction.query:
          final res = await _requireDriver(driver).getData(msg.payload['sql']);
          msg.replyTo.send(DbIsolateResponse(success: true, result: res));
          break;
        case DbIsolateAction.queryWithParams:
          final res = await _requireDriver(
            driver,
          ).getDataWithParams(msg.payload['sql'], msg.payload['params']);
          msg.replyTo.send(DbIsolateResponse(success: true, result: res));
          break;
        case DbIsolateAction.write:
          final res = await _requireDriver(
            driver,
          ).writeData(msg.payload['sql']);
          msg.replyTo.send(DbIsolateResponse(success: true, result: res));
          break;
        case DbIsolateAction.writeWithParams:
          final res = await _requireDriver(
            driver,
          ).writeDataWithParams(msg.payload['sql'], msg.payload['params']);
          msg.replyTo.send(DbIsolateResponse(success: true, result: res));
          break;
        case DbIsolateAction.disconnect:
          await driver?.disconnect();
          driver = null;
          msg.replyTo.send(DbIsolateResponse(success: true, result: true));
          break;
      }
    } catch (e, st) {
      log('DbIsolate error: $e');
      log(st.toString());
      msg.replyTo.send(DbIsolateResponse(success: false, error: e.toString()));
    }
  }
}

DbDriver _createDriver(void Function(String) log) {
  if (Platform.isWindows) {
    return OdbcMssqlDriver(logger: log);
  }
  return MssqlConnectionDriver();
}

DbDriver _requireDriver(DbDriver? driver) {
  if (driver == null || !driver.isConnected) {
    throw StateError('Database is not connected.');
  }
  return driver;
}
