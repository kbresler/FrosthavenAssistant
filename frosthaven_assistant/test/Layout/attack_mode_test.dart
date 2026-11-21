// ignore_for_file: no-magic-number, avoid-late-keyword

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/MonsterBox/monster_box.dart';
import 'package:frosthaven_assistant/Layout/attack_mode/attack_mode_controller.dart';
import 'package:frosthaven_assistant/Layout/attack_mode/attack_mode_panel.dart';
import 'package:frosthaven_assistant/Layout/menus/StatusMenu/status_menu.dart';
import 'package:frosthaven_assistant/Layout/top_bar.dart';
import 'package:frosthaven_assistant/Resource/commands/add_monster_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_standee_command.dart';
import 'package:frosthaven_assistant/Resource/commands/draw_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/game_data.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

const _monsterName = 'Ancient Artillery (FH)';

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  late GameState gs;
  late AttackModeController attack;

  void addStandee(int nr, MonsterType type) {
    gs.action(AddStandeeCommand(nr, null, _monsterName, type, false,
        gameState: gs));
  }

  // Looked up fresh each time: Undo rebuilds the game objects.
  Monster currentMonster() =>
      gs.currentList.firstWhere((e) => e is Monster) as Monster;

  MonsterInstance standee(int nr) =>
      currentMonster().monsterInstances.firstWhere((i) => i.standeeNr == nr);

  setUp(() {
    gs = getIt<GameState>();
    gs.clearList();
    gs.action(AddMonsterCommand(_monsterName, 1, false, gameState: gs));
    addStandee(1, MonsterType.normal);
    addStandee(2, MonsterType.normal);
    addStandee(3, MonsterType.elite);
    attack = AttackModeController(gameState: gs);
    getIt<Settings>().attackSeveral.value = true;
  });

  tearDown(() {
    attack.dispose();
    attackModeController().end();
  });

  void pickAndAttack(List<int> numbers) {
    attack.startSelecting();
    for (final n in numbers) {
      attack.togglePick(standee(n), _monsterName);
    }
    attack.startAttack();
  }

  group('Swerski attack mode: picking', () {
    test('starts off, and picking standees toggles them', () {
      expect(attack.phase.value, AttackPhase.off);
      attack.startSelecting();
      expect(attack.isSelecting, isTrue);
      attack.togglePick(standee(1), _monsterName);
      attack.togglePick(standee(2), _monsterName);
      expect(attack.picked.value.length, 2);
      attack.togglePick(standee(1), _monsterName);
      expect(attack.isPicked(_monsterName, standee(1).getId()), isFalse);
      expect(attack.isPicked(_monsterName, standee(2).getId()), isTrue);
    });

    test('starting from a standee menu pre-picks that standee', () {
      attack.startSelecting(first: standee(3), ownerId: _monsterName);
      expect(attack.picked.value.single.standeeNr, 3);
    });

    test('attacking with nothing picked does nothing', () {
      attack.startSelecting();
      attack.startAttack();
      expect(attack.isSelecting, isTrue);
    });

    test('everything picked starts switched on; end clears it all', () {
      pickAndAttack([1, 2]);
      expect(attack.isAttacking, isTrue);
      expect(attack.active.value.length, 2);
      attack.end();
      expect(attack.phase.value, AttackPhase.off);
      expect(attack.roster.value, isEmpty);
      expect(attack.picked.value, isEmpty);
    });

    test('Draw ends attack mode', () {
      pickAndAttack([1, 2]);
      gs.action(DrawCommand(gameState: gs));
      expect(attack.phase.value, AttackPhase.off);
      gs.undo(); // leave the round as it was for the next test
    });

    test('Undo of the Draw that ended an attack reopens it, as it was', () {
      pickAndAttack([1, 2, 3]);
      attack.only(attack.roster.value[1]);
      gs.action(DrawCommand(gameState: gs));
      expect(attack.phase.value, AttackPhase.off);

      gs.undo();
      expect(attack.isAttacking, isTrue);
      expect(attack.roster.value.length, 3);
      expect(attack.liveActive.single.standeeNr, 2);
    });

    test('a different action after the Draw lets the attack go for good', () {
      pickAndAttack([1, 2]);
      gs.action(DrawCommand(gameState: gs));
      gs.action(AddStandeeCommand(4, null, _monsterName, MonsterType.normal,
          false,
          gameState: gs));
      gs.undo(); // undoes the standee, not the Draw
      gs.undo(); // undoes the Draw, but too late
      expect(attack.phase.value, AttackPhase.off);
    });

    test('Done is a choice, so Undo does not bring the attack back', () {
      pickAndAttack([1, 2]);
      attack.changeHealth(-1);
      attack.end();
      gs.undo();
      expect(attack.phase.value, AttackPhase.off);
    });
  });

  group('Swerski attack mode: roster', () {
    test('chips toggle, long-press means only this one, all and none', () {
      pickAndAttack([1, 2, 3]);
      final t1 = attack.roster.value.first;
      attack.toggleActive(t1);
      expect(attack.liveActive.length, 2);
      attack.only(t1);
      expect(attack.liveActive.single, t1);
      attack.selectAll();
      expect(attack.liveActive.length, 3);
      attack.selectNone();
      expect(attack.liveActive, isEmpty);
    });

    test('the portrait switches a whole monster on or off', () {
      pickAndAttack([1, 2]);
      attack.toggleMonster(_monsterName);
      expect(attack.active.value, isEmpty);
      attack.toggleMonster(_monsterName);
      expect(attack.active.value.length, 2);
    });
  });

  group('Swerski attack mode: applying', () {
    test('health changes only the switched-on standees, as one undo', () {
      pickAndAttack([1, 2, 3]);
      attack.toggleActive(attack.roster.value[2]);
      final before1 = standee(1).health.value;
      final before3 = standee(3).health.value;

      attack.changeHealth(-1);
      expect(standee(1).health.value, before1 - 1);
      expect(standee(2).health.value, before1 - 1);
      expect(standee(3).health.value, before3);
      expect(attack.undoLabel, '−1 health (2)');

      gs.undo();
      expect(standee(1).health.value, before1);
      expect(standee(2).health.value, before1);
    });

    test('healing stops at max health', () {
      pickAndAttack([1, 2]);
      final max = standee(1).maxHealth.value;
      attack.changeHealth(1);
      expect(standee(1).health.value, max);
    });

    test('a kill removes the standees and one Undo brings them back', () {
      pickAndAttack([1, 2, 3]);
      attack.toggleActive(attack.roster.value[2]);
      attack.kill();
      expect(currentMonster().monsterInstances.map((i) => i.standeeNr), [3]);
      expect(attack.isDead(attack.roster.value[0]), isTrue);
      expect(attack.isDead(attack.roster.value[2]), isFalse);
      // killed standees no longer take part
      expect(attack.liveActive, isEmpty);

      gs.undo();
      expect(currentMonster().monsterInstances.length, 3);
      expect(attack.isDead(attack.roster.value[0]), isFalse);
      expect(attack.liveActive.length, 2);
    });

    test('a condition is given to those lacking it, then taken from all', () {
      pickAndAttack([1, 2]);
      expect(attack.tally(Condition.stun), ConditionTally.none);
      // one has it already
      gs.action(GroupConditionHelper.add(Condition.stun, standee(1), gs));
      expect(attack.tally(Condition.stun), ConditionTally.some);

      attack.toggleCondition(Condition.stun);
      expect(attack.tally(Condition.stun), ConditionTally.all);
      expect(standee(2).conditions.value, contains(Condition.stun));
      expect(standee(1).conditions.value.where((c) => c == Condition.stun),
          hasLength(1));

      attack.toggleCondition(Condition.stun);
      expect(attack.tally(Condition.stun), ConditionTally.none);
      expect(standee(1).conditions.value, isEmpty);
      expect(standee(2).conditions.value, isEmpty);
    });

    test('Undo label names the newest action in the game', () {
      pickAndAttack([1, 2]);
      attack.toggleCondition(Condition.stun);
      expect(attack.undoLabel, '+stun (2)');
    });

    test('bless and curse controls stay when everyone is dead or off', () {
      pickAndAttack([1, 2]);
      attack.kill();
      expect(attack.liveActive, isEmpty);
      expect(attack.monsterDeck, isNotNull);
      gs.undo();
    });

    test('chill goes on every switched-on standee at once', () {
      pickAndAttack([1, 2, 3]);
      attack.changeChill(1);
      expect([1, 2, 3].map((n) => standee(n).chill.value), [1, 1, 1]);
      expect(attack.chillTotal, 3);
      expect(attack.undoLabel, '+1 chill (3)');

      // a switched-off standee is left alone
      attack.toggleActive(attack.roster.value[2]);
      attack.changeChill(1);
      expect([1, 2, 3].map((n) => standee(n).chill.value), [2, 2, 1]);

      // taking it away removes one from each that has any, never below none
      attack.changeChill(-1);
      attack.changeChill(-1);
      attack.changeChill(-1);
      expect([1, 2, 3].map((n) => standee(n).chill.value), [0, 0, 1]);

      // The third "−" had nothing to remove, so it made no action. One Undo
      // reverses the whole previous group, for both standees at once.
      gs.undo();
      expect([1, 2, 3].map((n) => standee(n).chill.value), [1, 1, 1]);
    });

    test('chill stops at twelve per standee', () {
      pickAndAttack([1, 2]);
      for (int i = 0; i < 15; i++) {
        attack.changeChill(1);
      }
      expect([1, 2].map((n) => standee(n).chill.value), [12, 12]);
    });

    group('bless and curse: one card for each switched-on standee', () {
      late int startIndex;
      setUp(() => startIndex = gs.commandIndex.value);
      tearDown(() {
        while (gs.commandIndex.value > startIndex) {
          gs.undo();
        }
      });

      test('three standees add three cards, and one Undo takes them back', () {
        pickAndAttack([1, 2, 3]);
        final deck = attack.monsterDeck!;
        final before = deck.getRemovable('bless').value;
        attack.changeBless(1);
        expect(deck.getRemovable('bless').value, before + 3);
        expect(attack.undoLabel, '+3 bless');
        gs.undo();
        expect(deck.getRemovable('bless').value, before);
      });

      test('curse works the same way', () {
        pickAndAttack([1, 2, 3]);
        final deck = attack.monsterDeck!;
        final before = deck.getRemovable('curse').value;
        attack.changeCurse(1);
        expect(deck.getRemovable('curse').value, before + 3);
        expect(attack.undoLabel, '+3 curse');
      });

      test('only switched-on standees count', () {
        pickAndAttack([1, 2, 3]);
        attack.toggleActive(attack.roster.value[0]);
        final deck = attack.monsterDeck!;
        final before = deck.getRemovable('bless').value;
        attack.changeBless(1);
        expect(deck.getRemovable('bless').value, before + 2);
      });

      test('removing takes one per standee, never below none', () {
        pickAndAttack([1, 2, 3]);
        final deck = attack.monsterDeck!;
        final before = deck.getRemovable('bless').value;
        attack.changeBless(1); // +3
        attack.changeBless(-1); // back to where it was
        attack.changeBless(-1); // nothing left (or not below zero)
        // three standees take up to three, and it never goes below none
        expect(deck.getRemovable('bless').value, before > 3 ? before - 3 : 0);
      });

      test('stops at ten cards, standee by standee', () {
        pickAndAttack([1, 2, 3]);
        final deck = attack.monsterDeck!;
        while (deck.getRemovable('bless').value < 10) {
          attack.changeBless(1);
        }
        expect(deck.getRemovable('bless').value, 10);
        final index = gs.commandIndex.value;
        attack.changeBless(1); // already full: no action at all
        expect(gs.commandIndex.value, index);
      });
    });
  });

  group('Swerski attack mode: screens', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      await tester.pumpWidget(testApp(Scaffold(body: child)));
      await tester.pump();
      FlutterError.onError = originalOnError;
    }

    testWidgets('the panel shows who is being attacked and Done ends it',
        (tester) async {
      pickAndAttack([1, 2]);
      await pump(tester, AttackModePanel(controller: attack));
      expect(find.text('Attacking 2 of 2'), findsOneWidget);
      // Undo is always there and names the last action in the game.
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(attack.phase.value, AttackPhase.off);
    });

    testWidgets('tapping a chip switches that standee off', (tester) async {
      pickAndAttack([1, 2]);
      await pump(tester, AttackModePanel(controller: attack));
      await tester.tap(find.text('1').first);
      await tester.pump();
      expect(find.text('Attacking 1 of 2'), findsOneWidget);
    });

    testWidgets('chips show each standee\'s current health as it changes',
        (tester) async {
      pickAndAttack([1, 2]);
      await pump(tester, AttackModePanel(controller: attack));
      final start = standee(1).health.value;
      final max = standee(1).maxHealth.value;
      Text healthOf(int nr) => tester.widget<Text>(
          find.byKey(ValueKey('attack-health-$_monsterName-$nr')));
      expect(healthOf(1).data, '$start/$max');

      attack.changeHealth(-2);
      await tester.pump();
      expect(healthOf(1).data, '${start - 2}/$max');
      expect(healthOf(2).data, '${start - 2}/$max');
    });

    testWidgets('monsters are down the left, the status effects on the right',
        (tester) async {
      pickAndAttack([1, 2]);
      await pump(tester, AttackModePanel(controller: attack));
      final chip = tester.getCenter(
          find.byKey(ValueKey('attack-health-$_monsterName-1')));
      final stun = tester.getCenter(
          find.byKey(const ValueKey('attack-condition-stun')));
      final health = tester.getCenter(
          find.byKey(const ValueKey('attack-health-minus')));
      expect(chip.dx, lessThan(stun.dx));
      expect(chip.dx, lessThan(health.dx));
    });

    // Strict: unlike the other tests, an overflow here fails the test.
    for (final size in const [Size(375, 700), Size(1024, 700)]) {
      testWidgets('four monster types with many standees fit at $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // Any monsters in the test data, until there are four types.
        final candidates = <String>[
          for (final campaign in getIt<GameData>().modelData.value.values)
            ...campaign.monsters.keys
        ];
        for (final name in candidates) {
          if (gs.currentList.whereType<Monster>().length >= 4) break;
          if (gs.currentList.any((e) => e.id == name)) continue;
          try {
            gs.action(AddMonsterCommand(name, 1, false, gameState: gs));
          } on StateError {
            // not usable here
          }
        }
        expect(gs.currentList.whereType<Monster>().length, 4);
        for (final m in gs.currentList.whereType<Monster>()) {
          for (int nr = 1; nr <= 8; nr++) {
            gs.action(AddStandeeCommand(
                nr, null, m.id, nr == 1 ? MonsterType.elite : MonsterType.normal,
                false,
                gameState: gs));
          }
        }
        attack.startSelecting();
        for (final m in gs.currentList.whereType<Monster>()) {
          for (final i in m.monsterInstances) {
            attack.togglePick(i, m.id);
          }
        }
        attack.startAttack();
        expect(attack.roster.value.map((t) => t.ownerId).toSet().length, 4);

        final seen = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) => seen.add(d.toString());
        await tester.pumpWidget(
            testApp(Scaffold(body: AttackModePanel(controller: attack))));
        await tester.pump();
        FlutterError.onError = prev;
        expect(seen, isEmpty);

        // Every chip can be reached by scrolling, and the screen still works.
        expect(find.text('Select none'), findsOneWidget);
        await tester.drag(find.byType(SingleChildScrollView).first,
            const Offset(0, -2000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a condition tile applies to the switched-on standees',
        (tester) async {
      pickAndAttack([1, 2]);
      await pump(tester, AttackModePanel(controller: attack));
      await tester
          .tap(find.byKey(const ValueKey('attack-condition-stun')));
      await tester.pump();
      expect(standee(1).conditions.value, contains(Condition.stun));
      expect(standee(2).conditions.value, contains(Condition.stun));
      expect(find.text('+stun (2)'), findsOneWidget);
    });

    testWidgets('the sword button starts picking, then attacks',
        (tester) async {
      final global = attackModeController();
      await pump(
          tester,
          const Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 800, height: 60, child: TopBar())));
      await tester.tap(find.byKey(const ValueKey('attack-sword')));
      await tester.pump();
      expect(global.isSelecting, isTrue);

      global.togglePick(standee(1), _monsterName);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('attack-sword')));
      await tester.pump();
      expect(global.isAttacking, isTrue);
    });

    testWidgets('no sword when the setting is off', (tester) async {
      getIt<Settings>().attackSeveral.value = false;
      addTearDown(() => getIt<Settings>().attackSeveral.value = true);
      await pump(
          tester,
          const Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 800, height: 60, child: TopBar())));
      expect(find.byKey(const ValueKey('attack-sword')), findsNothing);
    });

    testWidgets('while picking, tapping a standee picks it (no menu)',
        (tester) async {
      final global = attackModeController();
      global.startSelecting();
      await pump(
          tester,
          Center(
              child: MonsterBox(
                  figureId: standee(1).getId(),
                  ownerId: _monsterName,
                  displayStartAnimation: '',
                  blockInput: false,
                  scale: 1)));
      await tester.tap(find.byType(MonsterBox));
      await tester.pump();
      expect(global.isPicked(_monsterName, standee(1).getId()), isTrue);
      expect(find.byType(StatusMenu), findsNothing);
    });
  });
}

/// Small helper so a test can put one condition on one standee.
class GroupConditionHelper {
  static Command add(Condition c, MonsterInstance m, GameState gs) =>
      _AddOne(c, m, gs);
}

class _AddOne extends Command {
  _AddOne(this.c, this.m, this.gs);
  final Condition c;
  final MonsterInstance m;
  final GameState gs;

  @override
  void execute() {
    m.setConditions(stateAccess, [...m.conditions.value, c]);
  }

  @override
  String describe() => 'test';
}
