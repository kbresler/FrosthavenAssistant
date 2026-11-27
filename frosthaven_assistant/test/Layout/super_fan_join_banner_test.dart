// ignore_for_file: avoid-late-keyword

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/main_scaffold.dart';
import 'package:frosthaven_assistant/Layout/message_panel.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/message_panel.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';
import 'package:frosthaven_assistant/services/network/network.dart';
import 'package:frosthaven_assistant/services/network/superfan/fans.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  late GameState gameState;
  late Network network;

  setUp(() {
    MessagePanel.reset();
    gameState = getIt<GameState>();
    network = getIt<Network>();
    gameState.clearList();
    network.superFanJoined.value = null;
  });
  tearDown(() => MessagePanel.reset());

  Future<void> pumpBanner(WidgetTester tester) async {
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
        // The banner arrives as a panel entry: the notifier needs the panel
        // on screen, as in MainScaffoldBody.
        home: const Scaffold(
          body: Stack(children: [
            SizedBox.expand(),
            SuperFanJoinBannerNotifier(),
            MessagePanelNotifier(),
          ]),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the banner names the characters the phone plays',
      (tester) async {
    AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
    AddCharacterCommand('Banner Spear', 'Frosthaven', null, 1).execute();

    await pumpBanner(tester);
    network.superFanJoined.value = const SwerskiFan(
        id: 'dev-1', name: 'Kitchen tablet', plays: ['Blinkblade', 'Banner Spear']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
        find.text(
            "Da Bears! Blinkblade & Banner Spear's phone is on the SuperNetwork"),
        findsOneWidget);
    // Consumed, so the next arrival can banner again.
    expect(network.superFanJoined.value, isNull);
    MessagePanel.instance.cancelTimers();
  });

  testWidgets('nothing played means the table is on the SuperNetwork',
      (tester) async {
    await pumpBanner(tester);
    network.superFanJoined.value =
        const SwerskiFan(id: 'dev-2', name: 'Laptop');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Da Bears! The table is on the SuperNetwork'),
        findsOneWidget);
    expect(network.superFanJoined.value, isNull);
    MessagePanel.instance.cancelTimers();
  });

  testWidgets('a character that left the game still shows its id',
      (tester) async {
    await pumpBanner(tester);
    network.superFanJoined.value = const SwerskiFan(
        id: 'dev-3', name: 'Old phone', plays: ['gone@7']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
        find.text("Da Bears! gone@7's phone is on the SuperNetwork"),
        findsOneWidget);
    MessagePanel.instance.cancelTimers();
  });
}
