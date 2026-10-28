import 'script.dart';

class ScriptRepositoryException implements Exception {
  const ScriptRepositoryException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

abstract interface class ScriptRepository {
  Future<List<ScriptFile>> list();
  Future<String> source(String path);
}

typedef ScriptRepositoryFactory =
    ScriptRepository Function(GitHubConfig config);
