import '../game_methods.dart';
import '../state/game_state.dart';
import 'command_l10n.dart';

/// Which kind of heart attack a manual adjustment touches.
enum HeartAttackKind { little, major }

/// Which period a manual adjustment touches.
enum HeartAttackPeriod { earlier, thisScenario }

/// Swerski: hand-corrects one of a hero's four heart-attack counts (little or
/// major, this scenario or earlier). Each tap of a +/− button is one of these,
/// so each is its own Undo step. Counts stay within 0..[max]; a tap at a bound
/// changes nothing. Deliberately produces no toast and no reply from another
/// hero — this is a bookkeeping fix, not an event.
class AdjustHeartAttacksCommand extends Command {
  AdjustHeartAttacksCommand({
    required this.characterId,
    required this.kind,
    required this.period,
    required this.change,
    required GameState gameState,
  }) : _gameState = gameState;

  static const int max = 99;

  final String characterId;
  final HeartAttackKind kind;
  final HeartAttackPeriod period;

  /// +1 or -1.
  final int change;

  final GameState _gameState;

  CharacterState? get _state =>
      GameMethods.getCharacterByName(characterId, gameState: _gameState)
          ?.characterState;

  int _current(CharacterState s) {
    if (kind == HeartAttackKind.little) {
      return period == HeartAttackPeriod.earlier
          ? s.littleHeartAttacksBefore.value
          : s.littleHeartAttacks.value;
    }
    return period == HeartAttackPeriod.earlier
        ? s.heartAttacksBefore.value
        : s.heartAttacks.value;
  }

  void _writeTo(CharacterState s, int value) {
    if (kind == HeartAttackKind.little) {
      if (period == HeartAttackPeriod.earlier) {
        s.setLittleHeartAttacksBefore(stateAccess, value);
      } else {
        s.setLittleHeartAttacks(stateAccess, value);
      }
    } else if (period == HeartAttackPeriod.earlier) {
      s.setHeartAttacksBefore(stateAccess, value);
    } else {
      s.setHeartAttacks(stateAccess, value);
    }
  }

  @override
  void execute() {
    final s = _state;
    if (s == null) {
      return;
    }
    var next = _current(s) + change;
    if (next < 0) {
      next = 0;
    }
    if (next > max) {
      next = max;
    }
    if (next != _current(s)) {
      _writeTo(s, next);
    }
  }

  @override
  String describe() {
    final l = commandL10n;
    final kindWord = kind == HeartAttackKind.little
        ? l.heartAttacksLittle
        : l.heartAttacksMajor;
    final periodWord = period == HeartAttackPeriod.earlier
        ? l.heartAttacksEarlier
        : l.heartAttacksThisScenario;
    return l.cmdAdjustHeartAttacks(
        characterId, kindWord, periodWord, change > 0 ? '+1' : '-1');
  }
}
