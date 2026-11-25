import 'dart:math';

import '../l10n/app_localizations.dart';

/// Swerski edition: heart attacks (a character dropping to 0 health).
///
/// The line/speaker picker here is pure — it takes plain data and an injected
/// [Random] — so it is testable without a widget tree or game state. The
/// command that fires it lives in `ChangeHealthCommand`.

/// The initiative a character picks to take a long rest (skip the round); in
/// this app 99 already sorts last and means "no turn this round". Used to
/// derive the recovering badge and its Draw toast.
const int heartAttackLongRestInitiative = 99;

/// One candidate to deliver a reply line: a character who is neither the
/// victim nor an Objective/Escort (the caller filters those out).
class HeartAttackSpeaker {
  const HeartAttackSpeaker(this.name, this.count);

  final String name;
  final int count;
}

/// A chosen line and the name of the character who says it.
class HeartAttackReply {
  const HeartAttackReply(this.speakerName, this.line);

  final String speakerName;
  final String line;
}

/// Picks a speaker and a deadpan line about the victim's new [victimCount].
///
/// [candidates] must already exclude the victim and any Objective/Escort. A
/// first heart attack draws from the first-attack pool, a victim repeating
/// while the speaker has none from the repeat pool, a level score from the
/// (single-line) tied pool, and otherwise from the scorecard pool for who is
/// ahead (see [_scorecardLines]). Returns null when there is nobody to speak.
/// [random] is injected so the choice is deterministic under test.
HeartAttackReply? pickHeartAttackReply({
  required List<HeartAttackSpeaker> candidates,
  required String victimName,
  required int victimCount,
  required AppLocalizations l10n,
  required Random random,
}) {
  if (candidates.isEmpty) {
    return null;
  }
  final speakerIndex = random.nextInt(candidates.length);
  final speaker = candidates[speakerIndex];
  final List<String> pool;
  if (victimCount <= 1) {
    pool = [
      l10n.heartAttackFirstNoted(victimName),
      l10n.heartAttackFirstScenario(victimName),
      l10n.heartAttackFirstBoard(victimName),
    ];
  } else if (speaker.count == 0) {
    pool = [
      l10n.heartAttackRepeatAgain(victimName, victimCount),
      l10n.heartAttackRepeatAnyway(victimName, victimCount),
      l10n.heartAttackRepeatWriteDown(victimName, victimCount),
      l10n.heartAttackRepeatRespectable(victimName, victimCount),
      l10n.heartAttackRepeatCarryOn(victimName, victimCount),
    ];
  } else if (victimCount == speaker.count) {
    pool = [l10n.heartAttackTied(victimName, victimCount)];
  } else {
    final rivals = [
      for (int i = 0; i < candidates.length; i++)
        if (i != speakerIndex) candidates[i].count,
    ];
    pool = _scorecardLines(
      victimName: victimName,
      victimCount: victimCount,
      speaker: speaker,
      rivals: rivals,
      l10n: l10n,
    );
  }
  return HeartAttackReply(speaker.name, pool[random.nextInt(pool.length)]);
}

/// The scorecard lines for a victim and a speaker who are not level.
///
/// The lead line only joins the victim-ahead pool while nobody in [rivals]
/// (everyone but the chosen speaker) is level with or ahead of the victim —
/// otherwise nobody is taking a lead. The "I'm only on" line claims the speaker
/// is behind, so it never joins the speaker-ahead pool.
List<String> _scorecardLines({
  required String victimName,
  required int victimCount,
  required HeartAttackSpeaker speaker,
  required List<int> rivals,
  required AppLocalizations l10n,
}) {
  final notARace =
      l10n.heartAttackNotARace(victimName, victimCount, speaker.count);
  final notWorried =
      l10n.heartAttackNotWorried(victimName, victimCount, speaker.count);
  if (victimCount > speaker.count) {
    final leadsTheTable = rivals.every((count) => victimCount > count);
    return [
      if (leadsTheTable) l10n.heartAttackLead(victimName, victimCount),
      l10n.heartAttackOnlyOn(victimName, victimCount, speaker.count),
      notARace,
      notWorried,
    ];
  }
  return [
    notARace,
    notWorried,
    l10n.heartAttackJustSaying(victimName, victimCount, speaker.count),
    l10n.heartAttackComfortable(victimName, victimCount, speaker.count),
  ];
}

/// One combined long-rest line for the recovering characters in [names];
/// several of them share a single toast on Draw, in the plural.
String heartAttackRecoveringLine(List<String> names, AppLocalizations l10n) {
  final joined = _joinNames(names);
  return names.length > 1
      ? l10n.heartAttackRecoveringPlural(joined)
      : l10n.heartAttackRecovering(joined);
}

String _joinNames(List<String> names) {
  if (names.length <= 1) {
    return names.join();
  }
  final last = names.last;
  final rest = names.sublist(0, names.length - 1).join(', ');
  return '$rest and $last';
}
