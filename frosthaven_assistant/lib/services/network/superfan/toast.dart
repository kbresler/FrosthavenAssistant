import 'dart:convert';

import 'cleaning.dart';
import 'greeting.dart';

/// A heart-attack line the host writes once and hands to every greeted
/// device, so the whole SuperNetwork reads the same line.
///
/// Wire format (framed like every other message, in `S3nD:`/`[EOM]`):
///
///     host → devices  swerski:toast {"line":"..."}
///
/// Host-to-devices only, and it carries no game state. [parse] returns null
/// for anything that is not a well-formed line, so a device ignores messages
/// it does not understand.
class SwerskiToast {
  static const _toastToken = 'toast ';
  static const lineLimit = 300;

  /// The host's [line] for every greeted device, cleaned and capped.
  static String encode(String line) {
    final clean = swerskiFit(swerskiClean(line), lineLimit);
    return '${SwerskiGreeting.wirePrefix}$_toastToken'
        '${jsonEncode({'line': clean})}';
  }

  static bool isToastMessage(String message) =>
      message.startsWith(SwerskiGreeting.wirePrefix + _toastToken);

  /// The line in [message], or null if it is not a well-formed `toast`
  /// message — a missing, empty, non-string or over-long line, bad JSON.
  static String? parse(String message) {
    if (!isToastMessage(message)) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(message
          .substring(SwerskiGreeting.wirePrefix.length + _toastToken.length)
          .trim());
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final Object? rawLine = decoded['line'];
    if (rawLine is! String) return null;
    final line = swerskiClean(rawLine);
    if (line.isEmpty || line.length > lineLimit) return null;
    return line;
  }
}
