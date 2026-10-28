import '../domain/script.dart';
import '../domain/script_repository.dart';
import '../domain/site_scripts.dart';

/// Caches directory listings per repository/ref/folder/site, never script bodies.
class DomainScriptCatalog {
  DomainScriptCatalog(this.repositories);
  final ScriptRepositoryFactory repositories;
  final Map<String, List<ScriptFile>> _cache = {};

  Future<List<ScriptFile>> list(
    GitHubConfig root,
    String domain, {
    bool refresh = false,
  }) async {
    final scoped = scriptsForDomain(root, domain);
    final key = '${scoped.repository}\n${scoped.branch}\n${scoped.folder}';
    if (!refresh && _cache.containsKey(key)) return _cache[key]!;
    try {
      final files = [...await repositories(scoped).list()];
      files.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return _cache[key] = List.unmodifiable(files);
    } on ScriptRepositoryException catch (error) {
      if (error.statusCode != 404) rethrow;
      return _cache[key] = const [];
    }
  }
}
