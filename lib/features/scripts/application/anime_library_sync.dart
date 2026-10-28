import 'dart:convert';
import 'dart:io';

typedef LibraryRequest =
    Future<Map<String, dynamic>> Function(
      String method,
      String token,
      Map<String, dynamic>? body,
    );

/// Credentials stay in Dart. The page can only return episode data.
class AnimeLibrarySync {
  AnimeLibrarySync({LibraryRequest? request})
    : request = request ?? githubRequest;
  final LibraryRequest request;
  static const repository = 'malqammaz/anime-library';
  static const branch = 'main';
  static const filePath = 'library.json';

  static Future<Map<String, dynamic>> githubRequest(
    String method,
    String token,
    Map<String, dynamic>? body,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.https(
        'api.github.com',
        '/repos/$repository/contents/$filePath',
        method == 'GET' ? {'ref': branch} : null,
      );
      final req = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 20));
      req.followRedirects = false;
      req.headers.set('User-Agent', 'ScriptBrowser');
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('Authorization', 'Bearer $token');
      req.headers.set('X-GitHub-Api-Version', '2022-11-28');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final response = await req.close().timeout(const Duration(seconds: 30));
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 409) throw const LibraryConflict();
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw StateError(
          'GitHub ${response.statusCode}: تحقق من التوكن وصلاحية Contents: Read and write.',
        );
      }
      return Map<String, dynamic>.from(jsonDecode(text) as Map);
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> sync(
    Map<String, dynamic> incoming,
    String token,
  ) async {
    if (token.trim().isEmpty) {
      throw StateError('اضغط زر مزامنة المكتبة وأدخل توكن GitHub مرة واحدة.');
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      final file = await request('GET', token, null);
      if (file['encoding'] != 'base64' ||
          file['content'] is! String ||
          file['sha'] is! String) {
        throw const FormatException('تعذر قراءة ملف المكتبة.');
      }
      final library = Map<String, dynamic>.from(
        jsonDecode(
              utf8.decode(
                base64Decode(
                  (file['content'] as String).replaceAll(RegExp(r'\s'), ''),
                ),
              ),
            )
            as Map,
      );
      final before = jsonEncode(library);
      final counts = merge(library, incoming);
      if (jsonEncode(library) == before) {
        return {'success': true, 'unchanged': true, ...counts};
      }
      try {
        final saved = await request('PUT', token, {
          'message': 'Update anime library: ${incoming['title']}',
          'branch': branch,
          'sha': file['sha'],
          'content': base64Encode(
            utf8.encode(
              '${const JsonEncoder.withIndent('  ').convert(library)}\n',
            ),
          ),
        });
        return {
          'success': true,
          ...counts,
          'url': saved['content']?['html_url'],
        };
      } on LibraryConflict {
        if (attempt == 1) rethrow;
      }
    }
    throw const LibraryConflict();
  }

  static Map<String, int> merge(
    Map<String, dynamic> library,
    Map<String, dynamic> incoming,
  ) {
    final rawTitle = incoming['title'];
    final rawEpisodes = incoming['episodes'];
    if (rawTitle is! String ||
        rawTitle.trim().isEmpty ||
        rawEpisodes is! List ||
        library['anime'] is! List) {
      throw const FormatException('بيانات الأنمي غير صالحة.');
    }
    final title = rawTitle.trim().replaceFirst(RegExp(r'^[اأإ]نمي\s+'), '');
    String titleKey(Object? value) => '$value'
        .trim()
        .replaceFirst(RegExp(r'^[اأإ]نمي\s+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    num number(Object? value) {
      final text = '$value'.trim().replaceAllMapped(
        RegExp('[٠-٩]'),
        (m) => '٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!).toString(),
      );
      if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text)) {
        throw const FormatException('رقم حلقة غير صالح.');
      }
      return num.parse(text);
    }

    final shows = List<dynamic>.from(library['anime'] as List);
    library['anime'] = shows;
    Map? show;
    for (final a in shows) {
      if (a is Map && titleKey(a['title']) == titleKey(title)) {
        show = a;
        break;
      }
    }
    var added = 0, updated = 0, skipped = 0;
    final valid = rawEpisodes
        .whereType<Map>()
        .where(
          (e) =>
              e['error'] == null &&
              e['links'] is List &&
              (e['links'] as List).isNotEmpty,
        )
        .toList();
    if (valid.isEmpty) {
      throw const FormatException('لا توجد حلقات ناجحة لرفعها.');
    }
    show ??= {'title': title, 'episodes': <dynamic>[]};
    if (!shows.contains(show)) shows.add(show);
    final image = incoming['image'];
    if (image is String && image.isNotEmpty) {
      final uri = Uri.tryParse(image);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw const FormatException('رابط صورة غير صالح.');
      }
      show['image'] = uri.toString();
    }
    if (show['episodes'] is! List) {
      throw const FormatException('قائمة الحلقات المخزنة غير صالحة.');
    }
    final episodes = List<dynamic>.from(show['episodes'] as List);
    show['episodes'] = episodes;
    const rank = {'player': 4, 'media': 3, 'iframe': 2, 'host-link': 1};
    for (final ep in valid) {
      final n = number(ep['number']);
      Map? old;
      for (final candidate in episodes) {
        if (candidate is Map && number(candidate['number']) == n) {
          old = candidate;
          break;
        }
      }
      if (old == null) {
        old = {'number': n, 'title': 'الحلقة $n', 'links': <dynamic>[]};
        episodes.add(old);
        added++;
      } else {
        updated++;
      }
      if (old['title'] == null ||
          RegExp(r'^مشاهدة(?: الحلقة)?$').hasMatch('${old['title']}'.trim())) {
        old['title'] = 'الحلقة $n';
      }
      if (old['links'] is! List) {
        throw const FormatException('الروابط المخزنة غير صالحة.');
      }
      final links = List<dynamic>.from(old['links'] as List);
      old['links'] = links;
      for (final raw in ep['links'] as List) {
        if (raw is! Map) throw const FormatException('رابط غير صالح.');
        final url = Uri.tryParse('${raw['url']}');
        if (url == null ||
            !['http', 'https'].contains(url.scheme) ||
            url.host.isEmpty) {
          throw const FormatException('رابط غير صالح.');
        }
        final link = Map<String, dynamic>.from(raw);
        if ('${link['label'] ?? ''}'.trim().isEmpty) link['label'] = url.host;
        if ('${link['quality'] ?? ''}'.isEmpty) {
          link['quality'] =
              RegExp(
                r'\b(FHD|HD|SD|4K|1080p|720p|480p)\b',
                caseSensitive: false,
              ).firstMatch('${link['label']}')?.group(0) ??
              '';
        }
        Map? existing;
        for (final l in links) {
          if (l is Map && l['url'] == link['url']) {
            existing = l;
            break;
          }
        }
        if (existing == null) {
          links.add(link);
        } else if ((rank[link['type']] ?? 0) >= (rank[existing['type']] ?? 0)) {
          for (final entry in link.entries) {
            if (entry.value != null && entry.value != '') {
              existing[entry.key] = entry.value;
            }
          }
        }
      }
    }
    episodes.sort((a, b) => number(a['number']).compareTo(number(b['number'])));
    skipped = rawEpisodes.length - valid.length;
    return {'added': added, 'updated': updated, 'skipped': skipped};
  }
}

class LibraryConflict implements Exception {
  const LibraryConflict();
  @override
  String toString() => 'تغيرت المكتبة أثناء التحديث؛ أعد تشغيل السكربت.';
}
