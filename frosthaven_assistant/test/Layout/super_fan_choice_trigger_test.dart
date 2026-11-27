// ignore_for_file: avoid-late-keyword

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/CharacterWidget/character_widget_internal.dart';
import 'package:frosthaven_assistant/Layout/main_scaffold.dart';
import 'package:frosthaven_assistant/Layout/menus/super_fan_choice_menu.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';
import 'package:frosthaven_assistant/services/network/client.dart';
import 'package:frosthaven_assistant/services/network/network.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';
import 'menus/super_fan_test_client.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  late GameState gameState;
  late Network network;
  late Settings settings;

  setUp(() {
    gameState = getIt<GameState>();
    network = getIt<Network>();
    settings = getIt<Settings>();
    gameState.clearList();
    settings.devicePlays.value = [];
    settings.client.value = ClientState.disconnected;
    network.hostGreeted.value = false;
    network.superFanChoiceRequested.value = false;
    CharacterWidgetInternal.localCharacterInitChanges.clear();
  });

  Future<void> pumpTriggerAndRequest(WidgetTester tester,
      {Client? client}) async {
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
        home: Scaffold(
          body: SuperFanChoiceDialogTrigger(client: client ?? Client()),
        ),
      ),
    );
    network.superFanChoiceRequested.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a request opens the picker and OK stores the choice',
      (tester) async {
    AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();

    await pumpTriggerAndRequest(tester);

    expect(find.byType(SuperFanChoiceMenu), findsOneWidget);
    expect(network.superFanChoiceRequested.value, isFalse);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(settings.devicePlays.value, equals(['Blinkblade']));
  });

  testWidgets('a game without characters does not open the picker',
      (tester) async {
    await pumpTriggerAndRequest(tester);

    expect(find.byType(SuperFanChoiceMenu), findsNothing);
    // The request is consumed, but the question stays unasked (the client
    // keeps it for the next connection; covered in client_test).
    expect(network.superFanChoiceRequested.value, isFalse);
  });

  testWidgets('dismissing the picker still greets with the stored choice',
      (tester) async {
    AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
    settings.client.value = ClientState.connected;
    network.hostGreeted.value = true;
    final client = RecordingClient();

    await pumpTriggerAndRequest(tester, client: client);
    expect(find.byType(SuperFanChoiceMenu), findsOneWidget);

    // Tap the scrim: the picker closes without OK.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SuperFanChoiceMenu), findsNothing);
    // The stored choice stands, and the host gets the normal greeting so it
    // announces the device instead of waiting for an OK that never comes.
    expect(client.savedPlays, isEmpty);
    expect(client.nothingToAsk, 1);
  });
}
