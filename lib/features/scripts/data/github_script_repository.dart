import 'dart:convert';
import 'dart:io';
import '../domain/script.dart';
import '../domain/script_repository.dart';

class GitHubScriptRepository implements ScriptRepository {
  GitHubScriptRepository(this.config);
  final GitHubConfig config;

  Uri uri(String path) {
    final parts = config.repository.trim().split('/');
    if (parts.length != 2 ||
        parts.any((p) => !RegExp(r'^[\w.-]+$').hasMatch(p))) {
      throw const FormatException('اكتب المستودع بالشكل owner/repo');
    }
    return Uri.https(
      'api.github.com',
      '/repos/${parts[0]}/${parts[1]}/contents/$path',
      {'ref': config.branch},
    );
  }

  Future<dynamic> read(String path) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri(path));
      request.headers.set('User-Agent', 'ScriptBrowser');
      request.headers.set('Accept', 'application/vnd.github+json');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw ScriptRepositoryException(
          'GitHub ${response.statusCode}: تأكد من المستودع العام والفرع والمجلد، أو حاول لاحقًا',
          statusCode: response.statusCode,
        );
      }
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<List<ScriptFile>> list() async {
    final data = await read(
      config.folder.trim().replaceAll(RegExp(r'^/+|/+$'), ''),
    );
    if (data is! List) throw const FormatException('المسار يجب أن يكون مجلدًا');
    return data
        .whereType<Map<String, dynamic>>()
        .where(
          (e) =>
              e['type'] == 'file' &&
              e['name'] is String &&
              (e['name'] as String).endsWith('.js') &&
              e['path'] is String,
        )
        .map(
          (e) =>
              ScriptFile(name: e['name'] as String, path: e['path'] as String),
        )
        .toList();
  }

  @override
  Future<String> source(String path) async {
    final data = await read(path);
    if (data is! Map ||
        data['encoding'] != 'base64' ||
        data['content'] is! String) {
      throw const FormatException('تعذر قراءة الملف أو حجمه كبير');
    }
    return utf8.decode(
      base64Decode((data['content'] as String).replaceAll(RegExp(r'\s'), '')),
    );
  }
}
