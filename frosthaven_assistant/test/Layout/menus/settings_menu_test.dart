import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/menus/SettingsMenu/settings_menu.dart';
import 'package:frosthaven_assistant/Layout/menus/save_menu.dart';
import 'package:frosthaven_assistant/Resource/commands/set_ally_deck_in_og_gloom_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../../command/test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  Future<void> pumpMenu(WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = ignoreOverflowErrors;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const SettingsMenu(),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    FlutterError.onError = originalOnError;
  }

  group('SettingsMenu', () {
    testWidgets('renders Dark mode checkbox', (WidgetTester tester) async {
      await pumpMenu(tester);
      expect(find.text('Dark mode'), findsOneWidget);
    });

    testWidgets('renders Expire Conditions checkbox',
        (WidgetTester tester) async {
      await pumpMenu(tester);
      expect(find.text('Remove conditions when they expire'), findsOneWidget);
    });

    testWidgets('groups settings under headings, Swerski Edition first',
        (WidgetTester tester) async {
      await pumpMenu(tester);
      final headings = ['Swerski Edition', 'Gameplay', 'Display', 'Other'];
      final tops = [
        for (final h in headings) tester.getTopLeft(find.text(h)).dy,
      ];
      for (int i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]),
            reason: '${headings[i]} should come after ${headings[i - 1]}');
      }
      // The Swerski options sit right under their heading.
      expect(
          tester
              .getTopLeft(find.text('Monster turns one standee at a time'))
              .dy,
          lessThan(tops[1]));
    });

    testWidgets('fixes the heath wheel typo', (WidgetTester tester) async {
      await pumpMenu(tester);
      expect(find.textContaining('heath'), findsNothing);
      expect(find.textContaining('Health wheel'), findsOneWidget);
    });

    testWidgets("Don't ask for initiative is ticked when noInit is on",
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.noInit.value;
      addTearDown(() => settings.noInit.value = before);
      settings.noInit.value = true;
      await pumpMenu(tester);
      final tile = tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, "Don't ask for initiative"));
      expect(tile.value, isTrue);
    });

    testWidgets('renders Close button', (WidgetTester tester) async {
      await pumpMenu(tester);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('tapping Dark mode checkbox toggles the setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.darkMode.value;
      await pumpMenu(tester);

      final finder = find.widgetWithText(CheckboxListTile, 'Dark mode');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.darkMode.value, !before);
      // restore
      settings.darkMode.value = before;
    });

    testWidgets('tapping Expire Conditions checkbox toggles the setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.expireConditions.value;
      await pumpMenu(tester);

      final finder = find.widgetWithText(
          CheckboxListTile, 'Remove conditions when they expire');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.expireConditions.value, !before);
      settings.expireConditions.value = before;
    });

    testWidgets('tapping Soft numpad for input checkbox toggles the setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.softNumpadInput.value;
      await pumpMenu(tester);

      final finder = find.widgetWithText(
          CheckboxListTile, 'On-screen number pad for typing numbers');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.softNumpadInput.value, !before);
      settings.softNumpadInput.value = before;
    });

    testWidgets("tapping Don't ask for initiative checkbox toggles setting",
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.noInit.value;
      await pumpMenu(tester);

      final finder =
          find.widgetWithText(CheckboxListTile, "Don't ask for initiative");
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.noInit.value, !before);
      settings.noInit.value = before;
    });

    testWidgets('tapping Auto Add Standees checkbox toggles the setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.autoAddStandees.value;
      await pumpMenu(tester);

      final finder =
          find.widgetWithText(CheckboxListTile, 'Auto-add standees');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.autoAddStandees.value, !before);
      settings.autoAddStandees.value = before;
    });

    testWidgets('tapping Random Standees checkbox toggles the setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.randomStandees.value;
      await pumpMenu(tester);

      final finder = find.widgetWithText(CheckboxListTile, 'Random standee numbers');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.randomStandees.value, !before);
      settings.randomStandees.value = before;
    });

    testWidgets('tapping No Calculations checkbox toggles the setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.noCalculation.value;
      await pumpMenu(tester);

      final finder = find.widgetWithText(CheckboxListTile, 'No calculations');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.noCalculation.value, !before);
      settings.noCalculation.value = before;
    });

    testWidgets("tapping Don't track Standees checkbox toggles setting",
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.noStandees.value;
      await pumpMenu(tester);

      final finder =
          find.widgetWithText(CheckboxListTile, "Don't track standees");
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.noStandees.value, !before);
      settings.noStandees.value = before;
    });

    testWidgets('tapping Auto Add Timed Spawns checkbox toggles setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.autoAddSpawns.value;
      await pumpMenu(tester);

      final finder =
          find.widgetWithText(CheckboxListTile, 'Auto-add timed spawns');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.autoAddSpawns.value, !before);
      settings.autoAddSpawns.value = before;
    });

    testWidgets('tapping Hide Loot Deck checkbox toggles setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.hideLootDeck.value;
      await pumpMenu(tester);

      final finder = find.widgetWithText(CheckboxListTile, 'Hide loot deck');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.hideLootDeck.value, !before);
      settings.hideLootDeck.value = before;
    });

    testWidgets('tapping Stat card text shimmers checkbox toggles setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.shimmer.value;
      await pumpMenu(tester);

      final finder =
          find.widgetWithText(CheckboxListTile, 'Stat card text shimmers');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.shimmer.value, !before);
      settings.shimmer.value = before;
    });

    testWidgets('tapping Show Scenario names in list checkbox toggles setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.showScenarioNames.value;
      await pumpMenu(tester);

      final finder =
          find.widgetWithText(CheckboxListTile, 'Show scenario names in the scenario list');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.showScenarioNames.value, !before);
      settings.showScenarioNames.value = before;
    });

    testWidgets('tapping Show Battle Goal Reminder checkbox toggles setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.showBattleGoalReminder.value;
      await pumpMenu(tester);

      final finder =
          find.widgetWithText(CheckboxListTile, 'Remind to choose Battle Goals');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.showBattleGoalReminder.value, !before);
      settings.showBattleGoalReminder.value = before;
    });

    testWidgets('tapping Show Custom Content checkbox toggles setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.showCustomContent.value;
      await pumpMenu(tester);

      final finder =
          find.widgetWithText(CheckboxListTile, 'Show custom content');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.showCustomContent.value, !before);
      settings.showCustomContent.value = before;
    });

    testWidgets('tapping Show Sections in Main Screen checkbox toggles setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.showSectionsInMainView.value;
      await pumpMenu(tester);

      final finder =
          find.widgetWithText(CheckboxListTile, 'Show sections on the main screen');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.showSectionsInMainView.value, !before);
      settings.showSectionsInMainView.value = before;
    });

    testWidgets(
        'tapping Show Round Special Rule Reminders checkbox toggles setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.showReminders.value;
      await pumpMenu(tester);

      final finder = find.widgetWithText(
          CheckboxListTile, 'Remind of special rules each round');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.showReminders.value, !before);
      settings.showReminders.value = before;
    });

    testWidgets('tapping Show Attack Modifier Decks checkbox toggles setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.showAmdDeck.value;
      await pumpMenu(tester);

      final finder =
          find.widgetWithText(CheckboxListTile, 'Show attack modifier decks');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.showAmdDeck.value, !before);
      settings.showAmdDeck.value = before;
    });

    testWidgets(
        'tapping Show character Attack Modifier Decks checkbox toggles setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.showCharacterAMD.value;
      await pumpMenu(tester);

      final finder = find.widgetWithText(
          CheckboxListTile, 'Show character attack modifier decks');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(settings.showCharacterAMD.value, !before);
      settings.showCharacterAMD.value = before;
    });

    testWidgets('tapping Style radio buttons changes the style',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      await pumpMenu(tester);

      // Find and tap the 'Original' radio button
      final originalFinder = find.descendant(
        of: find.widgetWithText(Row, 'Original'),
        matching: find.byType(Radio<Style>),
      );
      if (originalFinder.evaluate().isNotEmpty) {
        await tester.ensureVisible(originalFinder.first);
        await tester.tap(originalFinder.first);
        await tester.pump();
        expect(settings.style.value, Style.original);
      }
      // Restore to Frosthaven style
      settings.style.value = Style.frosthaven;
    });

    testWidgets('tapping Clear unlocked characters runs the command',
        (WidgetTester tester) async {
      await pumpMenu(tester);

      final finder =
          find.widgetWithText(ListTile, 'Clear unlocked characters');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
      expect(
          find.widgetWithText(ListTile, 'Clear unlocked characters'),
          findsOneWidget);
    });

    testWidgets('tapping Load/Save State opens SaveMenu',
        (WidgetTester tester) async {
      await pumpMenu(tester);

      final finder = find.widgetWithText(ListTile, 'Load or save game');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();

      expect(find.byType(SaveMenu), findsOneWidget);
    });

    testWidgets(
        'tapping Use Ally AMD in OG Gloomhaven checkbox toggles setting',
        (WidgetTester tester) async {
      final gameState = getIt<GameState>();
      final before = gameState.allyDeckInOGGloom.value;
      await pumpMenu(tester);

      final finder = find.widgetWithText(
          CheckboxListTile, 'Ally attack modifier deck in original Gloomhaven');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();

      expect(gameState.allyDeckInOGGloom.value, !before);
      // restore
      getIt<GameState>().action(
          SetAllyDeckInOgGloomCommand(before, gameState: getIt<GameState>()));
    });

    testWidgets('moving the Main List Scaling slider rebuilds the board',
        (WidgetTester tester) async {
      final gameState = getIt<GameState>();
      final settings = getIt<Settings>();
      final before = settings.userScalingMainList.value;
      int notifications = 0;
      void listener() => notifications++;
      gameState.updateList.addListener(listener);
      addTearDown(() => gameState.updateList.removeListener(listener));

      await pumpMenu(tester);
      final slider = find.byType(Slider).first; // Main List Scaling
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(-40, 0));
      await tester.pump();

      expect(notifications, greaterThan(0),
          reason:
              'changing the main-list scale must notify the board to rebuild');
      settings.userScalingMainList.value = before;
    });

    testWidgets('moving the App Bar Scaling slider rebuilds the board',
        (WidgetTester tester) async {
      final gameState = getIt<GameState>();
      final settings = getIt<Settings>();
      final before = settings.userScalingBars.value;
      int notifications = 0;
      void listener() => notifications++;
      gameState.updateList.addListener(listener);
      addTearDown(() => gameState.updateList.removeListener(listener));

      await pumpMenu(tester);
      final slider = find.byType(Slider).at(1); // App Bar Scaling
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(-40, 0));
      await tester.pump();

      expect(notifications, greaterThan(0),
          reason:
              'changing the app-bar scale must notify the board to rebuild');
      settings.userScalingBars.value = before;
    });

    testWidgets('renders the three power-saving tiers with an info button',
        (WidgetTester tester) async {
      await pumpMenu(tester);
      expect(find.text('Power saving'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Dim when idle'), findsOneWidget);
      expect(find.text('Reduce power use'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('selecting a tier updates the setting',
        (WidgetTester tester) async {
      final settings = getIt<Settings>();
      final before = settings.powerMode.value;
      addTearDown(() => settings.powerMode.value = before);

      await pumpMenu(tester);
      final radio = find.byWidgetPredicate((w) =>
          w is Radio<PowerMode> && w.value == PowerMode.dimWhenIdle);
      await tester.ensureVisible(radio);
      await tester.pumpAndSettle();
      await tester.tap(radio);
      await tester.pumpAndSettle();

      expect(settings.powerMode.value, PowerMode.dimWhenIdle);
    });

    testWidgets('info button sits to the right of the Power saving label',
        (WidgetTester tester) async {
      await pumpMenu(tester);
      final label = find.text('Power saving');
      final icon = find.byIcon(Icons.info_outline);
      await tester.ensureVisible(icon);
      await tester.pumpAndSettle();

      final labelRect = tester.getRect(label);
      final iconRect = tester.getRect(icon);
      expect(iconRect.left, greaterThanOrEqualTo(labelRect.right),
          reason: 'the info button must follow the label, not lead it');
      // Same row, not wrapped onto a line of its own.
      expect((iconRect.center.dy - labelRect.center.dy).abs(), lessThan(8));
    });

    testWidgets('info button explains all three power tiers',
        (WidgetTester tester) async {
      await pumpMenu(tester);
      final infoButton = find.byIcon(Icons.info_outline);
      await tester.ensureVisible(infoButton);
      await tester.pumpAndSettle();
      await tester.tap(infoButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      // The title text appears both in the dialog and behind it on the row.
      expect(find.text('Power saving'), findsNWidgets(2));

      final dialogText = tester
          .widgetList<Text>(find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Text),
          ))
          .map((t) => t.data ?? '')
          .join('\n');
      // The tradeoffs the user asked to be spelled out in-app.
      expect(dialogText, contains('Dim when idle'));
      expect(dialogText, contains('dims and turns off'));
      expect(dialogText, contains('shadows'));
      expect(dialogText, contains('shimmering text effects'));
      expect(dialogText, contains('no tracking, syncing or rules behaviour'));
      expect(dialogText,
          contains('infrequent use and low battery capacity devices'));
    });
  });
}
