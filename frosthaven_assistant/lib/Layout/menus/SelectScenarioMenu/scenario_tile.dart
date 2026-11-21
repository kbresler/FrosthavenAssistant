import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Resource/commands/set_scenario_command.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';
import 'package:frosthaven_assistant/services/translation_service.dart';

import '../../../Resource/app_constants.dart';
import '../../../l10n/app_localizations.dart';

class ScenarioTile extends StatelessWidget {
  const ScenarioTile({
    super.key,
    required this.name,
    required this.gameState,
    required this.settings,
  });

  final String name;
  final GameState gameState;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final translatedName = getIt<TranslationService>().t(name);
    // Swerski: "custom" reads as a proper entry, not a lower-case key.
    String title = name == "custom"
        ? AppLocalizations.of(context)!.customScenario
        : settings.showScenarioNames.value
            ? translatedName
            : name.split(' ').first;
    return ListTile(
      title: Text(title, style: kTitleStyle),
      onTap: () {
        Navigator.pop(context);
        gameState.action(SetScenarioCommand(name, false, gameState: gameState));
      },
    );
  }
}
