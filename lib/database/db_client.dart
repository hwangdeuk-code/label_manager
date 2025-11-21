import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:label_manager/utils/debug_logger.dart';

import 'db_isolate.dart';

/// DB 작업을 처리하는 Isolate 기반 클라이언트
class DbClient {
  DbClient._();
  static final DbClient instance = DbClient._();

  Isolate? _dbIsolate;
  SendPort? _dbSendPort;
  ReceivePort? _logReceivePort;
  StreamSubscription<dynamic>? _logSubscription;
  Future<void>? _isolateInit;

  bool get isConnected => _dbIsolate != null && _dbSendPort != null;

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final formatted = '[DbClient][$timestamp] $message';
    debugPrint(formatted);
    if (Platform.isWindows) {
      try {
        DebugLogger.outputDebugString(formatted);
      } catch (_) {
        // DebugView 출력 실패 시 무시
      }
    }
    try {
      stdout.writeln(formatted);
    } catch (_) {
      // 콘솔 출력 실패 시 무시
    }
  }

  Future<void> _ensureIsolate() async {
    if (_dbSendPort != null) return;
    if (_isolateInit != null) {
      await _isolateInit;
      return;
    }

    final initCompleter = Completer<void>();
    _isolateInit = initCompleter.future;

    _log('Isolate 준비 시작');
    final sw = Stopwatch()..start();
    final commandReceivePort = ReceivePort();
    _logReceivePort = ReceivePort();
    _logSubscription = _logReceivePort!.listen((message) {
      final text = message is String ? message : message.toString();
      if (Platform.isWindows) {
        try {
          DebugLogger.outputDebugString(text);
        } catch (_) {
          // ignore DebugView failure
        }
      }
      _log('[Isolate] $text');
    });

    try {
      _dbIsolate = await Isolate.spawn(
        dbIsolateMain,
        DbIsolateBootstrapMessage(
          commandPort: commandReceivePort.sendPort,
          logPort: _logReceivePort!.sendPort,
        ),
      );
      _dbSendPort = await commandReceivePort.first as SendPort;
      commandReceivePort.close();
      sw.stop();
      _log('Isolate 생성 완료 (${sw.elapsedMilliseconds}ms)');
      initCompleter.complete();
    } catch (e, st) {
      commandReceivePort.close();
      await _logSubscription?.cancel();
      _logSubscription = null;
      _logReceivePort?.close();
      _logReceivePort = null;
      _dbIsolate = null;
      _dbSendPort = null;
      _log('Isolate spawn failed: $e');
      initCompleter.completeError(e, st);
      rethrow;
    } finally {
      _isolateInit = null;
    }
  }

  Future<T> _sendToIsolate<T>(
    DbIsolateAction action,
    Map<String, dynamic> payload,
  ) async {
    await _ensureIsolate();
    final responsePort = ReceivePort();
    _log('Isolate 요청: $action, payload=${_maskPayload(payload)}');
    if (action == DbIsolateAction.connect) {
      _log('Isolate 연결 문자열(mask): ${_maskConnectionString(payload)}');
    }
    _dbSendPort!.send(DbIsolateRequest(action, payload, responsePort.sendPort));
    final DbIsolateResponse res = await responsePort.first as DbIsolateResponse;
    responsePort.close();
    _log('Isolate 응답: $action, success=${res.success}');
    if (res.success) {
      return res.result as T;
    }
    throw Exception(res.error ?? 'DB Isolate error');
  }

  Future<bool> connect({
    required String ip,
    required String port,
    required String databaseName,
    required String username,
    required String password,
    int timeoutInSeconds = 15,
  }) async {
    // Isolate가 준비될 때까지 기다려서 경합 조건을 방지한다.
    await _ensureIsolate();

    _log('DB 연결 시도: $ip:$port/$databaseName ($username)');
    final sw = Stopwatch()..start();
    final ok = await _sendToIsolate<bool>(DbIsolateAction.connect, {
      'ip': ip,
      'port': port,
      'databaseName': databaseName,
      'username': username,
      'password': password,
      'timeoutInSeconds': timeoutInSeconds,
    });
    sw.stop();
    _log('DB 연결 결과: $ok (${sw.elapsedMilliseconds}ms)');
    return ok;
  }

  Future<String> getData(String sql) async {
    _log('getData 요청 시작');
    _debugPrintSql(sql);
    final sw = Stopwatch()..start();
    final result = await _sendToIsolate<String>(DbIsolateAction.query, {
      'sql': sql,
    });
    sw.stop();
    _log('getData 요청 완료 (${sw.elapsedMilliseconds}ms)');
    return result;
  }

  Future<String> getDataWithParams(
    String sql,
    Map<String, dynamic> params,
  ) async {
    _log('getDataWithParams 요청 시작');
    _debugPrintSql(sql, params);
    final sw = Stopwatch()..start();
    final result = await _sendToIsolate<String>(
      DbIsolateAction.queryWithParams,
      {'sql': sql, 'params': params},
    );
    sw.stop();
    _log('getDataWithParams 요청 완료 (${sw.elapsedMilliseconds}ms)');
    return result;
  }

  Future<String> writeData(String sql) async {
    _log('writeData 요청 시작');
    _debugPrintSql(sql);
    final sw = Stopwatch()..start();
    final result = await _sendToIsolate<String>(DbIsolateAction.write, {
      'sql': sql,
    });
    sw.stop();
    _log('writeData 요청 완료 (${sw.elapsedMilliseconds}ms)');
    return result;
  }

  Future<String> writeDataWithParams(
    String sql,
    Map<String, dynamic> params,
  ) async {
    _log('writeDataWithParams 요청 시작');
    _debugPrintSql(sql, params);
    final sw = Stopwatch()..start();
    final result = await _sendToIsolate<String>(
      DbIsolateAction.writeWithParams,
      {'sql': sql, 'params': params},
    );
    sw.stop();
    _log('writeDataWithParams 요청 완료 (${sw.elapsedMilliseconds}ms)');
    return result;
  }

  Future<void> disconnect() async {
    if (_dbSendPort == null) return;
    _log('DB 연결 종료 요청');
    final sw = Stopwatch()..start();
    try {
      await _sendToIsolate(DbIsolateAction.disconnect, {});
    } finally {
      _dbIsolate?.kill(priority: Isolate.immediate);
      _dbIsolate = null;
      _dbSendPort = null;
      await _logSubscription?.cancel();
      _logSubscription = null;
      _logReceivePort?.close();
      _logReceivePort = null;
      sw.stop();
      _log('DB 연결 종료 완료 (${sw.elapsedMilliseconds}ms)');
    }
  }

  Map<String, dynamic> _maskPayload(Map<String, dynamic> payload) {
    return payload.map((key, value) {
      if (key.toLowerCase() == 'password') {
        return MapEntry(key, '******');
      }
      return MapEntry(key, value);
    });
  }

  String _maskConnectionString(Map<String, dynamic> payload) {
    final ip = (payload['ip'] ?? '').toString().trim();
    final port = (payload['port'] ?? '').toString().trim();
    final db = (payload['databaseName'] ?? '').toString().trim();
    final user = (payload['username'] ?? '').toString().trim();
    final timeout = (payload['timeoutInSeconds'] ?? '').toString().trim();
    return 'Server=$ip,$port;Database=$db;UID=$user;PWD=******;Login Timeout=$timeout;';
  }

  void _debugPrintSql(String sql, [Map<String, dynamic>? params]) {
    try {
      final statement =
          params == null ? sql : _formatSqlWithParams(sql, params);
      debugPrint('[LM] [DbClient][SQL] $statement');
    } catch (e) {
      debugPrint('[LM] [DbClient][SQL] format failed: $e');
      debugPrint('[LM] [DbClient][SQL] raw: $sql');
    }
  }

  String _formatSqlWithParams(String sql, Map<String, dynamic> params) {
    if (params.isEmpty) return sql;
    var statement = sql;
    final entries = params.entries
        .map((e) => MapEntry(_normalizeParamName(e.key), e.value))
        .toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in entries) {
      final literal = _toSqlLiteral(entry.value);
      final pattern = RegExp(
        '\\b${RegExp.escape(entry.key)}\\b',
        caseSensitive: false,
      );
      statement = statement.replaceAll(pattern, literal);
    }
    return statement;
  }

  String _normalizeParamName(String name) =>
      name.startsWith('@') ? name : '@$name';

  String _toSqlLiteral(dynamic value) {
    if (value == null) return 'NULL';
    if (value is num) return value.toString();
    if (value is bool) return value ? '1' : '0';
    if (value is DateTime) {
      final iso = value.toIso8601String();
      return "'${iso.replaceAll("'", "''")}'";
    }
    if (value is Iterable) {
      final list = value.map(_toSqlLiteral).join(', ');
      return '($list)';
    }
    final text = value.toString().replaceAll("'", "''");
    return "'$text'";
  }
}
