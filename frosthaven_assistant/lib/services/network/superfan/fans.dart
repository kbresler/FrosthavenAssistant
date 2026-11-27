import 'dart:convert';

import 'cleaning.dart';
import 'greeting.dart';

/// A device on the SuperNetwork, as the host lists it to every Swerski device.
///
/// Wire format (framed like every other message, in `S3nD:`/`[EOM]`):
///
///     host → devices  swerski:fans {"fans":[{"id":"...","name":"...","plays":["..."],"host":true}]}
///     host → devices  swerski:joined {"id":"...","name":"...","plays":["..."]}
///
/// The `fans` list is re-sent after every change; `joined` announces a device
/// joining for the first time. Both are host-to-devices only, and carry no
/// game state. [parseFans] and [parseJoined] return null for anything that is
/// not well-formed, so a device ignores messages it does not understand.
class SwerskiFan {
  static const _fansToken = 'fans ';
  static const _joinedToken = 'joined ';
  static const _idLimit = 64;
  static const _nameLimit = 30;
  static const _playCountLimit = 4;
  static const _playIdLimit = 40;
  static const _fanCountLimit = 16;

  final String id;
  final String name;
  final List<String> plays;

  /// Whether this entry is the host itself, which always plays the table.
  final bool host;

  const SwerskiFan({
    required this.id,
    this.name = '',
    this.plays = const [],
    this.host = false,
  });

  /// The host's list of every device on the SuperNetwork, [fans] capped at 16.
  static String encodeFans(List<SwerskiFan> fans) {
    final entries = fans.take(_fanCountLimit).map(_encodeEntry).toList();
    return '${SwerskiGreeting.wirePrefix}$_fansToken'
        '${jsonEncode({'fans': entries})}';
  }

  /// The announcement that [fan] joined. Carries no host marker.
  static String encodeJoined(SwerskiFan fan) {
    final payload = <String, Object?>{
      'id': swerskiFit(swerskiClean(fan.id), _idLimit),
      'name': swerskiFit(swerskiClean(fan.name), _nameLimit),
      'plays': _encodePlays(fan.plays),
    };
    return '${SwerskiGreeting.wirePrefix}$_joinedToken${jsonEncode(payload)}';
  }

  static bool isFansMessage(String message) =>
      message.startsWith(SwerskiGreeting.wirePrefix + _fansToken);

  static bool isJoinedMessage(String message) =>
      message.startsWith(SwerskiGreeting.wirePrefix + _joinedToken);

  /// The list in [message], or null if it is not a well-formed `fans` message.
  static List<SwerskiFan>? parseFans(String message) {
    if (!isFansMessage(message)) return null;
    final decoded = _decode(message.substring(
      SwerskiGreeting.wirePrefix.length + _fansToken.length,
    ));
    if (decoded is! Map) return null;
    final Object? rawFans = decoded['fans'];
    if (rawFans is! List) return null;
    if (rawFans.length > _fanCountLimit) return null;
    final fans = <SwerskiFan>[];
    for (final Object? rawFan in rawFans) {
      if (rawFan is! Map) return null;
      final fan = _parseFan(rawFan, withHost: true);
      if (fan == null) return null;
      fans.add(fan);
    }
    return fans;
  }

  /// The device announced in [message], or null if it is not a well-formed
  /// `joined` message.
  static SwerskiFan? parseJoined(String message) {
    if (!isJoinedMessage(message)) return null;
    final decoded = _decode(message.substring(
      SwerskiGreeting.wirePrefix.length + _joinedToken.length,
    ));
    if (decoded is! Map) return null;
    return _parseFan(decoded);
  }

  static Map<String, Object?> _encodeEntry(SwerskiFan fan) => {
    'id': swerskiFit(swerskiClean(fan.id), _idLimit),
    'name': swerskiFit(swerskiClean(fan.name), _nameLimit),
    'plays': _encodePlays(fan.plays),
    'host': fan.host,
  };

  static List<String> _encodePlays(List<String> plays) => plays
      .take(_playCountLimit)
      .map((p) => swerskiFit(swerskiClean(p), _playIdLimit))
      .toList();

  static Object? _decode(String body) {
    try {
      return jsonDecode(body.trim());
    } on FormatException {
      return null;
    }
  }

  /// One entry of a `fans` list or the body of a `joined` message, or null if
  /// any field is missing in a required way, of the wrong type or over limits.
  static SwerskiFan? _parseFan(Map entry, {bool withHost = false}) {
    final Object? rawId = entry['id'];
    final Object? rawName = entry['name'] ?? '';
    final Object? rawPlays = entry['plays'] ?? const [];
    if (rawId is! String) return null;
    final id = swerskiClean(rawId);
    if (id.isEmpty || id.length > _idLimit) return null;
    if (rawName is! String) return null;
    final name = swerskiClean(rawName);
    if (name.length > _nameLimit) return null;
    if (rawPlays is! List) return null;
    final plays = <String>[];
    for (final Object? play in rawPlays) {
      if (play is! String) return null;
      final cleaned = swerskiClean(play);
      if (cleaned.length > _playIdLimit) return null;
      plays.add(cleaned);
    }
    if (plays.length > _playCountLimit) return null;
    var host = false;
    if (withHost) {
      final Object? rawHost = entry['host'] ?? false;
      if (rawHost is! bool) return null;
      host = rawHost;
    }
    return SwerskiFan(id: id, name: name, plays: plays, host: host);
  }
}
