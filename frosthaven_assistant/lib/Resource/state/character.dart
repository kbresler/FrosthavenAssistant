import '../../Model/character_class.dart';
import '../../services/service_locator.dart';
import '../../Resource/commands/change_stat_commands/change_health_command.dart';
import '../enums.dart';
import 'character_state.dart';
import 'game_state.dart';
import 'list_item_data.dart';

class Character extends ListItemData {
  Character(this.characterState, this.characterClass) {
    id = characterState.display.value; //characterClass.name;
  }
  late final CharacterState characterState;
  late final CharacterClass characterClass;
  void nextRound() {
    if (characterClass.name != "Objective" && characterClass.name != "Escort") {
      characterState.initiative.value = 0;
    }
  }

  @override
  void setTurnState(TurnsState state, {bool init = false}) {
    if (!init && isTurnState(TurnsState.notDone)) {
      var conditions = characterState.conditions;
      if (state == TurnsState.current) {
        GameState gameState = getIt<GameState>();
        for (int i = conditions.value.length - 1; i >= 0; i--) {
          Condition item = conditions.value[i];
          if (item == Condition.wound) {
            //Future.delayed(const Duration(milliseconds: 600), () {
            gameState.action(ChangeHealthCommand(-1, id, id));
            GameMethods.setToastMessage("Wound applied to $id!");
            Future.delayed(const Duration(milliseconds: 5000), () {
              GameMethods.setToastMessage("");
            });
          }
        }
      }
    }

    super.setTurnState(state);
  }

  @override
  String toString() {
    return '{'
        '"id": "$id", '
        '"turnState": ${getTurnState().index}, '
        '"characterState": ${characterState.toString()}, '
        '"characterClass": "${characterClass.name}" '
        '}';
  }

  Character.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    setTurnState(TurnsState.values[json['turnState']], init: true);
    characterState = CharacterState.fromJson(json['characterState']);
    String className = json['characterClass'];
    GameState gameState = getIt<GameState>();
    List<CharacterClass> characters = [];
    for (String key in gameState.modelData.value.keys) {
      characters.addAll(gameState.modelData.value[key]!.characters);
    }
    for (var item in characters) {
      if (item.name == className) {
        characterClass = item;
        break;
      }
    }
  }
}
