// ignore_for_file: no-magic-number, avoid-top-level-members-in-tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/main_scaffold.dart';
import 'package:frosthaven_assistant/Resource/commands/command_l10n.dart';
import 'package:frosthaven_assistant/Resource/commands/turn_start_wounds.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/Resource/ui_utils.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

/// D1: the heart-attack line and the sticky messages (wounds, reminders)
/// share one slot — the line goes first, the message waits for it.
/// Both notifiers are pumped together, as in MainScaffoldBody.
void main() {
  setUpAll(() async {
    await setUpGame();
  });

  late GameState gs;

  setUp(() {
    gs = getIt<GameState>();
    gs.clearList();
    gs.heartAttackToast.value = '';
    GameUtilMethods.setToastMessage('', gameState: gs);
    // Module-level bar-state, not game state: reset here so a failed test
    // cannot leak the bar into the next one.
    heartAttackLineShown.value = null;
    heartAttackLineCount = 0;
    getIt<Settings>().gameStyleMessages.value = true;
  });

  Future<void> pumpToasts(WidgetTester tester,
      {void Function(BuildContext context)? capture}) async {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = ignoreOverflowErrors;
    await tester.pumpWidget(testApp(
      Scaffold(
        body: Stack(children: [
          const ToastNotifier(),
          const HeartAttackToastNotifier(),
          if (capture != null)
            Builder(
              builder: (context) {
                capture(context);
                return const SizedBox(width: 0, height: 0);
              },
            ),
        ]),
      ),
    ));
    await tester.pump();
    FlutterError.onError = originalOnError;
  }

  const line = 'Kling: write it down.';

  void setLine([String text = line]) => gs.heartAttackToast.value = text;

  void setMessage(String text) =>
      GameUtilMethods.setToastMessage(text, gameState: gs);

  String woundText([String who = 'Kling -1']) =>
      commandL10n.toastWoundDamage(who);

  /// Past the message bar's 200 ms show delay and the snackbar animations.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 300));

  /// A slot hand-off between the line and a message (or a clear): one
  /// snackbar closes, the 200 ms wait passes, the next entry is built. That
  /// chain crosses frames, so pump it in small steps, not one long pump.
  Future<void> handoff(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Time passing while the line is on the bar, stepped so the chains it
  /// fires (close, the 200 ms wait, the next show) run as they do on a
  /// real frame clock instead of piling onto one frame.
  Future<void> waiting(WidgetTester tester, {required int seconds}) async {
    for (int i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Run out every pending toast timer so the test ends clean. A snackbar
  /// close resolves at the end of a pump stage, so its follow-up timer lands
  /// in the next one — hence the trailing short pumps.
  Future<void> flush(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 60));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  group('heart-attack line and sticky messages', () {
    testWidgets('a wound on screen gives the bar to a line, then returns',
        (WidgetTester tester) async {
      await pumpToasts(tester);
      final wound = woundText();
      setMessage(wound);
      await settle(tester); // 200 ms delay: the wound shows
      expect(find.text(wound), findsOneWidget);

      setLine();
      await handoff(tester);
      expect(find.text(line), findsOneWidget);
      expect(find.text(wound), findsNothing);
      expect(gs.toastMessage.value, equals(wound)); // waits, not cleared

      await waiting(tester, seconds: 4); // line times out
      await handoff(tester); // its slot is handed to the waiting wound
      expect(find.text(wound), findsOneWidget);
      expect(gs.toastMessage.value, equals(wound));
      await flush(tester);
    });

    testWidgets('a line arriving before the wound message keeps the bar',
        (WidgetTester tester) async {
      await pumpToasts(tester);
      setLine();
      await settle(tester);

      setMessage(woundText());
      await settle(tester); // the 200 ms show delay passes behind the line
      expect(find.text(line), findsOneWidget);
      expect(find.text(woundText()), findsNothing);

      await waiting(tester, seconds: 4);
      await handoff(tester);
      expect(find.text(woundText()), findsOneWidget);
      await flush(tester);
    });

    testWidgets('a reminder comes back after the line, message intact',
        (WidgetTester tester) async {
      await pumpToasts(tester);
      const reminder = 'Remember the ritual at the start of each round';
      setMessage(reminder);
      await settle(tester);
      expect(find.text(reminder), findsOneWidget);

      setLine();
      await handoff(tester);
      expect(find.text(reminder), findsNothing);

      await waiting(tester, seconds: 4);
      await handoff(tester);
      expect(find.text(reminder), findsOneWidget);
      expect(gs.toastMessage.value, equals(reminder));
      await flush(tester);
    });

    testWidgets('tapping the line away brings the waiting message at once',
        (WidgetTester tester) async {
      await pumpToasts(tester);
      setLine();
      await handoff(tester); // fully in, or the tap misses the fade-in
      setMessage(woundText());
      await settle(tester);
      expect(find.text(woundText()), findsNothing);

      await tester.tap(find.text(line));
      await tester.pump(); // the line starts to slide away
      await handoff(tester);
      await handoff(tester);
      expect(find.text(woundText()), findsOneWidget);
      await flush(tester);
    });

    testWidgets('a message cleared while the line is up never shows later',
        (WidgetTester tester) async {
      await pumpToasts(tester);
      setLine();
      await settle(tester);
      setMessage(woundText());
      await settle(tester);
      setMessage(''); // an Undo clears it while the line holds the bar
      await handoff(tester);
      expect(find.text(line), findsOneWidget); // the clear must not touch it

      await waiting(tester, seconds: 4);
      await handoff(tester);
      expect(find.text(woundText()), findsNothing);
      await flush(tester);
    });

    testWidgets('a message replaced while waiting shows only the new one',
        (WidgetTester tester) async {
      await pumpToasts(tester);
      setLine();
      await settle(tester);
      setMessage(woundText());
      await settle(tester);
      setMessage('The relic is safe');
      await settle(tester);
      expect(find.text('The relic is safe'), findsNothing); // waits too

      await waiting(tester, seconds: 4);
      await handoff(tester);
      expect(find.text('The relic is safe'), findsOneWidget);
      expect(find.text(woundText()), findsNothing);
      await flush(tester);
    });

    testWidgets('without a line a message shows and stays until cleared',
        (WidgetTester tester) async {
      await pumpToasts(tester);
      setMessage('Scenario notes: watch for the timer');
      await settle(tester);
      expect(find.text('Scenario notes: watch for the timer'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Scenario notes: watch for the timer'), findsOneWidget);

      setMessage('');
      await handoff(tester);
      expect(find.text('Scenario notes: watch for the timer'), findsNothing);
      await flush(tester);
    });

    testWidgets('a wound message clears itself after about 6 seconds',
        (WidgetTester tester) async {
      await pumpToasts(tester);
      setMessage(woundText());
      await settle(tester);
      expect(find.text(woundText()), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text(woundText()), findsOneWidget);
      expect(gs.toastMessage.value, equals(woundText()));

      await tester.pump(const Duration(seconds: 2));
      await handoff(tester);
      expect(find.text(woundText()), findsNothing);
      expect(gs.toastMessage.value, isEmpty);
      await flush(tester);
    });

    testWidgets('a wound restores the old message after five seconds',
        (WidgetTester tester) async {
      // showWoundMessage on its own: no widgets on screen, no line.
      const reminder = 'Remember the ritual at the start of each round';
      setMessage(reminder);
      TurnStartWounds.showWoundMessage(gs, woundText());
      expect(gs.toastMessage.value, equals(woundText()));

      await waiting(tester, seconds: 4);
      expect(gs.toastMessage.value, equals(woundText()));

      await waiting(tester, seconds: 2);
      expect(gs.toastMessage.value, equals(reminder));
    });

    testWidgets('a wound behind a line gets its five seconds after the line',
        (WidgetTester tester) async {
      // No widgets: the line is simulated the way the notifier leaves the
      // bar state — shown, counted, then let go.
      const reminder = 'Remember the ritual at the start of each round';
      setMessage(reminder);
      TurnStartWounds.showWoundMessage(gs, woundText());

      heartAttackLineShown.value = line;
      heartAttackLineCount++;
      await waiting(tester, seconds: 8); // past the original five
      expect(gs.toastMessage.value, equals(woundText())); // still waiting

      heartAttackLineShown.value = null; // the line lets go of the bar
      await waiting(tester, seconds: 6);
      expect(gs.toastMessage.value, equals(reminder));
    });

    testWidgets('a line takes the bar from the network error toast',
        (WidgetTester tester) async {
      // The error toast stays for a day: the line must not queue behind it.
      BuildContext? barContext;
      await pumpToasts(tester, capture: (context) => barContext = context);
      await settle(tester); // the startup empty-message clear passes first
      showErrorToastStickyWithRetry(barContext!, 'Server error', () {});
      await settle(tester);
      expect(find.text('Server error'), findsOneWidget);

      setLine();
      await handoff(tester);
      expect(find.text(line), findsOneWidget);
      await flush(tester);
    });
  });
}
