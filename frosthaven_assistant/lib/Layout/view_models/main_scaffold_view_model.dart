import 'package:flutter/foundation.dart';
import 'package:frosthaven_assistant/Resource/game_data.dart';
import 'package:frosthaven_assistant/Resource/game_methods.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

import '../../Model/campaign.dart';

class MainScaffoldViewModel {
  MainScaffoldViewModel(
      {GameState? gameState, Settings? settings, GameData? gameData})
      : _gameState = gameState ?? getIt<GameState>(),
        _settings = settings ?? getIt<Settings>(),
        _gameData = gameData ?? getIt<GameData>();

  final GameState _gameState;
  final Settings _settings;
  final GameData _gameData;

  // Notifiers the widget subscribes to
  ValueListenable<Map<String, CampaignModel>> get modelData =>
      _gameData.modelData;
  ValueListenable<double> get userScalingBars => _settings.userScalingBars;
  ValueListenable<String> get scenario => _gameState.scenario;
  ValueListenable<String> get currentCampaign => _gameState.currentCampaign;
  ValueListenable<int> get scenarioSectionsVersion =>
      _gameState.scenarioSectionsVersion;
  Listenable get lootDeckCardCount => _gameState.lootDeck.drawPileNotifier;
  ValueListenable<bool> get hideLootDeck => _settings.hideLootDeck;
  ValueListenable<bool> get showAmdDeckNotifier => _settings.showAmdDeck;
  ValueListenable<bool> get showAllyDeck => _gameState.showAllyDeck;
  ValueListenable<bool> get allyDeckInOGGloom => _gameState.allyDeckInOGGloom;
  Listenable get currentListNotifier => _gameState.currentListNotifier;

  // Derived state
  bool get hasLootDeck => GameMethods.hasLootDeck();
  bool get shouldShowAlliesDeck => GameMethods.shouldShowAlliesDeck();
  bool get isButtonsAndBugs =>
      _gameState.currentCampaign.value == "Buttons and Bugs";
  bool get showAmdDeck => _settings.showAmdDeck.value;
  bool get showCharacterAmd => _settings.showCharacterAMD.value;

  /// Number of sections still available for the current scenario,
  /// or null if none should be shown.
  int? get availableSections {
    int? count = _gameData.modelData.value[_gameState.currentCampaign.value]
        ?.scenarios[_gameState.scenario.value]?.sections.length;
    if (count != null && _gameState.scenarioSectionsAdded.length == count) {
      count = null;
    }
    if (!_settings.showSectionsInMainView.value) {
      count = null;
    }
    return count;
  }
}
