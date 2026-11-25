import '../../Layout/MainList/main_list.dart';
import '../../services/service_locator.dart';
import '../../services/translation_service.dart';
import '../enums.dart';
import '../game_methods.dart';
import '../heart_attack.dart';
import '../settings.dart';
import '../state/game_state.dart';
import 'command_l10n.dart';
import 'turn_start_wounds.dart';

class DrawCommand extends Command with TurnStartWounds {
  final GameState _gameState;

  DrawCommand({required GameState gameState}) : _gameState = gameState;

  @override
  GameState get turnGameState => _gameState;

  @override
  void execute() {
    DeckMethods.drawAbilityCards(stateAccess);
    RoundMethods.sortByInitiative(stateAccess);
    RoundMethods.setRoundState(stateAccess, RoundState.playTurns);
    GameUtilMethods.clearBattleGoalReminder(gameState: _gameState);
    if (_gameState.currentList.isNotEmpty) {
      final before = snapshotTurns();
      RoundMethods.startTurn(stateAccess, _gameState.currentList.first);
      applyTurnStartWounds(before);
    }
    _maybeLittleHeartAttacks();

    Future.delayed(const Duration(milliseconds: 600), () {
      _gameState.updateList.notify();
      MainList.scrollToTop();
    });
  }

  /// A long rest (initiative 99) means a little heart attack: on Draw every
  /// healthy resting character adds one to their little tally, and one
  /// combined line names them. Only after Draw, so initiatives stay secret
  /// while they are being typed.
  void _maybeLittleHeartAttacks() {
    final settings = getIt.isRegistered<Settings>() ? getIt<Settings>() : null;
    if (settings == null || !settings.heartAttacks.value) {
      return;
    }
    if (!getIt.isRegistered<TranslationService>()) {
      return;
    }
    final translation = getIt<TranslationService>();
    final resting = GameMethods.getCurrentCharactersForState(_gameState)
        .where((c) =>
            !GameMethods.isObjectiveOrEscort(c.characterClass) &&
            c.characterState.initiative.value ==
                heartAttackLongRestInitiative &&
            c.characterState.health.value > 0)
        .toList();
    if (resting.isEmpty) {
      return;
    }
    for (final c in resting) {
      c.characterState.setLittleHeartAttacks(
        stateAccess,
        c.characterState.littleHeartAttacks.value + 1,
      );
    }
    final names =
        resting.map((c) => translation.t(c.characterClass.name)).toList();
    _gameState.heartAttackToast.value =
        heartAttackRecoveringLine(names, commandL10n);
  }

  @override
  String describe() {
    return commandL10n.cmdDraw;
  }
}
