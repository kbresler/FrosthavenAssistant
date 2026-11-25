// ignore_for_file: no-magic-number, avoid-late-keyword

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/CharacterWidget/character_health_widget.dart';
import 'package:frosthaven_assistant/Layout/CharacterWidget/character_level_widget.dart';
import 'package:frosthaven_assistant/Layout/CharacterWidget/character_widget.dart';
import 'package:frosthaven_assistant/Layout/CharacterWidget/character_xp_widget.dart';
import 'package:frosthaven_assistant/Layout/CharacterWidget/kielbasa_icon.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_health_command.dart';
import 'package:frosthaven_assistant/Resource/commands/draw_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_init_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_scenario_command.dart';
import 'package:frosthaven_assistant/Resource/game_methods.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

void main() {
  late GameState gs;
  final l10n = lookupAppLocalizations(const Locale('en'));

  Finder littleRow() => find.byKey(HeartAttackStat.littleKey);
  Finder majorRow() => find.byKey(HeartAttackStat.majorKey);
  Finder rowTexts(Finder row) =>
      find.descendant(of: row, matching: find.byType(Text));
  Finder rowIcon(Finder row) =>
      find.descendant(of: row, matching: find.byType(KielbasaIcon));
  Color? textCodeAt(WidgetTester tester, Finder row, int index) =>
      tester.widget<Text>(rowTexts(row).at(index)).style?.color;

  setUpAll(() async {
    await setUpGame();
  });

  setUp(() {
    FlutterError.onError = ignoreOverflowErrors;
    gs = getIt<GameState>();
    gs.clearList();
    gs.heartAttackToast.value = '';
    getIt<Settings>().heartAttacks.value = true;
    AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
  });

  Widget board() => testApp(Scaffold(
      body: SingleChildScrollView(
          child: Column(children: [
    for (final item in gs.currentList)
      if (item is Character)
        CharacterWidget(characterId: item.id, key: Key('card-${item.id}')),
  ]))));

  void hit(String id) {
    ChangeHealthCommand(-1000, id, id, gameState: gs).execute();
  }

  void heal(String id) {
    ChangeHealthCommand(5, id, id, gameState: gs).execute();
  }

  void rest(String id) {
    SetInitCommand(id, 99, gameState: gs).execute();
  }

  void draw() {
    DrawCommand(gameState: gs).execute();
  }

  void newScenario() {
    gs.action(SetScenarioCommand('custom', false, gameState: gs));
  }

  testWidgets('a fresh hero shows neither row', (tester) async {
    await tester.pumpWidget(board());
    expect(littleRow(), findsNothing);
    expect(majorRow(), findsNothing);
  });

  testWidgets('a major heart attack shows only the major row', (tester) async {
    await tester.pumpWidget(board());
    hit('Blinkblade');
    await tester.pump();
    expect(majorRow(), findsOneWidget);
    expect(littleRow(), findsNothing);
    final icon = tester.widget<KielbasaIcon>(rowIcon(majorRow()));
    expect(icon.recovering, isFalse);
    expect(icon.semanticLabel, l10n.heartAttackBadge(1));
    // Earlier 0 in grey, then the current number in red: zeros show.
    expect(rowTexts(majorRow()), findsNWidgets(2));
    expect(textCodeAt(tester, majorRow(), 0), Colors.grey);
    expect(tester.widget<Text>(rowTexts(majorRow()).first).data, '0');
    expect(textCodeAt(tester, majorRow(), 1), Colors.redAccent);
  });

  testWidgets('a long rest shows only the little row', (tester) async {
    rest('Blinkblade');
    await tester.pumpWidget(board());
    draw();
    // DrawCommand notifies on a 600 ms delay; let it run out.
    await tester.pump(const Duration(milliseconds: 700));
    expect(littleRow(), findsOneWidget);
    expect(majorRow(), findsNothing);
    final icon = tester.widget<KielbasaIcon>(rowIcon(littleRow()));
    expect(icon.recovering, isTrue);
    expect(icon.semanticLabel, l10n.heartAttackLittleBadge(1));
    expect(rowTexts(littleRow()), findsNWidgets(2));
    expect(textCodeAt(tester, littleRow(), 0), Colors.grey);
    expect(textCodeAt(tester, littleRow(), 1), Colors.white);
  });

  testWidgets('both kinds show both rows', (tester) async {
    hit('Blinkblade');
    heal('Blinkblade');
    rest('Blinkblade');
    await tester.pumpWidget(board());
    draw();
    await tester.pump(const Duration(milliseconds: 700));
    expect(littleRow(), findsOneWidget);
    expect(majorRow(), findsOneWidget);
    expect(tester.widget<KielbasaIcon>(rowIcon(littleRow())).recovering,
        isTrue);
    expect(tester.widget<KielbasaIcon>(rowIcon(majorRow())).recovering,
        isFalse);
    expect(textCodeAt(tester, littleRow(), 1), Colors.white);
    expect(textCodeAt(tester, majorRow(), 1), Colors.redAccent);
  });

  testWidgets('a past-scenario count shows grey with a current 0',
      (tester) async {
    hit('Blinkblade');
    newScenario();
    await tester.pumpWidget(board());
    expect(majorRow(), findsOneWidget);
    expect(rowTexts(majorRow()), findsNWidgets(2));
    expect(textCodeAt(tester, majorRow(), 0), Colors.grey);
    expect(tester.widget<Text>(rowTexts(majorRow()).first).data, '1');
    expect(tester.widget<Text>(rowTexts(majorRow()).last).data, '0');
    // Healing after the fold still counts nothing new.
    expect(rowIcon(majorRow()), findsOneWidget);
  });

  testWidgets('earlier and current stack on one row: grey then coloured',
      (tester) async {
    hit('Blinkblade');
    newScenario();
    rest('Blinkblade');
    await tester.pumpWidget(board());
    draw();
    await tester.pump(const Duration(milliseconds: 700));
    hit('Blinkblade');
    await tester.pump();
    expect(rowTexts(majorRow()), findsNWidgets(2));
    expect(textCodeAt(tester, majorRow(), 0), Colors.grey);
    expect(textCodeAt(tester, majorRow(), 1), Colors.redAccent);
    expect(rowTexts(littleRow()), findsNWidgets(2));
    expect(textCodeAt(tester, littleRow(), 1), Colors.white);
  });

  testWidgets('the icon does not move when the current count appears',
      (tester) async {
    hit('Blinkblade');
    newScenario();
    await tester.pumpWidget(board());
    final before = tester.getCenter(rowIcon(majorRow()));
    heal('Blinkblade');
    hit('Blinkblade');
    await tester.pump();
    // Current went 0 -> 1: same slot, so the icon stays where it was.
    expect(tester.getCenter(rowIcon(majorRow())), before);
  });

  testWidgets('the rows share the XP and level rows\' centres at both widths',
      (tester) async {
    hit('Blinkblade');
    heal('Blinkblade');
    rest('Blinkblade');
    await tester.pumpWidget(board());
    draw();
    await tester.pump(const Duration(milliseconds: 700));
    for (final size in const [Size(283, 660), Size(834, 1112)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(board());
      await tester.pump();
      final xpDy = tester.getCenter(find.byType(CharacterXPWidget)).dy;
      final levelDy = tester.getCenter(find.byType(CharacterLevelWidget)).dy;
      expect((tester.getCenter(littleRow()).dy - xpDy).abs(), lessThan(2.0));
      expect((tester.getCenter(majorRow()).dy - levelDy).abs(), lessThan(2.0));
    }
  });

  void twelveEach(String id) {
    // Two digits in every slot: 12 earlier + 12 current of each kind.
    for (int i = 0; i < 12; i++) {
      hit(id);
      heal(id);
    }
    rest(id);
    for (int i = 0; i < 12; i++) {
      draw();
    }
    newScenario();
    for (int i = 0; i < 12; i++) {
      hit(id);
      heal(id);
    }
    rest(id);
    for (int i = 0; i < 12; i++) {
      draw();
    }
  }

  void expectInsideCardAndClearOfTexts(
      WidgetTester tester, Finder row, Finder card) {
    final rowRect = tester.getRect(row);
    final cardRect = tester.getRect(card);
    expect(rowRect.width, greaterThan(0));
    expect(rowRect.right, lessThanOrEqualTo(cardRect.right + 0.01));
    expect(rowRect.left, greaterThanOrEqualTo(cardRect.left - 0.01));
    expect(rowRect.top, greaterThanOrEqualTo(cardRect.top - 0.01));
    expect(rowRect.bottom, lessThanOrEqualTo(cardRect.bottom + 0.01));
    final healthTexts = find.descendant(
        of: find.descendant(
            of: card, matching: find.byType(CharacterHealthWidget)),
        matching: find.byType(Text));
    for (int i = 0; i < healthTexts.evaluate().length; i++) {
      expect(rowRect.overlaps(tester.getRect(healthTexts.at(i))), isFalse,
          reason: 'stat row overlaps a name/health text');
    }
  }

  testWidgets('two-digit counts with a short name shrink into the gap and '
      'stay clear of the name and health text', (tester) async {
    twelveEach('Blinkblade');
    for (final size in const [Size(283, 660), Size(834, 1112)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(board());
      await tester.pump(const Duration(milliseconds: 700));
      final card = find.byType(CharacterWidget);
      for (final row in [littleRow(), majorRow()]) {
        expect(row, findsOneWidget, reason: 'rows show at $size');
        expectInsideCardAndClearOfTexts(tester, row, card);
      }
    }
  });

  testWidgets('a long name wins: no rows rather than covering the name',
      (tester) async {
    AddCharacterCommand('Banner Spear', 'Frosthaven', null, 1).execute();
    final spear = gs.currentList
        .whereType<Character>()
        .firstWhere((c) => c.id != 'Blinkblade');
    twelveEach(spear.id);
    expect(spear.characterState.totalHeartAttacks, greaterThan(0));
    for (final size in const [Size(283, 660), Size(834, 1112)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(board());
      await tester.pump(const Duration(milliseconds: 700));
      // Its name leaves no gap at any width, so both rows hide on its card;
      // Blinkblade's short name keeps its own rows (both counts folded
      // earlier… none here) — Blinkblade shows nothing, counts are 0.
      expect(littleRow(), findsNothing,
          reason: 'no little row behind a long name at $size');
      expect(majorRow(), findsNothing,
          reason: 'no major row behind a long name at $size');
    }
  });

  testWidgets('the rows stay full colour on the greyed-out card',
      (tester) async {
    hit('Blinkblade');
    rest('Blinkblade');
    await tester.pumpWidget(board());
    draw();
    await tester.pump(const Duration(milliseconds: 700));
    // The exhausted card is greyed out…
    expect(find.byType(ColorFiltered), findsWidgets);
    // …but the rows sit outside that filter.
    expect(
        find.ancestor(
            of: find.byType(KielbasaIcon),
            matching: find.byType(ColorFiltered)),
        findsNothing);
  });

  testWidgets('the setting hides the rows', (tester) async {
    hit('Blinkblade');
    heal('Blinkblade');
    rest('Blinkblade');
    await tester.pumpWidget(board());
    draw();
    await tester.pump(const Duration(milliseconds: 700));
    expect(littleRow(), findsOneWidget);
    expect(majorRow(), findsOneWidget);
    getIt<Settings>().heartAttacks.value = false;
    await tester.pump();
    expect(littleRow(), findsNothing);
    expect(majorRow(), findsNothing);
  });

  testWidgets('an Objective never gets a row', (tester) async {
    AddCharacterCommand('Objective', 'na', 'whatever', 1).execute();
    final objective = gs.currentList
        .whereType<Character>()
        .firstWhere((c) => GameMethods.isObjectiveOrEscort(c.characterClass));
    await tester.pumpWidget(board());
    hit(objective.id);
    rest(objective.id);
    draw();
    await tester.pump(const Duration(milliseconds: 700));
    expect(littleRow(), findsNothing);
    expect(majorRow(), findsNothing);
  });
}
