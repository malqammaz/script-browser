import 'dart:convert';
import 'dart:io';

class GitHub {
  GitHub(this.repository, this.branch, this.folder);
  final String repository, branch, folder;

  Uri uri(String path) {
    final parts = repository.trim().split('/');
    if (parts.length != 2 ||
        parts.any((p) => !RegExp(r'^[\w.-]+$').hasMatch(p))) {
      throw const FormatException('اكتب المستودع بالشكل owner/repo');
    }
    return Uri.https(
      'api.github.com',
      '/repos/${parts[0]}/${parts[1]}/contents/$path',
      {'ref': branch},
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
        throw HttpException(
          'GitHub ${response.statusCode}: تأكد من المستودع العام والفرع والمجلد، أو حاول لاحقًا',
        );
      }
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Map<String, dynamic>>> list() async {
    final data = await read(folder.trim().replaceAll(RegExp(r'^/+|/+$'), ''));
    if (data is! List) throw const FormatException('المسار يجب أن يكون مجلدًا');
    return data
        .whereType<Map<String, dynamic>>()
        .where(
          (e) => e['type'] == 'file' && (e['name'] as String).endsWith('.js'),
        )
        .toList();
  }

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
