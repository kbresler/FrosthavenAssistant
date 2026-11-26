import '../../services/service_locator.dart';
import '../enums.dart';
import '../game_methods.dart';
import '../settings.dart';
import '../state/game_state.dart';
import 'command_l10n.dart';

class AddConditionCommand extends Command {
  final Condition condition;
  final String? ownerId;
  final String figureId;
  final GameState _gameState;

  AddConditionCommand(this.condition, this.figureId, this.ownerId,
      {required GameState gameState})
      : _gameState = gameState;

  @override
  void execute() {
    FigureState? figure = GameMethods.getFigure(ownerId, figureId);
    if (figure != null) {
      List<Condition> newList = [];
      newList.addAll(figure.conditions.value);
      if (!newList.contains(condition) || //block from adding same condition
          condition == Condition.chill ||
          condition == Condition.plague) {
        newList.add(condition);
      }
      figure.setConditions(stateAccess, newList);

      if (condition == Condition.chill) {
        figure.setChill(stateAccess, figure.chill.value + 1);
      }
      if (condition == Condition.plague) {
        figure.setPlague(stateAccess, figure.plague.value + 1);
      }

      //only added this turn if is current or done
      final perStandee = getIt.isRegistered<Settings>() &&
          getIt<Settings>().perStandeeTurns.value;
      for (final item in _gameState.currentList) {
        if (item.id == ownerId) {
          // Swerski: with one standee at a time, its turn is its own, not the
          // group's, or a waiting standee would keep the condition a round.
          final turn =
              perStandee && item is Monster && figure is MonsterInstance
                  ? figure.turnState
                  : item.turnState.value;
          if (turn != TurnsState.notDone &&
              _gameState.roundState.value == RoundState.playTurns) {
            figure.addToConditionsThisTurn(stateAccess, condition);
          }
        }
      }
      _gameState.updateList.notify();
    }
  }

  @override
  String describe() {
    return commandL10n.cmdAddCondition(condition.getName());
  }
}
