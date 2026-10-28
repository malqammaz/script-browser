import 'package:flutter/material.dart';
import '../../application/media_source.dart';

String castSourceTitle(Uri uri) {
  if (publicMegaPreview(uri) != null) return 'MEGA';
  if (publicDrivePreview(uri) != null) return 'Google Drive';
  return uri.host;
}

String castSourceSubtitle(Uri uri, bool hls) {
  if (publicMegaPreview(uri) != null) return 'Opens directly on your TV';
  if (publicDrivePreview(uri) != null) return 'Public preview on your TV';
  return hls ? 'HLS · Adaptive stream' : 'Direct video';
}

class CastChoiceCard extends StatelessWidget {
  const CastChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onDetails,
  });
  final String title, subtitle;
  final bool selected;
  final VoidCallback? onTap, onDetails;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        child: Material(
          color: selected
              ? colors.primaryContainer
              : colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.check_circle : Icons.radio_button_off,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: selected
                                      ? colors.onPrimaryContainer
                                      : colors.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: selected
                                      ? colors.onPrimaryContainer
                                      : colors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (onDetails != null)
                      IconButton(
                        tooltip: 'Link details',
                        onPressed: onDetails,
                        icon: const Icon(Icons.info_outline),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
