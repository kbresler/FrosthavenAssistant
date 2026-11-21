import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/empty_board_prompt.dart';
import 'package:frosthaven_assistant/Layout/menus/SelectScenarioMenu/select_scenario_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/add_character_menu.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  setUp(() => getIt<GameState>().clearList());

  Future<void> pumpPrompt(WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = ignoreOverflowErrors;
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [Locale('en')],
      home: Scaffold(body: EmptyBoardPrompt()),
    ));
    await tester.pump();
  }

  group('EmptyBoardPrompt (Swerski)', () {
    testWidgets('an empty board shows Set Scenario and Add Character',
        (tester) async {
      await pumpPrompt(tester);
      expect(find.widgetWithText(FilledButton, 'Set Scenario'), findsOneWidget);
      expect(
          find.widgetWithText(FilledButton, 'Add Character'), findsOneWidget);
    });

    testWidgets('disappears once something is on the board', (tester) async {
      await pumpPrompt(tester);
      AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
      await tester.pump();
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('Set Scenario opens the scenario menu', (tester) async {
      await pumpPrompt(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Set Scenario'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SelectScenarioMenu), findsOneWidget);
    });

    testWidgets('Add Character opens the character menu', (tester) async {
      await pumpPrompt(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add Character'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AddCharacterMenu), findsOneWidget);
    });
  });
}
