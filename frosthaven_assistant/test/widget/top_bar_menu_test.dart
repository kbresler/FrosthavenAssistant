// ignore_for_file: no-magic-number

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/attack_mode/attack_mode_controller.dart';
import 'package:frosthaven_assistant/Layout/element_button.dart';
import 'package:frosthaven_assistant/Layout/top_bar.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  setUp(() {
    getIt<GameState>().clearList();
  });

  Future<GlobalKey<ScaffoldState>> pump(WidgetTester tester) async {
    final key = GlobalKey<ScaffoldState>();
    final originalOnError = FlutterError.onError;
    FlutterError.onError = ignoreOverflowErrors;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        key: key,
        appBar: const PreferredSize(
            preferredSize: Size.fromHeight(64), child: TopBar()),
        drawer: const Drawer(child: Text('the main menu')),
        body: const SizedBox(),
      ),
    ));
    await tester.pump();
    FlutterError.onError = originalOnError;
    return key;
  }

  bool drawerOpen(GlobalKey<ScaffoldState> key) =>
      key.currentState!.isDrawerOpen;

  group('Swerski: only the hamburger opens the main menu', () {
    testWidgets('tapping the hamburger opens it', (tester) async {
      final key = await pump(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(drawerOpen(key), isTrue);
    });

    testWidgets('a finger a little off the icon still opens it',
        (tester) async {
      final key = await pump(tester);
      final icon = tester.getRect(find.byIcon(Icons.menu));
      await tester.tapAt(Offset(icon.left + 1, icon.center.dy));
      await tester.pumpAndSettle();
      expect(drawerOpen(key), isTrue);
    });

    testWidgets('the gap between the hamburger and the sword does not',
        (tester) async {
      final key = await pump(tester);
      // The bar's left slot is 56 wide; its last few pixels are dead space.
      await tester.tapAt(const Offset(54, 32));
      await tester.pumpAndSettle();
      expect(drawerOpen(key), isFalse);
    });

    testWidgets('pressing the sword does not', (tester) async {
      final key = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('attack-sword')));
      await tester.pumpAndSettle();
      expect(drawerOpen(key), isFalse);
      attackModeController().end();
    });

    testWidgets('swiping in from the screen edge still opens it',
        (tester) async {
      final key = await pump(tester);
      await tester.dragFrom(const Offset(2, 300), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(drawerOpen(key), isTrue);
    });

    testWidgets('a tap on the hamburger\'s left edge (the swipe zone) opens it',
        (tester) async {
      final key = await pump(tester);
      await tester.tapAt(const Offset(10, 32));
      await tester.pumpAndSettle();
      expect(drawerOpen(key), isTrue);
    });

    testWidgets('and so does the strip above and below it', (tester) async {
      final key = await pump(tester);
      final icon = tester.getRect(find.byIcon(Icons.menu));
      await tester.tapAt(Offset(icon.center.dx, 3));
      await tester.pumpAndSettle();
      expect(drawerOpen(key), isTrue);
    });

    testWidgets('tapping an element does not', (tester) async {
      final key = await pump(tester);
      await tester.tap(find.byWidgetPredicate(
          (w) => w is ElementButton && w.element == Elements.fire));
      await tester.pumpAndSettle();
      expect(drawerOpen(key), isFalse);
      getIt<GameState>().undo();
    });

    testWidgets('tapping the title area does not', (tester) async {
      final key = await pump(tester);
      await tester.tap(find.textContaining('X-haven'));
      await tester.pumpAndSettle();
      expect(drawerOpen(key), isFalse);
    });

    testWidgets('tapping just outside the icon, in the bar, does not',
        (tester) async {
      final key = await pump(tester);
      final icon = tester.getRect(find.byIcon(Icons.menu));
      // Well to the right of the icon, still on the top bar.
      await tester.tapAt(Offset(icon.right + 60, icon.center.dy));
      await tester.pumpAndSettle();
      expect(drawerOpen(key), isFalse);
    });

    testWidgets('pressing elsewhere and releasing on the hamburger does not',
        (tester) async {
      final key = await pump(tester);
      final fire = find.byWidgetPredicate(
          (w) => w is ElementButton && w.element == Elements.fire);
      final gesture = await tester.startGesture(tester.getCenter(fire));
      await gesture.moveTo(tester.getCenter(find.byIcon(Icons.menu)));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(drawerOpen(key), isFalse);
      getIt<GameState>().undo();
    });

    testWidgets('pressing the hamburger and dragging away does not',
        (tester) async {
      final key = await pump(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byIcon(Icons.menu)));
      await gesture.moveBy(const Offset(120, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(drawerOpen(key), isFalse);
    });
  });
}
