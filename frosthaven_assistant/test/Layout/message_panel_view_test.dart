// ignore_for_file: no-magic-number, avoid-top-level-members-in-tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/main_scaffold.dart';
import 'package:frosthaven_assistant/Layout/message_panel.dart';
import 'package:frosthaven_assistant/Resource/commands/set_scenario_command.dart';
import 'package:frosthaven_assistant/Resource/message_panel.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
    loading.value = false;
  });

  setUp(() {
    MessagePanel.reset();
    getIt<GameState>().clearList();
    getIt<Settings>().gameStyleMessages.value = true;
    loading.value = false;
  });
  tearDown(() => MessagePanel.reset());

  /// The panel inside a bare Scaffold, like MainScaffoldBody holds it.
  Future<void> openPanel(WidgetTester tester) async {
    await tester.pumpWidget(testApp(Scaffold(
        body: Stack(children: const [SizedBox.expand(), MessagePanelNotifier()]))));
    await tester.pump();
  }

  /// Three messages of the three looks, so positions and stacking show.
  Future<void> fill(MessagePanel panel, WidgetTester tester) async {
    panel.add(const MessageEntry(MessageKind.reminder, 'reminder text'));
    panel.add(const MessageEntry(MessageKind.line, 'Kling: write it down.'));
    await tester.pump();
  }

  group('the panel on screen', () {
    testWidgets('shows every entry, newest at the bottom', (tester) async {
      await openPanel(tester);
      final panel = MessagePanel.instance;
      panel.add(const MessageEntry(MessageKind.reminder, 'reminder text'));
      panel.add(const MessageEntry(MessageKind.line, 'newest line'));
      await tester.pump();
      expect(find.text('reminder text'), findsOneWidget);
      expect(find.text('newest line'), findsOneWidget);
      expect(tester.getCenter(find.text('newest line')).dy,
          greaterThan(tester.getCenter(find.text('reminder text')).dy));
      panel.cancelTimers();
    });

    testWidgets('tapping one message removes only that one', (tester) async {
      await openPanel(tester);
      final panel = MessagePanel.instance;
      await fill(panel, tester);
      await tester.tap(find.text('Kling: write it down.'));
      await tester.pump();
      expect(find.text('Kling: write it down.'), findsNothing);
      expect(find.text('reminder text'), findsOneWidget);
      panel.cancelTimers();
    });

    testWidgets('a tap outside the messages reaches the board',
        (tester) async {
      var boardTaps = 0;
      await tester.pumpWidget(testApp(Scaffold(
          body: Stack(children: [
            GestureDetector(
                onTap: () => boardTaps++,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand()),
            const MessagePanelNotifier(),
          ]))));
      await tester.pump();
      final panel = MessagePanel.instance;
      panel.add(const MessageEntry(MessageKind.line, 'Kling: write it down.'));
      await tester.pump();
      // The same height as the message, far to its left: parchment leaves
      // that strip free, and the tap must reach the board under it.
      final dy = tester.getCenter(find.text('Kling: write it down.')).dy;
      await tester.tapAt(const Offset(2, 0) + Offset(0, dy));
      await tester.pump();
      expect(boardTaps, 1);
      expect(find.text('Kling: write it down.'), findsOneWidget);
      panel.cancelTimers();
    });

    testWidgets('the parchment banner look, by default', (tester) async {
      await openPanel(tester);
      final panel = MessagePanel.instance;
      panel.add(const MessageEntry(MessageKind.line, 'a line'));
      await tester.pump();
      final box = tester.widget<DecoratedBox>(
          find.ancestor(
              of: find.text('a line'), matching: find.byType(DecoratedBox)));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, kPanelParchment);
      expect(decoration.border?.top.color, kPanelBorder);
      panel.cancelTimers();
    });

    testWidgets('the teal bar when the game-style banner is off',
        (tester) async {
      getIt<Settings>().gameStyleMessages.value = false;
      await openPanel(tester);
      final panel = MessagePanel.instance;
      panel.add(const MessageEntry(MessageKind.line, 'a line'));
      await tester.pump();
      final box = tester.widget<ColoredBox>(find.descendant(
          of: find.byType(MessagePanelNotifier),
          matching: find.byType(ColoredBox)));
      expect(box.color, kPanelTeal);
      panel.cancelTimers();
    });

    testWidgets('a network error keeps its Retry button', (tester) async {
      await openPanel(tester);
      final panel = MessagePanel.instance;
      var retries = 0;
      panel.add(MessageEntry(MessageKind.error, 'connection lost',
          onRetry: () => retries++));
      await tester.pump();
      await tester.tap(find.text('RETRY'));
      await tester.pump();
      expect(retries, 1);
      expect(panel.entries, isEmpty);
    });

    testWidgets('long text wraps without overflow on a phone screen',
        (tester) async {
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openPanel(tester);
      final panel = MessagePanel.instance;
      panel.add(MessageEntry(
          MessageKind.reminder,
          List.generate(6, (i) => 'round ${i + 1}: remember this').join('\n')));
      panel.add(const MessageEntry(
          MessageKind.error, 'could not reach the other device at all'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(MessagePanelNotifier), findsOneWidget);
    });
  });

  group('in the real scaffold', () {
    testWidgets('a message stays visible and tappable above the decks',
        (tester) async {
      final gs = getIt<GameState>();
      final campaign = gs.currentCampaign as ValueNotifier<String>;
      final before = campaign.value;
      campaign.value = 'Frosthaven';
      addTearDown(() => campaign.value = before);
      gs.action(SetScenarioCommand('#0 Howling in the Snow', false,
          gameState: gs));
      addTearDown(() => gs.undo());

      final originalOnError = FlutterError.onError;
      addTearDown(() => FlutterError.onError = originalOnError);
      FlutterError.onError = ignoreOverflowErrors;
      await tester.pumpWidget(testApp(const MainScaffold()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      FlutterError.onError = originalOnError;

      final panel = MessagePanel.instance;
      panel.add(const MessageEntry(MessageKind.line, 'Kling: write it down.'));
      await tester.pump();
      // The decks really are on screen there.
      expect(find.text('Kling: write it down.'), findsOneWidget);
      await tester.tap(find.text('Kling: write it down.'));
      await tester.pump();
      expect(find.text('Kling: write it down.'), findsNothing);
    });
  });
}
