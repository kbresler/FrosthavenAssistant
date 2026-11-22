import '../Layout/view_models/condition_button_view_model.dart';
import '../Layout/view_models/status_menu_view_model.dart';
import 'commands/add_condition_command.dart';
import 'commands/change_stat_commands/change_bless_command.dart';
import 'commands/change_stat_commands/change_curse_command.dart';
import 'commands/change_stat_commands/change_health_command.dart';
import 'commands/group_command.dart';
import 'commands/labeled_command.dart';
import 'commands/remove_condition_command.dart';
import 'enums.dart';
import 'game_methods.dart';
import 'settings.dart';
import 'state/game_state.dart';

/// One figure a status action can be applied to: a monster standee, an ally,
/// or anything else [GameMethods.getFigure] can find.
typedef FigureRef = ({String ownerId, String figureId});

/// Health, conditions, chill and bless/curse applied to one or many figures
/// as ONE undoable action.
///
/// Each builder skips the figures the change cannot apply to (dead, immune,
/// at a cap, out of supply) and returns: null when nothing applies, the one
/// command (labeled) for a single figure, or a [GroupCommand] for several.
/// The labels use the attack-mode wording ("−1 health (2)", "+3 bless").
///
/// The same immunity and supply rules the single-figure menus use are called
/// here, not copied: [ConditionButtonViewModel] for conditions,
/// [GameMethods.hasImmunity] for curse, [GameMethods.blessCurseLeft] for the
/// shared card pools.
class StatusActions {
  /// The chill cap, same as the single-standee menu.
  static const int maxChill = 12;

  static Command? buildHealthChange(List<FigureRef> targets, int change,
      {required GameState gameState}) {
    final commands = <Command>[];
    for (final t in targets) {
      final fig = _figure(t, gameState);
      if (fig == null || fig.health.value <= 0) continue;
      if (change > 0 && fig.health.value >= fig.maxHealth.value) continue;
      commands.add(ChangeHealthCommand(change, t.figureId, t.ownerId,
          gameState: gameState));
    }
    return _one(commands, '${_signed(change)} health (${commands.length})');
  }

  static Command? buildKill(List<FigureRef> targets,
      {required GameState gameState}) {
    final commands = <Command>[];
    for (final t in targets) {
      final fig = _figure(t, gameState);
      if (fig == null || fig.health.value <= 0) continue;
      commands.add(ChangeHealthCommand(
          -fig.health.value, t.figureId, t.ownerId,
          gameState: gameState));
    }
    return _one(commands, 'Kill (${commands.length})');
  }

  static Command? buildAddCondition(List<FigureRef> targets,
      Condition condition,
      {required GameState gameState, required Settings settings}) {
    final commands = <Command>[];
    for (final t in targets) {
      final fig = _figure(t, gameState);
      if (fig == null || fig.health.value <= 0) continue;
      if (fig.conditions.value.contains(condition)) continue;
      if (isImmune(t, condition, gameState: gameState, settings: settings)) {
        continue;
      }
      commands.add(AddConditionCommand(condition, t.figureId, t.ownerId,
          gameState: gameState));
    }
    return _one(commands, '+${condition.getName()} (${commands.length})');
  }

  static Command? buildRemoveCondition(List<FigureRef> targets,
      Condition condition,
      {required GameState gameState, required Settings settings}) {
    final commands = <Command>[];
    for (final t in targets) {
      final fig = _figure(t, gameState);
      if (fig == null || fig.health.value <= 0) continue;
      if (!fig.conditions.value.contains(condition)) continue;
      if (isImmune(t, condition, gameState: gameState, settings: settings)) {
        continue;
      }
      commands.add(RemoveConditionCommand(condition, t.figureId, t.ownerId,
          gameState: gameState));
    }
    return _one(commands, '−${condition.getName()} (${commands.length})');
  }

  static Command? buildChillChange(List<FigureRef> targets, int change,
      {required GameState gameState}) {
    final commands = <Command>[];
    for (final t in targets) {
      final fig = _figure(t, gameState);
      if (fig == null || fig.health.value <= 0) continue;
      if (change > 0) {
        if (fig.chill.value >= maxChill) continue;
        commands.add(AddConditionCommand(Condition.chill, t.figureId, t.ownerId,
            gameState: gameState));
      } else if (fig.chill.value > 0) {
        commands.add(RemoveConditionCommand(
            Condition.chill, t.figureId, t.ownerId,
            gameState: gameState));
      }
    }
    return _one(commands, '${_signed(change)} chill (${commands.length})');
  }

  static Command? buildBlessChange(List<FigureRef> targets, int change,
          {required GameState gameState, required Settings settings}) =>
      _deckCards('bless', change, targets,
          gameState: gameState, settings: settings);

  static Command? buildCurseChange(List<FigureRef> targets, int change,
          {required GameState gameState, required Settings settings}) =>
      _deckCards('curse', change, targets,
          gameState: gameState, settings: settings);

  /// Whether [t] cannot get [condition]: it is immune, or the condition is
  /// hero-only (impair, infect) on a monster. The same check the
  /// single-standee menu's condition buttons use to disable themselves.
  static bool isImmune(FigureRef t, Condition condition,
      {required GameState gameState, required Settings settings}) {
    if ((condition == Condition.impair || condition == Condition.infect) &&
        _figure(t, gameState) is MonsterInstance) {
      return true;
    }
    return !ConditionButtonViewModel(
            condition: condition,
            figureId: t.figureId,
            ownerId: t.ownerId,
            immunities: _immunities(t, gameState: gameState, settings: settings),
            gameState: gameState,
            settings: settings)
        .enabled;
  }

  /// Immune to curse: it can't have a curse card added to its deck (the rule
  /// book: immunity stops adding the card, not a card already in the deck).
  static bool isImmuneToCurse(FigureRef t,
          {required GameState gameState, required Settings settings}) =>
      GameMethods.hasImmunity(
          _immunities(t, gameState: gameState, settings: settings), 'curse');

  /// The modifier deck [t]'s cards go into: a hero's own deck; allies share
  /// the ally deck outside OG Gloom; monsters share the monster deck.
  static ModifierDeck? deckOf(FigureRef t,
      {required GameState gameState, required Settings settings}) {
    // Resolve the figure before the monster view model: it casts the owner
    // `as Monster` and would throw for a hero or a hero's summon.
    final fig = _figure(t, gameState);
    if (fig is CharacterState) return fig.modifierDeck;
    if (_ownerMonster(t, gameState) == null) return null;
    final monster = _menu(t, gameState: gameState, settings: settings).monster;
    if (monster == null) return null;
    if (monster.isAlly &&
        (gameState.allyDeckInOGGloom.value ||
            !GameMethods.isOgGloomEdition())) {
      return gameState.modifierDeckAllies;
    }
    return gameState.modifierDeck;
  }

  // One bless (or curse) card into each applicable figure's modifier deck,
  // under the shared-pool limits ([GameMethods.blessCurseLeft], never below
  // none). [pending] counts the cards already queued for each deck.
  static Command? _deckCards(String id, int change, List<FigureRef> targets,
      {required GameState gameState, required Settings settings}) {
    final commands = <Command>[];
    final pending = <ModifierDeck, int>{}; // cards added so far, per deck
    for (final t in targets) {
      final deck = deckOf(t, gameState: gameState, settings: settings);
      if (deck == null) continue;
      if (id == 'curse' &&
          change > 0 &&
          isImmuneToCurse(t, gameState: gameState, settings: settings)) {
        continue;
      }
      final inDeck = deck.getRemovable(id).value + (pending[deck] ?? 0);
      if (change < 0 && inDeck <= 0) continue;
      if (change > 0 &&
          GameMethods.blessCurseLeft(id, deck,
                  pending: pending, gameState: gameState) <=
              0) {
        continue;
      }
      pending[deck] = (pending[deck] ?? 0) + change;
      commands.add(id == 'bless'
          ? ChangeBlessCommand(change, t.figureId, t.ownerId,
              gameState: gameState)
          : ChangeCurseCommand(change, t.figureId, t.ownerId,
              gameState: gameState));
    }
    return _one(commands, '${_signed(change * commands.length)} $id');
  }

  static Command? _one(List<Command> commands, String label) {
    if (commands.isEmpty) return null;
    if (commands.length == 1) return LabeledCommand(commands.first, label);
    return GroupCommand(commands, label);
  }

  static FigureState? _figure(FigureRef t, GameState gameState) =>
      GameMethods.getFigure(t.ownerId, t.figureId, gameState: gameState);

  static StatusMenuViewModel _menu(FigureRef t,
          {required GameState gameState, required Settings settings}) =>
      StatusMenuViewModel(
          figureId: t.figureId,
          monsterId: t.ownerId,
          gameState: gameState,
          settings: settings);

  // Rebuilt per call: monster immunities can change and tests mutate them.
  // Only a standee owned by a monster has an immunity list: the view model
  // casts the owner and would throw for a hero or a hero's summon.
  static List<String> _immunities(FigureRef t,
      {required GameState gameState, required Settings settings}) {
    final fig = _figure(t, gameState);
    if (fig is! MonsterInstance || _ownerMonster(t, gameState) == null) {
      return const [];
    }
    return _menu(t, gameState: gameState, settings: settings).immunities;
  }

  // The owner only when it is a monster on the board; a hero's or an ally's
  // summon is owned by a Character.
  static Monster? _ownerMonster(FigureRef t, GameState gameState) {
    for (final item in gameState.currentList) {
      if (item.id == t.ownerId) return item is Monster ? item : null;
    }
    return null;
  }

  static String _signed(int n) => n > 0 ? '+$n' : '−${-n}';
}
