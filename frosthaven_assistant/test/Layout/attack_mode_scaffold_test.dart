// ignore_for_file: no-magic-number

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/attack_mode/attack_mode_controller.dart';
import 'package:frosthaven_assistant/Layout/attack_mode/attack_mode_panel.dart';
import 'package:frosthaven_assistant/Layout/MainList/main_list.dart';
import 'package:frosthaven_assistant/Layout/main_scaffold.dart';
import 'package:frosthaven_assistant/Resource/commands/add_monster_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_standee_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
    loading.value = false;
  });

  tearDown(() => attackModeController().end());

  testWidgets('the real scaffold shows the attack screen without errors',
      (tester) async {
    final gs = getIt<GameState>();
    gs.clearList();
    gs.action(AddMonsterCommand('Ancient Artillery (FH)', 1, false,
        gameState: gs));
    for (final nr in [1, 2]) {
      gs.action(AddStandeeCommand(
          nr, null, 'Ancient Artillery (FH)', MonsterType.normal, false,
          gameState: gs));
    }
    await tester.pumpWidget(testApp(const MainScaffold()));
    await tester.pump(const Duration(milliseconds: 300));
    tester.takeException();

    final attack = attackModeController();
    final monster = gs.currentList.firstWhere((e) => e is Monster) as Monster;
    attack.startSelecting();
    for (final i in monster.monsterInstances) {
      attack.togglePick(i, monster.id);
    }
    attack.startAttack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AttackModePanel), findsOneWidget);
    // It must actually fill the board area and show its content, not just
    // exist: a zero-size panel looks like a blank white screen.
    final body = tester.getSize(find.byType(MainScaffoldBody));
    final panel = tester.getSize(find.byType(AttackModePanel));
    expect(panel.width, body.width);
    expect(panel.height, body.height);
    // The hidden board must stay laid out (an Offstage board is never laid
    // out, which blanked the attack screen in the real app).
    expect(tester.getSize(find.byType(MainList)).height, greaterThan(0));
    expect(find.text('Attacking 2 of 2'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byKey(const ValueKey('attack-condition-stun')), findsOneWidget);

    // Done brings the board back, also with real size.
    attack.end();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AttackModePanel), findsNothing);
    expect(find.byType(MainList), findsOneWidget);
    expect(tester.getSize(find.byType(MainList)).height, greaterThan(0));
  });
}
