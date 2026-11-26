import 'dart:convert';

/// Swerski-only keys inside `currentList[i].characterState` that an official
/// app client never sends.
const _preservedKeys = [
  'heartAttacks',
  'heartAttacksBefore',
  'littleHeartAttacks',
  'littleHeartAttacksBefore',
];

/// Re-adds Swerski-only fields to a client-sent game-state snapshot.
///
/// An official app client does not know the heart-attack counts, so its
/// snapshots lack those keys and loading one would zero the host's counts.
/// For every incoming list entry with a `characterState` whose `id` the host
/// also has, each of the [four keys](_preservedKeys) that [incoming] omits is
/// copied from [current] (the host's own JSON). A key that is present — even
/// as 0 — stays exactly as sent, so a genuine change still lands. Entries
/// without a `characterState`, characters the host does not have, and
/// anything that fails to parse are left alone: [incoming] comes back
/// unchanged.
String preserveSwerskiFields({
  required String incoming,
  required String current,
}) {
  try {
    final incomingJson = jsonDecode(incoming) as Map<String, dynamic>;
    final currentJson = jsonDecode(current) as Map<String, dynamic>;
    final currentStates = <String, Map<String, dynamic>>{};
    for (final entry in currentJson['currentList'] as List<dynamic>) {
      if (entry is Map<String, dynamic> &&
          entry['id'] is String &&
          entry['characterState'] is Map<String, dynamic>) {
        currentStates[entry['id'] as String] =
            entry['characterState'] as Map<String, dynamic>;
      }
    }
    var changed = false;
    for (final entry in incomingJson['currentList'] as List<dynamic>) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      final state = entry['characterState'];
      if (state is! Map<String, dynamic> || entry['id'] is! String) {
        continue;
      }
      final currentEntry = currentStates[entry['id'] as String];
      if (currentEntry == null) {
        continue;
      }
      for (final key in _preservedKeys) {
        if (!state.containsKey(key) && currentEntry.containsKey(key)) {
          state[key] = currentEntry[key];
          changed = true;
        }
      }
    }
    return changed ? jsonEncode(incomingJson) : incoming;
  } catch (_) {
    return incoming;
  }
}
