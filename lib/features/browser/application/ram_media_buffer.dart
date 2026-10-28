import 'dart:collection';
import 'dart:typed_data';

class BufferedSegment {
  BufferedSegment(this.bytes, this.contentType);
  final Uint8List bytes;
  final String contentType;
}

/// Limit retained media bytes, not the entire application's memory usage.
class RamMediaBuffer {
  RamMediaBuffer({this.capacity = 128 * 1024 * 1024});
  final int capacity;
  final _entries = LinkedHashMap<Uri, BufferedSegment>();
  int usedBytes = 0;
  int get freeBytes => capacity - usedBytes;
  BufferedSegment? get(Uri uri) {
    final value = _entries.remove(uri);
    if (value != null) _entries[uri] = value;
    return value;
  }

  bool contains(Uri uri) => _entries.containsKey(uri);
  bool put(Uri uri, BufferedSegment data) {
    if (data.bytes.length > capacity) return false;
    final old = _entries.remove(uri);
    if (old != null) usedBytes -= old.bytes.length;
    while (usedBytes + data.bytes.length > capacity && _entries.isNotEmpty) {
      final first = _entries.keys.first;
      usedBytes -= _entries.remove(first)!.bytes.length;
    }
    _entries[uri] = data;
    usedBytes += data.bytes.length;
    return true;
  }

  void removeWhere(bool Function(Uri) predicate) {
    for (final uri in _entries.keys.where(predicate).toList()) {
      usedBytes -= _entries.remove(uri)!.bytes.length;
    }
  }

  void clear() {
    _entries.clear();
    usedBytes = 0;
  }
}
