import 'package:collection/collection.dart';

import '../state/game_state.dart';

class ShuffleDrawnAbilityCardCommand extends Command {
  final String deck;
  ShuffleDrawnAbilityCardCommand(this.deck);

  @override
  void execute() {
    Monster? monster = GameMethods.getCurrentMonsters()
        .firstWhereOrNull((element) => element.type.deck == deck);
    if (monster != null) {
      MonsterAbilityState? deck = GameMethods.getDeck(monster.type.deck);
      deck?.shuffleUnDrawn(stateAccess);
    }
  }

  @override
  void undo() {}

  @override
  String describe() {
    return "Drawn ability deck shuffle";
  }
}
