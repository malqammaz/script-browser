import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/tv_cast.dart';
import '../application/media_source.dart';
import '../infrastructure/browser_web.dart';

class CastDialog extends StatefulWidget {
  const CastDialog({
    super.key,
    required this.web,
    required this.cast,
    this.discover = TvCast.discover,
  });
  final Future<List<CastTv>> Function() discover;
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
  bool busy = false, failed = false, lgBrowser = true;
  int step = 0;
  final manual = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (widget.cast.connected != null) {
      selected = widget.cast.connected;
      devices = [selected!];
      step = 2;
    } else {
      scan();
    }
  }

  @override
  void dispose() {
    manual.dispose();
    super.dispose();
  }

  Future<void> scan() async {
    final previous = selected?.control;
    setState(() {
      busy = true;
      failed = false;
      status = 'Finding TVs and videos…';
    });
    try {
      await widget.web.detectMedia();
      final found = await widget.discover();
      if (!mounted) return;
      setState(() {
        devices = found;
        selected =
            found.where((tv) => tv.control == previous).firstOrNull ??
            found.firstOrNull;
        final urls = widget.web.mediaRequests.keys;
        if (!urls.contains(media)) media = urls.lastOrNull;
        status = found.isEmpty
            ? 'No TVs found. Connect your phone and TV to the same Wi-Fi, then scan again.'
            : '';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          status = 'Discovery failed. Check Wi-Fi and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> action(Future<void> Function() task, String message) async {
    setState(() {
      busy = true;
      failed = false;
      status = 'Connecting…';
    });
    try {
      await task();
      if (mounted) {
        setState(() {
          status = message;
          step = 2;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          status =
              'Could not start casting. Check the video link and TV connection, then try again.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> connect() => action(() async {
    final raw = manual.text.trim().isNotEmpty ? manual.text.trim() : media;
    final uri = Uri.tryParse(raw ?? '');
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException();
    }
    await widget.cast.cast(
      selected!,
      uri,
      cookies: widget.web.mediaCookies,
      isHls: widget.web.isHlsMedia(uri),
      useBrowserReceiver:
          lgBrowser &&
          selected!.name.toLowerCase().contains('lg') &&
          (publicDrivePreview(uri) != null ||
              widget.web.isHlsMedia(uri) ||
              isDrivePreviewMedia(uri)),
      headers: widget.web.mediaRequests[raw] ?? {'Referer': widget.web.pageUrl},
    );
  }, 'Cast session ready');

  Widget get connection => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.cast.connected != null) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cast_connected),
          title: Text(widget.cast.connected!.name),
          subtitle: const Text('Casting can continue with your phone locked'),
        ),
        if (widget.cast.browserReceiver) ...[
          const Text(
            'On your TV',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            '1. Open Web Browser on your LG TV.\n2. Enter this address and bookmark it.\n3. Press Play in the TV player.',
          ),
          const SizedBox(height: 12),
          SelectableText(
            '${widget.cast.receiverUrl}',
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: '${widget.cast.receiverUrl}'),
              );
              if (mounted) setState(() => status = 'TV address copied');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy address'),
          ),
          const Text(
            'Control playback and volume on your TV. Supported streams show RAM buffer usage in the player.',
          ),
        ] else
          Wrap(
            children: [
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => action(
                        () => TvCast.command(
                          widget.cast.connected!,
                          'Pause',
                        ).then((_) {}),
                        'Playback paused',
                      ),
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              ),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => action(
                        () => TvCast.command(widget.cast.connected!, 'Play', {
                          'Speed': '1',
                        }).then((_) {}),
                        'Playback resumed',
                      ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
              ),
            ],
          ),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => action(widget.cast.stop, 'Casting stopped'),
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Stop casting'),
        ),
      ] else
        const Text('Choose a TV and video, then select Start casting.'),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cast to TV'),
    content: SizedBox(
      width: 480,
      height: MediaQuery.sizeOf(context).height * .62,
      child: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          Expanded(
            child: Stepper(
              margin: EdgeInsets.zero,
              currentStep: step,
              onStepTapped: busy
                  ? null
                  : (value) => setState(() => step = value),
              controlsBuilder: (_, details) => const SizedBox.shrink(),
              steps: [
                Step(
                  title: const Text('Choose a TV'),
                  isActive: step >= 0,
                  content: Column(
                    children: [
                      const Text('Both devices must be on the same Wi-Fi.'),
                      if (!busy && devices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No devices available yet.'),
                        ),
                      for (final tv in devices)
                        ListTile(
                          title: Text(tv.name),
                          subtitle: Text(
                            tv.control.host,
                            textDirection: TextDirection.ltr,
                          ),
                          leading: Icon(
                            selected == tv
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          selected: selected == tv,
                          onTap: busy
                              ? null
                              : () => setState(() => selected = tv),
                        ),
                      TextButton.icon(
                        onPressed: busy ? null : scan,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan again'),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Choose a video'),
                  isActive: step >= 1,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.web.mediaRequests.isEmpty)
                        const Text(
                          'Play the video on the page, then refresh videos, or paste a direct link.',
                        ),
                      for (final url in widget.web.mediaRequests.keys)
                        ListTile(
                          title: Text(
                            Uri.parse(url).host,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            publicDrivePreview(Uri.parse(url)) != null
                                ? 'Google Drive · Public preview'
                                : widget.web.isHlsMedia(Uri.parse(url))
                                ? 'HLS · Adaptive stream'
                                : 'Direct video',
                          ),
                          trailing: IconButton(
                            tooltip: 'Link details',
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Video URL'),
                                content: SingleChildScrollView(
                                  child: SelectableText(
                                    url,
                                    textDirection: TextDirection.ltr,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          leading: Icon(
                            media == url
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          selected: media == url,
                          onTap: busy
                              ? null
                              : () => setState(() {
                                  media = url;
                                  manual.clear();
                                }),
                        ),
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                await widget.web.detectMedia();
                                if (mounted) {
                                  setState(
                                    () => media ??= widget
                                        .web
                                        .mediaRequests
                                        .keys
                                        .lastOrNull,
                                  );
                                }
                              },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh videos'),
                      ),
                      ExpansionTile(
                        title: const Text('Manual link and advanced options'),
                        children: [
                          TextField(
                            controller: manual,
                            enabled: !busy,
                            onChanged: (_) => setState(() {}),
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                              labelText: 'MP4 / M3U8 / Google Drive',
                            ),
                          ),
                          SwitchListTile(
                            value: lgBrowser,
                            onChanged: busy
                                ? null
                                : (value) => setState(() => lgBrowser = value),
                            title: const Text('Use the LG browser for video'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Connect and play'),
                  isActive: step >= 2,
                  content: connection,
                ),
              ],
            ),
          ),
          if (status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                status,
                style: TextStyle(
                  color: failed ? Theme.of(context).colorScheme.error : null,
                ),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      if (step > 0)
        TextButton(
          onPressed: busy ? null : () => setState(() => step--),
          child: const Text('Back'),
        ),
      if (step < 2)
        FilledButton(
          onPressed:
              busy ||
                  (step == 0
                      ? selected == null
                      : media == null && manual.text.trim().isEmpty)
              ? null
              : () => setState(() => step++),
          child: const Text('Next'),
        ),
      if (step == 2 && selected != null)
        FilledButton.icon(
          onPressed: busy || (media == null && manual.text.trim().isEmpty)
              ? null
              : connect,
          icon: const Icon(Icons.cast),
          label: Text(failed ? 'Retry' : 'Start casting'),
        ),
    ],
  );
}
