// ignore_for_file: no-magic-number, avoid-top-level-members-in-tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Resource/commands/command_l10n.dart';
import 'package:frosthaven_assistant/Resource/message_panel.dart';

Future<void> advance(WidgetTester tester, Duration total) async {
  // Pump in small steps: follow-up timers scheduled inside one pump stage
  // only land in the next one.
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

final List<String> removals = [];

void main() {
  setUp(() {
    MessagePanel.reset();
    removals.clear();
  });
  tearDown(() => MessagePanel.reset());

  Future<MessagePanel> open(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    final panel = MessagePanel.instance;
    panel.onRemoved = (entry, timedOut) =>
        removals.add('${entry.text}:${timedOut ? 'timed' : 'tap'}');
    return panel;
  }

  List<String> texts(MessagePanel panel) =>
      panel.entries.map((e) => e.text).toList();

  group('stacking', () {
    testWidgets('new entries stack at the end, oldest first',
        (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.line, 'first'));
      panel.add(const MessageEntry(MessageKind.banner, 'second'));
      expect(texts(panel), ['first', 'second']);
      panel.cancelTimers();
    });

    testWidgets('a reminder and a wound stack', (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.reminder, 'reminder'));
      panel.add(const MessageEntry(MessageKind.wound, 'wounds'));
      expect(texts(panel), ['reminder', 'wounds']);
      panel.cancelTimers();
    });

    testWidgets('at three entries a new message shows and the oldest timed '
        'entry is dropped, with onRemoved', (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.line, 'line'));
      panel.add(const MessageEntry(MessageKind.reminder, 'reminder'));
      panel.add(const MessageEntry(MessageKind.error, 'error'));
      panel.add(const MessageEntry(MessageKind.timed, 'info'));
      expect(texts(panel), ['reminder', 'error', 'info']);
      expect(removals, ['line:tap']);
      panel.cancelTimers();
    });

    testWidgets('a new value of a kind already on screen replaces it '
        'in place, without onRemoved', (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.reminder, 'round 1'));
      panel.add(const MessageEntry(MessageKind.line, 'line'));
      panel.add(const MessageEntry(MessageKind.reminder, 'round 1 + more'));
      expect(texts(panel), ['round 1 + more', 'line']);
      expect(removals, isEmpty);
      panel.cancelTimers();
    });

    testWidgets('a second wound replaces the first, keeping its place',
        (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.wound, 'wound 1'));
      panel.add(const MessageEntry(MessageKind.reminder, 'reminder'));
      panel.add(const MessageEntry(MessageKind.wound, 'wound 2'));
      expect(texts(panel), ['wound 2', 'reminder']);
      expect(removals, isEmpty);
      panel.cancelTimers();
    });

    testWidgets('the panel notifies on add and on drop', (tester) async {
      final panel = await open(tester);
      var builds = 0;
      panel.addListener(() => builds++);
      panel.add(const MessageEntry(MessageKind.line, 'a'));
      expect(builds, 1);
      panel.remove(panel.entries.first);
      expect(builds, 2);
    });
  });

  group('lifetimes', () {
    testWidgets('a heart-attack line leaves after 8 s', (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.line, 'Kling: write it down.'));
      await advance(tester, const Duration(milliseconds: 7900));
      expect(texts(panel), ['Kling: write it down.']);
      await advance(tester, const Duration(milliseconds: 300));
      expect(panel.entries, isEmpty);
      expect(removals, ['Kling: write it down.:timed']);
    });

    testWidgets('a join banner and a plain toast leave after 4 s',
        (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.banner, 'banner'));
      panel.add(const MessageEntry(MessageKind.timed, 'info'));
      await advance(tester, const Duration(seconds: 4, milliseconds: 100));
      expect(panel.entries, isEmpty);
      expect(removals, ['banner:timed', 'info:timed']);
    });

    testWidgets('a wound leaves after 6 s', (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.wound, 'wounds'));
      await advance(tester, const Duration(seconds: 5, milliseconds: 900));
      expect(texts(panel), ['wounds']);
      await advance(tester, const Duration(milliseconds: 300));
      expect(panel.entries, isEmpty);
      expect(removals, ['wounds:timed']);
    });

    testWidgets('a reminder and a network error never leave by themselves',
        (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.reminder, 'reminder'));
      panel.add(MessageEntry(MessageKind.error, 'error', onRetry: () {}));
      await advance(tester, const Duration(seconds: 60));
      expect(texts(panel), ['reminder', 'error']);
      expect(removals, isEmpty);
    });

    testWidgets('a replaced wound restarts the timer', (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.wound, 'wound 1'));
      await advance(tester, const Duration(seconds: 5));
      panel.add(const MessageEntry(MessageKind.wound, 'wound 2'));
      await advance(tester, const Duration(seconds: 4));
      expect(texts(panel), ['wound 2']);
      await advance(tester, const Duration(seconds: 2, milliseconds: 300));
      expect(panel.entries, isEmpty);
      expect(removals, ['wound 2:timed']);
    });

    testWidgets('an entry dropped at the cap cannot expire later',
        (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.timed, 'a'));
      panel.add(const MessageEntry(MessageKind.timed, 'b'));
      panel.add(const MessageEntry(MessageKind.reminder, 'r'));
      panel.add(const MessageEntry(MessageKind.timed, 'c'));
      expect(texts(panel), ['b', 'r', 'c']); // 'a' dropped for the cap
      expect(removals, ['a:tap']);
      removals.clear();
      // 'b' and 'c' expire on their own; the already-dropped 'a' must not
      // report anything again.
      await advance(tester, const Duration(seconds: 6));
      expect(removals, ['b:timed', 'c:timed']);
      expect(texts(panel), ['r']);
    });
  });

  group('removal', () {
    testWidgets('remove takes only that entry, with a tap onRemoved',
        (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.line, 'line'));
      panel.add(const MessageEntry(MessageKind.wound, 'wounds'));
      panel.remove(panel.entries.first);
      expect(texts(panel), ['wounds']);
      expect(removals, ['line:tap']);
      panel.cancelTimers();
    });

    testWidgets('removeSilently drops without onRemoved', (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.reminder, 'reminder'));
      panel.add(const MessageEntry(MessageKind.wound, 'wounds'));
      panel.removeSilently(MessageKind.wound);
      expect(texts(panel), ['reminder']);
      expect(removals, isEmpty);
    });

    testWidgets('clearAll empties the panel silently and stops the timers',
        (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.line, 'line'));
      panel.clearAll();
      expect(panel.entries, isEmpty);
      await advance(tester, const Duration(seconds: 10));
      expect(removals, isEmpty);
    });

    testWidgets('reset starts an empty panel', (tester) async {
      final panel = await open(tester);
      panel.add(const MessageEntry(MessageKind.line, 'line'));
      MessagePanel.reset();
      expect(MessagePanel.instance.entries, isEmpty);
    });
  });

  group('wound text', () {
    test('the wound prefix from the game is recognised', () {
      final prefix = commandL10n.toastWoundDamage('');
      expect(isWoundMessage('${prefix}Kling -1'), isTrue);
    });

    test('anything else is not a wound', () {
      expect(isWoundMessage('Round 1: something to remember'), isFalse);
      expect(isWoundMessage(''), isFalse);
    });
  });
}
