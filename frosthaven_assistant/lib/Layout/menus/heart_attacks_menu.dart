import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Resource/commands/adjust_heart_attacks_command.dart';
import 'package:frosthaven_assistant/Resource/game_methods.dart';
import 'package:frosthaven_assistant/Resource/ui_utils.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';
import 'package:frosthaven_assistant/services/translation_service.dart';

import '../../Resource/settings.dart';
import '../../Resource/state/game_state.dart';
import '../../services/service_locator.dart';
import '../CharacterWidget/kielbasa_icon.dart';
import '../widgets/modal_background.dart';

/// Swerski: hand-corrects a hero's four heart-attack tallies (little/major ×
/// this scenario/earlier). Opened from a card tally or from the little / major
/// totals in the status menu. Each +/− tap runs one
/// [AdjustHeartAttacksCommand] through the action handler, so every tap is its
/// own Undo step and the two views (dialog and card) stay in sync via the
/// shared counts. No toast: this is bookkeeping, not an event.
class HeartAttacksMenu extends StatefulWidget {
  const HeartAttacksMenu({
    super.key,
    required this.characterId,
    this.gameState,
    this.settings,
  });

  final String characterId;
  final GameState? gameState;
  final Settings? settings;

  /// Test handles for the per-cell steppers.
  static Key minusKey(HeartAttackKind kind, HeartAttackPeriod period) =>
      ValueKey('heart-minus-${kind.name}-${period.name}');

  static Key plusKey(HeartAttackKind kind, HeartAttackPeriod period) =>
      ValueKey('heart-plus-${kind.name}-${period.name}');

  @override
  State<HeartAttacksMenu> createState() => _HeartAttacksMenuState();
}

class _HeartAttacksMenuState extends State<HeartAttacksMenu> {
  static const double _kMenuWidth = 320.0;
  static const double _kLabelWidth = 88.0;
  static const double _kIconHeight = 12.0;
  static const double _kIconGap = 6.0;

  GameState get _gameState => widget.gameState ?? getIt<GameState>();

  CharacterState? get _state => GameMethods.getCharacterByName(
        widget.characterId,
        gameState: _gameState,
      )?.characterState;

  void _adjust(HeartAttackKind kind, HeartAttackPeriod period, int change) {
    _gameState.action(AdjustHeartAttacksCommand(
      characterId: widget.characterId,
      kind: kind,
      period: period,
      change: change,
      gameState: _gameState,
    ));
  }

  Widget _stepper(double scale, HeartAttackKind kind, HeartAttackPeriod period,
      int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: HeartAttacksMenu.minusKey(kind, period),
          // Disabled at the bounds: a tap that changes nothing would still
          // leave an empty Undo step.
          onPressed: value > 0 ? () => _adjust(kind, period, -1) : null,
          iconSize: 18 * scale,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 30 * scale,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: getTitleTextStyle(scale),
          ),
        ),
        IconButton(
          key: HeartAttacksMenu.plusKey(kind, period),
          onPressed: value < AdjustHeartAttacksCommand.max
              ? () => _adjust(kind, period, 1)
              : null,
          iconSize: 18 * scale,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _valueRow(double scale, AppLocalizations l10n, HeartAttackKind kind,
      String label, int before, int current) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4 * scale),
      child: Row(
        children: [
          SizedBox(
            width: _kLabelWidth * scale,
            child: Row(
              children: [
                KielbasaIcon(
                  height: _kIconHeight * scale,
                  recovering: kind == HeartAttackKind.little,
                ),
                SizedBox(width: _kIconGap * scale),
                Flexible(
                  child: Text(label, style: getTitleTextStyle(scale)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _stepper(scale, kind, HeartAttackPeriod.earlier, before),
          ),
          Expanded(
            child:
                _stepper(scale, kind, HeartAttackPeriod.thisScenario, current),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = getModalMenuScale(context);
    final l10n = AppLocalizations.of(context)!;
    final name = getIt<TranslationService>().t(widget.characterId);

    return ModalBackground(
      width: _kMenuWidth * scale,
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: ListenableBuilder(
          listenable: _gameState.commandIndex,
          builder: (context, child) {
            final state = _state;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.heartAttacksMenuTitle(name),
                    textAlign: TextAlign.center,
                    style: getTitleTextStyle(scale)),
                SizedBox(height: 12 * scale),
                if (state == null)
                  const SizedBox.shrink()
                else ...[
                  Padding(
                    padding: EdgeInsets.only(bottom: 4 * scale),
                    child: Row(
                      children: [
                        SizedBox(width: _kLabelWidth * scale),
                        Expanded(
                          child: Text(
                            l10n.heartAttacksEarlier,
                            textAlign: TextAlign.center,
                            style: getSmallTextStyle(scale),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            l10n.heartAttacksThisScenario,
                            textAlign: TextAlign.center,
                            style: getSmallTextStyle(scale),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _valueRow(scale, l10n, HeartAttackKind.little,
                      l10n.heartAttacksLittle, state.littleHeartAttacksBefore.value,
                      state.littleHeartAttacks.value),
                  _valueRow(scale, l10n, HeartAttackKind.major,
                      l10n.heartAttacksMajor, state.heartAttacksBefore.value,
                      state.heartAttacks.value),
                ],
                SizedBox(height: 8 * scale),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.close, style: getButtonTextStyle(scale)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
