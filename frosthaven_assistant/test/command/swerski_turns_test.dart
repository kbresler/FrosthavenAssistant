// ignore_for_file: avoid-late-keyword, no-magic-number

import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_condition_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_monster_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_standee_command.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_health_command.dart';
import 'package:frosthaven_assistant/Resource/commands/draw_command.dart';
import 'package:frosthaven_assistant/Resource/commands/next_round_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_init_command.dart';
import 'package:frosthaven_assistant/Resource/commands/turn_done_command.dart';
import 'package:frosthaven_assistant/Resource/game_data.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import 'test_helpers.dart';

/// Swerski edition: monster turns one standee at a time, and automatic wound
/// damage at the start of a turn.
void main() {
  setUpAll(() async {
    await setUpGame();
  });

  late GameState gs;
  late Settings settings;
  late Character character;
  late Monster monster;

  void turnDone(String id) => TurnDoneCommand(id, gameState: gs).execute();

  List<TurnsState> standeeTurns() =>
      monster.monsterInstances.map((i) => i.turnState).toList();

  MonsterInstance standee(int nr) =>
      monster.monsterInstances.firstWhere((i) => i.standeeNr == nr);

  void addCondition(Condition condition, String figureId, String ownerId) =>
      AddConditionCommand(condition, figureId, ownerId, gameState: gs)
          .execute();

  setUp(() {
    gs = getIt<GameState>();
    settings = getIt<Settings>();
    settings.perStandeeTurns.value = true;
    settings.autoApplyWounds.value = true;
    gs.clearList();
    AddCharacterCommand('Banner Spear', 'Frosthaven', 'BS', 1).execute();
    AddMonsterCommand('Zealot', 1, false, gameState: gs).execute();
    character = gs.currentList.whereType<Character>().first;
    monster = gs.currentList.whereType<Monster>().first;
    for (final nr in [1, 2, 3]) {
      AddStandeeCommand(nr, null, monster.id, MonsterType.normal, false,
              gameState: gs)
          .execute();
    }
  });

  group('one standee at a time', () {
    test('tapping the group walks through its standees, then ends it', () {
      turnDone(monster.id);
      expect(monster.turnState.value, TurnsState.current);
      expect(standeeTurns(),
          [TurnsState.current, TurnsState.notDone, TurnsState.notDone]);

      turnDone(monster.id);
      expect(monster.turnState.value, TurnsState.current);
      expect(standeeTurns(),
          [TurnsState.done, TurnsState.current, TurnsState.notDone]);

      turnDone(monster.id);
      expect(standeeTurns(),
          [TurnsState.done, TurnsState.done, TurnsState.current]);

      turnDone(monster.id);
      expect(monster.turnState.value, TurnsState.done);
      expect(standeeTurns(), everyElement(TurnsState.done));
    });

    test('a stunned standee loses its turn', () {
      addCondition(Condition.stun, standee(2).getId(), monster.id);

      turnDone(monster.id);
      turnDone(monster.id);

      expect(standeeTurns(),
          [TurnsState.done, TurnsState.done, TurnsState.current]);
    });

    test('with the setting off, one tap ends the whole group', () {
      settings.perStandeeTurns.value = false;

      turnDone(monster.id);
      expect(standeeTurns(), everyElement(TurnsState.notDone));

      turnDone(monster.id);
      expect(monster.turnState.value, TurnsState.done);
      expect(standeeTurns(), everyElement(TurnsState.done));
    });

    test('standees added after the group went are the only ones to go', () {
      for (int i = 0; i < 4; i++) {
        turnDone(monster.id); // start, then standees 1-3, group done
      }
      expect(monster.turnState.value, TurnsState.done);

      // A door reveals standee 4 of the same group.
      AddStandeeCommand(4, null, monster.id, MonsterType.normal, false,
              gameState: gs)
          .execute();
      turnDone(monster.id); // the group gets a turn again

      expect(monster.turnState.value, TurnsState.current);
      expect(standeeTurns(), [
        TurnsState.done,
        TurnsState.done,
        TurnsState.done,
        TurnsState.current,
      ]);

      turnDone(monster.id); // standee 4 done: the group is done again
      expect(monster.turnState.value, TurnsState.done);
    });

    test('replaying a group where everyone went lets them all go again', () {
      for (int i = 0; i < 4; i++) {
        turnDone(monster.id);
      }
      turnDone(monster.id); // tap the finished group again

      expect(standeeTurns(),
          [TurnsState.current, TurnsState.notDone, TurnsState.notDone]);
    });

    test('standee turn state survives save and load', () {
      turnDone(monster.id);
      turnDone(monster.id);

      checkSaveState();
      expect(standeeTurns(),
          [TurnsState.done, TurnsState.current, TurnsState.notDone]);
    });
  });

  group('conditions drop off with the standee\'s own turn', () {
    setUp(() {
      settings.expireConditions.value = true;
    });

    List<Condition> of(int nr) => standee(nr).conditions.value.toList();

    void add(Condition condition, int nr) =>
        addCondition(condition, standee(nr).getId(), monster.id);

    // Draws the round with the monster group going first, standee 1 up.
    void draw() {
      SetInitCommand(character.id, 99, gameState: gs).execute();
      DrawCommand(gameState: gs).execute();
      expect(standee(1).turnState, TurnsState.current);
    }

    test('at the end of that standee, not of the group', () {
      add(Condition.muddle, 1);

      turnDone(monster.id); // standee 1
      expect(of(1), contains(Condition.muddle));
      turnDone(monster.id); // standee 2

      expect(of(1), isNot(contains(Condition.muddle)));
    });

    test('a skipped standee loses its stun as it is passed over', () {
      add(Condition.stun, 2);

      turnDone(monster.id); // standee 1
      turnDone(monster.id); // 2 is passed over, standee 3

      expect(of(2), isNot(contains(Condition.stun)));
    });

    test('a stun put on a waiting standee costs one turn, not two', () {
      draw();
      add(Condition.stun, 2); // while standee 1 is acting

      turnDone(monster.id); // 2 is passed over, standee 3

      expect(standee(3).turnState, TurnsState.current);
      expect(of(2), isNot(contains(Condition.stun)));
    });

    test('a condition gained on its own turn stays for the next one', () {
      draw();
      add(Condition.muddle, 1);

      for (int i = 0; i < 3; i++) {
        turnDone(monster.id); // standees 1-3, group done
      }

      expect(monster.turnState.value, TurnsState.done);
      expect(of(1), contains(Condition.muddle));
    });

    test('only one chill comes off', () {
      add(Condition.chill, 1);
      add(Condition.chill, 1);

      for (int i = 0; i < 4; i++) {
        turnDone(monster.id); // start, standees 1-3, group done
      }

      expect(monster.turnState.value, TurnsState.done);
      expect(of(1), [Condition.chill]);
    });

    test('the next round ends the turn of standees that never went', () {
      add(Condition.muddle, 3);

      NextRoundCommand(
              gameState: gs, gameData: getIt<GameData>(), settings: settings)
          .execute();

      expect(of(3), isNot(contains(Condition.muddle)));
      expect(standeeTurns(), everyElement(TurnsState.notDone));
    });

    test('going back gives the condition back', () {
      add(Condition.muddle, 1);
      turnDone(monster.id); // standee 1
      turnDone(monster.id); // standee 2

      turnDone(character.id); // back to the character

      expect(of(1), contains(Condition.muddle));
    });

    test('a finished standee keeps it off when late standees take a turn', () {
      add(Condition.muddle, 1);
      for (int i = 0; i < 4; i++) {
        turnDone(monster.id);
      }
      AddStandeeCommand(4, null, monster.id, MonsterType.normal, false,
              gameState: gs)
          .execute();

      turnDone(monster.id); // standee 4 only
      turnDone(monster.id); // group done

      expect(of(1), isNot(contains(Condition.muddle)));
    });

    test('replaying the whole group gives the condition back', () {
      add(Condition.muddle, 1);
      for (int i = 0; i < 4; i++) {
        turnDone(monster.id);
      }

      turnDone(monster.id); // everyone goes again

      expect(of(1), contains(Condition.muddle));
    });
  });

  group('wound at start of turn', () {
    test('a wounded character loses 1 health when its turn starts', () {
      addCondition(Condition.wound, character.id, character.id);
      final health = character.characterState.health.value;

      turnDone(character.id);

      expect(character.characterState.health.value, health - 1);
      expect(gs.toastMessage.value, contains('Wound damage'));
    });

    test('replaying a finished turn does not wound twice', () {
      addCondition(Condition.wound, character.id, character.id);
      final health = character.characterState.health.value;

      turnDone(character.id); // starts: -1
      turnDone(character.id); // done
      turnDone(character.id); // current again (replay)

      expect(character.characterState.health.value, health - 1);
    });

    test('going back resets later figures; their wound is not repeated', () {
      final nr1 = standee(1);
      addCondition(Condition.wound, nr1.getId(), monster.id);
      final health = nr1.health.value;

      turnDone(monster.id); // monster group starts, standee 1: -1
      expect(nr1.health.value, health - 1);
      turnDone(character.id); // back to the character (monster reset)
      turnDone(character.id); // character done, monster starts again

      expect(nr1.health.value, health - 1);
      expect(nr1.turnState, TurnsState.current);
    });

    test('a new round allows wound damage again', () {
      addCondition(Condition.wound, character.id, character.id);
      final health = character.characterState.health.value;

      turnDone(character.id); // -1
      NextRoundCommand(
              gameState: gs, gameData: getIt<GameData>(), settings: settings)
          .execute();
      turnDone(character.id); // next round's turn: -1 again

      expect(character.characterState.health.value, health - 2);
    });

    test('a standee is wounded when its own turn starts', () {
      addCondition(Condition.wound, standee(2).getId(), monster.id);
      final health = standee(2).health.value;

      turnDone(monster.id); // standee 1 starts
      expect(standee(2).health.value, health);

      turnDone(monster.id); // standee 2 starts
      expect(standee(2).health.value, health - 1);
    });

    test('a standee killed by its wound is skipped', () {
      final nr2 = standee(2);
      addCondition(Condition.wound, nr2.getId(), monster.id);
      ChangeHealthCommand(1 - nr2.health.value, nr2.getId(), monster.id,
              gameState: gs)
          .execute();

      turnDone(monster.id); // standee 1
      turnDone(monster.id); // standee 2 dies, standee 3 goes

      expect(monster.monsterInstances.map((i) => i.standeeNr), [1, 3]);
      expect(standee(3).turnState, TurnsState.current);
      expect(monster.turnState.value, TurnsState.current);
    });

    test('regenerate prevents the wound damage', () {
      addCondition(Condition.wound, character.id, character.id);
      addCondition(Condition.regenerate, character.id, character.id);
      final health = character.characterState.health.value;

      turnDone(character.id);

      expect(character.characterState.health.value, health);
    });

    List<Condition> characterConditions() =>
        character.characterState.conditions.value;

    test('ward halves the wound damage (1 becomes 0) and is used up', () {
      addCondition(Condition.wound, character.id, character.id);
      addCondition(Condition.ward, character.id, character.id);
      final health = character.characterState.health.value;

      turnDone(character.id);

      expect(character.characterState.health.value, health);
      expect(characterConditions(), isNot(contains(Condition.ward)));
      expect(characterConditions(), contains(Condition.wound));
    });

    test('brittle doubles the wound damage and is used up', () {
      addCondition(Condition.wound, character.id, character.id);
      addCondition(Condition.brittle, character.id, character.id);
      final health = character.characterState.health.value;

      turnDone(character.id);

      expect(character.characterState.health.value, health - 2);
      expect(characterConditions(), isNot(contains(Condition.brittle)));
    });

    test('ward and brittle together cancel out and are both used up', () {
      addCondition(Condition.wound, character.id, character.id);
      addCondition(Condition.ward, character.id, character.id);
      addCondition(Condition.brittle, character.id, character.id);
      final health = character.characterState.health.value;

      turnDone(character.id);

      expect(character.characterState.health.value, health - 1);
      expect(characterConditions(), isNot(contains(Condition.ward)));
      expect(characterConditions(), isNot(contains(Condition.brittle)));
    });

    test('ward on a standee with double wound: 2 becomes 1', () {
      final nr1 = standee(1);
      addCondition(Condition.wound2, nr1.getId(), monster.id);
      addCondition(Condition.ward, nr1.getId(), monster.id);
      final health = nr1.health.value;

      turnDone(monster.id);

      expect(nr1.health.value, health - 1);
      expect(nr1.conditions.value, isNot(contains(Condition.ward)));
    });

    // Stun takes the turn away, not what happens at the start of it.
    void stunAndWound(int nr) {
      addCondition(Condition.stun, standee(nr).getId(), monster.id);
      addCondition(Condition.wound, standee(nr).getId(), monster.id);
    }

    test('a stunned character is still wounded', () {
      addCondition(Condition.stun, character.id, character.id);
      addCondition(Condition.wound, character.id, character.id);
      final health = character.characterState.health.value;

      turnDone(character.id);

      expect(character.characterState.health.value, health - 1);
    });

    test('a stunned standee is wounded when it is skipped', () {
      stunAndWound(2);
      final health = standee(2).health.value;

      turnDone(monster.id); // standee 1 starts
      expect(standee(2).health.value, health);
      turnDone(monster.id); // standee 2 is skipped, standee 3 starts

      expect(standee(2).health.value, health - 1);
      expect(standeeTurns(),
          [TurnsState.done, TurnsState.done, TurnsState.current]);
      expect(gs.toastMessage.value, contains('Wound damage'));
    });

    test('a stunned first standee is wounded when the group starts', () {
      stunAndWound(1);
      final health = standee(1).health.value;

      turnDone(monster.id);

      expect(standee(1).health.value, health - 1);
      expect(standee(2).turnState, TurnsState.current);
    });

    test('a stunned last standee is wounded as the group finishes', () {
      stunAndWound(3);
      final health = standee(3).health.value;

      turnDone(monster.id); // standee 1
      turnDone(monster.id); // standee 2
      turnDone(monster.id); // standee 3 is skipped, group done

      expect(monster.turnState.value, TurnsState.done);
      expect(standee(3).health.value, health - 1);
    });

    // A second group, after the first one in the list.
    Monster addSecondGroup() {
      AddMonsterCommand('Ancient Artillery (FH)', 1, false, gameState: gs)
          .execute();
      final second = gs.currentList.whereType<Monster>().last;
      for (final nr in [1, 2]) {
        AddStandeeCommand(nr, null, second.id, MonsterType.normal, false,
                gameState: gs)
            .execute();
      }
      return second;
    }

    test('an all-stunned group is wounded and passes to the next group', () {
      final second = addSecondGroup();
      for (final nr in [1, 2, 3]) {
        stunAndWound(nr);
      }
      final health = standee(1).health.value;
      final next = second.monsterInstances.first;
      addCondition(Condition.wound, next.getId(), second.id);
      final nextHealth = next.health.value;

      turnDone(monster.id);

      expect(monster.monsterInstances.map((i) => i.health.value),
          everyElement(health - 1));
      expect(monster.turnState.value, TurnsState.done);
      expect(second.turnState.value, TurnsState.current);
      expect(next.turnState, TurnsState.current);
      expect(next.health.value, nextHealth - 1);
    });

    test('finishing a standee passes over stunned ones into the next group', () {
      final second = addSecondGroup();
      stunAndWound(2);
      stunAndWound(3);
      final health = standee(2).health.value;

      turnDone(monster.id); // standee 1
      turnDone(monster.id); // 2 and 3 are stunned: on to the next group

      expect(standee(2).health.value, health - 1);
      expect(standee(3).health.value, health - 1);
      expect(monster.turnState.value, TurnsState.done);
      expect(second.monsterInstances.first.turnState, TurnsState.current);
    });

    test('Draw passes over an all-stunned first group', () {
      for (final nr in [1, 2, 3]) {
        stunAndWound(nr);
      }
      final health = standee(1).health.value;
      // Monster cards are always below 99, so the group goes first.
      SetInitCommand(character.id, 99, gameState: gs).execute();

      DrawCommand(gameState: gs).execute();

      expect(gs.currentList.first, monster);
      expect(monster.turnState.value, TurnsState.done);
      expect(character.turnState.value, TurnsState.current);
      expect(monster.monsterInstances.map((i) => i.health.value),
          everyElement(health - 1));
    });

    test('a stunned standee killed by its wound is removed', () {
      stunAndWound(2);
      ChangeHealthCommand(
              1 - standee(2).health.value, standee(2).getId(), monster.id,
              gameState: gs)
          .execute();

      turnDone(monster.id); // standee 1
      turnDone(monster.id); // standee 2 dies, standee 3 goes

      expect(monster.monsterInstances.map((i) => i.standeeNr), [1, 3]);
      expect(standee(3).turnState, TurnsState.current);
    });

    test('a group wiped out by wounds while stunned ends its turn', () {
      for (final nr in [1, 2, 3]) {
        stunAndWound(nr);
        ChangeHealthCommand(
                1 - standee(nr).health.value, standee(nr).getId(), monster.id,
                gameState: gs)
            .execute();
      }

      turnDone(monster.id);

      expect(monster.monsterInstances, isEmpty);
      expect(monster.turnState.value, TurnsState.done);
    });

    test('a stunned standee reached after a wound death is wounded too', () {
      addCondition(Condition.wound, standee(1).getId(), monster.id);
      ChangeHealthCommand(
              1 - standee(1).health.value, standee(1).getId(), monster.id,
              gameState: gs)
          .execute();
      stunAndWound(2);
      final health = standee(2).health.value;

      turnDone(monster.id); // standee 1 dies, 2 is skipped, 3 goes

      expect(standee(2).health.value, health - 1);
      expect(standee(3).turnState, TurnsState.current);
    });

    test('nothing happens with the setting off', () {
      settings.autoApplyWounds.value = false;
      addCondition(Condition.wound, character.id, character.id);
      final health = character.characterState.health.value;

      turnDone(character.id);

      expect(character.characterState.health.value, health);
    });
  });
}
