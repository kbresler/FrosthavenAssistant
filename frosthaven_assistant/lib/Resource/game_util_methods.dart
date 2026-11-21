part of 'state/game_state.dart';
// ignore_for_file: library_private_types_in_public_api

/// Shown when a scenario starts, ahead of the scenario's own notes.
const String kBattleGoalReminder = "Remember to choose your Battle Goals.";

class GameUtilMethods {
  //note: while this changes the game state, it is a state used also by non game related instances.
  static void setToastMessage(String message, {GameState? gameState}) {
    final gs = gameState ?? getIt<GameState>();
    gs._toastMessage.value = message;
  }

  /// Swerski: Battle Goals are chosen before the first Draw, so the reminder
  /// is dropped then. Any scenario notes after it stay on screen.
  static void clearBattleGoalReminder({GameState? gameState}) {
    final gs = gameState ?? getIt<GameState>();
    final message = gs._toastMessage.value;
    if (message.startsWith(kBattleGoalReminder)) {
      gs._toastMessage.value =
          message.substring(kBattleGoalReminder.length).trimLeft();
    }
  }
}
