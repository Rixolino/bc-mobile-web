class LibsqlClient {
  LibsqlClient.remote(String url, {String? authToken});

  Future<void> connect() async {}

  Future<void> execute(String sql, {List<Object?> positional = const []}) async {}

  Future<List<Map<String, Object?>>> query(String sql, {List<Object?> positional = const []}) async {
    return <Map<String, Object?>>[];
  }
}