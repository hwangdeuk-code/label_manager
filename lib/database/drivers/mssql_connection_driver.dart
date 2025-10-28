import 'package:mssql_connection/mssql_connection.dart';

import 'db_driver.dart';

class MssqlConnectionDriver implements DbDriver {
  MssqlConnectionDriver() : _inner = MssqlConnection.getInstance();

  final MssqlConnection _inner;

  @override
  bool get isConnected => _inner.isConnected;

  @override
  Future<bool> connect({
    required String ip,
    required String port,
    required String databaseName,
    required String username,
    required String password,
    int timeoutInSeconds = 15,
  }) {
    return _inner.connect(
      ip: ip,
      port: port,
      databaseName: databaseName,
      username: username,
      password: password,
      timeoutInSeconds: timeoutInSeconds,
    );
  }

  @override
  Future<String> getData(String sql) => _inner.getData(sql);

  @override
  Future<String> writeData(String sql) => _inner.writeData(sql);

  @override
  Future<String> getDataWithParams(String sql, Map<String, dynamic> params) =>
    _inner.getDataWithParams(sql, params);

  @override
  Future<String> writeDataWithParams(String sql, Map<String, dynamic> params) =>
    _inner.writeDataWithParams(sql, params);

  @override
  Future<bool> disconnect() => _inner.disconnect();
}
