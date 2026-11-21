import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/MainList/main_list.dart';
import 'package:frosthaven_assistant/Layout/bottom_overlay.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';
import 'package:reorderables/reorderables.dart';

import '../command/test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  setUp(() {
    getIt<GameState>().clearList();
    bottomOverlayHeight.value = 0;
  });

  group('Swerski: board scrolls clear of the deck area', () {
    testWidgets('the deck area reports its height', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: ReportBottomOverlayHeight(
                child: SizedBox(width: 100, height: 260)),
          ),
        ),
      ));
      await tester.pump();
      expect(bottomOverlayHeight.value, 260);
    });

    Future<double> boardEndPadding(WidgetTester tester) async {
      final originalOnError = FlutterError.onError;
      addTearDown(() => FlutterError.onError = originalOnError);
      FlutterError.onError = ignoreOverflowErrors;
      AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: MainList())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      FlutterError.onError = originalOnError;
      final wrap = tester.widget<ReorderableWrap>(find.byType(ReorderableWrap));
      return (wrap.padding as EdgeInsets).bottom;
    }

    testWidgets('a short deck area keeps the usual half-screen end space',
        (tester) async {
      bottomOverlayHeight.value = 100;
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(await boardEndPadding(tester), closeTo(screenHeight / 2, 1));
    });

    testWidgets('a tall deck area gets at least its own height plus room',
        (tester) async {
      tester.view.physicalSize = const Size(400, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      bottomOverlayHeight.value = 400; // taller than half of 500
      expect(await boardEndPadding(tester), greaterThan(400));
    });
  });
}
