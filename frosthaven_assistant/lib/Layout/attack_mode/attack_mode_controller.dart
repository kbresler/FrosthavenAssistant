import 'package:flutter/foundation.dart';

import '../../Resource/commands/add_condition_command.dart';
import '../../Resource/commands/change_stat_commands/change_bless_command.dart';
import '../../Resource/commands/change_stat_commands/change_curse_command.dart';
import '../../Resource/commands/change_stat_commands/change_health_command.dart';
import '../../Resource/commands/group_command.dart';
import '../../Resource/commands/remove_condition_command.dart';
import '../../Resource/enums.dart';
import '../../Resource/game_methods.dart';
import '../../Resource/settings.dart';
import '../../Resource/state/game_state.dart';
import '../../services/service_locator.dart';
import '../view_models/condition_button_view_model.dart';
import '../view_models/status_menu_view_model.dart';

enum AttackPhase { off, selecting, attacking }

/// How many of a condition the switched-on standees carry.
enum ConditionTally { none, some, all }

/// One standee that can be attacked. Remembers what it looked like when it was
/// picked, so a standee that dies (and leaves the board) still has a chip.
class AttackTarget {
  const AttackTarget(
      {required this.ownerId,
      required this.figureId,
      required this.standeeNr,
      required this.type,
      required this.gfx});

  factory AttackTarget.of(MonsterInstance instance, String ownerId) =>
      AttackTarget(
          ownerId: ownerId,
          figureId: instance.getId(),
          standeeNr: instance.standeeNr,
          type: instance.type,
          gfx: instance.gfx);

  final String ownerId;
  final String figureId;
  final int standeeNr;
  final MonsterType type;
  final String gfx;

  @override
  bool operator ==(Object other) =>
      other is AttackTarget &&
      other.ownerId == ownerId &&
      other.figureId == figureId;

  @override
  int get hashCode => Object.hash(ownerId, figureId);
}

/// Swerski attack mode: pick several monster standees, then change health and
/// conditions on all the switched-on ones at once.
///
/// Selection is local to this device. Every change is one ordinary action
/// (a [GroupCommand]), so Undo and network sync work as usual.
class AttackModeController {
  static const int _kMaxChill = 12;

  AttackModeController({GameState? gameState, Settings? settings})
      : _gameState = gameState ?? getIt<GameState>(),
        _settings = settings ?? getIt<Settings>() {
    _round = _gameState.round.value;
    _roundState = _gameState.roundState.value;
    _gameState.round.addListener(_onRoundMoved);
    _gameState.roundState.addListener(_onRoundMoved);
    _gameState.commandIndex.addListener(_onCommandIndex);
  }

  final GameState _gameState;
  final Settings _settings;
  late int _round;
  late RoundState _roundState;

  // The attack that Draw or Next Round ended, and the action that ended it.
  // Undoing that action brings the attack back.
  List<AttackTarget>? _resumeRoster;
  Set<AttackTarget>? _resumeActive;
  int? _resumeAt;

  final phase = ValueNotifier<AttackPhase>(AttackPhase.off);

  /// Standees picked so far, in the order they were picked.
  final picked = ValueNotifier<List<AttackTarget>>(const []);

  /// The roster chosen when the attack started, and which of them are
  /// switched on.
  final roster = ValueNotifier<List<AttackTarget>>(const []);
  final active = ValueNotifier<Set<AttackTarget>>(const {});

  bool get isSelecting => phase.value == AttackPhase.selecting;
  bool get isAttacking => phase.value == AttackPhase.attacking;

  void dispose() {
    _gameState.round.removeListener(_onRoundMoved);
    _gameState.roundState.removeListener(_onRoundMoved);
    _gameState.commandIndex.removeListener(_onCommandIndex);
  }

  // Draw and Next Round end it.
  void _onRoundMoved() {
    final moved = _round != _gameState.round.value ||
        _roundState != _gameState.roundState.value;
    _round = _gameState.round.value;
    _roundState = _gameState.roundState.value;
    if (!moved || phase.value == AttackPhase.off) return;
    final wasAttacking = isAttacking;
    final roster = List<AttackTarget>.of(this.roster.value);
    final active = Set<AttackTarget>.of(this.active.value);
    end();
    if (wasAttacking) {
      // The action that moved the round lands at the next index.
      _resumeRoster = roster;
      _resumeActive = active;
      _resumeAt = _gameState.commandIndex.value + 1;
    }
  }

  // Undoing the action that ended an attack reopens it; any other new action
  // lets it go. (Last attack only, on this device.)
  void _onCommandIndex() {
    final at = _resumeAt;
    if (at == null) return;
    final index = _gameState.commandIndex.value;
    if (index < at) {
      if (phase.value == AttackPhase.off) {
        roster.value = _resumeRoster ?? const [];
        active.value = _resumeActive ?? const {};
        phase.value = AttackPhase.attacking;
      }
      _forgetResume();
    } else if (index > at) {
      _forgetResume();
    }
  }

  void _forgetResume() {
    _resumeRoster = null;
    _resumeActive = null;
    _resumeAt = null;
  }

  // ── Selecting ─────────────────────────────────────────────────────────────

  bool isPicked(String ownerId, String figureId) => picked.value
      .any((t) => t.ownerId == ownerId && t.figureId == figureId);

  void startSelecting({MonsterInstance? first, String? ownerId}) {
    _forgetResume();
    picked.value =
        (first != null && ownerId != null) ? [AttackTarget.of(first, ownerId)] : [];
    phase.value = AttackPhase.selecting;
  }

  void togglePick(MonsterInstance instance, String ownerId) {
    final target = AttackTarget.of(instance, ownerId);
    final list = List<AttackTarget>.of(picked.value);
    if (!list.remove(target)) list.add(target);
    picked.value = list;
  }

  /// Picks every standee of [monster] that is on the board, or lets them all
  /// go when they are all picked already.
  void togglePickMonster(Monster monster) {
    final instances =
        monster.monsterInstances.where((i) => i.health.value > 0).toList();
    if (instances.isEmpty) return;
    final allPicked = instances.every((i) => isPicked(monster.id, i.getId()));
    final list = List<AttackTarget>.of(picked.value);
    for (final i in instances) {
      final target = AttackTarget.of(i, monster.id);
      if (allPicked) {
        list.remove(target);
      } else if (!list.contains(target)) {
        list.add(target);
      }
    }
    picked.value = list;
  }

  /// Starts attacking with everything picked. Does nothing when empty.
  void startAttack() {
    if (picked.value.isEmpty) return;
    roster.value = List.of(picked.value);
    active.value = Set.of(picked.value);
    phase.value = AttackPhase.attacking;
  }

  /// Leaves selecting or attacking (Done, cancel, or Draw and Next Round).
  /// Done and cancel are a choice, so they are not brought back by Undo.
  void end() {
    _forgetResume();
    phase.value = AttackPhase.off;
    picked.value = const [];
    roster.value = const [];
    active.value = const {};
  }

  // ── Roster ────────────────────────────────────────────────────────────────

  FigureState? figureOf(AttackTarget t) =>
      GameMethods.getFigure(t.ownerId, t.figureId, gameState: _gameState);

  bool isDead(AttackTarget t) {
    final fig = figureOf(t);
    return fig == null || fig.health.value <= 0;
  }

  /// Switched-on standees that are still on the board.
  List<AttackTarget> get liveActive => roster.value
      .where((t) => active.value.contains(t) && !isDead(t))
      .toList();

  void toggleActive(AttackTarget t) {
    final next = Set.of(active.value);
    if (!next.remove(t)) next.add(t);
    active.value = next;
  }

  void only(AttackTarget t) => active.value = {t};

  void selectAll() => active.value = Set.of(roster.value);

  void selectNone() => active.value = const {};

  /// Switches a whole monster group on, or off when it is all on already.
  void toggleMonster(String ownerId) {
    final members = roster.value.where((t) => t.ownerId == ownerId).toList();
    final allOn = members.every(active.value.contains);
    final next = Set.of(active.value);
    if (allOn) {
      next.removeAll(members);
    } else {
      next.addAll(members);
    }
    active.value = next;
  }

  // ── Applying ──────────────────────────────────────────────────────────────

  static String _signed(int n) => n > 0 ? '+$n' : '−${-n}';

  void changeHealth(int change) {
    final commands = <ChangeHealthCommand>[];
    for (final t in liveActive) {
      final fig = figureOf(t);
      if (fig == null) continue;
      if (change > 0 && fig.health.value >= fig.maxHealth.value) continue;
      commands.add(ChangeHealthCommand(change, t.figureId, t.ownerId,
          gameState: _gameState));
    }
    if (commands.isEmpty) return;
    _gameState.action(
        GroupCommand(commands, '${_signed(change)} health (${commands.length})'));
  }

  void kill() {
    final commands = <ChangeHealthCommand>[];
    for (final t in liveActive) {
      final fig = figureOf(t);
      if (fig == null) continue;
      commands.add(ChangeHealthCommand(-fig.health.value, t.figureId, t.ownerId,
          gameState: _gameState));
    }
    if (commands.isEmpty) return;
    _gameState.action(GroupCommand(commands, 'Kill (${commands.length})'));
  }

  List<String> _immunities(AttackTarget t) =>
      StatusMenuViewModel(
              figureId: t.figureId,
              monsterId: t.ownerId,
              gameState: _gameState,
              settings: _settings)
          .immunities;

  /// Immune to curse: it can't have a curse card added to its deck (the rule
  /// book: immunity stops adding the card, not a card already in the deck).
  bool isImmuneToCurse(AttackTarget t) =>
      GameMethods.hasImmunity(_immunities(t), 'curse');

  /// Whether this standee cannot get [condition] (immune): the same check the
  /// single-standee menu's condition buttons use to disable themselves.
  bool isImmune(AttackTarget t, Condition condition) => !ConditionButtonViewModel(
          condition: condition,
          figureId: t.figureId,
          ownerId: t.ownerId,
          immunities: _immunities(t),
          gameState: _gameState,
          settings: _settings)
      .enabled;

  /// How many of the switched-on standees (that can get it) carry [condition].
  ({int count, int of}) tallyCounts(Condition condition) {
    final targets = liveActive.where((t) => !isImmune(t, condition)).toList();
    int have = 0;
    for (final t in targets) {
      if (figureOf(t)?.conditions.value.contains(condition) ?? false) have++;
    }
    return (count: have, of: targets.length);
  }

  ConditionTally tally(Condition condition) {
    final r = tallyCounts(condition);
    if (r.of == 0 || r.count == 0) return ConditionTally.none;
    return r.count == r.of ? ConditionTally.all : ConditionTally.some;
  }

  /// How many of the roster are dead.
  int get deadCount => roster.value.where(isDead).length;

  /// Chill on the switched-on standees, added up.
  int get chillTotal =>
      liveActive.fold(0, (sum, t) => sum + (figureOf(t)?.chill.value ?? 0));

  /// Gives the condition to those who lack it; takes it from everyone when
  /// they all have it already.
  void toggleCondition(Condition condition) {
    final targets = liveActive.where((t) => !isImmune(t, condition)).toList();
    if (targets.isEmpty) return;
    final allHave = tally(condition) == ConditionTally.all;
    final commands = <Command>[];
    for (final t in targets) {
      final has = figureOf(t)?.conditions.value.contains(condition) ?? false;
      if (allHave) {
        commands.add(RemoveConditionCommand(condition, t.figureId, t.ownerId,
            gameState: _gameState));
      } else if (!has) {
        commands.add(AddConditionCommand(condition, t.figureId, t.ownerId,
            gameState: _gameState));
      }
    }
    if (commands.isEmpty) return;
    _gameState.action(GroupCommand(commands,
        '${allHave ? '−' : '+'}${condition.getName()} (${commands.length})'));
  }

  /// Chill stacks: one more (or one less) on every switched-on standee.
  void changeChill(int change) {
    final commands = <Command>[];
    for (final t in liveActive) {
      final fig = figureOf(t);
      if (fig == null) continue;
      if (change > 0) {
        // Same limit as the single-standee menu.
        if (fig.chill.value >= _kMaxChill) continue;
        commands.add(AddConditionCommand(Condition.chill, t.figureId, t.ownerId,
            gameState: _gameState));
      } else if (fig.chill.value > 0) {
        commands.add(RemoveConditionCommand(
            Condition.chill, t.figureId, t.ownerId,
            gameState: _gameState));
      }
    }
    if (commands.isEmpty) return;
    _gameState.action(GroupCommand(
        commands, '${_signed(change)} chill (${commands.length})'));
  }

  // ── Bless and curse live in the monsters' shared modifier deck ───────────

  ModifierDeck? get monsterDeck {
    // Still shown when everyone is dead or switched off, so the controls
    // don't vanish and shift the screen.
    final live = liveActive;
    final targets = live.isNotEmpty ? live : roster.value;
    if (targets.isEmpty) return null;
    final monster = StatusMenuViewModel(
            figureId: targets.first.figureId,
            monsterId: targets.first.ownerId,
            gameState: _gameState,
            settings: _settings)
        .monster;
    return monster == null ? null : _deckOf(monster);
  }

  ModifierDeck _deckOf(Monster monster) {
    if (monster.isAlly &&
        (_gameState.allyDeckInOGGloom.value || !GameMethods.isOgGloomEdition())) {
      return _gameState.modifierDeckAllies;
    }
    return _gameState.modifierDeck;
  }

  /// The same thing the single-standee menu does for each standee: one bless
  /// (or curse) card into that standee's modifier deck, under the same limits
  /// ([GameMethods.blessCurseLeft], never below none). Run for every
  /// switched-on standee, as one action.
  void _changeDeckCards(String id, int change) {
    final commands = <Command>[];
    final pending = <ModifierDeck, int>{}; // cards added so far, per deck
    for (final t in liveActive) {
      final monster = StatusMenuViewModel(
              figureId: t.figureId,
              monsterId: t.ownerId,
              gameState: _gameState,
              settings: _settings)
          .monster;
      if (monster == null) continue;
      if (id == 'curse' && change > 0 && isImmuneToCurse(t)) continue;
      final deck = _deckOf(monster);
      final inDeck = deck.getRemovable(id).value + (pending[deck] ?? 0);
      if (change < 0 && inDeck <= 0) continue;
      if (change > 0 &&
          GameMethods.blessCurseLeft(id, deck,
                  pending: pending, gameState: _gameState) <=
              0) {
        continue;
      }
      pending[deck] = (pending[deck] ?? 0) + change;
      commands.add(id == 'bless'
          ? ChangeBlessCommand(change, t.figureId, t.ownerId,
              gameState: _gameState)
          : ChangeCurseCommand(change, t.figureId, t.ownerId,
              gameState: _gameState));
    }
    if (commands.isEmpty) return;
    _gameState.action(GroupCommand(
        commands, '${_signed(change * commands.length)} $id'));
  }

  void changeBless(int change) => _changeDeckCards('bless', change);

  void changeCurse(int change) => _changeDeckCards('curse', change);

  /// What Undo would reverse right now, or null when there is nothing.
  String? get undoLabel {
    final index = _gameState.commandIndex.value;
    final descriptions = _gameState.commandDescriptions;
    if (index < 0 || index >= descriptions.length) return null;
    return descriptions[index];
  }
}

/// The one controller for this device.
AttackModeController attackModeController() {
  if (!getIt.isRegistered<AttackModeController>()) {
    getIt.registerLazySingleton<AttackModeController>(
        () => AttackModeController());
  }
  return getIt<AttackModeController>();
}
