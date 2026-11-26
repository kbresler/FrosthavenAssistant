// ignore_for_file: no-magic-number, avoid-late-keyword

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/CharacterWidget/character_widget.dart';
import 'package:frosthaven_assistant/Layout/CharacterWidget/kielbasa_icon.dart';
import 'package:frosthaven_assistant/Layout/attack_mode/attack_mode_controller.dart';
import 'package:frosthaven_assistant/Layout/menus/StatusMenu/status_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/StatusMenu/status_menu_stat_column.dart';
import 'package:frosthaven_assistant/Layout/menus/heart_attacks_menu.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/adjust_heart_attacks_command.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_health_command.dart';
import 'package:frosthaven_assistant/Resource/game_methods.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

void main() {
  late GameState gs;
  late String heroId;
  final l10n = lookupAppLocalizations(const Locale('en'));

  Finder majorRow() => find.byKey(HeartAttackStat.majorKey);
  Finder dialog() => find.byType(HeartAttacksMenu);
  setUpAll(() async {
    await setUpGame();
  });

  setUp(() {
    FlutterError.onError = ignoreOverflowErrors;
    gs = getIt<GameState>();
    gs.clearList();
    gs.heartAttackToast.value = '';
    attackModeController().end();
    getIt<Settings>().heartAttacks.value = true;
    AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
    heroId = gs.currentList.whereType<Character>().first.id;
  });

  tearDown(() {
    attackModeController().end();
  });

  Widget board() => testApp(Scaffold(
      body: SingleChildScrollView(
          child: Column(children: [
    for (final item in gs.currentList)
      if (item is Character)
        CharacterWidget(characterId: item.id, key: Key('card-${item.id}')),
  ]))));

  Widget menuOf(String id) =>
      testApp(Scaffold(body: StatusMenu(figureId: id, characterId: id)));

  void hit() {
    ChangeHealthCommand(-1000, heroId, heroId, gameState: gs).execute();
  }

  Future<void> openEditorViaCard(WidgetTester tester) async {
    await tester.pumpWidget(board());
    hit();
    await tester.pump();
    expect(majorRow(), findsOneWidget);
    await tester.tap(majorRow());
    await tester.pumpAndSettle();
  }

  testWidgets('tapping the drawn major row opens the editor', (tester) async {
    await openEditorViaCard(tester);
    expect(dialog(), findsOneWidget);
    expect(find.textContaining('heart attacks'), findsWidgets);
    expect(find.text(l10n.heartAttacksLittle), findsOneWidget);
    expect(find.text(l10n.heartAttacksMajor), findsOneWidget);
    expect(find.text(l10n.heartAttacksEarlier), findsOneWidget);
    expect(find.text(l10n.heartAttacksThisScenario), findsOneWidget);
    for (final kind in HeartAttackKind.values) {
      for (final period in HeartAttackPeriod.values) {
        expect(find.byKey(HeartAttacksMenu.minusKey(kind, period)),
            findsOneWidget);
        expect(find.byKey(HeartAttacksMenu.plusKey(kind, period)),
            findsOneWidget);
      }
    }
  });

  testWidgets('+ in the dialog moves the dialog number and the card row',
      (tester) async {
    await openEditorViaCard(tester);
    final cell =
        find.descendant(of: dialog(), matching: find.text('1'));
    expect(cell, findsOneWidget);
    await tester.tap(find.descendant(
        of: dialog(),
        matching: find.byKey(HeartAttacksMenu.plusKey(
            HeartAttackKind.major, HeartAttackPeriod.thisScenario))));
    await tester.pumpAndSettle();
    expect(find.descendant(of: dialog(), matching: find.text('2')),
        findsOneWidget);
    final rowTexts = find.descendant(
        of: majorRow(), matching: find.byType(Text));
    expect(tester.widget<Text>(rowTexts.last).data, '2');
  });

  testWidgets('close dismisses the editor', (tester) async {
    await openEditorViaCard(tester);
    await tester.tap(find.descendant(
        of: dialog(), matching: find.text(l10n.close)));
    await tester.pumpAndSettle();
    expect(dialog(), findsNothing);
    expect(majorRow(), findsOneWidget);
  });

  testWidgets('a hero with no heart attacks can tap a tally to add some',
      (tester) async {
    await tester.pumpWidget(board());
    await tester.tap(majorRow());
    await tester.pumpAndSettle();
    expect(dialog(), findsOneWidget);
  });

  testWidgets('a tap away from the tallies still opens the status menu',
      (tester) async {
    await tester.pumpWidget(board());
    await tester.tap(find.byType(CharacterWidget));
    await tester.pumpAndSettle();
    expect(find.byType(StatusMenu), findsOneWidget);
    expect(dialog(), findsNothing);
  });

  testWidgets('during attack picking a tally tap picks the hero',
      (tester) async {
    final attack = attackModeController();
    await tester.pumpWidget(board());
    hit();
    await tester.pump();
    attack.startSelecting();
    await tester.pump();
    await tester.tap(majorRow());
    await tester.pumpAndSettle();
    expect(attack.isPicked(heroId, heroId), isTrue);
    expect(dialog(), findsNothing);
  });

  Finder entry() => find.byKey(StatusMenuStatColumn.heartAttacksKey);

  String? total(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data;

  testWidgets('the status menu shows little / major totals, like level',
      (tester) async {
    hit();
    await tester.pumpWidget(menuOf(heroId));
    await tester.pumpAndSettle();
    expect(entry(), findsOneWidget);
    expect(total(tester, StatusMenuStatColumn.littleTotalKey), '0');
    expect(total(tester, StatusMenuStatColumn.majorTotalKey), '1');
    final icons = tester
        .widgetList<KielbasaIcon>(
            find.descendant(of: entry(), matching: find.byType(KielbasaIcon)))
        .map((i) => i.recovering);
    expect(icons, [true, false]);
    await tester.tap(entry());
    await tester.pumpAndSettle();
    expect(dialog(), findsOneWidget);
    // The status menu stays underneath, as it does for the level popup.
    expect(find.byType(StatusMenu), findsOneWidget);
    // Totals count both periods.
    await tester.tap(find.byKey(HeartAttacksMenu.plusKey(
        HeartAttackKind.little, HeartAttackPeriod.earlier)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HeartAttacksMenu.plusKey(
        HeartAttackKind.little, HeartAttackPeriod.thisScenario)));
    await tester.pumpAndSettle();
    expect(total(tester, StatusMenuStatColumn.littleTotalKey), '2');
  });

  testWidgets('the totals sit on the same grid as the skull and level row',
      (tester) async {
    await tester.pumpWidget(menuOf(heroId));
    await tester.pumpAndSettle();
    Finder asset(String name) => find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == 'assets/images/psd/$name.png');
    final skull = tester.getCenter(asset('skull'));
    final level = tester.getCenter(asset('level'));
    final icons = find.descendant(
        of: entry(), matching: find.byType(KielbasaIcon));
    expect(tester.getCenter(icons.first).dx, moreOrLessEquals(skull.dx));
    expect(tester.getCenter(icons.last).dx, moreOrLessEquals(level.dx));
    // The major total starts where the level number does.
    final levelButton =
        find.ancestor(of: asset('level'), matching: find.byType(IconButton));
    expect(
        tester.getTopLeft(find.byKey(StatusMenuStatColumn.majorTotalKey)).dx,
        moreOrLessEquals(tester.getTopRight(levelButton).dx));
    // The little total stays between the two sausages.
    final little =
        tester.getRect(find.byKey(StatusMenuStatColumn.littleTotalKey));
    expect(little.left, greaterThanOrEqualTo(tester.getRect(icons.first).right));
    expect(little.right, lessThanOrEqualTo(tester.getRect(icons.last).left));
  });

  testWidgets('an Objective gets no heart-attack control', (tester) async {
    AddCharacterCommand('Objective', 'na', 'whatever', 1).execute();
    final objective = gs.currentList
        .whereType<Character>()
        .firstWhere((c) => GameMethods.isObjectiveOrEscort(c.characterClass));
    await tester.pumpWidget(menuOf(objective.id));
    await tester.pumpAndSettle();
    expect(entry(), findsNothing);
  });

  testWidgets('minus is disabled at 0, so no empty Undo step', (tester) async {
    await tester.pumpWidget(
        testApp(Scaffold(body: HeartAttacksMenu(characterId: heroId))));
    await tester.pumpAndSettle();
    final minus = find.byKey(HeartAttacksMenu.minusKey(
        HeartAttackKind.little, HeartAttackPeriod.thisScenario));
    final plus = find.byKey(HeartAttacksMenu.plusKey(
        HeartAttackKind.little, HeartAttackPeriod.thisScenario));
    expect(tester.widget<IconButton>(minus).onPressed, isNull);
    final before = gs.commandIndex.value;
    await tester.tap(minus);
    await tester.pumpAndSettle();
    expect(gs.commandIndex.value, before);
    // Above zero it works again.
    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(minus).onPressed, isNotNull);
  });

  testWidgets('plus is disabled at 99', (tester) async {
    for (int i = 0; i < AdjustHeartAttacksCommand.max; i++) {
      gs.action(AdjustHeartAttacksCommand(
          characterId: heroId,
          kind: HeartAttackKind.major,
          period: HeartAttackPeriod.earlier,
          change: 1,
          gameState: gs));
    }
    await tester.pumpWidget(
        testApp(Scaffold(body: HeartAttacksMenu(characterId: heroId))));
    await tester.pumpAndSettle();
    final plus = find.byKey(HeartAttacksMenu.plusKey(
        HeartAttackKind.major, HeartAttackPeriod.earlier));
    expect(tester.widget<IconButton>(plus).onPressed, isNull);
  });

  testWidgets('each row label carries its kielbasa, pale for little',
      (tester) async {
    await tester.pumpWidget(
        testApp(Scaffold(body: HeartAttacksMenu(characterId: heroId))));
    await tester.pumpAndSettle();
    final icons = tester
        .widgetList<KielbasaIcon>(find.byType(KielbasaIcon))
        .toList();
    expect(icons.map((i) => i.recovering), [true, false]);
  });

  testWidgets('the setting hides the heart-attack control', (tester) async {
    getIt<Settings>().heartAttacks.value = false;
    await tester.pumpWidget(menuOf(heroId));
    await tester.pumpAndSettle();
    expect(entry(), findsNothing);
  });
}
