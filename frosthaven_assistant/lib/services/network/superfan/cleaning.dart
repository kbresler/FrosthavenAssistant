// Text cleaning shared by every Swerski message (greeting, fans, joined).

const framingMarkers = ['S3nD:', '[EOM]'];

/// Removes the framing text. Repeats until the string stops changing: one
/// pass would let nested framing smuggle a marker back in
/// (`[E[EOM]OM]` → `[EOM]`).
String swerskiClean(String value) {
  var result = value;
  while (true) {
    final before = result;
    for (final marker in framingMarkers) {
      result = result.replaceAll(marker, '');
    }
    if (result == before) return result;
  }
}

/// Shortens to [limit] UTF-16 units without cutting an emoji in half.
String swerskiFit(String value, int limit) {
  if (value.length <= limit) return value;
  final last = value.codeUnitAt(limit - 1);
  final splitsPair = last >= 0xD800 && last <= 0xDBFF;
  return value.substring(0, splitsPair ? limit - 1 : limit);
}
