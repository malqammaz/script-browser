import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/tv_cast.dart';
import '../application/media_source.dart';
import '../infrastructure/browser_web.dart';
import 'widgets/cast_choice_card.dart';

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
  bool sessionReady = false;
  final manual = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (widget.cast.connected != null) {
      selected = widget.cast.connected;
      devices = [selected!];
      step = 2;
      sessionReady = true;
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
        status = '';
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
      status = 'Working…';
    });
    try {
      await task();
      if (mounted) {
        setState(() {
          status = message;
          step = 2;
          sessionReady = widget.cast.connected != null;
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
          (publicEmbeddedPreview(uri) != null ||
              widget.web.isHlsMedia(uri) ||
              isDrivePreviewMedia(uri)),
      headers: widget.web.mediaRequests[raw] ?? {'Referer': widget.web.pageUrl},
    );
  }, 'Cast session ready');

  String? get manualError {
    final value = manual.text.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return 'Enter a full http:// or https:// link.';
    }
    if (['mega.nz', 'www.mega.nz'].contains(uri.host) &&
        publicMegaPreview(uri) == null) {
      return 'Use a public MEGA file link including its key.';
    }
    if (uri.host == 'drive.google.com' && publicDrivePreview(uri) == null) {
      return 'Use a public Google Drive file view link.';
    }
    return null;
  }

  bool get hasVideo =>
      manualError == null && (manual.text.trim().isNotEmpty || media != null);

  Widget notice(String message, {bool error = false}) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error ? colors.errorContainer : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(error ? Icons.error_outline : Icons.info_outline, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: error ? colors.onErrorContainer : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget get tvStep => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Choose a TV', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Connect your phone and TV to the same Wi-Fi.'),
      const SizedBox(height: 20),
      if (!busy && !failed && devices.isEmpty)
        notice(
          'No TVs found yet. Turn on your TV, check Wi-Fi, and scan again.',
        ),
      for (final tv in devices)
        CastChoiceCard(
          title: tv.name,
          subtitle: tv.control.host,
          selected: selected == tv,
          onTap: busy
              ? null
              : () => setState(() {
                  selected = tv;
                  sessionReady = false;
                }),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: busy ? null : scan,
          icon: const Icon(Icons.refresh),
          label: const Text('Scan again'),
        ),
      ),
    ],
  );

  Future<void> refreshVideos() async {
    setState(() {
      busy = true;
      status = 'Detecting videos…';
      failed = false;
    });
    try {
      await widget.web.detectMedia();
      if (!mounted) return;
      setState(() {
        if (!widget.web.mediaRequests.containsKey(media)) {
          media = widget.web.mediaRequests.keys.lastOrNull;
        }
        status = widget.web.mediaRequests.isEmpty
            ? 'No video found yet. Press Play on the page, then try again.'
            : '';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          status =
              'Could not refresh videos. Return to the page and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget get videoStep => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Choose a video', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
        'Select a detected source, or paste a public video link below.',
      ),
      const SizedBox(height: 20),
      if (widget.web.mediaRequests.isEmpty)
        notice(
          'No video detected yet. Play it on the page first, then refresh.',
        ),
      for (final url in widget.web.mediaRequests.keys)
        CastChoiceCard(
          title: castSourceTitle(Uri.parse(url)),
          subtitle: castSourceSubtitle(
            Uri.parse(url),
            widget.web.isHlsMedia(Uri.parse(url)),
          ),
          selected: media == url && manual.text.trim().isEmpty,
          onTap: busy
              ? null
              : () => setState(() {
                  media = url;
                  manual.clear();
                  sessionReady = false;
                }),
          onDetails: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Video URL'),
              content: SingleChildScrollView(
                child: SelectableText(url, textDirection: TextDirection.ltr),
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
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: busy ? null : refreshVideos,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh videos'),
        ),
      ),
      const SizedBox(height: 12),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Paste a link or change options'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: TextField(
              controller: manual,
              enabled: !busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              onChanged: (_) => setState(() => sessionReady = false),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'Video or public file URL',
                hintText: 'https://…',
                errorText: manualError,
                helperText: 'MP4, HLS, Google Drive or MEGA',
                helperMaxLines: 2,
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: lgBrowser,
            onChanged: busy
                ? null
                : (value) => setState(() {
                    lgBrowser = value;
                    sessionReady = false;
                  }),
            title: const Text('Use the LG web player'),
            subtitle: const Text(
              'Recommended for HLS and public file players.',
            ),
          ),
        ],
      ),
    ],
  );

  Widget get connection => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        sessionReady ? 'Your cast session' : 'Ready to connect',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tv),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selected?.name ?? 'No TV selected',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (media != null || manual.text.trim().isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                manual.text.trim().isNotEmpty
                    ? 'Pasted video link'
                    : castSourceTitle(Uri.parse(media!)),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (media != null && manual.text.trim().isEmpty)
                Text(
                  castSourceSubtitle(
                    Uri.parse(media!),
                    widget.web.isHlsMedia(Uri.parse(media!)),
                  ),
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (sessionReady && widget.cast.connected != null) ...[
        notice(
          'Background casting is active. You can lock your phone; keep Wi-Fi connected.',
        ),
        const SizedBox(height: 20),
        if (widget.cast.browserReceiver) ...[
          Text(
            'Open on your TV',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Open Web Browser on your LG and enter this address. Save it as a bookmark for next time.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              '${widget.cast.receiverUrl}',
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: '${widget.cast.receiverUrl}'),
                );
                if (mounted) setState(() => status = 'TV address copied');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy address'),
            ),
          ),
          const Text(
            'Press Play on the TV. For a new MEGA video, reopen this bookmark rather than refreshing the previous MEGA page.',
          ),
        ] else
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton.icon(
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
              OutlinedButton.icon(
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
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => action(widget.cast.stop, 'Casting stopped'),
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Stop casting'),
        ),
      ] else
        notice(
          'Select Start casting, then follow the TV instructions. Closing this screen after connecting keeps the session active.',
        ),
    ],
  );

  Widget progressTabs() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        for (var index = 0; index < 3; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
              child: Semantics(
                selected: step == index,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: step == index
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed:
                      busy ||
                          (index > 0 && selected == null) ||
                          (index == 2 && !hasVideo && !sessionReady)
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          setState(() => step = index);
                        },
                  child: Text(
                    ['1. TV', '2. Video', '3. Connect'][index],
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget footer() {
    final done = step == 2 && sessionReady;
    final canContinue =
        !busy &&
        (step == 0 ? selected != null : hasVideo) &&
        (step < 2 || selected != null);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (step > 0) ...[
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      setState(() => step--);
                    },
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton(
              onPressed: busy
                  ? null
                  : done
                  ? () => Navigator.pop(context)
                  : !canContinue
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      if (step < 2) {
                        setState(() => step++);
                      } else {
                        connect();
                      }
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  done
                      ? 'Done'
                      : step < 2
                      ? 'Next'
                      : failed
                      ? 'Retry'
                      : 'Start casting',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final compact =
        MediaQuery.sizeOf(context).width < 600 || availableHeight < 500;
    final short = availableHeight < 420;
    final content = SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.cast),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cast to TV',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close casting',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (!short) progressTabs(),
          if (busy) const LinearProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey(step),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (step == 0)
                    tvStep
                  else if (step == 1)
                    videoStep
                  else
                    connection,
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    notice(status, error: failed),
                  ],
                ],
              ),
            ),
          ),
          footer(),
        ],
      ),
    );
    if (compact) return Dialog.fullscreen(child: content);
    return Dialog(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
      child: content,
    );
  }
}
