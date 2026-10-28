import 'package:flutter/material.dart';
import '../application/browser_session.dart';

/// Local-only navigation library. Selecting a site returns its original URL.
class SavedSitesDialog extends StatefulWidget {
  const SavedSitesDialog({super.key, required this.session});
  final BrowserSession session;

  @override
  State<SavedSitesDialog> createState() => _SavedSitesDialogState();
}

class _SavedSitesDialogState extends State<SavedSitesDialog> {
  String query = '';

  Future<void> perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save changes. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> clearRecent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear recent sites?'),
        content: const Text(
          'Your bookmarks and last opened site will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) await perform(widget.session.clearRecentSites);
  }

  Widget sites(List<String> urls, {required bool bookmarks}) {
    final filtered = urls
        .where((url) => url.toLowerCase().contains(query))
        .toList();
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            query.isNotEmpty
                ? 'No matching sites.'
                : bookmarks
                ? 'No bookmarks yet. Use “Bookmark this page” in the browser menu.'
                : 'Sites you visit will appear here, newest first.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final url = filtered[index];
        final uri = Uri.parse(url);
        final saved = widget.session.isBookmarked(url);
        return ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          title: Text(uri.host, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.pop(context, url),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: saved ? 'Remove bookmark' : 'Bookmark site',
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () =>
                    perform(() => widget.session.toggleBookmark(url)),
              ),
              if (!bookmarks)
                IconButton(
                  tooltip: 'Remove from recent sites',
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      perform(() => widget.session.removeRecent(url)),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: SafeArea(
      child: DefaultTabController(
        length: 2,
        child: AnimatedBuilder(
          animation: widget.session,
          builder: (context, _) => Column(
            children: [
              ListTile(
                title: const Text('Your sites'),
                subtitle: const Text(
                  'Saved on this device · no account needed',
                ),
                trailing: IconButton(
                  tooltip: 'Close saved sites',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    labelText: 'Search saved sites',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Recent sites'),
                  Tab(text: 'Bookmarks'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: widget.session.recentSites.isEmpty
                                ? null
                                : clearRecent,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Clear recent sites'),
                          ),
                        ),
                        Expanded(
                          child: sites(
                            widget.session.recentSites,
                            bookmarks: false,
                          ),
                        ),
                      ],
                    ),
                    sites(widget.session.bookmarks, bookmarks: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
