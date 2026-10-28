import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/tv_cast.dart';

/// A read-only session summary; transport operations stay outside the widget.
class CastStatusBar extends StatefulWidget {
  const CastStatusBar({
    super.key,
    required this.cast,
    required this.onOpen,
    required this.onStop,
  });
  final TvCast cast;
  final VoidCallback onOpen, onStop;
  @override
  State<CastStatusBar> createState() => _CastStatusBarState();
}

class _CastStatusBarState extends State<CastStatusBar> {
  late final Timer timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final relay = widget.cast.relay;
    final state = switch (relay?.receiverState) {
      'playing' => 'Playing',
      'paused' => 'Paused',
      'buffering' => 'Buffering…',
      'seeking' => 'Seeking…',
      'recovering' => 'Recovering playback…',
      'ended' => 'Video ended',
      'waiting' => 'Waiting for TV playback',
      'error' => 'Unable to play video',
      _ => 'Cast session ready',
    };
    final buffer = relay?.buffer;
    final details = buffer != null && buffer.usedBytes > 0
        ? '$state · RAM ${(buffer.usedBytes / 1048576).toStringAsFixed(1)} / 128 MB'
        : state;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.cast_connected),
        title: Text(
          widget.cast.connected?.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(details, maxLines: 2),
        onTap: widget.onOpen,
        trailing: IconButton(
          tooltip: 'Stop casting',
          icon: const Icon(Icons.stop_circle_outlined),
          onPressed: widget.onStop,
        ),
      ),
    );
  }
}
