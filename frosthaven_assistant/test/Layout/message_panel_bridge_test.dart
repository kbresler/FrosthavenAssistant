// ignore_for_file: no-magic-number, avoid-top-level-members-in-tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/main_scaffold.dart';
import 'package:frosthaven_assistant/Layout/message_panel.dart';
import 'package:frosthaven_assistant/Resource/commands/command_l10n.dart';
import 'package:frosthaven_assistant/Resource/message_panel.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

const reminder = 'Round 1: spawn adds at the marked spaces.';

String woundText([String who = 'Kling -1']) =>
    commandL10n.toastWoundDamage(who);

void main() {
  setUpAll(() async {
    await setUpGame();
    loading.value = false;
  });

  setUp(() {
    MessagePanel.reset();
    getIt<GameState>().clearList();
    GameUtilMethods.setToastMessage('', gameState: getIt<GameState>());
  });
  tearDown(() => MessagePanel.reset());

  /// The scaffold's pair: ToastNotifier bridges `toastMessage`,
  /// MessagePanelNotifier draws it.
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(testApp(Scaffold(
        body: Stack(children: const [
      SizedBox.expand(),
      ToastNotifier(),
      MessagePanelNotifier(),
    ]))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Changes the game message mid-test and lets the bridge (postFrame) and
  /// the panel repaint.
  Future<void> setMessage(WidgetTester tester, String text) async {
    GameUtilMethods.setToastMessage(text, gameState: getIt<GameState>());
    await tester.pump(); // ToastNotifier rebuilds, its postFrame syncs
    await tester.pump(); // the panel change repaints
  }

  Future<void> advance(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 100);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  group('rule 5: one game message, two panel entries', () {
    testWidgets('a reminder already in the message is shown at first sight',
        (tester) async {
      GameUtilMethods.setToastMessage(reminder, gameState: getIt<GameState>());
      await open(tester);
      expect(find.text(reminder), findsOneWidget);
    });

    testWidgets('a wound leaves the reminder on screen: both visible',
        (tester) async {
      GameUtilMethods.setToastMessage(reminder, gameState: getIt<GameState>());
      await open(tester);
      await setMessage(tester, woundText());
      expect(find.text(reminder), findsOneWidget);
      expect(find.text(woundText()), findsOneWidget);
      MessagePanel.instance.cancelTimers();
    });

    testWidgets('the wound leaves after 6 s, the reminder stays; '
        'next round (message cleared) takes it too', (tester) async {
      GameUtilMethods.setToastMessage(reminder, gameState: getIt<GameState>());
      await open(tester);
      await setMessage(tester, woundText());
      await advance(tester, const Duration(seconds: 6, milliseconds: 300));
      expect(find.text(woundText()), findsNothing);
      expect(find.text(reminder), findsOneWidget);
      // The wound's exit wrote the reminder back into the game message.
      expect(getIt<GameState>().toastMessage.value, reminder);
      // Next round.
      await setMessage(tester, '');
      expect(find.text(reminder), findsNothing);
    });

    testWidgets('tapping the wound early writes the reminder back',
        (tester) async {
      GameUtilMethods.setToastMessage(reminder, gameState: getIt<GameState>());
      await open(tester);
      await setMessage(tester, woundText());
      await tester.tap(find.text(woundText()));
      await tester.pump();
      expect(find.text(woundText()), findsNothing);
      expect(find.text(reminder), findsOneWidget);
      expect(getIt<GameState>().toastMessage.value, reminder);
    });

    testWidgets('tapping the reminder while a wound holds the game message '
        'touches nothing', (tester) async {
      GameUtilMethods.setToastMessage(reminder, gameState: getIt<GameState>());
      await open(tester);
      await setMessage(tester, woundText());
      await tester.tap(find.text(reminder));
      await tester.pump();
      expect(find.text(reminder), findsNothing);
      // The wound is what the game holds: not the tapped entry's text, so
      // no write-back — the wound keeps showing and its message stands.
      expect(find.text(woundText()), findsOneWidget);
      expect(getIt<GameState>().toastMessage.value, woundText());
      // Its expiry then writes back as it should: with no reminder left on
      // screen the game message goes empty, ready for the next round.
      await advance(tester, const Duration(seconds: 6, milliseconds: 300));
      expect(find.text(woundText()), findsNothing);
      expect(getIt<GameState>().toastMessage.value, isEmpty);
    });

    testWidgets('a cleared message (next round, new scenario, Undo) takes '
        'both entries off', (tester) async {
      GameUtilMethods.setToastMessage(reminder, gameState: getIt<GameState>());
      await open(tester);
      await setMessage(tester, woundText());
      // What a state load does: the notifier holds the restored value.
      (getIt<GameState>().toastMessage as ValueNotifier<String>).value = '';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(reminder), findsNothing);
      expect(find.text(woundText()), findsNothing);
    });

    testWidgets('the same wound text can show again', (tester) async {
      GameUtilMethods.setToastMessage(woundText(), gameState: getIt<GameState>());
      await open(tester);
      expect(find.text(woundText()), findsOneWidget);
      await advance(tester, const Duration(seconds: 6, milliseconds: 300));
      expect(find.text(woundText()), findsNothing);
      expect(getIt<GameState>().toastMessage.value, isEmpty);
      await setMessage(tester, woundText());
      expect(find.text(woundText()), findsOneWidget);
      MessagePanel.instance.cancelTimers();
    });

    testWidgets('a message cleared and replaced within one frame does not '
        'leave the old entry behind', (tester) async {
      GameUtilMethods.setToastMessage(reminder, gameState: getIt<GameState>());
      await open(tester);
      expect(find.text(reminder), findsOneWidget);
      // What DrawCommand does with a battle-goal reminder: it clears it and
      // sets the wound in the same frame. A build-triggered sync would only
      // ever see the last value and leave the reminder on screen.
      GameUtilMethods.setToastMessage('', gameState: getIt<GameState>());
      GameUtilMethods.setToastMessage(woundText(), gameState: getIt<GameState>());
      await tester.pump();
      await tester.pump();
      expect(find.text(reminder), findsNothing);
      expect(find.text(woundText()), findsOneWidget);
      MessagePanel.instance.cancelTimers();
    });

    testWidgets('tapping the current reminder does not take a still-shown '
        'wound entry with it', (tester) async {
      // The wound went up first, then the game announced the new reminder;
      // the wound entry is still on screen beside it.
      await open(tester);
      await setMessage(tester, woundText());
      await setMessage(tester, reminder);
      expect(find.text(woundText()), findsOneWidget);
      expect(find.text(reminder), findsOneWidget);
      await tester.tap(find.text(reminder));
      await tester.pump();
      await tester.pump();
      expect(find.text(reminder), findsNothing);
      // The write-back ('' — no reminder is shown anymore) is the panel's
      // own echo: it must not clear the wound entry off the panel.
      expect(find.text(woundText()), findsOneWidget);
      expect(getIt<GameState>().toastMessage.value, isEmpty);
      MessagePanel.instance.cancelTimers();
    });

    testWidgets('a tapped-away reminder does not come back by itself',
        (tester) async {
      GameUtilMethods.setToastMessage(reminder, gameState: getIt<GameState>());
      await open(tester);
      await tester.tap(find.text(reminder));
      await tester.pump();
      expect(find.text(reminder), findsNothing);
      expect(getIt<GameState>().toastMessage.value, isEmpty);
      await advance(tester, const Duration(seconds: 10));
      expect(find.text(reminder), findsNothing);
    });
  });
}
