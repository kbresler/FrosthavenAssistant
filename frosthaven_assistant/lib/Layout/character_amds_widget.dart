import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/l10n/app_localizations.dart';

import '../Resource/enums.dart';
import '../Resource/scaling.dart';
import '../Resource/settings.dart';
import '../Resource/state/game_state.dart';
import '../Resource/ui_utils.dart';
import 'theme.dart';
import 'ModifierDeckWidget/modifier_deck_widget.dart';
import 'view_models/character_amds_view_model.dart';

class CharacterAmdsWidget extends StatefulWidget {
  const CharacterAmdsWidget({super.key, this.gameState, this.settings});

  final GameState? gameState;
  final Settings? settings;

  @override
  CharacterAmdsWidgetState createState() => CharacterAmdsWidgetState();
}

class CharacterAmdsWidgetState extends State<CharacterAmdsWidget> {
  static const double _kDeckBaseHeight = 39.0;
  static const double _kDeckMargin = 4.0;

  CharacterAmdsViewModel? _vmInstance;
  CharacterAmdsViewModel get _vm => _vmInstance ??= CharacterAmdsViewModel(
      gameState: widget.gameState, settings: widget.settings);
  _OpenState _openStateUserIntentPlayTurns = _OpenState.oneOpen;
  _OpenState _openStateUserIntentChooseInit = _OpenState.allOpen;
  _OpenState _lastState = _OpenState.noOpen;

  // Swerski: narrow-screen strip holding the monster deck too. Each half of
  // the tab opens or closes its own decks: none, either one, or both.
  bool _stripMonstersOpen = true;
  bool _stripCharactersOpen = true;

  /// Folds [content] up (open = false) or out, tucking it down into the strip.
  Widget _foldable(bool open, Widget content) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: open ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 400),
      curve: Easing.standard,
      builder: (context, value, child) => ClipRect(
          child: Align(
              alignment: Alignment.topCenter,
              heightFactor: value,
              child: child)),
      child: content,
    );
  }

  Widget _deck(String name, double barScale) => Container(
      margin: EdgeInsets.only(top: _kDeckMargin * barScale),
      child: ModifierDeckWidget(key: ValueKey(name), name: name));

  /// Swerski: narrow screens. One strip with a split tab: character decks on
  /// top, the monster deck under them, running down behind the bottom bar.
  Widget _buildStrip(BuildContext context) {
    final barScale = _vm.barScale;
    final l10n = AppLocalizations.of(context)!;
    final current = _vm.currentCharacter;
    final characters = _vm.canShowOneDeck && current != null
        ? [current]
        : _vm.charsWithPerks;
    return RepaintBoundary(
        child: Column(children: [
      _ToggleButton(
        text: l10n.characterDecks,
        barScale: barScale,
        split: true,
        open: _stripCharactersOpen,
        onPressed: () =>
            setState(() => _stripCharactersOpen = !_stripCharactersOpen),
        monstersOpen: _stripMonstersOpen,
        onMonsters: () =>
            setState(() => _stripMonstersOpen = !_stripMonstersOpen),
      ),
      _ParchmentPanel(
        barScale: barScale,
        child: Column(children: [
          _foldable(
              _stripCharactersOpen,
              Column(
                  children: characters
                      .map((c) => _deck(c.id, barScale))
                      .toList())),
          _foldable(_stripMonstersOpen, _deck('', barScale)),
        ]),
      ),
    ]));
  }

  List<Offset> _getOffsets(int characterAmount) {
    final roundState = _vm.roundState;
    final currentCharacter = _vm.currentCharacter;
    final barScale = _vm.barScale;
    final deckHeight = (_kDeckBaseHeight + _kDeckMargin) * barScale;
    final goingUpAll = [Offset(0, deckHeight * characterAmount), Offset(0, 0)];
    final goingUpSome = [
      Offset(0, deckHeight * (characterAmount - 1)),
      Offset(0, 0)
    ];
    final goingUpOne = [Offset(0, deckHeight), Offset(0, 0)];
    final goingDownOne = [
      Offset(0, deckHeight * (characterAmount - 1)),
      Offset(0, deckHeight * characterAmount)
    ];
    final goingDownAll = [
      Offset(0, 0),
      Offset(0, deckHeight * characterAmount)
    ];
    final goingDownSome = [
      Offset(0, -deckHeight * (characterAmount - 1)),
      Offset(0, 0)
    ];
    final goingNowhereNone = [
      Offset(0, deckHeight * (characterAmount)),
      Offset(0, deckHeight * (characterAmount))
    ];
    final goingNowhereAll = [Offset(0, 0), Offset(0, 0)];
    final goingNowhereOne = [Offset(0, 0), Offset(0, 0)];
    var retVal = [Offset(0, 0), Offset(0, 0)];

    _OpenState whereWeAre = _lastState;
    _OpenState whereWeAreGoing = _OpenState.noOpen;

    if (roundState == RoundState.chooseInitiative) {
      whereWeAreGoing = _openStateUserIntentChooseInit;
    } else if (roundState == RoundState.playTurns) {
      whereWeAreGoing = _openStateUserIntentPlayTurns;
      if (currentCharacter == null && whereWeAreGoing == _OpenState.oneOpen) {
        whereWeAreGoing = _OpenState.noOpen;
      }
    }

    if (whereWeAre == whereWeAreGoing) {
      if (whereWeAre == _OpenState.noOpen) {
        retVal = goingNowhereNone;
      }
      if (whereWeAre == _OpenState.oneOpen) {
        retVal = goingNowhereOne;
      }
      if (whereWeAre == _OpenState.allOpen) {
        retVal = goingNowhereAll;
      }
    }
    if (whereWeAreGoing == _OpenState.allOpen) {
      if (whereWeAre == _OpenState.noOpen) {
        retVal = goingUpAll;
      }
      if (whereWeAre == _OpenState.oneOpen) {
        if (characterAmount == 1) {
          return goingNowhereOne;
        }
        retVal = goingUpSome;
      }
    }
    if (whereWeAreGoing == _OpenState.oneOpen) {
      if (whereWeAre == _OpenState.noOpen) {
        retVal = goingUpOne;
      }
      if (whereWeAre == _OpenState.allOpen) {
        if (characterAmount == 1) {
          return goingNowhereOne;
        }
        retVal = goingDownSome;
      }
    }
    if (whereWeAreGoing == _OpenState.noOpen) {
      if (whereWeAre == _OpenState.oneOpen) {
        retVal = goingDownOne;
      }
      if (whereWeAre == _OpenState.allOpen) {
        retVal = goingDownAll;
      }
    }

    _lastState = whereWeAreGoing;
    return retVal;
  }

  @override
  Widget build(BuildContext context) {
    if (!_vm.showCharacterAmd) {
      return Container();
    }
    return ListenableBuilder(
        listenable: _vm.currentListNotifier,
        builder: (context, child) {
          final characterAmount = _vm.characterAmount;
          if (characterAmount == 0) {
            return Container();
          }
          // Swerski: narrow screens get one strip that also holds the
          // monster deck, with a Monsters | Characters tab.
          if (_vm.holdsMonsterDeck(
              fitsOnBar: modifiersFitOnBar(context, settings: _vm.settings))) {
            return _buildStrip(context);
          }

          final currentCharacter = _vm.currentCharacter;
          final roundState = _vm.roundState;
          final canShowOneDeck = _vm.canShowOneDeck;
          const duration = Duration(milliseconds: 500);
          final barScale = _vm.barScale;
          final offsets = _getOffsets(characterAmount);
          final text = AppLocalizations.of(context)!.characterDecks;

          return RepaintBoundary(
              child: TweenAnimationBuilder<Offset>(
                  tween: Tween(begin: offsets.first, end: offsets.last),
                  duration: duration,
                  curve: Easing.standard,
                  builder: (context, offset, child) =>
                      Transform.translate(offset: offset, child: child),
                  child: Column(children: [
                    _ToggleButton(
                        text: text,
                        barScale: barScale,
                        open: _lastState != _OpenState.noOpen,
                        onPressed: () => {
                              setState(() {
                                if (roundState == RoundState.chooseInitiative) {
                                  if (_openStateUserIntentChooseInit ==
                                      _OpenState.noOpen) {
                                    _openStateUserIntentChooseInit =
                                        _OpenState.allOpen;
                                  } else if (_openStateUserIntentChooseInit ==
                                      _OpenState.allOpen) {
                                    _openStateUserIntentChooseInit =
                                        _OpenState.noOpen;
                                  }
                                } else {
                                  if (canShowOneDeck) {
                                    if (_openStateUserIntentPlayTurns ==
                                        _OpenState.oneOpen) {
                                      _openStateUserIntentPlayTurns =
                                          _OpenState.allOpen;
                                    } else if (_openStateUserIntentPlayTurns ==
                                        _OpenState.allOpen) {
                                      _openStateUserIntentPlayTurns =
                                          _OpenState.oneOpen;
                                    } else if (_openStateUserIntentPlayTurns ==
                                        _OpenState.noOpen) {
                                      _openStateUserIntentPlayTurns =
                                          _OpenState.oneOpen;
                                    }
                                  } else {
                                    if (_openStateUserIntentPlayTurns ==
                                        _OpenState.noOpen) {
                                      _openStateUserIntentPlayTurns =
                                          _OpenState.allOpen;
                                    } else if (_openStateUserIntentPlayTurns ==
                                        _OpenState.allOpen) {
                                      _openStateUserIntentPlayTurns =
                                          _OpenState.oneOpen;
                                    } else if (_openStateUserIntentPlayTurns ==
                                        _OpenState.oneOpen) {
                                      _openStateUserIntentPlayTurns =
                                          _OpenState.allOpen;
                                    }
                                  }
                                }
                              })
                            }),
                    // Swerski: the parchment stays put while the decks on it
                    // fade, so closing slides it back behind the bottom bar.
                    _ParchmentPanel(
                      barScale: barScale,
                      child: RepaintBoundary(
                        child: AnimatedOpacity(
                            opacity:
                                _lastState == _OpenState.noOpen ? 0.0 : 1.0,
                            duration: duration,
                            curve: Easing.standard,
                            child: (_openStateUserIntentPlayTurns ==
                                        _OpenState.oneOpen &&
                                    canShowOneDeck)
                                ? Container(
                                    margin: EdgeInsets.only(
                                        top: _kDeckMargin * barScale),
                                    child: ModifierDeckWidget(
                                        key: ValueKey(
                                            currentCharacter?.id ?? ''),
                                        name: currentCharacter?.id ?? ''))
                                : Column(
                                    children: _vm.charsWithPerks
                                        .map((item) => Container(
                                            margin: EdgeInsets.only(
                                                top: _kDeckMargin * barScale),
                                            child: ModifierDeckWidget(
                                                key: ValueKey(item.id),
                                                name: item.id)))
                                        .toList(),
                                  ))))
                  ])));
        });
  }
}

enum _OpenState { noOpen, oneOpen, allOpen }

// Swerski: the tab and the open decks form one strip of parchment.
// A deck is 153 px wide. With one card discarded its right side looks empty:
// that space is where the second card slides out when two are drawn
// (advantage / disadvantage), so the panel keeps the full width.
const double _kDeckWidth = 153.0;
const double _kPanelPad = 4.0;
const double _kParchmentRadius = 5.0;
const double _kParchmentBorderWidth = 1.5;

/// How far the parchment reaches below the character decks: past any decks
/// shown under them (monster deck on narrow screens, allies deck, 43 px each)
/// and the gap above the bottom bar. The board's edge cuts it off there, so
/// it looks like it comes out from behind the bar.
const double _kParchmentTail = 120.0;

/// Swerski (parchment menus on): the decks sit on a strip of parchment under
/// the tab that runs down behind the bottom bar. Opening slides it up out of
/// the bar; closing slides it back, leaving the tab on a short lip. Any deck
/// shown under the character decks (the monster deck on narrow screens, the
/// allies deck) sits on the same strip.
class _ParchmentPanel extends StatelessWidget {
  const _ParchmentPanel({required this.barScale, required this.child});

  final double barScale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!useParchmentMenus()) return child;
    final side = BorderSide(
        color: kParchmentBorder, width: _kParchmentBorderWidth * barScale);
    final inset = (_kPanelPad + _kParchmentBorderWidth) * barScale;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        bottom: -_kParchmentTail * barScale,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kParchment,
            // The tab's lower edge is the top seam; no bottom edge, the bar
            // covers it.
            border: Border(left: side, right: side),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(
            inset, 0, inset, _kPanelPad * barScale),
        child: child,
      ),
    ]);
  }
}

/// The "Character Decks" toggle. Swerski (parchment menus on): a slim
/// parchment tab as wide as the deck panel, with an arrow for open/closed,
/// instead of the official bright button floating over the board. With
/// [split] (narrow screens, monster deck on the strip) it is two handles:
/// "Monsters" opens and closes the monster deck, "Characters" the character
/// decks, each on its own.
class _ToggleButton extends StatelessWidget {
  static const double _kTabHeight = 24.0;
  static const double _kFontSize = 14.0;
  static const double _kIconSize = 18.0;
  static const Color _kText = Color(0xFF3B2A14);

  const _ToggleButton({
    required this.text,
    required this.barScale,
    required this.open,
    required this.onPressed,
    this.split = false,
    this.monstersOpen = true,
    this.onMonsters,
  });

  final String text;
  final double barScale;
  final bool open;
  final VoidCallback onPressed;
  final bool split;
  final bool monstersOpen;
  final VoidCallback? onMonsters;

  Widget _label(String label, {bool? arrowOpen}) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: _kFontSize * barScale, color: _kText)),
            if (arrowOpen != null)
              Icon(arrowOpen ? Icons.expand_more : Icons.expand_less,
                  size: _kIconSize * barScale, color: _kText),
          ]);

  @override
  Widget build(BuildContext context) {
    if (!useParchmentMenus()) {
      return ElevatedButton(onPressed: onPressed, child: Text(text));
    }
    // Square bottom corners: the tab always sits on the parchment strip.
    final corner = Radius.circular(_kParchmentRadius * barScale);
    final radius = BorderRadius.only(topLeft: corner, topRight: corner);
    return SizedBox(
      // Same width as the panel: deck + padding + border on both sides.
      width: (_kDeckWidth + 2 * (_kPanelPad + _kParchmentBorderWidth)) *
          barScale,
      height: _kTabHeight * barScale,
      child: Material(
        color: kParchment,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
              color: kParchmentBorder,
              width: _kParchmentBorderWidth * barScale),
        ),
        child: split
            ? Row(children: [
                Expanded(
                    child: InkWell(
                        borderRadius: BorderRadius.only(topLeft: corner),
                        onTap: onMonsters,
                        child: Center(
                            child: _label(
                                AppLocalizations.of(context)!.deckTabMonsters,
                                arrowOpen: monstersOpen)))),
                Container(
                    width: _kParchmentBorderWidth * barScale,
                    color: kParchmentBorder),
                Expanded(
                    child: InkWell(
                        borderRadius: BorderRadius.only(topRight: corner),
                        onTap: onPressed,
                        child: Center(
                            child: _label(
                                AppLocalizations.of(context)!.deckTabCharacters,
                                arrowOpen: open)))),
              ])
            : InkWell(
                borderRadius: radius,
                onTap: onPressed,
                child: Center(child: _label(text, arrowOpen: open)),
              ),
      ),
    );
  }
}
