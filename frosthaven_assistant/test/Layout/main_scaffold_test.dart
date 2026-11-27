import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/MainList/main_list.dart';
import 'package:frosthaven_assistant/Layout/bottom_bar.dart';
import 'package:frosthaven_assistant/Layout/main_scaffold.dart';
import 'package:frosthaven_assistant/Layout/menus/main_menu.dart';
import 'package:frosthaven_assistant/Layout/section_button.dart';
import 'package:frosthaven_assistant/Resource/commands/set_scenario_command.dart';
import 'package:frosthaven_assistant/Resource/message_panel.dart';
import 'package:frosthaven_assistant/Layout/top_bar.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
    // Ensure loading is finished so MainScaffoldBody shows MainList
    loading.value = false;
  });

  setUp(() {
    MessagePanel.reset();
    getIt<GameState>().clearList();
    loading.value = false;
  });
  tearDown(() => MessagePanel.reset());

  Future<void> pumpScaffold(WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = ignoreOverflowErrors;
    await tester.pumpWidget(
      const MaterialApp(
        home: MainScaffold(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    FlutterError.onError = originalOnError;
  }

  // With localization (the plain pump below has none, which makes the Draw
  // button an error box that fills the whole bar).
  Future<void> pumpLocalized(WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = ignoreOverflowErrors;
    await tester.pumpWidget(testApp(const MainScaffold()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    FlutterError.onError = originalOnError;
  }

  group('MainScaffold', () {
    testWidgets('renders SafeArea and Scaffold', (WidgetTester tester) async {
      await pumpScaffold(tester);
      expect(find.byType(Scaffold), findsAtLeast(1));
      expect(find.byType(SafeArea), findsAtLeast(1));
    });

    testWidgets('the section buttons are in the bottom bar only',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() => sectionsDontFitInBar.value = false);
      final gs = getIt<GameState>();
      final campaign = gs.currentCampaign as ValueNotifier<String>;
      final before = campaign.value;
      campaign.value = 'Frosthaven'; // the scenario's campaign
      addTearDown(() => campaign.value = before);
      gs.action(SetScenarioCommand('#0 Howling in the Snow', false,
          gameState: gs));
      addTearDown(() => gs.undo());
      await pumpLocalized(tester);
      await tester.pump();
      expect(sectionsDontFitInBar.value, isFalse);
      expect(find.byType(SectionButton), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(BottomBar), matching: find.byType(SectionButton)),
          findsOneWidget);
    });

    testWidgets('on a narrow screen the bar has no room, so they sit above it',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() => sectionsDontFitInBar.value = false);
      final gs = getIt<GameState>();
      final campaign = gs.currentCampaign as ValueNotifier<String>;
      final before = campaign.value;
      campaign.value = 'Frosthaven';
      addTearDown(() => campaign.value = before);
      gs.action(SetScenarioCommand('#0 Howling in the Snow', false,
          gameState: gs));
      addTearDown(() => gs.undo());
      await pumpLocalized(tester);
      await tester.pump(); // the bar reports it has no room
      await tester.pump(const Duration(milliseconds: 300));

      expect(sectionsDontFitInBar.value, isTrue);
      expect(find.byType(SectionButton), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(BottomBar), matching: find.byType(SectionButton)),
          findsNothing);
    });

    testWidgets('renders TopBar in appBar', (WidgetTester tester) async {
      await pumpScaffold(tester);
      expect(find.byType(TopBar), findsOneWidget);
    });

    testWidgets('renders BottomBar', (WidgetTester tester) async {
      await pumpScaffold(tester);
      expect(find.byType(BottomBar), findsOneWidget);
    });

    testWidgets('has MainMenu as the scaffold drawer widget',
        (WidgetTester tester) async {
      await pumpScaffold(tester);
      // Drawer is lazy — not rendered until opened. Check scaffold property instead.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.drawer, isA<MainMenu>());
    });

    testWidgets('renders MainScaffoldBody in body',
        (WidgetTester tester) async {
      await pumpScaffold(tester);
      expect(find.byType(MainScaffoldBody), findsOneWidget);
    });
  });

  group('MainScaffoldBody', () {
    testWidgets('renders MainList when not loading',
        (WidgetTester tester) async {
      loading.value = false;
      await pumpScaffold(tester);
      expect(find.byType(MainList), findsOneWidget);
    });

    testWidgets('renders CircularProgressIndicator when loading',
        (WidgetTester tester) async {
      loading.value = true;
      final originalOnError = FlutterError.onError;
      addTearDown(() => FlutterError.onError = originalOnError);
      FlutterError.onError = ignoreOverflowErrors;
      await tester.pumpWidget(
        const MaterialApp(
          home: MainScaffold(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      FlutterError.onError = originalOnError;

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      loading.value = false;
    });

    testWidgets('renders ToastNotifier', (WidgetTester tester) async {
      await pumpScaffold(tester);
      expect(find.byType(ToastNotifier), findsOneWidget);
    });
  });

  group('ToastNotifier', () {
    testWidgets('renders SizedBox(0, 0)', (WidgetTester tester) async {
      final originalOnError = FlutterError.onError;
      addTearDown(() => FlutterError.onError = originalOnError);
      FlutterError.onError = ignoreOverflowErrors;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ToastNotifier()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      FlutterError.onError = originalOnError;

      final sizedBox = tester.widget<SizedBox>(
        find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 0 && w.height == 0),
      );
      expect(sizedBox, isNotNull);
    });

    testWidgets('does not crash when toastMessage is empty',
        (WidgetTester tester) async {
      (getIt<GameState>().toastMessage as ValueNotifier<String>).value = '';
      final originalOnError = FlutterError.onError;
      addTearDown(() => FlutterError.onError = originalOnError);
      FlutterError.onError = ignoreOverflowErrors;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ToastNotifier())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      FlutterError.onError = originalOnError;
      expect(find.byType(ToastNotifier), findsOneWidget);
    });
  });
}
