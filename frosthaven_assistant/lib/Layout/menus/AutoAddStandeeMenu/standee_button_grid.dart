import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';

import '../../../Layout/widgets/standee_nr_button.dart';
import '../../../Resource/app_constants.dart';
import '../../../Resource/enums.dart';
import '../../../Resource/ui_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/service_locator.dart';
import '../../../services/translation_service.dart';

const double _kButtonSpacerHeight = 20.0;
const int _kButtonRowSize = 4;

// Swerski: number chips that read on both the light and the dark popup.
const double _kChipMargin = 4.0;
const double _kChipRadius = 6.0;
const double _kChipBorderWidth = 1.5;
const double _kUnavailableOpacity = 0.35;
const Color _kEliteGold = Color(0xFFE2B33C);
const Color _kEliteGoldBorder = Color(0xFF8C6A12);

class StandeeButtonGrid extends StatelessWidget {
  const StandeeButtonGrid({
    super.key,
    required this.scale,
    required this.monster,
    required this.elite,
    required this.nrOfStandees,
    required this.nrLeft,
    required this.nrOfElite,
    required this.nrOfNormal,
    required this.isStandeeOut,
    required this.onStandeePress,
    this.darkMode = false,
    this.useChips = true,
  });

  final double scale;
  final bool darkMode;
  // Swerski setting: solid chips (true) or the official plain numbers (false).
  final bool useChips;
  final Monster monster;
  final bool elite;
  final int nrOfStandees;
  final int nrLeft;
  final int nrOfElite;
  final int nrOfNormal;
  final bool Function(int nr, Monster monster, bool elite, int nrOfElite,
      int nrOfNormal) isStandeeOut;
  final void Function(int nr, Monster monster, MonsterType type, bool elite,
      bool isOut, int nrOfElite, int nrOfNormal) onStandeePress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayName = getIt<TranslationService>().t(monster.type.display);
    final String text;
    if (nrLeft <= 0) {
      text = elite ? l10n.allEliteStandeesPlaced : l10n.allNormalStandeesPlaced;
    } else {
      text = elite
          ? l10n.addEliteStandees(nrLeft, displayName)
          : l10n.addNormalStandees(nrLeft, displayName);
    }

    final rows = <Widget>[];
    for (int start = 1; start <= nrOfStandees; start += _kButtonRowSize) {
      final end = (start + _kButtonRowSize - 1).clamp(1, nrOfStandees);
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          end - start + 1,
          (i) {
            final nr = start + i;
            bool boss = monster.type.levels.first.boss != null;
            MonsterType type = elite
                ? MonsterType.elite
                : (boss ? MonsterType.boss : MonsterType.normal);
            bool isOut = isStandeeOut(nr, monster, elite, nrOfElite, nrOfNormal);
            if (!useChips) {
              Color color = isOut
                  ? Colors.grey
                  : (elite ? Colors.yellow : (boss ? Colors.red : Colors.white));
              return StandeeNrButton(
                nr: nr,
                scale: scale,
                color: color,
                onPressed: () => onStandeePress(
                    nr, monster, type, elite, isOut, nrOfElite, nrOfNormal),
              );
            }
            bool onBoard =
                monster.monsterInstances.any((item) => item.standeeNr == nr);
            return _StandeeChip(
              nr: nr,
              scale: scale,
              type: type,
              onBoard: onBoard,
              unavailable: isOut && !onBoard,
              darkMode: darkMode,
              onPressed: () => onStandeePress(
                  nr, monster, type, elite, isOut, nrOfElite, nrOfNormal),
            );
          },
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: _kButtonSpacerHeight * scale),
        Text(text, style: getTitleTextStyle(scale)),
        ...rows,
      ],
    );
  }
}

/// One standee number. Free numbers are solid chips (gold for elite, red for
/// boss); numbers already on the board are greyed and struck through; numbers
/// that can't be added right now are faded.
class _StandeeChip extends StatelessWidget {
  const _StandeeChip({
    required this.nr,
    required this.scale,
    required this.type,
    required this.onBoard,
    required this.unavailable,
    required this.darkMode,
    required this.onPressed,
  });

  final int nr;
  final double scale;
  final MonsterType type;
  final bool onBoard;
  final bool unavailable;
  final bool darkMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    Color fill;
    Color border;
    Color textColor;
    if (onBoard) {
      fill = darkMode ? Colors.grey.shade800 : Colors.grey.shade300;
      border = Colors.transparent;
      textColor = darkMode ? Colors.grey.shade500 : Colors.grey.shade600;
    } else if (type == MonsterType.elite) {
      fill = _kEliteGold;
      border = _kEliteGoldBorder;
      textColor = Colors.black87;
    } else if (type == MonsterType.boss) {
      fill = Colors.red.shade700;
      border = Colors.red.shade900;
      textColor = Colors.white;
    } else {
      fill = darkMode ? Colors.grey.shade900 : Colors.white;
      border = darkMode ? Colors.white70 : Colors.black54;
      textColor = darkMode ? Colors.white : Colors.black87;
    }

    final radius = BorderRadius.circular(_kChipRadius * scale);
    return Opacity(
      opacity: unavailable ? _kUnavailableOpacity : 1.0,
      child: SizedBox(
        width: kButtonSize * scale,
        height: kButtonSize * scale,
        child: Padding(
          padding: EdgeInsets.all(_kChipMargin * scale),
          child: Material(
            color: fill,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                  color: border, width: _kChipBorderWidth * scale),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: onPressed,
              child: Center(
                child: Text(
                  nr.toString(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: kFontSizeTitle * scale,
                    decoration: onBoard ? TextDecoration.lineThrough : null,
                    decorationColor: textColor,
                    decorationThickness: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
