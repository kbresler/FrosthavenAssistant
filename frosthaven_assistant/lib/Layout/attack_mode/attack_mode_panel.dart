import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  static const double _kPortraitSize = 48.0;
  static const double _kRoundButton = 42.0;
  static const double _kMinCell = 62.0;
  static const double _kMaxRing = 74.0;
  static const double _kRingStroke = 5.0;
  static const double _kTwoUpWidth = 460.0;
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
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(pad, pad, pad, bottom),
                              child: _monsters(context, attack, gs, s),
                            ),
                          ),
                          Container(width: 1.5, color: kParchmentBorder),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, inner) => SingleChildScrollView(
                                padding:
                                    EdgeInsets.fromLTRB(pad, pad, pad, bottom),
                                child: _status(context, attack, gs, settings, s,
                                    inner.maxWidth - 2 * pad),
                              ),
                            ),
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

  String _monsterName(GameState gs, String ownerId) {
    for (final item in gs.currentList) {
      if (item is Monster && item.id == ownerId) {
        return getIt<TranslationService>().t(item.type.display);
      }
    }
    return ownerId;
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
                          image: AssetImage(
                              'assets/images/monsters/${entry.value.first.gfx}.png'))),
                ),
              ),
              SizedBox(width: 8 * s),
              Expanded(
                child: Text(_monsterName(gs, entry.key),
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
              children: [for (final t in entry.value) _chip(attack, t, s)],
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

  Widget _chip(AttackModeController attack, AttackTarget t, double s) {
    final on = attack.active.value.contains(t);
    final dead = attack.isDead(t);
    final fig = attack.figureOf(t);
    final elite = t.type == MonsterType.elite;
    final boss = t.type == MonsterType.boss;
    final fill = dead
        ? _kDeadFill
        : elite
            ? _kElite
            : boss
                ? Colors.red.shade200
                : _kChip;
    final border = dead
        ? kSwerskiAccent
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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(7 * s),
              border: Border.all(color: border, width: (dead ? 2.5 : 1.5) * s),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${t.standeeNr}',
                  style: TextStyle(
                      fontSize: 21 * s,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                      color: dead ? kSwerskiAccent : _kInk,
                      decoration:
                          dead ? TextDecoration.lineThrough : TextDecoration.none)),
              if (hp != null)
                Text(hp,
                    key: ValueKey('attack-health-${t.ownerId}-${t.standeeNr}'),
                    style: TextStyle(fontSize: 14 * s, height: 1.1, color: _kInk)),
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

    Widget label(String text) => Padding(
          padding: EdgeInsets.only(top: 10 * s, bottom: 2 * s),
          child: Text(text, style: TextStyle(fontSize: 17 * s, color: _kMuted)),
        );

    final counters = <Widget>[
      _counterRow(
        s: s,
        key: 'health',
        icon: 'assets/images/abilities/heal.png',
        tint: kSwerskiAccent,
        name: l10n.attackHealthEach,
        onMinus: () => attack.changeHealth(-1),
        onPlus: () => attack.changeHealth(1),
      ),
      if (showDeck) ...[
        _deckCounter(s, 'bless', 'assets/images/abilities/bless.png',
            l10n.attackBless, deck, attack, l10n),
        _deckCounter(s, 'curse', 'assets/images/abilities/curse.png',
            l10n.attackCurse, deck, attack, l10n),
      ],
      if (custom)
        _counterRow(
          s: s,
          key: 'chill',
          icon: 'assets/images/abilities/chill.png',
          name: l10n.attackChill,
          total: attack.chillTotal == 0
              ? l10n.attackNone
              : l10n.attackInTotal(attack.chillTotal),
          onMinus: () => attack.changeChill(-1),
          onPlus: () => attack.changeChill(1),
        ),
    ];
    // Wide enough: two counters side by side, so the conditions get the room.
    final twoUp = width >= _kTwoUpWidth * s;
    final gap = 18 * s;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (twoUp)
        Wrap(
            spacing: gap,
            children: [
              for (final c in counters)
                SizedBox(width: (width - gap) / 2, child: c)
            ])
      else
        ...counters,
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

  Widget _deckCounter(double s, String id, String icon, String name,
      ModifierDeck deck, AttackModeController attack, AppLocalizations l10n) {
    return ValueListenableBuilder<int>(
      valueListenable: deck.getRemovable(id),
      builder: (context, value, _) => _counterRow(
        s: s,
        key: id,
        icon: icon,
        name: name,
        total: value == 0 ? l10n.attackNone : l10n.attackInDeck(value),
        onMinus: () =>
            id == 'bless' ? attack.changeBless(-1) : attack.changeCurse(-1),
        onPlus: () =>
            id == 'bless' ? attack.changeBless(1) : attack.changeCurse(1),
      ),
    );
  }

  Widget _counterRow({
    required double s,
    required String key,
    required String icon,
    required String name,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    Color? tint,
    String? total,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3 * s),
      child: Row(children: [
        SizedBox(
          width: 30 * s,
          height: 30 * s,
          child: Image(
              fit: BoxFit.contain,
              color: tint,
              colorBlendMode: tint == null ? null : BlendMode.srcIn,
              image: AssetImage(icon)),
        ),
        SizedBox(width: 10 * s),
        // The total sits under the name, so a narrow column never overflows.
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 20 * s, height: 1.05, fontWeight: FontWeight.w600)),
            if (total != null)
              Text(total,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15 * s, height: 1, color: _kMuted)),
          ]),
        ),
        _round(s, '−', ValueKey('attack-$key-minus'), onMinus),
        SizedBox(width: 8 * s),
        _round(s, '+', ValueKey('attack-$key-plus'), onPlus),
      ]),
    );
  }

  Widget _round(double s, String text, Key key, VoidCallback onTap) {
    return SizedBox(
      width: _kRoundButton * s,
      height: _kRoundButton * s,
      child: Material(
        color: _kChip,
        shape: const CircleBorder(
            side: BorderSide(color: kParchmentBorder, width: 2)),
        child: InkWell(
          key: key,
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 26 * s, height: 1, color: _kInk))),
        ),
      ),
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
      inner: isMark ? vm.classColor : kParchment,
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
