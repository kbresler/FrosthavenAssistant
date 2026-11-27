// ignore_for_file: avoid-late-keyword, no-magic-number

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/CharacterWidget/character_widget_internal.dart';
import 'package:frosthaven_assistant/Layout/menus/super_fan_choice_menu.dart';
import 'package:frosthaven_assistant/Resource/app_constants.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../../command/test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  late GameState gameState;
  late Settings settings;

  setUp(() {
    gameState = getIt<GameState>();
    settings = getIt<Settings>();
    gameState.clearList();
    settings.devicePlays.value = [];
    CharacterWidgetInternal.localCharacterInitChanges.clear();
  });

  Character add(String className, {String edition = 'Frosthaven'}) {
    AddCharacterCommand(className, edition, null, 1).execute();
    // addToMainList inserts at the top.
    return gameState.currentList.whereType<Character>().first;
  }

  List<String>? result;

  Future<void> pumpMenu(
    WidgetTester tester,
    List<Character> characters, {
    List<String>? storedPlays,
  }) async {
    result = null;
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
              showDialog<List<String>>(
                context: context,
                // Same wrapping as openDialogWithDismissOption: without the
                // Dialog, the route gives the menu unbounded height and
                // CheckboxListTile inflates to a bogus size.
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(kDialogInsetPadding),
                  child: SuperFanChoiceMenu(
                    characters: characters,
                    storedPlays: storedPlays ?? settings.devicePlays.value,
                  ),
                ),
              ).then((picks) => result = picks);
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

  List<CheckboxListTile> tiles(WidgetTester tester) =>
      tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();

  Future<void> tick(WidgetTester tester, int index) async {
    // Tapping the row toggles it, same as the box.
    await tester.tap(find.byType(CheckboxListTile).at(index));
    await tester.pump();
  }

  group('SuperFanChoiceMenu', () {
    testWidgets('lists the characters with the stored choice pre-ticked',
        (tester) async {
      final blink = add('Blinkblade');
      final spear = add('Banner Spear');
      settings.devicePlays.value = [spear.id];

      await pumpMenu(tester, [blink, spear]);

      final listed = tiles(tester);
      expect(listed.length, equals(2));
      expect(listed[0].value, isFalse);
      expect(listed[1].value, isTrue);
    });

    testWidgets('pre-ticks local initiative when the stored choice is gone',
        (tester) async {
      final blink = add('Blinkblade');
      settings.devicePlays.value = ['gone@7'];
      CharacterWidgetInternal.localCharacterInitChanges.add(blink.id);

      await pumpMenu(tester, [blink]);

      expect(tiles(tester)[0].value, isTrue);
    });

    testWidgets('nothing is pre-ticked when neither matches', (tester) async {
      final blink = add('Blinkblade');
      settings.devicePlays.value = ['gone@7'];

      await pumpMenu(tester, [blink]);

      expect(tiles(tester)[0].value, isFalse);
    });

    testWidgets('a fifth tick is refused', (tester) async {
      final characters = [
        add('Blinkblade'),
        add('Banner Spear'),
        add('Hail', edition: 'Mercenary Packs'),
        add('Pain Conduit'),
        add('Hatchet', edition: 'Jaws of the Lion'),
      ];

      await pumpMenu(tester, characters);

      for (final index in [0, 1, 2, 3]) {
        await tick(tester, index);
      }

      expect(tiles(tester).length, equals(5));
      final fifth = tiles(tester)[4];
      expect(fifth.value, isFalse);
      expect(fifth.onChanged, isNull);
    });

    testWidgets('OK pops the ticks in list order', (tester) async {
      final blink = add('Blinkblade');
      final spear = add('Banner Spear');
      final hail = add('Hail', edition: 'Mercenary Packs');

      // Menu order follows the list passed in.
      await pumpMenu(tester, [blink, spear, hail]);

      await tick(tester, 0);
      await tick(tester, 2);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(result, equals([blink.id, hail.id]));
    });

    testWidgets('nothing ticked pops the empty table choice', (tester) async {
      add('Blinkblade');

      await pumpMenu(tester, gameState.currentList.whereType<Character>()
          .toList());
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(result, isEmpty);
    });

    testWidgets('dismiss pops null', (tester) async {
      add('Blinkblade');

      await pumpMenu(
          tester, gameState.currentList.whereType<Character>().toList());

      // The barrier around the dialog; a dismiss keeps the stored choice
      // (the trigger re-sends it unchanged).
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}
