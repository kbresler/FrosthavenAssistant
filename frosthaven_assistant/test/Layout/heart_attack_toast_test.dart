// ignore_for_file: no-magic-number, avoid-top-level-members-in-tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/main_scaffold.dart';
import 'package:frosthaven_assistant/Layout/message_panel.dart';
import 'package:frosthaven_assistant/Resource/message_panel.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/network/network.dart';
import 'package:frosthaven_assistant/services/network/superfan/fans.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

const line = 'Kling: write it down.';
const reminder = 'Round 1: spawn adds at the marked spaces.';
const tableBanner = 'Da Bears! The table is on the SuperNetwork';

void main() {
  setUpAll(() async {
    await setUpGame();
    loading.value = false;
  });

  setUp(() {
    MessagePanel.reset();
    final gs = getIt<GameState>();
    gs.clearList();
    gs.heartAttackToast.value = '';
    GameUtilMethods.setToastMessage('', gameState: getIt<GameState>());
    getIt<Network>().superFanJoined.value = null;
  });
  tearDown(() => MessagePanel.reset());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(testApp(Scaffold(
        body: Stack(children: const [
      SizedBox.expand(),
      ToastNotifier(),
      HeartAttackToastNotifier(),
      SuperFanJoinBannerNotifier(),
      MessagePanelNotifier(),
    ]))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> showLine() async {
    getIt<GameState>().heartAttackToast.value = line;
  }

  Future<void> advance(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 100);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  group('heart-attack lines on the message panel', () {
    testWidgets('a line shows on the panel and the notifier clears',
        (tester) async {
      await open(tester);
      await showLine();
      await tester.pump();
      await tester.pump();
      expect(find.text(line), findsOneWidget);
      expect(getIt<GameState>().heartAttackToast.value, isEmpty);
      MessagePanel.instance.cancelTimers();
    });

    testWidgets('a line leaves on its own after 8 s', (tester) async {
      await open(tester);
      await showLine();
      await tester.pump();
      await tester.pump();
      await advance(tester, const Duration(milliseconds: 7900));
      expect(find.text(line), findsOneWidget);
      await advance(tester, const Duration(milliseconds: 300));
      expect(find.text(line), findsNothing);
    });

    testWidgets('the same line can fire again after it is gone',
        (tester) async {
      await open(tester);
      await showLine();
      await tester.pump();
      await tester.pump();
      await advance(tester, const Duration(seconds: 8, milliseconds: 300));
      expect(find.text(line), findsNothing);
      await showLine();
      await tester.pump();
      await tester.pump();
      expect(find.text(line), findsOneWidget);
      MessagePanel.instance.cancelTimers();
    });

    testWidgets('tapping a line removes only it', (tester) async {
      GameUtilMethods.setToastMessage(reminder, gameState: getIt<GameState>());
      await open(tester);
      await showLine();
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text(line));
      await tester.pump();
      expect(find.text(line), findsNothing);
      expect(find.text(reminder), findsOneWidget);
    });

    testWidgets('line, join banner and reminder are visible together',
        (tester) async {
      GameUtilMethods.setToastMessage(reminder, gameState: getIt<GameState>());
      await open(tester);
      await showLine();
      getIt<Network>().superFanJoined.value =
          const SwerskiFan(id: 'p1', name: 'Hatchet');
      await tester.pump();
      await tester.pump();
      expect(find.text(reminder), findsOneWidget);
      expect(find.text(line), findsOneWidget);
      expect(find.text(tableBanner), findsOneWidget);
      // The join notifier consumed its announcement too.
      expect(getIt<Network>().superFanJoined.value, isNull);
      MessagePanel.instance.cancelTimers();
    });

    testWidgets('a line shares the panel with the network error',
        (tester) async {
      await open(tester);
      MessagePanel.instance.add(MessageEntry(MessageKind.error,
          'could not reach the other device',
          onRetry: () {}));
      await showLine();
      await tester.pump();
      await tester.pump();
      expect(find.text('could not reach the other device'), findsOneWidget);
      expect(find.text(line), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);
      MessagePanel.instance.cancelTimers();
    });
  });
}
