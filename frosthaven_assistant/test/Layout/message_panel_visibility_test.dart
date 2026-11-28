// ignore_for_file: no-magic-number, avoid-top-level-members-in-tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/main_scaffold.dart';
import 'package:frosthaven_assistant/Resource/message_panel.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

// The short timed entry lives 4 s (MessagePanel._kShort); every wait here
// crosses that border on purpose. The panel only becomes visible again when
// a close animation ends, so the waits leave room for that animation on
// top of the restarted 4 s.
BuildContext? _ctx;

ScaffoldState mainScaffold(WidgetTester tester) => tester
    .stateList<ScaffoldState>(find.descendant(
        of: find.byType(MainScaffold), matching: find.byType(Scaffold)))
    .first;

void main() {
  setUpAll(() async {
    await setUpGame();
    loading.value = false;
  });

  setUp(() {
    MessagePanel.reset();
    getIt<GameState>().clearList();
    _ctx = null;
  });

  tearDown(() => MessagePanel.reset());

  Future<void> pumpScaffold(WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = ignoreOverflowErrors;
    await tester.pumpWidget(testApp(Builder(builder: (context) {
      _ctx = context;
      return MainScaffold(panel: MessagePanel.instance);
    })));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    FlutterError.onError = originalOnError;
  }

  void addTimed() => MessagePanel.instance.add(
      const MessageEntry(MessageKind.timed, 'a timed line'));

  group('panel visibility', () {
    testWidgets('visible: a timed entry still leaves on its own',
        (tester) async {
      await pumpScaffold(tester);
      addTimed();
      expect(MessagePanel.instance.entries.length, equals(1));
      await tester.pump(const Duration(seconds: 4, milliseconds: 100));
      expect(MessagePanel.instance.entries, isEmpty);
    });

    testWidgets('a covering route holds the timer, then restarts it',
        (tester) async {
      await pumpScaffold(tester);
      addTimed();
      await tester.pump(const Duration(seconds: 2));
      expect(MessagePanel.instance.entries.length, equals(1));

      showDialog(context: _ctx!, builder: (_) => const Text('a dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Well past the 4 s, but the dialog held them.
      await tester.pump(const Duration(seconds: 4, milliseconds: 100));
      expect(MessagePanel.instance.entries.length, equals(1));

      Navigator.of(_ctx!).pop();
      await tester.pump();
      // The timer restarts only when the close animation ends.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 3500));
      expect(MessagePanel.instance.entries.length, equals(1));
      await tester.pump(const Duration(milliseconds: 600));
      expect(MessagePanel.instance.entries, isEmpty);
    });

    testWidgets('an open drawer holds the timer, closing restarts it',
        (tester) async {
      await pumpScaffold(tester);
      mainScaffold(tester).openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      addTimed();
      await tester.pump(const Duration(seconds: 4, milliseconds: 100));
      expect(MessagePanel.instance.entries.length, equals(1));

      mainScaffold(tester).closeDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 3500));
      expect(MessagePanel.instance.entries.length, equals(1));
      await tester.pump(const Duration(milliseconds: 600));
      expect(MessagePanel.instance.entries, isEmpty);
    });

    testWidgets('a hidden app holds the timer, resuming restarts it',
        (tester) async {
      await pumpScaffold(tester);
      addTimed();
      await tester.pump(const Duration(seconds: 2));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 4, milliseconds: 100));
      expect(MessagePanel.instance.entries.length, equals(1));

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.pump(const Duration(seconds: 3, milliseconds: 900));
      expect(MessagePanel.instance.entries.length, equals(1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(MessagePanel.instance.entries, isEmpty);
    });

    testWidgets('inactive is still visible: focus loss does not hold',
        (tester) async {
      await pumpScaffold(tester);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      addTimed();
      await tester.pump(const Duration(seconds: 4, milliseconds: 100));
      expect(MessagePanel.instance.entries, isEmpty);
    });
  });
}
