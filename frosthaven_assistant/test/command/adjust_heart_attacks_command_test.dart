// ignore_for_file: no-magic-number, avoid-late-keyword

import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/adjust_heart_attacks_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_init_command.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  late GameState gs;
  late String heroId;

  setUp(() {
    gs = getIt<GameState>();
    gs.clearList();
    gs.heartAttackToast.value = '';
    getIt<Settings>().heartAttacks.value = true;
    AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
    heroId = gs.currentList.whereType<Character>().first.id;
  });

  Character hero() =>
      gs.currentList.whereType<Character>().firstWhere((c) => c.id == heroId);

  int read(HeartAttackKind kind, HeartAttackPeriod period) {
    final s = hero().characterState;
    if (kind == HeartAttackKind.little) {
      return period == HeartAttackPeriod.earlier
          ? s.littleHeartAttacksBefore.value
          : s.littleHeartAttacks.value;
    }
    return period == HeartAttackPeriod.earlier
        ? s.heartAttacksBefore.value
        : s.heartAttacks.value;
  }

  // One tap through the action handler: a real, undoable step.
  void tap(HeartAttackKind kind, HeartAttackPeriod period, int change) {
    gs.action(AdjustHeartAttacksCommand(
      characterId: heroId,
      kind: kind,
      period: period,
      change: change,
      gameState: gs,
    ));
  }

  // A bare execute: mutates without a snapshot (as a raw +/- press does not —
  // but lets a clamp test reach a bound cheaply).
  void press(HeartAttackKind kind, HeartAttackPeriod period, int change) {
    AdjustHeartAttacksCommand(
      characterId: heroId,
      kind: kind,
      period: period,
      change: change,
      gameState: gs,
    ).execute();
  }

  const allCells = [
    (HeartAttackKind.little, HeartAttackPeriod.earlier),
    (HeartAttackKind.little, HeartAttackPeriod.thisScenario),
    (HeartAttackKind.major, HeartAttackPeriod.earlier),
    (HeartAttackKind.major, HeartAttackPeriod.thisScenario),
  ];

  group('AdjustHeartAttacksCommand', () {
    test('each +1 moves only its own count', () {
      for (final (kind, period) in allCells) {
        final others = {
          for (final (ok, op) in allCells)
            if (!(ok == kind && op == period)) '$ok/$op': read(ok, op)
        };
        tap(kind, period, 1);
        expect(read(kind, period), 1, reason: '$kind/$period');
        // The other three cells are untouched.
        for (final (ok, op) in allCells) {
          if (ok == kind && op == period) continue;
          expect(read(ok, op), others['$ok/$op'],
              reason: '$ok/$op should not move');
        }
      }
    });

    test('-1 lowers its own count and floors at zero', () {
      tap(HeartAttackKind.major, HeartAttackPeriod.thisScenario, 1);
      tap(HeartAttackKind.major, HeartAttackPeriod.thisScenario, 1);
      expect(read(HeartAttackKind.major, HeartAttackPeriod.thisScenario), 2);
      tap(HeartAttackKind.major, HeartAttackPeriod.thisScenario, -1);
      expect(read(HeartAttackKind.major, HeartAttackPeriod.thisScenario), 1);
      // Down to 0 and below stays at 0.
      tap(HeartAttackKind.major, HeartAttackPeriod.thisScenario, -1);
      tap(HeartAttackKind.major, HeartAttackPeriod.thisScenario, -1);
      expect(read(HeartAttackKind.major, HeartAttackPeriod.thisScenario), 0);
    });

    test('all four counts floor at zero', () {
      for (final (kind, period) in allCells) {
        press(kind, period, -1);
        expect(read(kind, period), 0, reason: '$kind/$period clamps at 0');
      }
    });

    test('every count caps at 99', () {
      for (final (kind, period) in allCells) {
        for (int i = 0; i < AdjustHeartAttacksCommand.max + 5; i++) {
          press(kind, period, 1);
        }
        expect(read(kind, period), AdjustHeartAttacksCommand.max,
            reason: '$kind/$period caps at 99');
      }
    });

    test('a tap is its own undo step', () {
      // Baseline action: undo restores the last saved snapshot, and only
      // gameState.action() saves one.
      tap(HeartAttackKind.major, HeartAttackPeriod.thisScenario, 1); // ->1
      tap(HeartAttackKind.major, HeartAttackPeriod.thisScenario, 1); // ->2
      expect(read(HeartAttackKind.major, HeartAttackPeriod.thisScenario), 2);
      gs.undo();
      expect(read(HeartAttackKind.major, HeartAttackPeriod.thisScenario), 1);
      gs.undo();
      expect(read(HeartAttackKind.major, HeartAttackPeriod.thisScenario), 0);
      // The undo also reaches the earlier cells only if they were changed:
      // a fresh little count is untouched by these majors.
      expect(read(HeartAttackKind.little, HeartAttackPeriod.thisScenario), 0);
    });

    test('no toast is raised by an adjustment', () {
      tap(HeartAttackKind.major, HeartAttackPeriod.thisScenario, 1);
      tap(HeartAttackKind.little, HeartAttackPeriod.earlier, 1);
      expect(gs.heartAttackToast.value, isEmpty);
    });

    test('a tap at a bound changes nothing (still undoable, but no-op)', () {
      // Baseline to snapshot against.
      gs.action(SetInitCommand(heroId, 5, gameState: gs));
      press(HeartAttackKind.major, HeartAttackPeriod.thisScenario, -1); // 0->0
      final before = read(HeartAttackKind.major, HeartAttackPeriod.thisScenario);
      tap(HeartAttackKind.major, HeartAttackPeriod.thisScenario, -1);
      expect(read(HeartAttackKind.major, HeartAttackPeriod.thisScenario), before);
    });

    test('an unknown hero is a quiet no-op', () {
      expect(
        () => AdjustHeartAttacksCommand(
          characterId: 'Nobody',
          kind: HeartAttackKind.major,
          period: HeartAttackPeriod.thisScenario,
          change: 1,
          gameState: gs,
        ).execute(),
        returnsNormally,
      );
    });
  });
}
