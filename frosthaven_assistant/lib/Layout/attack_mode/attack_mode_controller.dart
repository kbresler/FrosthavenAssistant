import 'package:flutter/foundation.dart';

import '../../Resource/enums.dart';
import '../../Resource/game_methods.dart';
import '../../Resource/settings.dart';
import '../../Resource/state/game_state.dart';
import '../../Resource/status_actions.dart';
import '../../services/service_locator.dart';

enum AttackPhase { off, selecting, attacking }

/// How many of a condition the switched-on standees carry.
enum ConditionTally { none, some, all }

/// One figure that can be attacked: a monster standee or a hero. Remembers
/// what it looked like when it was picked, so a standee that dies (and leaves
/// the board) still has a chip.
class AttackTarget {
  const AttackTarget(
      {required this.ownerId,
      required this.figureId,
      required this.standeeNr,
      required this.type,
      required this.gfx,
      this.hero = false});

  factory AttackTarget.of(MonsterInstance instance, String ownerId) =>
      AttackTarget(
          ownerId: ownerId,
          figureId: instance.getId(),
          standeeNr: instance.standeeNr,
          type: instance.type,
          gfx: instance.gfx);

  /// A hero character. Standee number, type and gfx are placeholders: the
  /// panel shows the hero's name and class icon instead.
  factory AttackTarget.ofHero(String characterId) => AttackTarget(
      ownerId: characterId,
      figureId: characterId,
      standeeNr: 0,
      type: MonsterType.normal,
      gfx: '',
      hero: true);

  final String ownerId;
  final String figureId;
  final int standeeNr;
  final MonsterType type;
  final String gfx;

  /// Whether this target is a hero character rather than a standee.
  final bool hero;

  @override
  bool operator ==(Object other) =>
      other is AttackTarget &&
      other.ownerId == ownerId &&
      other.figureId == figureId;

  @override
  int get hashCode => Object.hash(ownerId, figureId);
}

/// Swerski attack mode: pick several standees and heroes, then change health
/// and conditions on all the switched-on ones at once.
///
/// Selection is local to this device. Every change is one ordinary action
/// built by [StatusActions], so Undo and network sync work as usual.
class AttackModeController {
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

  /// Starts picking. [first] with [ownerId] seeds it with one standee,
  /// [firstHero] (a character id) with one hero.
  void startSelecting(
      {MonsterInstance? first, String? ownerId, String? firstHero}) {
    _forgetResume();
    if (firstHero != null) {
      picked.value = [AttackTarget.ofHero(firstHero)];
    } else {
      picked.value = (first != null && ownerId != null)
          ? [AttackTarget.of(first, ownerId)]
          : [];
    }
    phase.value = AttackPhase.selecting;
  }

  void togglePick(MonsterInstance instance, String ownerId) {
    final target = AttackTarget.of(instance, ownerId);
    final list = List<AttackTarget>.of(picked.value);
    if (!list.remove(target)) list.add(target);
    picked.value = list;
  }

  /// Picks or unpicks a hero character.
  void togglePickCharacter(String characterId) {
    final target = AttackTarget.ofHero(characterId);
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

  FigureRef _ref(AttackTarget t) => (ownerId: t.ownerId, figureId: t.figureId);

  /// The switched-on standees still on the board, as plain figure refs.
  List<FigureRef> _refs() => liveActive.map(_ref).toList();

  void _run(Command? command) {
    if (command != null) _gameState.action(command);
  }

  void changeHealth(int change) => _run(
      StatusActions.buildHealthChange(_refs(), change, gameState: _gameState));

  void kill() => _run(StatusActions.buildKill(_refs(), gameState: _gameState));

  /// Immune to curse: it can't have a curse card added to its deck (the rule
  /// book: immunity stops adding the card, not a card already in the deck).
  bool isImmuneToCurse(AttackTarget t) => StatusActions.isImmuneToCurse(_ref(t),
      gameState: _gameState, settings: _settings);

  /// Whether this standee cannot get [condition] (immune): the same check the
  /// single-standee menu's condition buttons use to disable themselves.
  bool isImmune(AttackTarget t, Condition condition) => StatusActions.isImmune(
      _ref(t), condition,
      gameState: _gameState, settings: _settings);

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

  /// Whether the roster includes a hero.
  bool get hasHero => roster.value.any((t) => t.hero);

  /// Chill on the switched-on standees, added up.
  int get chillTotal =>
      liveActive.fold(0, (sum, t) => sum + (figureOf(t)?.chill.value ?? 0));

  /// Gives the condition to those who lack it; takes it from everyone when
  /// they all have it already.
  void toggleCondition(Condition condition) {
    final allHave = tally(condition) == ConditionTally.all;
    _run(allHave
        ? StatusActions.buildRemoveCondition(_refs(), condition,
            gameState: _gameState, settings: _settings)
        : StatusActions.buildAddCondition(_refs(), condition,
            gameState: _gameState, settings: _settings));
  }

  /// Chill stacks: one more (or one less) on every switched-on standee.
  void changeChill(int change) => _run(StatusActions.buildChillChange(_refs(),
      change,
      gameState: _gameState));

  // ── Bless and curse live in the monsters' shared modifier deck ───────────

  ModifierDeck? get monsterDeck {
    // Still shown when everyone is dead or switched off, so the controls
    // don't vanish and shift the screen.
    final live = liveActive;
    final targets = live.isNotEmpty ? live : roster.value;
    if (targets.isEmpty) return null;
    return StatusActions.deckOf(_ref(targets.first),
        gameState: _gameState, settings: _settings);
  }

  void changeBless(int change) => _run(StatusActions.buildBlessChange(_refs(),
      change,
      gameState: _gameState, settings: _settings));

  void changeCurse(int change) => _run(StatusActions.buildCurseChange(_refs(),
      change,
      gameState: _gameState, settings: _settings));

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
