import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Network boundaries shared by casting and browsing on the phone.
class MediaNetworkPolicy {
  static bool isLan(InternetAddress address) {
    final b = address.rawAddress;
    if (b.length == 16) return (b[0] & 0xfe) == 0xfc;
    return b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168);
  }

  static bool isPublic(InternetAddress address) {
    final b = address.rawAddress;
    if (b.length == 16) {
      return (b[0] & 0xe0) == 0x20 &&
          !(b[0] == 0x20 &&
              (b[1] == 2 ||
                  (b[1] == 1 && b[2] < 2) ||
                  (b[1] == 1 && b[2] == 13 && b[3] == 184)));
    }
    return !isLan(address) &&
        b[0] != 0 &&
        b[0] != 127 &&
        b[0] < 224 &&
        !(b[0] == 100 && b[1] >= 64 && b[1] <= 127) &&
        !(b[0] == 169 && b[1] == 254) &&
        !(b[0] == 192 && b[1] == 0) &&
        !(b[0] == 192 && b[1] == 88 && b[2] == 99) &&
        !(b[0] == 198 && [18, 19, 51].contains(b[1])) &&
        !(b[0] == 203 && b[1] == 0 && b[2] == 113);
  }

  static bool isLanLiteral(Uri uri) {
    final address = InternetAddress.tryParse(uri.host);
    return address != null && isLan(address);
  }

  static bool blockedWebUrl(Uri uri) =>
      uri.scheme == 'http' && !isLanLiteral(uri);

  static Future<String> readText(Stream<List<int>> stream, int maxBytes) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('Response exceeds the size limit.');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }
}
