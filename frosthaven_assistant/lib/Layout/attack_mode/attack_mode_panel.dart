import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../Resource/app_constants.dart';
import '../../Resource/enums.dart';
import '../../Resource/game_methods.dart';
import '../../Resource/settings.dart';
import '../../Resource/state/game_state.dart';
import '../../Resource/ui_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../services/service_locator.dart';
import '../../services/translation_service.dart';
import '../bottom_overlay.dart';
import '../theme.dart';
import '../view_models/condition_button_view_model.dart';
import 'attack_mode_controller.dart';

/// Swerski attack mode: replaces the board while several standees are being
/// attacked. The top bar, bottom bar and deck strip stay live around it.
///
/// Two columns that fill the whole area: the standees being attacked down the
/// left, everything that can be done to them (health, bless, curse, chill and
/// the conditions) on the right.
class AttackModePanel extends StatelessWidget {
  static const double _kHeaderHeight = 60.0;
  static const double _kPad = 10.0;
  static const double _kChipWidth = 46.0;
  static const double _kChipHeight = 50.0;
  static const double _kDeadSkull = 28.0;
  static const double _kPortraitSize = 48.0;
  static const double _kMinCell = 62.0;
  static const double _kMaxRing = 74.0;
  static const double _kRingStroke = 5.0;
  // On a narrow screen Undo may take this much of the width, so the title
  // always has room.
  static const double _kUndoShare = 0.32;
  static const double _kLeftShare = 0.38;
  static const double _kLeftMin = 150.0;
  static const double _kLeftMax = 340.0;
  static const double _kFadedAlpha = 0.45;
  static const double _kImmuneAlpha = 0.35;

  static const Color _kInk = Color(0xFF3B2A14);
  static const Color _kMuted = Color(0xFF5C4526);
  static const Color _kTrack = Color(0xFFD8C59A);
  static const Color _kChip = Color(0xFFFBF4E2);
  static const Color _kElite = Color(0xFFE2B33C);
  static const Color _kEliteBorder = Color(0xFF8C6A12);
  static const Color _kDeadFill = Color(0xFFEADFC4);
  // the strip the counters sit on: parchment a shade darker
  static const Color _kPlate = Color(0xFFEBDFC1);
  // inside a ring that is on for everyone: a faint wash of the wax red
  static const Color _kSealed = Color(0xFFF2D4C8);
  // a killed standee: red border and number
  static const Color _kDeadRed = Color(0xFFC62828);

  const AttackModePanel(
      {super.key, this.controller, this.gameState, this.settings});

  // injected for testing
  final AttackModeController? controller;
  final GameState? gameState;
  final Settings? settings;

  @override
  Widget build(BuildContext context) {
    final attack = controller ?? attackModeController();
    final gs = gameState ?? getIt<GameState>();
    final settings = this.settings ?? getIt<Settings>();
    final s = getModalMenuScale(context);

    return Material(
      color: kParchment,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: _kInk, fontFamily: 'Markazi'),
        child: ListenableBuilder(
          listenable: Listenable.merge([
            attack.roster,
            attack.active,
            gs.commandIndex,
            gs.updateList,
          ]),
          builder: (context, _) => Column(children: [
            _header(context, attack, s),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                final left =
                    (box.maxWidth * _kLeftShare).clamp(_kLeftMin * s, _kLeftMax * s);
                return ValueListenableBuilder<double>(
                  valueListenable: bottomOverlayHeight,
                  builder: (context, overlay, _) {
                    final pad = _kPad * s;
                    final bottom = overlay + pad;
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: left,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(pad, pad, pad, bottom),
                              child: _fit(
                                  left - 2 * pad,
                                  _monsters(context, attack, gs, s)),
                            ),
                          ),
                          Container(width: 1.5, color: kParchmentBorder),
                          Expanded(
                            child: LayoutBuilder(builder: (context, inner) {
                              final width = inner.maxWidth - 2 * pad;
                              return Padding(
                                padding:
                                    EdgeInsets.fromLTRB(pad, pad, pad, bottom),
                                child: _fit(
                                    width,
                                    _status(context, attack, gs, settings, s,
                                        width)),
                              );
                            }),
                          ),
                        ]);
                  },
                );
              }),
            ),
          ]),
        ),
      ),
    );
  }

  /// A column at its full size, shrunk (never enlarged) to fit the room it
  /// has, so however many standees there are, the whole screen shows with no
  /// scrolling.
  Widget _fit(double width, Widget content) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: content));

  // ── Header: count, Undo (names what it undoes), Done ──────────────────────

  Widget _header(
      BuildContext context, AttackModeController attack, double s) {
    final l10n = AppLocalizations.of(context)!;
    final undo = attack.undoLabel;
    final dead = attack.deadCount;
    return Container(
      height: _kHeaderHeight * s,
      padding: EdgeInsets.symmetric(horizontal: _kPad * s),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kSwerskiAccent, width: 2))),
      child: Row(children: [
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(
                l10n.attackHeader(
                    attack.liveActive.length, attack.roster.value.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Pirata',
                    fontSize: 26 * s,
                    height: 1.1,
                    color: _kInk),
              ),
            ),
            if (dead > 0) ...[
              SizedBox(width: 8 * s),
              Text(l10n.attackKilled(dead),
                  maxLines: 1,
                  style: TextStyle(fontSize: 17 * s, color: kSwerskiAccent)),
            ],
          ]),
        ),
        // Always there, so nothing moves when the first action is made. Not
        // a flexible child: it takes only what it needs, at the right edge.
        ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: math.min(
                    240 * s, MediaQuery.sizeOf(context).width * _kUndoShare)),
            child: OutlinedButton(
              onPressed: undo == null ? null : _undo,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kInk,
                backgroundColor: _kChip,
                side: const BorderSide(color: kParchmentBorder, width: 1.5),
                padding: EdgeInsets.symmetric(horizontal: 10 * s),
                minimumSize: Size(0, 46 * s),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.undo, size: 20 * s, color: kSwerskiAccent),
                SizedBox(width: 6 * s),
                Flexible(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.attackUndo,
                            style: TextStyle(
                                fontSize: 17 * s,
                                fontWeight: FontWeight.w700,
                                height: 1)),
                        if (undo != null)
                          Text(undo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13 * s, height: 1, color: _kMuted)),
                      ]),
                ),
              ]),
            ),
          ),
        SizedBox(width: 8 * s),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: kSwerskiAccent,
              minimumSize: Size(0, 46 * s),
              padding: EdgeInsets.symmetric(horizontal: 18 * s)),
          onPressed: attack.end,
          child: Text(l10n.attackDone,
              style: TextStyle(
                  fontSize: 19 * s,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ]),
    );
  }

  void _undo() => (gameState ?? getIt<GameState>()).undo();

  // ── Left: the standees being attacked ─────────────────────────────────────

  /// Display name of a roster group: a hero's name as the card shows it (an
  /// objective or escort keeps its own name) or the monster type. Also the
  /// label on a hero's chip (heroes have no standee number).
  String _groupName(GameState gs, AttackTarget t) {
    for (final item in gs.currentList) {
      if (item.id != t.ownerId) continue;
      if (item is Character) {
        return getIt<TranslationService>().t(item.characterState.display.value);
      }
      if (item is Monster) {
        return getIt<TranslationService>().t(item.type.display);
      }
    }
    return t.ownerId;
  }

  String _portraitPath(GameState gs, AttackTarget t) {
    if (t.hero) {
      for (final item in gs.currentList) {
        if (item is Character && item.id == t.ownerId) {
          return 'assets/images/class-icons/${item.characterClass.name}.png';
        }
      }
    }
    return 'assets/images/monsters/${t.gfx}.png';
  }

  Widget _monsters(BuildContext context, AttackModeController attack,
      GameState gs, double s) {
    final l10n = AppLocalizations.of(context)!;
    final groups = <String, List<AttackTarget>>{};
    for (final t in attack.roster.value) {
      groups.putIfAbsent(t.ownerId, () => []).add(t);
    }
    final live = attack.roster.value.where((t) => !attack.isDead(t)).toList();
    final allOn = live.isNotEmpty && live.every(attack.active.value.contains);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final entry in groups.entries)
        Padding(
          padding: EdgeInsets.only(bottom: 14 * s),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () => attack.toggleMonster(entry.key),
                child: SizedBox(
                  width: _kPortraitSize * s,
                  height: _kPortraitSize * s,
                  child: ClipOval(
                      child: Image(
                          fit: BoxFit.cover,
                          image:
                              AssetImage(_portraitPath(gs, entry.value.first)))),
                ),
              ),
              SizedBox(width: 8 * s),
              Expanded(
                child: Text(_groupName(gs, entry.value.first),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Pirata', fontSize: 19 * s, height: 1.05)),
              ),
            ]),
            SizedBox(height: 8 * s),
            Wrap(
              spacing: 7 * s,
              runSpacing: 9 * s,
              children: [for (final t in entry.value) _chip(attack, gs, t, s)],
            ),
          ]),
        ),
      Text(l10n.attackHoldHint,
          style: TextStyle(fontSize: 15 * s, color: _kMuted)),
      TextButton(
        style: TextButton.styleFrom(
            foregroundColor: kSwerskiAccent,
            padding: EdgeInsets.symmetric(horizontal: 4 * s),
            minimumSize: Size(0, 40 * s),
            alignment: Alignment.centerLeft),
        onPressed: allOn ? attack.selectNone : attack.selectAll,
        child: Text(allOn ? l10n.attackSelectNone : l10n.attackSelectAll,
            style: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  Widget _chip(
      AttackModeController attack, GameState gs, AttackTarget t, double s) {
    final on = attack.active.value.contains(t);
    final dead = attack.isDead(t);
    final fig = attack.figureOf(t);
    final label = t.hero ? _groupName(gs, t) : '${t.standeeNr}';
    final elite = !t.hero && t.type == MonsterType.elite;
    final boss = !t.hero && t.type == MonsterType.boss;
    final fill = dead
        ? _kDeadFill
        : elite
            ? _kElite
            : boss
                ? Colors.red.shade200
                : _kChip;
    final border = dead
        ? _kDeadRed
        : elite
            ? _kEliteBorder
            : kParchmentBorder;
    final hp = fig == null ? null : '${fig.health.value}/${fig.maxHealth.value}';
    return GestureDetector(
      onTap: () => attack.toggleActive(t),
      onLongPress: () => attack.only(t),
      child: Opacity(
        opacity: on || dead ? 1 : _kFadedAlpha,
        child: Stack(clipBehavior: Clip.none, children: [
          // IntrinsicWidth: only as wide as its text (with a minimum), not the
          // whole column.
          IntrinsicWidth(
              child: Container(
            constraints: BoxConstraints(
                minWidth: _kChipWidth * s, minHeight: _kChipHeight * s),
            padding: EdgeInsets.symmetric(horizontal: 6 * s),
            // (Killed: no centring, so the corner number is the chip's corner.)
            alignment: dead ? null : Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(7 * s),
              border: Border.all(color: border, width: (dead ? 2.5 : 1.5) * s),
            ),
            // Killed: the number in the top left corner and a skull and
            // crossbones (the solid black one) centred. Alive: the number over
            // the health.
            child: dead
                ? Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                        Image.asset('assets/images/psd/skull-new.png',
                            key: ValueKey(
                                'attack-dead-${t.ownerId}-${t.standeeNr}'),
                            height: _kDeadSkull * s),
                        // tucked right into the corner, out of the skull's way
                        Positioned(
                            top: -2 * s,
                            left: -4 * s,
                            child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 60 * s),
                                child: Text(label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: (t.hero ? 11 : 15) * s,
                                        fontWeight: FontWeight.w700,
                                        height: 1.1,
                                        color: _kDeadRed)))),
                      ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 110 * s),
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: t.hero ? 15 * s : 21 * s,
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                                color: _kInk))),
                    if (hp != null)
                      Text(hp,
                          key: ValueKey(
                              'attack-health-${t.ownerId}-${t.standeeNr}'),
                          style: TextStyle(
                              fontSize: 14 * s, height: 1.1, color: _kInk)),
                  ]),
          )),
          if (on && !dead)
            Positioned(
              top: -7 * s,
              right: -7 * s,
              child: Container(
                width: 18 * s,
                height: 18 * s,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kSwerskiAccent,
                    border: Border.all(color: kParchment, width: 1.5)),
                child: Icon(Icons.check, size: 11 * s, color: Colors.white),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Right: everything that can be done to them ────────────────────────────

  Widget _status(BuildContext context, AttackModeController attack,
      GameState gs, Settings settings, double s, double width) {
    final l10n = AppLocalizations.of(context)!;
    final deck = attack.monsterDeck;
    final showDeck = deck != null && settings.showAmdDeck.value;
    final custom = settings.showCustomContent.value;
    final marks = GameMethods.getCurrentCharacterAmount(gameState: gs);
    final harmful = <Condition>[
      Condition.stun,
      Condition.immobilize,
      Condition.disarm,
      Condition.wound,
      Condition.muddle,
      Condition.poison,
      Condition.bane,
      Condition.brittle,
      if (custom) Condition.rupture,
      // Hero-only conditions, shown when a hero is in the roster. Monsters
      // are "immune" to them (StatusActions.isImmune), so they skip them.
      if (attack.hasHero) Condition.impair,
      if (attack.hasHero && custom) Condition.infect,
    ];
    final helpful = <Condition>[
      Condition.strengthen,
      Condition.invisible,
      Condition.regenerate,
      Condition.ward,
      if (custom) Condition.dodge,
    ];
    final characters = <Condition>[
      if (marks > 0) Condition.character1,
      if (marks > 1) Condition.character2,
      if (marks > 2) Condition.character3,
      if (marks > 3) Condition.character4,
    ];
    final cols = (width / (_kMinCell * s)).floor().clamp(3, 9);
    final cell = width / cols;

    // A manuscript-style heading: the label, then a thin rule running out to
    // the edge. The rule shows where a group starts.
    Widget label(String text) => Padding(
          padding: EdgeInsets.only(top: 12 * s, bottom: 4 * s),
          child: Row(children: [
            Text(text, style: TextStyle(fontSize: 17 * s, color: _kMuted)),
            SizedBox(width: 8 * s),
            Expanded(
                child: Container(
                    height: 1.5,
                    color: kParchmentBorder.withValues(alpha: 0.45))),
          ]),
        );

    // The same compact − icon + steppers as the single-standee menu, so
    // several fit on a line and the screen stays short.
    final counters = <Widget>[
      _stepper(
        s: s,
        key: 'health',
        icon: 'assets/images/abilities/heal.png',
        tint: Colors.red,
        name: l10n.attackHealthEach,
        onMinus: () => attack.changeHealth(-1),
        onPlus: () => attack.changeHealth(1),
      ),
      if (showDeck) ...[
        _deckStepper(s, 'bless', 'assets/images/abilities/bless.png',
            l10n.attackBless, deck, attack),
        _deckStepper(s, 'curse', 'assets/images/abilities/curse.png',
            l10n.attackCurse, deck, attack),
      ],
      if (custom)
        _stepper(
          s: s,
          key: 'chill',
          icon: 'assets/images/abilities/chill.png',
          name: l10n.attackChill,
          // what the selected standees carry, added up (nothing when none)
          count: attack.chillTotal == 0 ? null : attack.chillTotal,
          onMinus: () => attack.changeChill(-1),
          onPlus: () => attack.changeChill(1),
        ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity, // lines up with the headings' rules
        padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
        decoration: BoxDecoration(
          color: _kPlate,
          borderRadius: BorderRadius.circular(8 * s),
          border: Border.all(
              color: kParchmentBorder.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Wrap(spacing: 16 * s, runSpacing: 2 * s, children: counters),
      ),
      label(l10n.attackHarmful),
      _grid(cell, [
        for (final c in harmful) _tile(attack, settings, c, s, cell, l10n),
        // Death is just the last harmful condition.
        _skullTile(attack, s, cell, l10n),
      ]),
      label(l10n.attackHelpful),
      _grid(cell,
          [for (final c in helpful) _tile(attack, settings, c, s, cell, l10n)]),
      if (characters.isNotEmpty) ...[
        label(l10n.attackMarks),
        _grid(cell, [
          for (final c in characters) _tile(attack, settings, c, s, cell, l10n)
        ]),
      ],
    ]);
  }

  Widget _deckStepper(double s, String id, String icon, String name,
      ModifierDeck deck, AttackModeController attack) {
    return ValueListenableBuilder<int>(
      valueListenable: deck.getRemovable(id),
      builder: (context, value, _) => _stepper(
        s: s,
        key: id,
        icon: icon,
        name: name,
        count: value, // cards of this kind in the monster deck
        onMinus: () =>
            id == 'bless' ? attack.changeBless(-1) : attack.changeCurse(-1),
        onPlus: () =>
            id == 'bless' ? attack.changeBless(1) : attack.changeCurse(1),
      ),
    );
  }

  /// − icon +, with a count on the icon: looks like the counters in the
  /// single-standee menu.
  Widget _stepper({
    required double s,
    required String key,
    required String icon,
    required String name,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    Color tint = Colors.white,
    int? count,
  }) {
    // Icons only on screen; the name is just for screen readers.
    return Semantics(
      label: name,
      container: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _stepButton(s, 'assets/images/psd/sub.png', ValueKey('attack-$key-minus'),
            onMinus),
        Stack(children: [
          SizedBox(
            width: kIconSize * s,
            height: kIconSize * s,
            child: Image(
                color: tint,
                colorBlendMode: BlendMode.modulate,
                fit: BoxFit.contain,
                image: AssetImage(icon)),
          ),
          if (count != null)
            Positioned(
                bottom: 0,
                right: 0,
                child: Text('$count',
                    style: getWhiteShadowStyle(
                        kFontSizeBody * s, textShadow(s),
                        height: 0.5))),
        ]),
        _stepButton(s, 'assets/images/psd/add.png', ValueKey('attack-$key-plus'),
            onPlus),
      ]),
    );
  }

  Widget _stepButton(double s, String image, Key key, VoidCallback onTap) {
    return SizedBox(
      width: kButtonSize * s,
      height: kButtonSize * s,
      child: IconButton(
          key: key,
          icon: Image.asset(image), onPressed: onTap),
    );
  }

  Widget _grid(double cell, List<Widget> tiles) => Wrap(children: [
        for (final t in tiles) SizedBox(width: cell, child: t),
      ]);

  Widget _tileFrame({
    required double s,
    required double cell,
    required double fraction,
    required String tally,
    required Widget icon,
    required Color inner,
    required VoidCallback? onTap,
    required Key key,
    double opacity = 1,
  }) {
    final ring = math.min(cell * 0.88, _kMaxRing * s);
    final disc = ring - 2 * _kRingStroke;
    return Opacity(
      opacity: opacity,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(ring / 2),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 3 * s),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: ring,
              height: ring,
              child: CustomPaint(
                painter: _RingPainter(
                    fraction: fraction,
                    track: _kTrack,
                    color: kSwerskiAccent,
                    stroke: _kRingStroke),
                child: Center(
                  child: Container(
                    width: disc,
                    height: disc,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: inner),
                    child: icon,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 17 * s,
              child: Text(tally,
                  maxLines: 1,
                  style: TextStyle(fontSize: 14 * s, height: 1.2, color: _kMuted)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tile(AttackModeController attack, Settings settings,
      Condition condition, double s, double cell, AppLocalizations l10n) {
    final vm = ConditionButtonViewModel(
        condition: condition,
        figureId: '',
        ownerId: null,
        immunities: const [],
        settings: settings);
    final r = attack.tallyCounts(condition);
    final live = attack.liveActive;
    final immuneToAll =
        live.isNotEmpty && live.every((t) => attack.isImmune(t, condition));
    final ring = math.min(cell * 0.88, _kMaxRing * s);
    final disc = ring - 2 * _kRingStroke;
    final isMark = vm.isCharacter;
    final Widget icon = Image.asset(vm.imagePath,
        width: disc * (isMark ? 0.62 : 0.7), height: disc * (isMark ? 0.62 : 0.7));
    return _tileFrame(
      s: s,
      cell: cell,
      key: ValueKey('attack-condition-${condition.name}'),
      fraction: r.of == 0 ? 0 : r.count / r.of,
      tally: r.count == 0
          ? ''
          : r.count == r.of
              ? l10n.attackAll
              : '${r.count}/${r.of}',
      icon: icon,
      inner: isMark
          ? vm.classColor
          : (r.of > 0 && r.count == r.of ? _kSealed : kParchment),
      opacity: immuneToAll ? _kImmuneAlpha : 1,
      onTap: immuneToAll ? null : () => attack.toggleCondition(condition),
    );
  }

  Widget _skullTile(
      AttackModeController attack, double s, double cell, AppLocalizations l10n) {
    final total = attack.roster.value.length;
    final dead = attack.deadCount;
    final ring = math.min(cell * 0.88, _kMaxRing * s);
    final disc = ring - 2 * _kRingStroke;
    return _tileFrame(
      s: s,
      cell: cell,
      key: const ValueKey('attack-kill'),
      fraction: total == 0 ? 0 : dead / total,
      tally: dead == 0
          ? ''
          : dead == total
              ? l10n.attackAll
              : '$dead/$total',
      icon: Image.asset('assets/images/psd/skull.png',
          width: disc * 0.7, height: disc * 0.7),
      inner: kParchment,
      onTap: attack.kill,
    );
  }
}

/// The ring round a condition tile: how many of the switched-on standees have
/// it, as a share of the circle.
class _RingPainter extends CustomPainter {
  _RingPainter(
      {required this.fraction,
      required this.track,
      required this.color,
      required this.stroke});

  final double fraction;
  final Color track;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, paint);
    if (fraction > 0) {
      paint.color = color;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2, 2 * math.pi * fraction.clamp(0.0, 1.0), false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.color != color;
}
