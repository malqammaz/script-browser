import 'package:flutter/material.dart';
import '../application/tv_cast.dart';
import '../infrastructure/browser_web.dart';

class CastDialog extends StatefulWidget {
  const CastDialog({super.key, required this.web, required this.cast});
  final BrowserWeb web;
  final TvCast cast;
  @override
  State<CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends State<CastDialog> {
  List<CastTv> devices = [];
  CastTv? selected;
  String? media;
  String status = '';
  bool busy = false;
  bool lgBrowser = true;
  final manual = TextEditingController();
  @override
  void initState() {
    super.initState();
    scan();
  }

  @override
  void dispose() {
    manual.dispose();
    super.dispose();
  }

  Future<void> scan() async {
    setState(() => busy = true);
    try {
      await widget.web.detectMedia();
      final found = await TvCast.discover();
      if (!mounted) return;
      setState(() {
        devices = found;
        selected = found.firstOrNull;
        media = widget.web.mediaRequests.keys.lastOrNull;
        status = found.isEmpty
            ? 'لم أجد تلفزيوناً. تأكد أن الجهازين على نفس Wi-Fi.'
            : '';
      });
    } catch (_) {
      if (mounted)
        setState(
          () => status = 'تعذر البحث عن التلفزيون. تحقق من اتصال Wi-Fi.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> action(Future<void> Function() task, String message) async {
    setState(() => busy = true);
    try {
      await task();
      if (mounted)
        setState(
          () => status =
              widget.cast.browserReceiver &&
                  message == 'تم إرسال الفيديو للتلفزيون'
              ? 'افتح هذا العنوان في متصفح LG:\n${widget.cast.receiverUrl}\nثم اضغط Play على التلفزيون. اترك التطبيق مفتوحاً.'
              : message,
        );
    } catch (error) {
      if (mounted) setState(() => status = '$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('بث الفيديو إلى التلفزيون'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'شغّل الفيديو في الصفحة أولاً، ثم ابحث. أبقِ التطبيق مفتوحاً أثناء البث وعلى نفس شبكة Wi-Fi.',
            ),
            const SizedBox(height: 12),
            if (busy) const LinearProgressIndicator(),
            for (final tv in devices)
              RadioListTile<CastTv>(
                title: Text(tv.name),
                subtitle: Text(tv.control.host),
                value: tv,
                groupValue: selected,
                onChanged: busy
                    ? null
                    : (value) => setState(() => selected = value),
              ),
            const Divider(),
            if (widget.web.mediaRequests.isEmpty)
              const Text(
                'لم يُكتشف فيديو بعد. ارجع للصفحة وشغّله أو الصق رابط MP4 / M3U8 مباشر.',
              ),
            for (final url in widget.web.mediaRequests.keys)
              RadioListTile<String>(
                title: Text(Uri.parse(url).host),
                subtitle: Text(
                  url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                ),
                value: url,
                groupValue: media,
                onChanged: busy
                    ? null
                    : (value) => setState(() => media = value),
              ),
            TextField(
              controller: manual,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'رابط فيديو مباشر (اختياري)',
              ),
              textDirection: TextDirection.ltr,
            ),
            if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: SelectableText(status),
              ),
            SwitchListTile(
              value: lgBrowser,
              onChanged: busy
                  ? null
                  : (value) => setState(() => lgBrowser = value),
              title: const Text('استخدام متصفح LG لبث HLS'),
            ),
            if (widget.cast.connected != null)
              Wrap(
                spacing: 8,
                children: [
                  if (!widget.cast.browserReceiver)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => action(
                              () => TvCast.command(
                                widget.cast.connected!,
                                'Pause',
                              ).then((_) {}),
                              'تم الإيقاف المؤقت',
                            ),
                      child: const Text('إيقاف مؤقت'),
                    ),
                  if (!widget.cast.browserReceiver)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => action(
                              () => TvCast.command(
                                widget.cast.connected!,
                                'Play',
                                {'Speed': '1'},
                              ).then((_) {}),
                              'تم الاستئناف',
                            ),
                      child: const Text('استئناف'),
                    ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => action(widget.cast.stop, 'تم إيقاف البث'),
                    child: const Text('إيقاف البث'),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : scan,
        child: const Text('إعادة البحث'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إغلاق'),
      ),
      FilledButton(
        onPressed: busy || selected == null
            ? null
            : () => action(() async {
                final url = manual.text.trim().isNotEmpty
                    ? manual.text.trim()
                    : media;
                final uri = Uri.tryParse(url ?? '');
                if (uri == null ||
                    !['http', 'https'].contains(uri.scheme) ||
                    uri.host.isEmpty)
                  throw const FormatException('اختر رابط فيديو مباشر أولاً.');
                await widget.cast.cast(
                  selected!,
                  uri,
                  cookies: widget.web.mediaCookies,
                  useBrowserReceiver:
                      lgBrowser &&
                      selected!.name.toLowerCase().contains('lg') &&
                      uri.path.toLowerCase().endsWith('.m3u8'),
                  headers:
                      widget.web.mediaRequests[url] ??
                      {'Referer': widget.web.pageUrl},
                );
              }, 'تم إرسال الفيديو للتلفزيون'),
        child: const Text('بث'),
      ),
    ],
  );
}
