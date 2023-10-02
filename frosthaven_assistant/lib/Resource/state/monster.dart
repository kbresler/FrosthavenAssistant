import 'package:flutter/widgets.dart';

import '../../Model/monster.dart';
import '../../services/service_locator.dart';
import '../commands/change_stat_commands/change_health_command.dart';
import '../enums.dart';
import 'game_state.dart';
import 'list_item_data.dart';
import 'monster_instance.dart';

class Monster extends ListItemData {
  Monster(String name, int level, {required this.isAlly}) {
    id = name;
    this.level.value = level;
    GameState gameState = getIt<GameState>();
    Map<String, MonsterModel> monsters = {};
    for (String key in gameState.modelData.value.keys) {
      monsters.addAll(gameState.modelData.value[key]!.monsters);
    }
    for (String key in monsters.keys) {
      if (key == name) {
        type = monsters[key]!;
      }
    }

    GameMethods.addAbilityDeck(this);
  }
  late final MonsterModel type;
  final monsterInstances = ValueNotifier<List<MonsterInstance>>([]);
  final level = ValueNotifier<int>(0);
  bool isAlly;
  //note: this is only used for the no standee tracking setting
  bool isActive = false;

  // @override
  // bool isTurnState(TurnsState state) {
  //   return false;
  // }

  @override
  void setTurnState(TurnsState state, {bool init = false}) {
    if (init) {
      super.setTurnState(state);
    }
    GameState gameState = getIt<GameState>();
    if (!init && isTurnState(TurnsState.notDone)) {
      for (var instance in monsterInstances.value) {
        if (state == TurnsState.current &&
            instance.isTurnState(TurnsState.notDone)) {
          if (instance.conditions.value.contains(Condition.wound)) {
            gameState.action(ChangeHealthCommand(-1, instance.getId(), id));
            GameMethods.setToastMessage(
                "Wound applied to $id ${instance.standeeNr}!");
            Future.delayed(const Duration(milliseconds: 5000), () {
              GameMethods.setToastMessage("");
            });
          }

          if (instance.conditions.value.contains(Condition.stun)) {
            instance.turnState = TurnsState.done;
            continue;
          }

          instance.turnState = state;
          break;
        }

        instance.turnState = state;
      }
    }

    if (state == TurnsState.notDone) {
      for (var instance in monsterInstances.value) {
        instance.turnState = state;
      }
    }

    super.setTurnState(state);
  }

  bool hasElites() {
    for (var instance in monsterInstances.value) {
      if (instance.type == MonsterType.elite) {
        return true;
      }
    }
    return false;
  }

  //includes boss
  bool hasNormal() {
    for (var instance in monsterInstances.value) {
      if (instance.type != MonsterType.elite) {
        return true;
      }
    }
    return false;
  }

  void setLevel(int level) {
    this.level.value = level;
    for (var item in monsterInstances.value) {
      item.setLevel(this);
    }
  }

  @override
  String toString() {
    return '{'
        '"id": "$id", '
        '"turnState": ${getTurnState().index}, '
        '"isActive": $isActive, '
        '"type": "${type.name}", '
        '"monsterInstances": ${monsterInstances.value.toString()}, '
        //'"state": ${state.index}, '
        '"isAlly": $isAlly, '
        '"level": ${level.value} '
        '}';
  }

  Monster.fromJson(Map<String, dynamic> json) : isAlly = false {
    id = json['id'];
    setTurnState(TurnsState.values[json['turnState']], init: true);
    level.value = json['level'];
    if (json.containsKey("isAlly")) {
      isAlly = json['isAlly'];
    }
    if (json.containsKey("isActive")) {
      isActive = json['isActive'];
    }
    String modelName = json['type'];
    //state = ListItemState.values[json["state"]];

    GameState gameState = getIt<GameState>();
    Map<String, MonsterModel> monsters = {};
    for (String key in gameState.modelData.value.keys) {
      monsters.addAll(gameState.modelData.value[key]!.monsters);
    }
    for (var item in monsters.keys) {
      if (item == modelName) {
        type = monsters[item]!;
        break;
      }
    }

    List<dynamic> instanceList = json["monsterInstances"];

    List<MonsterInstance> newList = [];
    for (Map<String, dynamic> item in instanceList) {
      var instance = MonsterInstance.fromJson(item);
      newList.add(instance);
    }
    monsterInstances.value = newList;
  }
}
