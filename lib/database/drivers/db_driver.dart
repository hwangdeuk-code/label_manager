abstract class DbDriver {
  bool get isConnected;

  Future<bool> connect({
    required String ip,
    required String port,
    required String databaseName,
    required String username,
    required String password,
    int timeoutInSeconds = 15,
  });

  Future<String> getData(String sql);

  Future<String> writeData(String sql);

  Future<String> getDataWithParams(String sql, Map<String, dynamic> params);

  Future<String> writeDataWithParams(String sql, Map<String, dynamic> params);

  Future<bool> disconnect();
}
