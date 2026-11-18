import '../../services/service_locator.dart';
import '../enums.dart';
import '../settings.dart';
import '../state/game_state.dart';
import 'change_stat_commands/change_health_command.dart';
import 'command_l10n.dart';
import 'remove_condition_command.dart';

/// Swerski edition: applies wound damage automatically when a figure's turn
/// starts (Settings.autoApplyWounds).
///
/// Usage inside a command: take [snapshotTurns] before changing turn states,
/// then call [applyTurnStartWounds] with it afterwards. Only figures that went
/// from "not done" to "current" take damage, so tapping a finished figure to
/// replay its turn does not wound it twice. Undo restores health as usual,
/// because the whole command is one undo step.
mixin TurnStartWounds on Command {
  static const int _kMaxPasses = 20;
  static const int _kToastSeconds = 5;

  GameState get turnGameState;

  Settings? get _settings =>
      getIt.isRegistered<Settings>() ? getIt<Settings>() : null;

  Map<String, TurnsState> snapshotTurns() {
    final turns = <String, TurnsState>{};
    for (final item in turnGameState.currentList) {
      if (item is Character) {
        turns[_characterKey(item)] = item.turnState.value;
      } else if (item is Monster) {
        turns[_monsterKey(item)] = item.turnState.value;
        for (final instance in item.monsterInstances) {
          turns[_standeeKey(item, instance)] = instance.turnState;
        }
      }
    }
    return turns;
  }

  void applyTurnStartWounds(Map<String, TurnsState> before) {
    final settings = _settings;
    if (settings == null || !settings.autoApplyWounds.value) {
      return;
    }
    final perStandee = settings.perStandeeTurns.value;
    final wounded = <String>[];
    var previous = before;
    for (int pass = 0; pass < _kMaxPasses; pass++) {
      final hits = _collectStartedTurns(previous, perStandee);
      if (hits.isEmpty) {
        break;
      }
      for (final hit in hits) {
        hit.figure.setWoundTakenThisRound(stateAccess, true);
        for (final used in hit.usedUp) {
          RemoveConditionCommand(used, hit.figureId, hit.ownerId,
                  gameState: turnGameState)
              .execute();
        }
        if (hit.damage > 0) {
          ChangeHealthCommand(-hit.damage, hit.figureId, hit.ownerId,
                  gameState: turnGameState)
              .execute();
        }
        final note = hit.usedUp.isEmpty
            ? ''
            : ' (${hit.usedUp.map((c) => c.name).join(', ')})';
        wounded.add('${hit.name} -${hit.damage}$note');
      }
      // A standee killed by its wound can't act: move on to the next one.
      previous = snapshotTurns();
      for (final item in turnGameState.currentList.toList()) {
        if (item is Monster) {
          RoundMethods.continueAfterStandeeRemoved(stateAccess, item,
              gameState: turnGameState, settings: settings);
        }
      }
    }
    if (wounded.isNotEmpty) {
      final gs = turnGameState;
      final message = commandL10n.toastWoundDamage(wounded.join(', '));
      // Don't bring back an older wound message, only other messages.
      final woundPrefix = commandL10n.toastWoundDamage('');
      final previous = gs.toastMessage.value.startsWith(woundPrefix)
          ? ''
          : gs.toastMessage.value;
      GameUtilMethods.setToastMessage(message, gameState: gs);
      // Toasts stay up until cleared; after a few seconds give the message
      // bar back to whatever it showed before (e.g. a scenario reminder),
      // unless something else has replaced our message meanwhile.
      Future.delayed(const Duration(seconds: _kToastSeconds), () {
        if (gs.toastMessage.value == message) {
          GameUtilMethods.setToastMessage(previous, gameState: gs);
        }
      });
    }
  }

  List<_WoundHit> _collectStartedTurns(
      Map<String, TurnsState> before, bool perStandee) {
    bool started(String key, TurnsState now) =>
        now == TurnsState.current &&
        (before[key] ?? TurnsState.notDone) == TurnsState.notDone;

    final hits = <_WoundHit>[];
    for (final item in turnGameState.currentList) {
      if (item is Character) {
        if (!started(_characterKey(item), item.turnState.value)) {
          continue;
        }
        _addHit(hits, item.characterState, item.id, item.id, item.id);
        for (final summon in item.characterState.summonList) {
          _addHit(hits, summon, summon.getId(), item.id, summon.name);
        }
      } else if (item is Monster) {
        final groupStarted = started(_monsterKey(item), item.turnState.value);
        for (final instance in item.monsterInstances) {
          final standeeStarted = perStandee
              ? started(_standeeKey(item, instance), instance.turnState)
              : groupStarted;
          if (standeeStarted) {
            _addHit(hits, instance, instance.getId(), item.id,
                '${item.type.display} ${instance.standeeNr}');
          }
        }
      }
    }
    return hits;
  }

  static void _addHit(List<_WoundHit> hits, FigureState figure,
      String figureId, String ownerId, String name) {
    final conditions = figure.conditions.value;
    if (figure.health.value <= 0 || figure.woundTakenThisRound) {
      return;
    }
    // Regenerate heals first at the start of the turn, and a heal removes
    // wound, so no wound damage is taken.
    if (conditions.contains(Condition.regenerate)) {
      return;
    }
    int damage = 0;
    if (conditions.contains(Condition.wound2)) {
      damage = 2;
    } else if (conditions.contains(Condition.wound)) {
      damage = 1;
    }
    if (damage == 0) {
      return;
    }
    // Frosthaven: ward halves the next damage (rounded down), brittle doubles
    // it; either is used up by it. With both, they cancel and both go.
    final hasWard = conditions.contains(Condition.ward);
    final hasBrittle = conditions.contains(Condition.brittle);
    final usedUp = <Condition>[];
    if (hasWard && hasBrittle) {
      usedUp.addAll([Condition.ward, Condition.brittle]);
    } else if (hasWard) {
      damage = damage ~/ 2;
      usedUp.add(Condition.ward);
    } else if (hasBrittle) {
      damage = damage * 2;
      usedUp.add(Condition.brittle);
    }
    hits.add(_WoundHit(figure, figureId, ownerId, name, damage, usedUp));
  }

  static String _characterKey(Character c) => 'c:${c.id}';
  static String _monsterKey(Monster m) => 'm:${m.id}';
  static String _standeeKey(Monster m, MonsterInstance i) =>
      's:${m.id}:${i.getId()}';
}

class _WoundHit {
  const _WoundHit(this.figure, this.figureId, this.ownerId, this.name,
      this.damage, this.usedUp);

  final FigureState figure;
  final String figureId;
  final String ownerId;
  final String name;
  final int damage;

  /// Ward and/or brittle consumed by this damage.
  final List<Condition> usedUp;
}
