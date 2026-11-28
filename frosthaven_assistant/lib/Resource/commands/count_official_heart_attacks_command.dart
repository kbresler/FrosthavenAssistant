import '../enums.dart';
import '../game_methods.dart';
import '../heart_attack.dart';
import '../state/game_state.dart';

/// Counts heart attacks for characters an official app player controls.
///
/// An official app never counts them itself: its snapshots carry no
/// `heartAttacks` keys. The host runs this after loading such a snapshot —
/// for the characters that came without the keys — and writes the counts
/// itself, so they are saved, sent on to the other clients and undoable.
///
/// A major: the character was above 0 health before this update and sits at
/// 0 now. A little: the round went from choosing initiative to playing turns
/// (a Draw) while the character rests on initiative 99 with health above 0.
/// Objectives and Escorts never count, and neither does a character the host
/// did not have before. No toast is raised here: the host's own after-load
/// comparison spots the counts and writes the line.
class CountOfficialHeartAttacksCommand extends Command {
  final Set<String> _officialIds;
  final Map<String, ({int health, int major, int little})> _before;
  final RoundState _roundBefore;
  final GameState _gameState;

  CountOfficialHeartAttacksCommand({
    required Set<String> officialIds,
    required Map<String, ({int health, int major, int little})> before,
    required RoundState roundBefore,
    required GameState gameState,
  })  : _officialIds = officialIds,
        _before = before,
        _roundBefore = roundBefore,
        _gameState = gameState;

  @override
  void execute() {
    final drawn = _roundBefore == RoundState.chooseInitiative &&
        _gameState.roundState.value == RoundState.playTurns;
    for (final id in _officialIds) {
      final was = _before[id];
      if (was == null) {
        continue; // not on the table before this update
      }
      final character =
          GameMethods.getCharacterByName(id, gameState: _gameState);
      if (character == null ||
          GameMethods.isObjectiveOrEscort(character.characterClass)) {
        continue;
      }
      final state = character.characterState;
      if (was.health > 0 && state.health.value == 0) {
        state.setHeartAttacks(stateAccess, state.heartAttacks.value + 1);
      } else if (drawn &&
          state.initiative.value == heartAttackLongRestInitiative &&
          state.health.value > 0) {
        state.setLittleHeartAttacks(
          stateAccess,
          state.littleHeartAttacks.value + 1,
        );
      }
    }
  }

  @override
  String describe() {
    // The server calls execute() directly, never through the action
    // handler, so this description is never shown.
    return '';
  }
}
