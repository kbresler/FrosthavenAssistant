import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';

import '../Resource/state/game_state.dart';
import '../Resource/ui_utils.dart';
import '../l10n/app_localizations.dart';
import '../services/service_locator.dart';
import 'menus/SelectScenarioMenu/select_scenario_menu.dart';
import 'menus/add_character_menu.dart';

/// Swerski: on an empty board, show what to do first instead of a blank
/// ice background. Disappears as soon as anything is on the board.
class EmptyBoardPrompt extends StatelessWidget {
  static const Color _kParchment = Color(0xFFF2E6C9);
  static const Color _kBorder = Color(0xFF7A5A2E);
  static const Color _kText = Color(0xFF3B2A14);
  static const double _kMaxWidth = 420.0;
  static const double _kRadius = 8.0;
  static const double _kBorderWidth = 2.0;
  static const double _kHintSize = 22.0;
  static const double _kButtonTextSize = 20.0;
  static const double _kGap = 12.0;

  const EmptyBoardPrompt({super.key, this.gameState});

  // injected for testing
  final GameState? gameState;

  @override
  Widget build(BuildContext context) {
    final gameState = this.gameState ?? getIt<GameState>();
    return ValueListenableBuilder<BuiltList<ListItemData>>(
        valueListenable: gameState.currentListNotifier,
        builder: (context, list, child) {
          if (list.isNotEmpty) return const SizedBox.shrink();
          final l10n = AppLocalizations.of(context)!;
          final buttonStyle = FilledButton.styleFrom(
            backgroundColor: _kBorder,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
                fontFamily: "Markazi", fontSize: _kButtonTextSize),
          );
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: _kMaxWidth),
              margin: const EdgeInsets.all(_kGap),
              padding: const EdgeInsets.all(_kGap * 1.5),
              decoration: BoxDecoration(
                color: _kParchment,
                borderRadius: BorderRadius.circular(_kRadius),
                border: Border.all(color: _kBorder, width: _kBorderWidth),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l10n.emptyBoardHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: "Markazi",
                        fontSize: _kHintSize,
                        height: 1.1,
                        color: _kText)),
                const SizedBox(height: _kGap),
                Wrap(
                    alignment: WrapAlignment.center,
                    spacing: _kGap,
                    runSpacing: _kGap,
                    children: [
                      FilledButton(
                        style: buttonStyle,
                        onPressed: () =>
                            openDialog(context, const SelectScenarioMenu()),
                        child: Text(l10n.menuSetScenario),
                      ),
                      FilledButton(
                        style: buttonStyle,
                        onPressed: () =>
                            openDialog(context, const AddCharacterMenu()),
                        child: Text(l10n.menuAddCharacter),
                      ),
                    ]),
              ]),
            ),
          );
        });
  }
}
