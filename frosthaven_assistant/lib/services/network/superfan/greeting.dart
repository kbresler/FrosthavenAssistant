import 'dart:convert';

import 'cleaning.dart';

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

  /// The Swerski wire prefix, shared by every Swerski message.
  static const wirePrefix = _prefix;
  static const _prefix = 'swerski:';
  static const _head = 'Da Bears! superfan:';
  static const _idLimit = 64;
  static const _nameLimit = 30;
  static const _playCountLimit = 4;
  static const _playIdLimit = 40;

  final String id;
  final String name;
  final List<String> plays;

  /// Whether the sender has not picked its characters yet this app run and is
  /// still deciding — the host lists it but does not announce it yet.
  final bool asking;

  const SwerskiGreeting._({
    required this.id,
    required this.name,
    required this.plays,
    this.asking = false,
  });

  /// The greeting a client sends. [name] and [plays] are shortened to the
  /// protocol limits; an empty [plays] means "this device plays the table".
  static String encode({
    required String id,
    String name = '',
    List<String> plays = const [],
    bool asking = false,
  }) {
    final payload = <String, Object?>{
      'id': swerskiFit(swerskiClean(id), _idLimit),
      'name': swerskiFit(swerskiClean(name), _nameLimit),
      'plays': plays
          .take(_playCountLimit)
          .map((p) => swerskiFit(swerskiClean(p), _playIdLimit))
          .toList(),
    };
    // Only written when set, so a plain greeting stays byte-identical.
    if (asking) payload['asking'] = true;
    return '$_prefix$_head$version ${jsonEncode(payload)}';
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
    final Object? rawAsking = decoded['asking'] ?? false;
    if (rawId is! String) return null;
    final id = swerskiClean(rawId);
    if (id.isEmpty || id.length > _idLimit) return null;
    if (rawName is! String) return null;
    if (rawPlays is! List) return null;
    if (rawAsking is! bool) return null;

    final name = swerskiClean(rawName);
    if (name.length > _nameLimit) return null;
    final plays = <String>[];
    for (final Object? play in rawPlays) {
      if (play is! String) return null;
      final cleaned = swerskiClean(play);
      if (cleaned.length > _playIdLimit) return null;
      plays.add(cleaned);
    }
    if (plays.length > _playCountLimit) return null;

    return SwerskiGreeting._(id: id, name: name, plays: plays, asking: rawAsking);
  }

}
