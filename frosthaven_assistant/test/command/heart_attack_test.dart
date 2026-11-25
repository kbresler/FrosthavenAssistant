// ignore_for_file: no-magic-number, avoid-late-keyword

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_monster_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_standee_command.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_health_command.dart';
import 'package:frosthaven_assistant/Resource/commands/draw_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_init_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_scenario_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/game_methods.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  late GameState gs;
  late Character blinkblade;

  setUp(() {
    gs = getIt<GameState>();
    gs.clearList();
    gs.heartAttackToast.value = '';
    getIt<Settings>().heartAttacks.value = true;
    AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
    blinkblade = gs.currentList.whereType<Character>().first;
  });

  Character addSpear() {
    AddCharacterCommand('Banner Spear', 'Frosthaven', null, 1).execute();
    return gs.currentList.whereType<Character>().firstWhere((c) => c != blinkblade);
  }

  void hit(Character c, [int damage = 1000]) {
    ChangeHealthCommand(-damage, c.id, c.id, gameState: gs).execute();
  }

  void heal(Character c) {
    ChangeHealthCommand(5, c.id, c.id, gameState: gs).execute();
  }

  void rest(Character c) {
    SetInitCommand(c.id, 99, gameState: gs).execute();
  }

  void draw() {
    DrawCommand(gameState: gs).execute();
  }

  void newScenario() {
    gs.action(SetScenarioCommand('custom', false, gameState: gs));
  }

  int major(Character c) => c.characterState.heartAttacks.value;
  int little(Character c) => c.characterState.littleHeartAttacks.value;

  // After gs.undo() the character objects are rebuilt from a snapshot, so
  // these re-fetch by the (stable) id rather than a stale reference.
  int majorById(String id) => gs.currentList
      .whereType<Character>()
      .firstWhere((c) => c.id == id)
      .characterState
      .heartAttacks
      .value;
  int littleById(String id) => gs.currentList
      .whereType<Character>()
      .firstWhere((c) => c.id == id)
      .characterState
      .littleHeartAttacks
      .value;

  // DrawCommand notifies on a 600 ms delay; drain it so no timer is pending.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  group('Major heart attack count', () {
    test('counts once when health drops from above zero to zero', () {
      hit(blinkblade);
      expect(blinkblade.characterState.health.value, 0);
      expect(major(blinkblade), 1);
    });

    test('does not count again while already at zero', () {
      hit(blinkblade);
      hit(blinkblade, 1);
      expect(major(blinkblade), 1);
    });

    test('healing never clears the count', () {
      hit(blinkblade);
      heal(blinkblade);
      expect(blinkblade.characterState.health.value, 5);
      expect(major(blinkblade), 1);
    });

    test('a second heart attack counts up', () {
      hit(blinkblade);
      heal(blinkblade);
      hit(blinkblade);
      expect(major(blinkblade), 2);
    });

    test('a standee hitting zero is not a heart attack', () {
      addSpear();
      AddMonsterCommand('Zealot', 1, false, gameState: gs).execute();
      AddStandeeCommand(
        1,
        null,
        'Zealot',
        MonsterType.normal,
        false,
        gameState: gs,
      ).execute();
      final monster = gs.currentList.whereType<Monster>().first;
      final standee = monster.monsterInstances.first;
      ChangeHealthCommand(-1000, standee.getId(), monster.id, gameState: gs)
          .execute();
      expect(major(blinkblade), 0);
      expect(gs.heartAttackToast.value, isEmpty);
    });

    test('a summon hitting zero is not a heart attack', () {
      addSpear();
      final summonData = SummonData(1, 'Test Summon', 10, 2, 2, 0, 'test_gfx');
      AddStandeeCommand(
        1,
        summonData,
        blinkblade.id,
        MonsterType.summon,
        true,
        gameState: gs,
      ).execute();
      final summon = blinkblade.characterState.summonList.first;
      ChangeHealthCommand(
        -1000,
        summon.getId(),
        blinkblade.id,
        gameState: gs,
      ).execute();
      expect(major(blinkblade), 0);
      expect(gs.heartAttackToast.value, isEmpty);
    });

    test('an Objective hitting zero is not a heart attack', () {
      addSpear();
      AddCharacterCommand('Objective', 'na', 'whatever', 1).execute();
      final objective = gs.currentList
          .whereType<Character>()
          .firstWhere((c) => GameMethods.isObjectiveOrEscort(c.characterClass));
      hit(objective);
      expect(objective.characterState.health.value, 0);
      expect(objective.characterState.heartAttacks.value, 0);
      expect(gs.heartAttackToast.value, isEmpty);
    });

    test('setting off: no count and no toast', () {
      getIt<Settings>().heartAttacks.value = false;
      addTearDown(() => getIt<Settings>().heartAttacks.value = true);
      hit(blinkblade);
      expect(major(blinkblade), 0);
      expect(gs.heartAttackToast.value, isEmpty);
    });

    test('undoing the hit removes the heart attack again', () {
      // A baseline action first: undo restores the last saved snapshot, and
      // only gameState.action() saves one.
      gs.action(SetInitCommand(blinkblade.id, 5, gameState: gs));
      gs.action(
          ChangeHealthCommand(-1000, blinkblade.id, blinkblade.id,
              gameState: gs));
      expect(major(blinkblade), 1);
      gs.undo();
      expect(majorById(blinkblade.id), 0);
    });
  });

  group('Little heart attack count', () {
    testWidgets('a healthy character resting on 99 gains one, not a major',
        (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      rest(blinkblade);
      draw();
      expect(little(blinkblade), 1);
      expect(major(blinkblade), 0);
      await settle(tester);
    });

    testWidgets('each Draw at 99 adds one more', (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      rest(blinkblade);
      draw();
      draw();
      expect(little(blinkblade), 2);
      await settle(tester);
    });

    testWidgets('an unwounded character at zero health does not gain one',
        (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      hit(blinkblade); // now at 0 health
      rest(blinkblade);
      draw();
      expect(little(blinkblade), 0);
      await settle(tester);
    });

    testWidgets('an initiative that is not 99 does not gain one',
        (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      SetInitCommand(blinkblade.id, 5, gameState: gs).execute();
      draw();
      expect(little(blinkblade), 0);
      await settle(tester);
    });

    testWidgets('an Objective resting does not gain one', (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      AddCharacterCommand('Objective', 'na', 'whatever', 1).execute();
      final objective = gs.currentList
          .whereType<Character>()
          .firstWhere((c) => GameMethods.isObjectiveOrEscort(c.characterClass));
      rest(objective);
      draw();
      expect(objective.characterState.littleHeartAttacks.value, 0);
      await settle(tester);
    });

    testWidgets('setting off: no little count', (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      getIt<Settings>().heartAttacks.value = false;
      addTearDown(() => getIt<Settings>().heartAttacks.value = true);
      rest(blinkblade);
      draw();
      expect(little(blinkblade), 0);
      await settle(tester);
    });

    testWidgets('undoing the Draw restores the little count', (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      rest(blinkblade);
      gs.action(DrawCommand(gameState: gs));
      expect(little(blinkblade), 1);
      gs.undo();
      expect(littleById(blinkblade.id), 0);
      await settle(tester);
    });

    testWidgets('two resting characters each gain one, on one toast',
        (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      final spear = addSpear();
      rest(blinkblade);
      rest(spear);
      draw();
      expect(little(blinkblade), 1);
      expect(little(spear), 1);
      expect(gs.heartAttackToast.value,
          contains('each had a little heart attack'));
      expect(gs.heartAttackToast.value, contains('Blinkblade'));
      expect(gs.heartAttackToast.value, contains('Banner Spear'));
      await settle(tester);
    });
  });

  group('Reply toast', () {
    test('another character comments on the acting device', () {
      addSpear();
      hit(blinkblade);
      expect(gs.heartAttackToast.value, startsWith('Banner Spear: '));
      expect(gs.heartAttackToast.value, contains('Blinkblade'));
    });

    test('nobody else in the scenario, nobody speaks', () {
      hit(blinkblade);
      expect(gs.heartAttackToast.value, isEmpty);
    });

    test('the toast is never serialised', () {
      addSpear();
      hit(blinkblade);
      expect(gs.heartAttackToast.value, isNotEmpty);
      expect(gs.toString(), isNot(contains(gs.heartAttackToast.value)));
    });

    testWidgets('the victim count totals little attacks, not just majors',
        (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      addSpear(); // a speaker with no attacks → the repeat pool
      rest(blinkblade);
      draw(); // one little heart attack
      await settle(tester);
      hit(blinkblade); // and now a major: total 2, so past the first-attack line
      expect(blinkblade.characterState.totalHeartAttacks, 2);
      // Repeat lines all carry the count; a first attack would say none.
      expect(gs.heartAttackToast.value, contains('2'));
      expect(gs.heartAttackToast.value, isNot(contains('first')));
    });

    testWidgets('a speaker is scored on little attacks too', (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      final spear = addSpear();
      // Blinkblade ends on 2 (1 little + the major below), Spear on 2 little.
      rest(blinkblade);
      rest(spear);
      draw(); // both little = 1
      SetInitCommand(blinkblade.id, 5, gameState: gs)
          .execute(); // drop Blinkblade out of 99
      draw(); // Spear little = 2, Blinkblade stays 1
      await settle(tester);
      expect(little(blinkblade), 1);
      expect(little(spear), 2);
      hit(blinkblade); // major → total 2, level with Spear's 2
      expect(blinkblade.characterState.totalHeartAttacks, 2);
      expect(spear.characterState.totalHeartAttacks, 2);
      // Only a level score produces the "level on" line.
      expect(gs.heartAttackToast.value, startsWith('Banner Spear: '));
      expect(gs.heartAttackToast.value, contains('level on'));
      expect(gs.heartAttackToast.value, contains('2'));
    });
  });

  group('Scenario fold', () {
    testWidgets('a new scenario folds both kinds into "earlier"',
        (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      hit(blinkblade); // major this scenario
      heal(blinkblade);
      rest(blinkblade);
      draw(); // little this scenario
      await settle(tester);
      newScenario();
      final st = blinkblade.characterState;
      expect(st.heartAttacksBefore.value, 1);
      expect(st.littleHeartAttacksBefore.value, 1);
      expect(st.heartAttacks.value, 0);
      expect(st.littleHeartAttacks.value, 0);
      expect(st.totalHeartAttacks, 2);
    });

    testWidgets('a second scenario change folds nothing new', (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      hit(blinkblade);
      heal(blinkblade);
      rest(blinkblade);
      draw();
      await settle(tester);
      newScenario();
      newScenario();
      final st = blinkblade.characterState;
      expect(st.heartAttacksBefore.value, 1);
      expect(st.littleHeartAttacksBefore.value, 1);
      expect(st.totalHeartAttacks, 2);
    });
  });

  group('Heart attack serialisation', () {
    test('all four tallies round-trip through toJson/fromJson', () {
      final json = blinkblade.characterState.toJson()
        ..['heartAttacks'] = 3
        ..['heartAttacksBefore'] = 2
        ..['littleHeartAttacks'] = 5
        ..['littleHeartAttacksBefore'] = 4;
      final revived = CharacterState.fromJson('Blinkblade', json);
      expect(revived.heartAttacks.value, 3);
      expect(revived.heartAttacksBefore.value, 2);
      expect(revived.littleHeartAttacks.value, 5);
      expect(revived.littleHeartAttacksBefore.value, 4);
      expect(revived.totalHeartAttacks, 14);
    });

    test('missing keys default to zero and a sync clears them', () {
      final json = blinkblade.characterState.toJson()
        ..['heartAttacks'] = 3
        ..['littleHeartAttacks'] = 5;
      final official = Map<String, dynamic>.from(json)
        ..remove('heartAttacks')
        ..remove('heartAttacksBefore')
        ..remove('littleHeartAttacks')
        ..remove('littleHeartAttacksBefore');
      final revived = CharacterState.fromJson('Blinkblade', json);
      expect(revived.heartAttacks.value, 3);
      expect(revived.littleHeartAttacks.value, 5);
      // Official-app state has none of the keys: sync resets all four to zero.
      revived.updateFromJson('Blinkblade', official);
      expect(revived.heartAttacks.value, 0);
      expect(revived.heartAttacksBefore.value, 0);
      expect(revived.littleHeartAttacks.value, 0);
      expect(revived.littleHeartAttacksBefore.value, 0);
    });

    test('state without the key defaults to zero and resets on sync', () {
      hit(blinkblade);
      final json = blinkblade.characterState.toJson();
      final official = Map<String, dynamic>.from(json)..remove('heartAttacks');
      // Old saves and official-app state: no key, no heart attack.
      expect(CharacterState.fromJson('Blinkblade', official).heartAttacks.value,
          0);
      final revived = CharacterState.fromJson('Blinkblade', json);
      expect(revived.heartAttacks.value, 1);
      // Syncing official-app state over a Swerski state clears it, not sticks.
      revived.updateFromJson('Blinkblade', official);
      expect(revived.heartAttacks.value, 0);
    });

    testWidgets('a save carries per-kind all-time totals into the earlier '
        'tallies', (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      hit(blinkblade); // major this scenario
      heal(blinkblade);
      rest(blinkblade);
      draw(); // little this scenario
      await settle(tester);
      newScenario(); // fold: both become "earlier", current resets
      hit(blinkblade); // one fresh major, so major totals sum 1 + 1
      final saved = blinkblade.characterState.toSave();
      expect(saved, contains('"heartAttacks": 2'));
      expect(saved, contains('"littleHeartAttacks": 1'));
      final fromSave =
          CharacterState.fromSave('Blinkblade', jsonDecode(saved));
      expect(fromSave.heartAttacksBefore.value, 2);
      expect(fromSave.littleHeartAttacksBefore.value, 1);
      // A loaded save starts a fresh scenario: nothing counted "this scenario".
      expect(fromSave.heartAttacks.value, 0);
      expect(fromSave.littleHeartAttacks.value, 0);
    });

    test('a full game state sync keeps and clears the count', () {
      hit(blinkblade);
      final data = gs.toString();
      gs.loadFromData(data);
      expect(major(blinkblade), 1);

      final official = jsonDecode(data) as Map<String, dynamic>;
      for (final item in official['currentList'] as List) {
        ((item as Map)['characterState'] as Map?)?.remove('heartAttacks');
      }
      gs.loadFromData(jsonEncode(official));
      expect(major(blinkblade), 0);
    });
  });
}
