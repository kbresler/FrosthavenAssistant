// ignore_for_file: no-magic-number

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_health_command.dart';
import 'package:frosthaven_assistant/Resource/commands/count_official_heart_attacks_command.dart';
import 'package:frosthaven_assistant/Resource/commands/draw_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_init_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/game_methods.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import 'test_helpers.dart';

typedef Watch = ({int health, int major, int little});

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  setUp(() {
    final gs = getIt<GameState>();
    gs.clearList();
    gs.heartAttackToast.value = '';
    // The app's own counting is off: here only the command may move the
    // tallies, exactly as on a host that counts for its official players.
    getIt<Settings>().heartAttacks.value = false;
    AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
  });

  Character hero() =>
      getIt<GameState>().currentList.whereType<Character>().first;

  void hit(Character c) {
    ChangeHealthCommand(-1000, c.id, c.id, gameState: getIt<GameState>())
        .execute();
  }

  void rest(Character c) {
    SetInitCommand(c.id, 99, gameState: getIt<GameState>()).execute();
  }

  // DrawCommand notifies on a 600 ms delay; drain it so no timer is pending.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  void count(
    Set<String> officialIds,
    Map<String, Watch> before, {
    RoundState roundBefore = RoundState.chooseInitiative,
  }) {
    CountOfficialHeartAttacksCommand(
      officialIds: officialIds,
      before: before,
      roundBefore: roundBefore,
      gameState: getIt<GameState>(),
    ).execute();
  }

  Map<String, Watch> beforeHealth(Map<String, int> healthById) => {
        for (final e in healthById.entries)
          e.key: (health: e.value, major: 0, little: 0),
      };

  int major(Character c) => c.characterState.heartAttacks.value;
  int little(Character c) => c.characterState.littleHeartAttacks.value;

  group('CountOfficialHeartAttacksCommand', () {
    test('an official hero dropped to zero gains a major', () {
      final blinkblade = hero();
      final before = beforeHealth({blinkblade.id: 9});
      hit(blinkblade);
      count({blinkblade.id}, before);
      expect(major(blinkblade), 1);
      expect(little(blinkblade), 0);
    });

    test('a hero already at zero gains nothing', () {
      final blinkblade = hero();
      final before = beforeHealth({blinkblade.id: 0});
      count({blinkblade.id}, before);
      expect(major(blinkblade), 0);
    });

    test('a hero still standing gains nothing', () {
      final blinkblade = hero();
      final before = beforeHealth({blinkblade.id: 9});
      count({blinkblade.id}, before);
      expect(major(blinkblade), 0);
      expect(little(blinkblade), 0);
    });

    test('a hero not on the official list gains nothing', () {
      final blinkblade = hero();
      final before = beforeHealth({blinkblade.id: 9});
      hit(blinkblade);
      count({}, before);
      expect(major(blinkblade), 0);
    });

    test('an Objective dropped to zero gains nothing', () {
      AddCharacterCommand('Objective', 'na', 'whatever', 1).execute();
      // New characters go on top: find the Objective by its class, not by
      // position.
      final objective = getIt<GameState>()
          .currentList
          .whereType<Character>()
          .firstWhere((c) => GameMethods.isObjectiveOrEscort(c.characterClass));
      final before = beforeHealth({objective.id: 1});
      hit(objective);
      count({objective.id}, before);
      expect(objective.characterState.heartAttacks.value, 0);
    });

    test('a hero added by this very update gains nothing', () {
      // Its id is not in the before map: the host cannot have seen it fall.
      final blinkblade = hero();
      hit(blinkblade);
      count({blinkblade.id}, {});
      expect(major(blinkblade), 0);
    });

    testWidgets('resting through a Draw gains a little', (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      final blinkblade = hero();
      final before = beforeHealth({blinkblade.id: 9});
      rest(blinkblade);
      DrawCommand(gameState: getIt<GameState>()).execute();
      count({blinkblade.id}, before);
      expect(little(blinkblade), 1);
      expect(major(blinkblade), 0);
      expect(getIt<GameState>().heartAttackToast.value, isEmpty);
      await settle(tester);
    });

    test('without a Draw the resting hero gains nothing', () {
      final blinkblade = hero();
      final before = beforeHealth({blinkblade.id: 9});
      rest(blinkblade);
      // The update did not contain a Draw: the round was already playing
      // turns, so a rest is just a rest.
      count({blinkblade.id}, before, roundBefore: RoundState.playTurns);
      expect(little(blinkblade), 0);
    });

    testWidgets('a resting hero at zero gains the major, not the little',
        (tester) async {
      await tester.pumpWidget(testApp(const SizedBox()));
      final blinkblade = hero();
      final before = beforeHealth({blinkblade.id: 9});
      hit(blinkblade);
      rest(blinkblade);
      DrawCommand(gameState: getIt<GameState>()).execute();
      count({blinkblade.id}, before);
      expect(major(blinkblade), 1);
      expect(little(blinkblade), 0);
      await settle(tester);
    });

    test('the command itself writes no toast line', () {
      final blinkblade = hero();
      final before = beforeHealth({blinkblade.id: 9});
      hit(blinkblade);
      // The app's own counting is on again: only the command moves a tally
      // here, so any line on screen would be its doing.
      getIt<Settings>().heartAttacks.value = true;
      count({blinkblade.id}, before);
      expect(major(blinkblade), 1);
      expect(getIt<GameState>().heartAttackToast.value, isEmpty);
    });
  });
}
