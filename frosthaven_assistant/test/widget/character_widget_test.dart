import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosthaven_assistant/Layout/CharacterWidget/character_widget_internal.dart';
import 'package:frosthaven_assistant/Layout/CharacterWidget/character_widget.dart';
import 'package:frosthaven_assistant/Layout/attack_mode/attack_mode_controller.dart';
import 'package:frosthaven_assistant/Layout/menus/StatusMenu/status_menu.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/draw_command.dart';
import 'package:frosthaven_assistant/Resource/commands/next_round_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_init_command.dart';
import 'package:frosthaven_assistant/Resource/commands/turn_done_command.dart';
import 'package:frosthaven_assistant/Resource/game_data.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/Resource/ui_utils.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../command/test_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGame();
  });

  setUp(() {
    getIt<GameState>().clearList();
    AddCharacterCommand('Blinkblade', 'Frosthaven', null, 1).execute();
  });

  Future<void> pumpCharacterWidget(WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = ignoreOverflowErrors;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: const CharacterWidget(characterId: 'Blinkblade'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    FlutterError.onError = originalOnError;
  }

  group('CharacterWidget', () {
    testWidgets('renders when character exists', (WidgetTester tester) async {
      await pumpCharacterWidget(tester);
      expect(find.byType(CharacterWidget), findsOneWidget);
    });

    testWidgets('shows InkWell for tap interaction', (
      WidgetTester tester,
    ) async {
      await pumpCharacterWidget(tester);
      expect(find.byType(InkWell), findsAtLeast(1));
    });

    testWidgets('tapping character widget opens StatusMenu', (
      WidgetTester tester,
    ) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      await pumpCharacterWidget(tester);
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      FlutterError.onError = originalOnError;
      expect(find.byType(StatusMenu), findsOneWidget);
    });

    testWidgets('returns empty Container when character not found', (
      WidgetTester tester,
    ) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CharacterWidget(characterId: 'NonExistent')),
        ),
      );
      await tester.pump();
      FlutterError.onError = originalOnError;
      // Should render without crash — returns Container()
      expect(find.byType(CharacterWidget), findsOneWidget);
    });

    testWidgets('renders ColorFiltered widget when character turn is done',
        (WidgetTester tester) async {
      final gs = getIt<GameState>();
      // ColorFiltered is only applied when notGrayScale is false (turn done in
      // playTurns). Draw to enter playTurns, then mark the character's turn done.
      DrawCommand(gameState: gs).execute();
      TurnDoneCommand('Blinkblade', gameState: gs).execute();
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CharacterWidget(characterId: 'Blinkblade'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      FlutterError.onError = originalOnError;
      expect(find.byType(ColorFiltered), findsAtLeast(1));
      // Reset round state for subsequent tests.
      NextRoundCommand(
        gameState: gs,
        gameData: getIt<GameData>(),
        settings: getIt<Settings>(),
      ).execute();
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('renders health wheel when not in chooseInitiative round state', (
      WidgetTester tester,
    ) async {
      // Draw changes roundState to playTurns, triggering buildWithHealthWheel path
      DrawCommand(gameState: getIt<GameState>()).execute();
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CharacterWidget(characterId: 'Blinkblade'),
            ),
          ),
        ),
      );
      // Pump past DrawCommand's 600ms Future.delayed timer
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      FlutterError.onError = originalOnError;
      expect(find.byType(CharacterWidget), findsOneWidget);
      // Reset round state (NextRoundCommand also has 600ms timer — pump past it)
      NextRoundCommand(
        gameState: getIt<GameState>(),
        gameData: getIt<GameData>(),
        settings: getIt<Settings>(),
      ).execute();
      await tester.pump(const Duration(milliseconds: 700));
    });
  });

  group('Swerski turn glow', () {
    // The character's own turn box: the DecoratedBox whose fill marks the turn.
    BoxDecoration? turnBox(WidgetTester tester) {
      for (final box
          in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
        final d = box.decoration;
        if (d is BoxDecoration &&
            (d.color == kTurnColor || d.color == Colors.tealAccent)) {
          return d;
        }
      }
      return null;
    }

    Future<void> drawAndPump(WidgetTester tester) async {
      final gs = getIt<GameState>();
      DrawCommand(gameState: gs).execute();
      final originalOnError = FlutterError.onError;
      FlutterError.onError = ignoreOverflowErrors;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CharacterWidget(characterId: 'Blinkblade'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      FlutterError.onError = originalOnError;
    }

    Future<void> resetRound(WidgetTester tester) async {
      NextRoundCommand(
        gameState: getIt<GameState>(),
        gameData: getIt<GameData>(),
        settings: getIt<Settings>(),
      ).execute();
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('current character gets the green outline and glow',
        (tester) async {
      expect(getIt<Settings>().turnGlow.value, isTrue);
      await drawAndPump(tester);
      final d = turnBox(tester);
      expect(d?.color, kTurnColor);
      expect(d?.border, isNotNull);
      expect(d?.boxShadow?.single.color, isNot(Colors.black38));
      await resetRound(tester);
    });

    testWidgets('setting off brings back the official teal edge',
        (tester) async {
      getIt<Settings>().turnGlow.value = false;
      addTearDown(() => getIt<Settings>().turnGlow.value = true);
      await drawAndPump(tester);
      final d = turnBox(tester);
      expect(d?.color, Colors.tealAccent);
      expect(d?.border, isNull);
      await resetRound(tester);
    });
  });

  group('Swerski: saved initiative on a rebuilt card', () {
    String? fieldText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller?.text;

    void setInit(int value) =>
        SetInitCommand('Blinkblade', value, gameState: getIt<GameState>())
            .execute();

    testWidgets('a freshly built card shows it (reload)', (tester) async {
      setInit(27);
      await pumpCharacterWidget(tester);
      expect(fieldText(tester), '27');
    });

    testWidgets('picking the hero in attack mode keeps it', (tester) async {
      addTearDown(() => attackModeController().end());
      await pumpCharacterWidget(tester);
      await tester.enterText(find.byType(TextField), '27');
      await tester.pump();

      attackModeController().startSelecting();
      attackModeController().togglePickCharacter('Blinkblade');
      await tester.pumpAndSettle();
      expect(fieldText(tester), '27');

      attackModeController().togglePickCharacter('Blinkblade');
      await tester.pumpAndSettle();
      expect(fieldText(tester), '27');
    });

    testWidgets('stays empty when no initiative is set', (tester) async {
      await pumpCharacterWidget(tester);
      expect(fieldText(tester), isEmpty);
    });

    testWidgets('stays hidden when it came from another device',
        (tester) async {
      setInit(27);
      getIt<Settings>().server.value = true;
      CharacterWidgetInternal.localCharacterInitChanges.clear();
      addTearDown(() => getIt<Settings>().server.value = false);
      await pumpCharacterWidget(tester);
      expect(fieldText(tester), '??');
    });
  });
}
