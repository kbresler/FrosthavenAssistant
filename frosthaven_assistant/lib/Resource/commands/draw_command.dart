import '../../Layout/MainList/main_list.dart';
import '../enums.dart';
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
    if (_gameState.currentList.isNotEmpty) {
      final before = snapshotTurns();
      RoundMethods.startTurn(stateAccess, _gameState.currentList.first);
      applyTurnStartWounds(before);
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      _gameState.updateList.notify();
      MainList.scrollToTop();
    });
  }

  @override
  String describe() {
    return commandL10n.cmdDraw;
  }
}
