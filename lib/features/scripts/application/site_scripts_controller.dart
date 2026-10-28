import 'package:flutter/foundation.dart';
import '../domain/script.dart';
import '../domain/site_scripts.dart';
import 'domain_script_catalog.dart';

/// Rejects late network results after a site/configuration change.
class SiteScriptsController extends ChangeNotifier {
  SiteScriptsController(this.catalog);
  final DomainScriptCatalog catalog;
  GitHubConfig config = const GitHubConfig();
  String domain = '';
  List<ScriptFile> files = const [];
  String? error;
  bool loading = false;
  int _generation = 0;
  bool _disposed = false;
  bool get configured => config.repository.isNotEmpty;

  void configure(GitHubConfig value) {
    config = value;
    _reset();
  }

  void setPage(String url) {
    final next = scriptDomain(url);
    if (next == domain) return;
    domain = next;
    _reset();
  }

  void _reset() {
    _generation++;
    files = const [];
    error = null;
    loading = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> discover({bool refresh = false}) async {
    if (_disposed || domain.isEmpty || !configured) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final found = await catalog.list(config, domain, refresh: refresh);
      if (!_disposed && generation == _generation) files = found;
    } catch (e) {
      if (!_disposed && generation == _generation) error = '$e';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
