/// Converts address-bar input into a web destination without UI or storage dependencies.
class AddressResolver {
  const AddressResolver();
  Uri resolve(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      throw const FormatException('Enter a website or search term');
    }
    final explicit = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(text);
    final candidate = Uri.tryParse(explicit ? text : 'https://$text');
    if (explicit) {
      if (candidate == null ||
          !['https', 'http'].contains(candidate.scheme) ||
          candidate.host.isEmpty) {
        throw const FormatException('This URL scheme is not supported');
      }
      return candidate;
    }
    if (!RegExp(r'\s').hasMatch(text) &&
        candidate != null &&
        (candidate.host.contains('.') ||
            candidate.host == 'localhost' ||
            candidate.host.contains(':')) &&
        !candidate.host.startsWith('.') &&
        !candidate.host.endsWith('.')) {
      return candidate;
    }
    return Uri.https('www.google.com', '/search', {'q': text});
  }
}
