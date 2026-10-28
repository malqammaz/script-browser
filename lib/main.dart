import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_blocker.dart';
import 'browser_web.dart';

import 'github.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff146c60),
      useMaterial3: true,
    ),
    home: const Directionality(
      textDirection: TextDirection.rtl,
      child: Browser(),
    ),
  ),
);

class Browser extends StatefulWidget {
  const Browser({super.key});
  @override
  State<Browser> createState() => _BrowserState();
}

class _BrowserState extends State<Browser> {
  final address = TextEditingController();
  final repo = TextEditingController();
  final branch = TextEditingController(text: 'main');
  final folder = TextEditingController(text: 'scripts');
  final editor = TextEditingController(
    text:
        "const button = document.querySelector('button');\nif (!button) throw new Error('لم يتم العثور على زر');\nbutton.click();\nreturn 'تم الضغط على الزر';",
  );
  final blocker = AdBlocker();
  late final BrowserWeb web;
  int blockedCount = 0;
  int progress = 100;
  int navigation = 0;
  bool busy = false, running = false;
  String scriptName = 'سكربت تجريبي', result = 'النتائج ستظهر هنا';

  @override
  void initState() {
    super.initState();
    web = BrowserWeb(
      blocker: blocker,
      onStarted: (url) {
        if (mounted) {
          setState(() {
            navigation++;
            blockedCount = 0;
            address.text = url;
          });
        }
      },
      onFinished: (url) {
        if (mounted) {
          setState(() {
            address.text = url;
            progress = 100;
          });
        }
      },
      onProgress: (value) {
        if (mounted) setState(() => progress = value);
      },
      onError: (message) {
        if (mounted) setState(() => progress = 100);
        notice(message);
      },
      onBlocked: () {
        blockedCount++;
      },
    );
    restore();
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    repo.text = prefs.getString('repo') ?? '';
    branch.text = prefs.getString('branch') ?? 'main';
    folder.text = prefs.getString('folder') ?? 'scripts';
    editor.text = prefs.getString('code') ?? editor.text;
    setState(() {
      blocker.enabled = prefs.getBool('adBlockEnabled') ?? true;
      blocker.allowedSites.addAll(
        prefs.getStringList('adBlockAllowedSites') ?? [],
      );
      blocker.customDomains.addAll(
        prefs.getStringList('adBlockCustomDomains') ?? [],
      );
    });
    await web.updateProtection();
  }

  Future<void> protection() async {
    final host = Uri.tryParse(web.pageUrl)?.host ?? '';
    final custom = TextEditingController(
      text: blocker.customDomains.join('\n'),
    );
    var enabled = blocker.enabled;
    var allowSite = blocker.allowedSites.contains(host);
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('حماية الإعلانات'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('تم حظر $blockedCount طلب إعلان أو نافذة في هذه الصفحة.'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('حظر الإعلانات والتتبع'),
                  value: enabled,
                  onChanged: (value) => update(() => enabled = value),
                ),
                if (host.isNotEmpty)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('السماح بالإعلانات لهذا الموقع'),
                    subtitle: Text(host),
                    value: allowSite,
                    onChanged: (value) => update(() => allowSite = value),
                  ),
                const Text(
                  'يحظر نطاقات إعلانية معروفة والنوافذ الجديدة ويخفي علامات الإعلان الشائعة. قد لا يمنع جميع الإعلانات. إذا تعطلت وظيفة في الموقع، فعّل الاستثناء أعلاه.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: custom,
                  minLines: 3,
                  maxLines: 6,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'نطاقات إضافية — نطاق في كل سطر',
                    hintText: 'ads.example.com',
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  AdBlocker.parseCustomDomains(custom.text);
                  Navigator.pop(ctx, true);
                } catch (e) {
                  update(() => error = '$e');
                }
              },
              child: const Text('حفظ وإعادة تحميل'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        blocker.enabled = enabled;
        if (host.isNotEmpty) {
          if (allowSite) {
            blocker.allowedSites.add(host);
          } else {
            blocker.allowedSites.remove(host);
          }
        }
        blocker.customDomains
          ..clear()
          ..addAll(AdBlocker.parseCustomDomains(custom.text));
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('adBlockEnabled', blocker.enabled);
      await prefs.setStringList(
        'adBlockAllowedSites',
        blocker.allowedSites.toList(),
      );
      await prefs.setStringList(
        'adBlockCustomDomains',
        blocker.customDomains.toList(),
      );
      await web.updateProtection();
      await web.reload();
    }
    // Dialog exit animation can still reference its text controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    custom.dispose();
  }

  void notice(Object message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$message')));
    }
  }

  Future<void> open() async {
    try {
      var value = address.text.trim();
      if (!value.contains('://')) value = 'https://$value';
      final uri = Uri.parse(value);
      if (!['https', 'http'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const FormatException('أدخل رابط موقع صحيح');
      }
      await web.loadRequest(uri);
    } catch (e) {
      notice(e);
    }
  }

  Future<void> scripts() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سكربتات GitHub'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('مستودع عام. الملفات تظهر من المجلد المحدد مباشرةً.'),
              TextField(
                controller: repo,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'owner/repo'),
              ),
              TextField(
                controller: branch,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الفرع أو commit SHA',
                ),
              ),
              TextField(
                controller: folder,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'المجلد (فارغ للجذر)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تحميل القائمة'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => busy = true);
    try {
      final github = GitHub(
        repo.text.trim(),
        branch.text.trim(),
        folder.text.trim(),
      );
      final items = await github.list();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('repo', repo.text.trim());
      await prefs.setString('branch', branch.text.trim());
      await prefs.setString('folder', folder.text.trim());
      if (!mounted) return;
      final chosen = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(
            items.isEmpty ? 'لا توجد ملفات .js في هذا المجلد' : 'اختر سكربتًا',
          ),
          children: items
              .map(
                (item) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, item),
                  child: Text(item['name'] as String),
                ),
              )
              .toList(),
        ),
      );
      if (chosen == null) return;
      final code = await github.source(chosen['path'] as String);
      if (!mounted) return;
      setState(() {
        editor.text = code;
        scriptName = chosen['name'] as String;
      });
      await edit();
    } catch (e) {
      notice(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(scriptName),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'السكربت يستطيع قراءة بيانات الصفحة والتفاعل معها. شغّل فقط كودًا تثق فيه. استخدم return لإرجاع نتيجة، ويمكن استخدام await.',
              ),
              const SizedBox(height: 12),
              Flexible(
                child: TextField(
                  controller: editor,
                  textDirection: TextDirection.ltr,
                  maxLines: 18,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حفظ وإغلاق'),
          ),
        ],
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('code', editor.text);
  }

  Future<void> run() async {
    setState(() {
      running = true;
      result = 'جارٍ التنفيذ…';
    });
    final key = '__scriptBrowser_${DateTime.now().microsecondsSinceEpoch}';
    final encodedKey = jsonEncode(key);
    final initialNavigation = navigation;
    try {
      await web.runJavaScript('''(() => {
        const key = $encodedKey;
        window[key] = null;
        (async () => {
          try {
            const value = await (async () => {
              ${editor.text}
            })();
            window[key] = JSON.stringify({ok:true, value: value === undefined ? 'تم التنفيذ بدون قيمة إرجاع' : value});
          } catch(e) { window[key] = JSON.stringify({ok:false,error:String(e)}); }
        })();
      })();''');
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (mounted && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        if (navigation != initialNavigation) {
          setState(
            () => result =
                'تغيّرت الصفحة أثناء التنفيذ؛ قد يكون السكربت قد نفّذ التنقّل.',
          );
          return;
        }
        final raw = await web.runJavaScriptReturningResult(
          'window[$encodedKey] || ""',
        );
        dynamic value = raw;
        // Android may return either a JSON-quoted string or the string itself.
        if (value is String && value.startsWith('"')) value = jsonDecode(value);
        if (value is! String || value.isEmpty) continue;
        final data = jsonDecode(value) as Map<String, dynamic>;
        setState(
          () => result = data['ok'] == true
              ? const JsonEncoder.withIndent('  ').convert(data['value'])
              : 'خطأ: ${data['error']}',
        );
        return;
      }
      if (mounted) {
        setState(
          () => result =
              'انتهى انتظار النتيجة بعد 30 ثانية. قد يستمر السكربت؛ أعد تحميل الصفحة لإيقافه.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => result = 'تعذر التنفيذ: $e');
    } finally {
      unawaited(
        web
            .runJavaScript('delete window[$encodedKey]')
            .catchError((Object _) {}),
      );
      if (mounted) setState(() => running = false);
    }
  }

  @override
  void dispose() {
    for (final c in [address, repo, branch, folder, editor]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('متصفح السكربتات'),
      actions: [
        IconButton(
          tooltip: 'حماية الإعلانات',
          onPressed: protection,
          icon: Icon(
            blocker.activeFor(web.pageUrl)
                ? Icons.shield
                : Icons.shield_outlined,
          ),
        ),
        IconButton(
          tooltip: 'GitHub',
          onPressed: busy ? null : scripts,
          icon: const Icon(Icons.cloud_download_outlined),
        ),
        IconButton(
          tooltip: 'تعديل السكربت',
          onPressed: running ? null : edit,
          icon: const Icon(Icons.code),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: address,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.url,
                    onSubmitted: (_) => open(),
                    decoration: const InputDecoration(
                      hintText: 'https://example.com',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'فتح',
                  onPressed: open,
                  icon: const Icon(Icons.arrow_forward),
                ),
                IconButton(
                  tooltip: 'إعادة تحميل',
                  onPressed: () => web.reload(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (progress < 100 || busy)
            LinearProgressIndicator(value: busy ? null : progress / 100),
          Expanded(child: web.view()),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'رجوع',
                        onPressed: () async {
                          if (await web.canGoBack()) await web.goBack();
                        },
                        icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      ),
                      Expanded(
                        child: Text(
                          scriptName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: running || busy || progress < 100
                            ? null
                            : run,
                        icon: Icon(
                          running ? Icons.hourglass_top : Icons.play_arrow,
                        ),
                        label: const Text('تشغيل'),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 90,
                    child: SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SelectableText(result),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: result));
                        notice('تم نسخ النتيجة');
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('نسخ النتيجة'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
