import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Resource/app_constants.dart';
import 'package:frosthaven_assistant/Resource/scaling.dart';

import '../../Resource/color_matrices.dart';
import '../../Resource/game_methods.dart';
import '../../Resource/settings.dart';
import '../../Resource/state/game_state.dart';
import '../../Resource/ui_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../services/service_locator.dart';
import '../../services/translation_service.dart';
import '../MonsterBox/monster_box.dart';
import '../attack_mode/attack_mode_controller.dart';
import '../attack_mode/attack_pick_outline.dart';
import '../health_wheel_controller.dart';
import '../view_models/character_view_model.dart';
import 'character_widget_internal.dart';
import 'kielbasa_icon.dart';

class CharacterWidget extends StatefulWidget {
  static const double _kSpacing = 2.0;
  static const double _kElevation = 8.0;
  static const double _kMarginH = 3.2;
  static const int _kBothSides = 2;

  const CharacterWidget({
    required this.characterId,
    super.key,
    this.initPreset,
    this.gameState,
    this.settings,
  });

  final String characterId;
  final int? initPreset;

  final GameState? gameState;
  // injected for testing
  final Settings? settings;

  @override
  CharacterWidgetState createState() => CharacterWidgetState();
}

class CharacterWidgetState extends State<CharacterWidget> {
  bool isCharacter = true;
  List<MonsterInstance> lastList = [];

  @override
  void initState() {
    final character = GameMethods.getCharacterByName(widget.characterId);
    if (character != null) {
      lastList = character.characterState.summonList.toList();
    }
    super.initState();
  }

  Widget _buildCharacterContent(
    CharacterViewModel vm,
    Character character,
    bool isCharacter,
    Widget inner,
  ) {
    if (vm.isChooseInitiative) {
      return CharacterWidgetInternal(
        character: character,
        isCharacter: isCharacter,
        characterId: character.id,
        initPreset: widget.initPreset,
      );
    }
    if (vm.showHealthWheel) {
      return HealthWheelController(
        figureId: widget.characterId,
        ownerId: widget.characterId,
        child: inner,
      );
    }
    return inner;
  }

  Widget buildMonsterBoxGrid(double scale, Character character) {
    String displayStartAnimation = "";

    final summonList = character.characterState.summonList;
    if (lastList.length < summonList.length) {
      //find which is new - always the last one
      displayStartAnimation = summonList.last
          .getId(); //issue: if several with same id?
    }

    final generatedChildren = List<Widget>.generate(
      summonList.length,
      (index) => AnimatedSize(
        //not really needed now
        key: Key(index.toString()),
        duration: const Duration(milliseconds: kAnimationDurationMs),
        child: MonsterBox(
          key: Key(summonList[index].getId()),
          figureId:
              summonList[index].name +
              summonList[index].gfx +
              summonList[index].standeeNr.toString(),
          ownerId: character.id,
          displayStartAnimation: displayStartAnimation,
          blockInput: false,
          scale: scale,
        ),
      ),
    );
    lastList = summonList.toList();
    return Wrap(
      runSpacing: CharacterWidget._kSpacing * scale,
      spacing: CharacterWidget._kSpacing * scale,
      children: generatedChildren,
    );
  }

  @override
  Widget build(BuildContext context) {
    final character = GameMethods.getCharacterByName(widget.characterId);
    if (character == null) return Container();

    final vm = CharacterViewModel(
      character,
      gameState: widget.gameState,
      settings: widget.settings,
    );

    return InkWell(
      onTap: () {
        // Swerski: while attack mode is picking, the card picks the hero.
        final attack = attackModeController();
        if (attack.isSelecting) {
          attack.togglePickCharacter(character.id);
        } else {
          vm.openStatusMenu(context);
        }
      },
      child: ListenableBuilder(
        listenable: vm.updateList,
        builder: (context, child) {
          final double scale = getScaleByReference(context);
          // The rows live in the gap between the unwrapped name text
          // and the XP column; a long name eats it (at phone width even
          // a middling one does), and the rows hide rather than cover it.
          final statGap = HeartAttackStat.nameGap(context, character, scale);

          // DecoratedBox instead of PhysicalShape: avoids creating a
          // PhysicalModelLayer (compositing save layer), which causes
          // TextStyle.shadows to paint at wrong coords on iOS/Impeller.
          const dropShadow = BoxShadow(
            color: Colors.black38,
            blurRadius: CharacterWidget._kElevation,
            offset: Offset(0, CharacterWidget._kElevation / 4),
          );
          // Swerski: same green outline and glow as monsters and
          // standees when it's this character's turn.
          final glow = vm.isCurrentTurn && useTurnGlow();
          Widget inner = DecoratedBox(
            decoration: BoxDecoration(
              color: vm.isCurrentTurn
                  ? (glow ? kTurnColor : Colors.tealAccent)
                  : Colors.transparent,
              border: glow
                  ? Border.all(
                      color: kTurnColor,
                      width: kTurnOutlineWidth * scale,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    )
                  : null,
              boxShadow: [if (glow) turnGlowShadow(scale) else dropShadow],
            ),
            child: CharacterWidgetInternal(
              character: character,
              isCharacter: isCharacter,
              characterId: character.id,
              initPreset: widget.initPreset,
            ),
          );

          final Widget characterContent = _buildCharacterContent(
            vm,
            character,
            isCharacter,
            inner,
          );

          return Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                margin: EdgeInsets.only(
                  left: CharacterWidget._kMarginH * scale,
                  right: CharacterWidget._kMarginH * scale,
                ),
                width:
                    getMainListWidth(context) -
                    CharacterWidget._kMarginH *
                        CharacterWidget._kBothSides *
                        scale,
                child: ValueListenableBuilder<BuiltList<MonsterInstance>>(
                  valueListenable: vm.summonListNotifier,
                  builder: (context, value, child) {
                    return buildMonsterBoxGrid(scale, character);
                  },
                ),
              ),
              // Swerski: the pick outline hugs the hero card, not the
              // summons row above it. The kielbasa rows sit in the gap left
              // of the XP/level column, outside the grey filter so they keep
              // their colour on a greyed-out exhausted card; they are
              // Positioned and inert, so they shift nothing and block
              // nothing.
              AttackPickOutline(
                ownerId: character.id,
                figureId: character.id,
                child: Stack(
                  children: [
                    grayScaleIf(
                      grayedOut: !vm.notGrayScale,
                      child: characterContent,
                    ),
                    Positioned(
                      top: HeartAttackStat._kLittleTop * scale,
                      right:
                          getMainListWidth(context) -
                          HeartAttackStat._kXPColumnLeft * scale +
                          HeartAttackStat._kGapToXP * scale,
                      child: IgnorePointer(
                        child: HeartAttackStat(
                          character: character,
                          scale: scale,
                          little: true,
                          gap: statGap,
                          settings: widget.settings,
                        ),
                      ),
                    ),
                    Positioned(
                      top: HeartAttackStat._kMajorTop * scale,
                      right:
                          getMainListWidth(context) -
                          HeartAttackStat._kXPColumnLeft * scale +
                          HeartAttackStat._kGapToXP * scale,
                      child: IgnorePointer(
                        child: HeartAttackStat(
                          character: character,
                          scale: scale,
                          little: false,
                          gap: statGap,
                          settings: widget.settings,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Swerski: one of the two heart-attack rows of a character card, standing in
/// the gap left of the XP/level column as `[earlier] [kielbasa] [this
/// scenario]`, right-aligned to that column. The little (long-rest) row sits
/// on the XP row: pale kielbasa, white current count. The major row sits on
/// the level row: full-colour kielbasa, red current count. Earlier-scenario
/// counts are grey. Both numbers always show, zero included; the whole row
/// is drawn only once either number of its kind is above zero.
/// Nothing when the setting is off.
class HeartAttackStat extends StatelessWidget {
  const HeartAttackStat({
    super.key,
    required this.character,
    required this.scale,
    required this.little,
    required this.gap,
    this.settings,
  });

  // Row anchors mirroring CharacterWidgetInternal: the little row starts at
  // the XP row's top and the major row at the level row's top, so each one
  // centres exactly on its counterpart; the XP column's left edge is where
  // the gap ends.
  static const double _kLittleTop = 10.0;
  static const double _kMajorTop = 28.0;
  static const double _kXPColumnLeft = 314.0;
  static const double _kGapToXP = 4.0;
  // Where the name text starts on the card (after the class icon and the
  // initiative display); the name never wraps, so it eats the gap from here.
  static const double _kNameLeft = 107.0;
  // CharacterHealthWidget's name font sizes (private there, mirrored here
  // for the width measurement).
  static const double _kNameFontSizeFH = 15.0;
  static const double _kNameFontSizeOrig = 16.0;
  // Below this the row would smear to nothing: hide it instead.
  static const double _kMinRowWidth = 24.0;
  // The laid-out name can sit a hair wider than its measured style; leave
  // this much clear air beside it.
  static const double _kNameClampMargin = 2.0;
  // The level crown's icon height: the star's 16 would reach into the name
  // text, which runs further into the gap than the empty card suggests.
  static const double _kIconHeight = 12.0;
  // The XP star's height: the little row must end up as tall as the XP row
  // for the two to share a vertical centre.
  static const double _kLittleRowHeight = 19.0;
  // The level row's height, for the same purpose.
  static const double _kMajorRowHeight = 18.0;
  static const double _kGap = 2.0;
  // Offset of the dark outline around the red major count.
  static const double _kOutline = 0.8;

  static const Key littleKey = Key('heart-attack-little');
  static const Key majorKey = Key('heart-attack-major');

  final Character character;
  final double scale;

  /// True for the pale little-heart-attack row, false for the major one.
  final bool little;

  /// The gap the row may use, from [nameGap]; 0 hides the row.
  final double gap;

  // injected for testing
  final Settings? settings;

  /// How much room is left between the (unwrapped) name text and the XP
  /// column. Long names leave none at phone width, where the row hides
  /// rather than covering the name.
  static double nameGap(
    BuildContext context,
    Character character,
    double scale,
  ) {
    final display = character.characterState.display.value;
    final name = getIt.isRegistered<TranslationService>()
        ? getIt<TranslationService>().t(display)
        : display;
    final fh = GameMethods.isFrosthavenStyle(null);
    // Measure the name exactly as the card lays it out: a Text merges its
    // style with the inherited DefaultTextStyle (letterSpacing leaks in),
    // so the painter must merge the same way.
    final nameStyle = DefaultTextStyle.of(context).style.merge(
      getCardTitleStyle(
        (fh ? _kNameFontSizeFH : _kNameFontSizeOrig) * scale,
        textShadow(scale),
        fh,
      ),
    );
    final painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(text: name, style: nameStyle)
      ..layout();
    final gap =
        (_kXPColumnLeft - _kGapToXP - _kNameLeft) * scale -
        painter.width -
        _kNameClampMargin * scale;
    return gap < _kMinRowWidth * scale ? 0.0 : gap;
  }

  @override
  Widget build(BuildContext context) {
    if (GameMethods.isObjectiveOrEscort(character.characterClass)) {
      return const SizedBox.shrink();
    }
    if (gap <= 0) {
      return const SizedBox.shrink();
    }
    final st = settings ?? getIt<Settings>();
    final state = character.characterState;
    final before = little
        ? state.littleHeartAttacksBefore
        : state.heartAttacksBefore;
    final current = little ? state.littleHeartAttacks : state.heartAttacks;
    return ListenableBuilder(
      listenable: Listenable.merge([st.heartAttacks, before, current]),
      builder: (context, child) {
        if (!st.heartAttacks.value) {
          return const SizedBox.shrink();
        }
        if (before.value == 0 && current.value == 0) {
          return const SizedBox.shrink();
        }
        return _row(context, before.value, current.value);
      },
    );
  }

  /// Red alone is hard to read on the orange card, so the major count gets a
  /// dark outline (four hard shadows, one per diagonal) on top of the usual
  /// soft shadow. Same look on every card colour.
  TextStyle _redOutlined(TextStyle base) {
    final o = _kOutline * scale;
    const dark = Color(0xFF3A0A0A);
    return base.copyWith(
      shadows: [
        ...?base.shadows,
        Shadow(color: dark, offset: Offset(o, o)),
        Shadow(color: dark, offset: Offset(-o, o)),
        Shadow(color: dark, offset: Offset(o, -o)),
        Shadow(color: dark, offset: Offset(-o, -o)),
      ],
    );
  }

  Widget _row(BuildContext context, int before, int current) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      // No translations provided (a bare test app): show no row, not a crash.
      return const SizedBox.shrink();
    }
    TextStyle numberStyle(Color color) => getCardTitleStyle(
      kFontSizeSmall * scale,
      textShadow(scale),
      GameMethods.isFrosthavenStyle(null),
      color: color,
    );
    // A fixed-height slot centred on the XP or level row: when the row
    // scales down to fit the gap, its centre stays put instead of drifting
    // up. OverflowBox leaves the height to the content, so only the width
    // limits the scaling.
    return SizedBox(
      width: gap,
      height: (little ? _kLittleRowHeight : _kMajorRowHeight) * scale,
      child: OverflowBox(
        alignment: Alignment.centerRight,
        minWidth: 0,
        maxWidth: gap,
        minHeight: 0,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(
            key: little ? littleKey : majorKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$before', style: numberStyle(Colors.grey)),
              SizedBox(width: _kGap * scale),
              KielbasaIcon(
                height: _kIconHeight * scale,
                recovering: little,
                semanticLabel: little
                    ? l10n.heartAttackLittleBadge(before + current)
                    : l10n.heartAttackBadge(before + current),
              ),
              SizedBox(width: _kGap * scale),
              Text(
                '$current',
                style: little
                    ? numberStyle(Colors.white)
                    : _redOutlined(numberStyle(Colors.redAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
