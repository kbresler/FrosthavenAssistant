import 'dart:math';

import '../services/network/network.dart';
import '../services/service_locator.dart';
import '../services/translation_service.dart';
import 'settings.dart';
import 'commands/command_l10n.dart';
import 'game_methods.dart';
import 'heart_attack.dart';
import 'state/game_state.dart';

/// Swerski: building and publishing the heart-attack lines, shared by the
/// commands (on the device that applied the change) and by the server's
/// SuperNetwork announce.

/// The deadpan reply line for [victim]'s new major heart attack — another
/// character speaks, in this device's language. Null when nobody can speak
/// or translations are unavailable (e.g. in command tests).
String? heartAttackReplyLine(Character victim, GameState gameState) {
  if (!getIt.isRegistered<TranslationService>()) {
    return null;
  }
  final translation = getIt<TranslationService>();
  String name(Character c) => translation.t(c.characterClass.name);
  final candidates = GameMethods.getCurrentCharactersForState(gameState)
      .where((c) => c.id != victim.id)
      .map((c) =>
          HeartAttackSpeaker(name(c), c.characterState.totalHeartAttacks))
      .toList();
  final reply = pickHeartAttackReply(
    candidates: candidates,
    victimName: name(victim),
    victimCount: victim.characterState.totalHeartAttacks,
    l10n: commandL10n,
    random: Random(),
  );
  if (reply == null) {
    return null;
  }
  return '${reply.speakerName}: ${reply.line}';
}

/// The combined long-rest line naming everyone who took a little heart attack
/// this Draw. Null when the list is empty or translations are unavailable.
String? heartAttackRestingLine(List<Character> resting) {
  if (resting.isEmpty || !getIt.isRegistered<TranslationService>()) {
    return null;
  }
  final translation = getIt<TranslationService>();
  final names =
      resting.map((c) => translation.t(c.characterClass.name)).toList();
  return heartAttackRecoveringLine(names, commandL10n);
}

/// Shows [line] on this device and, when this device hosts the game, sends it
/// to every greeted device. Does nothing for a null or empty line, so a
/// caller never has to check first. Does nothing on a phone attached to a
/// greeted host: there the host writes the one line everybody sees (the
/// counts still happened — this only skips the line).
void publishHeartAttackLine(String? line, GameState gameState) {
  if (line == null || line.isEmpty) {
    return;
  }
  if (getIt.isRegistered<Network>()) {
    final network = getIt<Network>();
    if (getIt<Settings>().client.value == ClientState.connected &&
        network.hostGreeted.value) {
      return;
    }
    // The host's "Heart attacks" setting is deliberately not checked here: it
    // only stops the host showing the line, never passing it on.
    if (getIt<Settings>().server.value) {
      network.server.sendSuperFanToast(line);
    }
  }
  gameState.heartAttackToast.value = line;
}
