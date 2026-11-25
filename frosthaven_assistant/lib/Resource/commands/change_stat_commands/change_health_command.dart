import 'dart:math';

import '../../../services/service_locator.dart';
import '../../../services/translation_service.dart';
import '../../settings.dart';
import '../../heart_attack.dart';
import '../../game_event.dart';
import '../../game_methods.dart';
import '../../state/game_state.dart';
import 'change_stat_command.dart';
import '../command_l10n.dart';

class ChangeHealthCommand extends ChangeStatCommand {
  ChangeHealthCommand(super.change, super.figureId, super.ownerId,
      {required super.gameState});

  @override
  void execute() {
    FigureState? figure = GameMethods.getFigure(ownerId, figureId);
    if (figure != null) {
      final previousValue = figure.health.value;
      if (previousValue + change < 0) {
        //no negative values
        figure.setHealth(stateAccess, 0);
      } else {
        figure.setHealth(stateAccess, figure.health.value + change);
      }
      final newValue = figure.health.value;
      if (previousValue <= 0 && newValue > 0) {
        //un death
        gameState.updateList.notify();
      }

      // Swerski: a character dropping from above 0 to exactly 0 has a major
      // heart attack — it carries across scenarios, only Undo clears it (the
      // count is part of the snapshot undo restores).
      if (figure is CharacterState && previousValue > 0 && newValue == 0) {
        _maybeHeartAttack(figure);
      }

      if (newValue <= 0) {
        handleDeath();
      }
    }
  }

  void _maybeHeartAttack(CharacterState figure) {
    final settings =
        getIt.isRegistered<Settings>() ? getIt<Settings>() : null;
    if (settings == null || !settings.heartAttacks.value) {
      return;
    }
    // Objectives and Escorts sitting at 0 don't count as heart attacks.
    final character = _ownerOf(figure);
    if (character == null ||
        GameMethods.isObjectiveOrEscort(character.characterClass)) {
      return;
    }
    figure.setHeartAttacks(stateAccess, figure.heartAttacks.value + 1);
    // The toast talks about every heart attack, both kinds and all scenarios.
    _fireReplyToast(character, figure.totalHeartAttacks);
  }

  /// A deadpan reply line from another character, shown once on this device.
  /// Skipped quietly when translations are unavailable (e.g. in command tests).
  void _fireReplyToast(Character victim, int victimCount) {
    if (!getIt.isRegistered<TranslationService>()) {
      return;
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
      victimCount: victimCount,
      l10n: commandL10n,
      random: Random(),
    );
    if (reply != null) {
      gameState.heartAttackToast.value = '${reply.speakerName}: ${reply.line}';
    }
  }

  /// The [Character] whose body is [figure], or null. Used to tell a real
  /// character (which gets a heart attack) from an Objective/Escort.
  Character? _ownerOf(CharacterState figure) {
    for (final item in gameState.currentList) {
      if (item is Character && identical(item.characterState, figure)) {
        return item;
      }
    }
    return null;
  }

  @override
  GameEvent get event => HealthChangedEvent(figureId, ownerId ?? '', change);

  @override
  String describe() {
    if (change > 0) {
      //TODO: looks bad
      return commandL10n.cmdIncreaseHealth(figureId, change);
    }
    FigureState? figure = GameMethods.getFigure(ownerId, figureId);
    if (figure == null || figure.health.value <= 0) {
      return commandL10n.cmdKill(ownerId ?? '');
    }
    //TODO: incorrect for character summons
    return commandL10n.cmdDecreaseHealth(ownerId ?? '', -change);
  }
}
