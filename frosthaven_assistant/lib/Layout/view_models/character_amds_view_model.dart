import 'package:flutter/foundation.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/game_methods.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

class CharacterAmdsViewModel {
  CharacterAmdsViewModel({GameState? gameState, Settings? settings})
      : _gameState = gameState ?? getIt<GameState>(),
        _settings = settings ?? getIt<Settings>();

  final GameState _gameState;
  final Settings _settings;

  Listenable get currentListNotifier => _gameState.currentListNotifier;

  bool get showCharacterAmd => _settings.showCharacterAMD.value;

  double get barScale => _settings.userScalingBars.value;

  // Swerski: together with modifiersFitOnBar, tells whether the monster deck
  // sits right under the character decks (narrow screens) instead of on the
  // bottom bar — the same rule the main scaffold uses to place it.
  bool get showAmdDeck => _settings.showAmdDeck.value;
  bool get isButtonsAndBugs =>
      _gameState.currentCampaign.value == "Buttons and Bugs";
  Settings get settings => _settings;

  /// Swerski: on narrow screens with parchment menus, the character decks'
  /// parchment strip also holds the monster deck (so it can slide away with
  /// them). [fitsOnBar] is modifiersFitOnBar for the current screen.
  bool holdsMonsterDeck({required bool fitsOnBar}) =>
      _settings.parchmentMenus.value &&
      !fitsOnBar &&
      showAmdDeck &&
      !isButtonsAndBugs &&
      showCharacterAmd &&
      characterAmount > 0;

  RoundState get roundState => _gameState.roundState.value;

  List<Character> get charsWithPerks => GameMethods.getCurrentCharacters()
      .where((c) => c.characterClass.perks.isNotEmpty)
      .toList();

  int get characterAmount => charsWithPerks.length;

  Character? get currentCharacter => GameMethods.getCurrentCharacter();

  bool get canShowOneDeck {
    final c = currentCharacter;
    return roundState == RoundState.playTurns &&
        c != null &&
        c.characterClass.perks.isNotEmpty;
  }
}
