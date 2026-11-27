import 'dart:convert';

/// The SuperNetwork greeting — the message a Swerski device sends right after
/// `init`, and the answer the host gives it.
///
/// Wire format (framed like every other message, in `S3nD:`/`[EOM]`):
///
///     client → host  swerski:Da Bears! superfan:1 {"id":"...","name":"...","plays":["..."]}
///     host → client  swerski:Da Bears! superfan:1
///
/// Official-app devices never send or expect these; both sides ignore messages
/// they do not know, so [parse] returns null for anything that is not a
/// well-formed greeting of this version.
class SwerskiGreeting {
  static const version = 1;
  static const _prefix = 'swerski:';
  static const _head = 'Da Bears! superfan:';
  static const _framing = ['S3nD:', '[EOM]'];
  static const _idLimit = 64;
  static const _nameLimit = 30;
  static const _playCountLimit = 4;
  static const _playIdLimit = 40;

  final String id;
  final String name;
  final List<String> plays;

  const SwerskiGreeting._({
    required this.id,
    required this.name,
    required this.plays,
  });

  /// The greeting a client sends. [name] and [plays] are shortened to the
  /// protocol limits; an empty [plays] means "this device plays the table".
  static String encode({
    required String id,
    String name = '',
    List<String> plays = const [],
  }) {
    final trimmed = plays
        .take(_playCountLimit)
        .map((p) => _fit(_clean(p), _playIdLimit))
        .toList();
    return '$_prefix$_head$version '
        '${jsonEncode({'id': _fit(_clean(id), _idLimit), 'name': _fit(_clean(name), _nameLimit), 'plays': trimmed})}';
  }

  /// The host's answer to a greeting.
  static String encodeAck() => '$_prefix$_head$version';

  /// Whether [message] is Swerski traffic — the greeting or the ack.
  static bool isSwerskiMessage(String message) => message.startsWith(_prefix);

  /// Whether [message] is the host's ack.
  static bool isAck(String message) => message == encodeAck();

  /// The greeting in [message], or null if it is not a greeting this version
  /// understands — a missing or empty id, a wrong token or version, unparseable
  /// JSON, fields of the wrong type, or fields over the limits.
  static SwerskiGreeting? parse(String message) {
    if (!isSwerskiMessage(message)) return null;
    final rest = message.substring(_prefix.length);
    if (!rest.startsWith(_head)) return null;
    final afterHead = rest.substring(_head.length);
    final space = afterHead.indexOf(' ');
    if (space == -1) return null;
    if (int.tryParse(afterHead.substring(0, space)) != version) return null;

    final body = afterHead.substring(space + 1).trim();
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;

    final Object? rawId = decoded['id'];
    final Object? rawName = decoded['name'] ?? '';
    final Object? rawPlays = decoded['plays'] ?? const [];
    if (rawId is! String) return null;
    final id = _clean(rawId);
    if (id.isEmpty || id.length > _idLimit) return null;
    if (rawName is! String) return null;
    if (rawPlays is! List) return null;

    final name = _clean(rawName);
    if (name.length > _nameLimit) return null;
    final plays = <String>[];
    for (final Object? play in rawPlays) {
      if (play is! String) return null;
      final cleaned = _clean(play);
      if (cleaned.length > _playIdLimit) return null;
      plays.add(cleaned);
    }
    if (plays.length > _playCountLimit) return null;

    return SwerskiGreeting._(id: id, name: name, plays: plays);
  }

  /// Removes the framing text. Repeats until the string stops changing: one
  /// pass would let nested framing smuggle a marker back in
  /// (`[E[EOM]OM]` → `[EOM]`).
  static String _clean(String value) {
    var result = value;
    while (true) {
      final before = result;
      for (final marker in _framing) {
        result = result.replaceAll(marker, '');
      }
      if (result == before) return result;
    }
  }

  /// Shortens to [limit] UTF-16 units without cutting an emoji in half.
  static String _fit(String value, int limit) {
    if (value.length <= limit) return value;
    final last = value.codeUnitAt(limit - 1);
    final splitsPair = last >= 0xD800 && last <= 0xDBFF;
    return value.substring(0, splitsPair ? limit - 1 : limit);
  }
}
