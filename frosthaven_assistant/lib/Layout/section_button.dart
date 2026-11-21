import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/Resource/ui_utils.dart';

import '../Resource/commands/set_scenario_command.dart';
import 'attack_mode/attack_mode_controller.dart';
import '../Resource/settings.dart';
import '../services/service_locator.dart';
import 'theme.dart';

class SectionButton extends StatelessWidget {
  static const double _kButtonWidth = 55.0;
  static const double _kButtonHeight = 25.0;
  static const double _kElevation = 4.0;
  static const double _kTextScale = 0.8;
  static const double _kGlowBlur = 5.0;
  static const double _kParchmentBorderWidth = 1.5;
  static const double _kParchmentRadius = 6.0;
  static const Color _kInk = Color(0xFF3B2A14);
  // an added section: dimmed, like a used-up note
  static const Color _kParchmentUsed = Color(0xFFD8C59A);
  static const Color _kInkUsed = Color(0xFF8A7650);

  final String data;
  // injected for testing
  final GameState? gameState;
  final Settings? settings;

  const SectionButton(
      {super.key, required this.data, this.gameState, this.settings});

  @override
  Widget build(BuildContext context) {
    final gameState = this.gameState ?? getIt<GameState>();
    final settings = this.settings ?? getIt<Settings>();
    double scale = settings.userScalingBars.value;
    final attack = attackModeController();
    return ListenableBuilder(
        listenable: Listenable.merge(
            [gameState.scenarioSectionsVersion, attack.phase]),
        builder: (context, child) {
          // Swerski: adding a section changes the board, so not while picking
          // or attacking standees.
          final locked = attack.phase.value != AttackPhase.off;
          final enabled =
              !locked && !gameState.scenarioSectionsAdded.contains(data);
          // Swerski: parchment, like the other menus, when that is on.
          final parchment = useParchmentMenus();
          final textStyle = getTitleTextStyle(scale * _kTextScale,
              settings: settings);
          return RepaintBoundary(
              child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: parchment ? _kInk : Colors.black,
              disabledBackgroundColor:
                  parchment ? _kParchmentUsed : Colors.blueGrey,
              fixedSize: Size(_kButtonWidth * scale, _kButtonHeight * scale),
              // Swerski: solid grey buttons, glowing text (or parchment).
              backgroundColor: parchment ? kParchment : Colors.grey.shade400,
              elevation: _kElevation,
              side: parchment
                  ? BorderSide(
                      color: kParchmentBorder,
                      width: _kParchmentBorderWidth * scale)
                  : null,
              shape: parchment
                  ? RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(_kParchmentRadius * scale))
                  : null,
            ),
            onPressed: enabled
                ? () {
                    gameState.action(
                        SetScenarioCommand(data, true, gameState: gameState));
                  }
                : null,
            child: Text(
              data.split(" ").first,
              style: parchment
                  ? textStyle.copyWith(
                      color: enabled ? _kInk : _kInkUsed, shadows: const [])
                  : textStyle.copyWith(shadows: const [
                      Shadow(color: Colors.black, blurRadius: _kGlowBlur),
                    ]),
              maxLines: 1,
            ),
          ));
        });
  }
}
