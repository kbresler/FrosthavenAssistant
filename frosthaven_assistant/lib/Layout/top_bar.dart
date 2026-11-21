import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Resource/app_constants.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';

import '../Resource/enums.dart';
import '../l10n/app_localizations.dart';
import 'attack_mode/attack_mode_controller.dart';
import 'theme.dart';
import '../Resource/ui_utils.dart';
import '../services/service_locator.dart';
import 'element_button.dart';

class TopBar extends StatelessWidget {
  static const double _kMenuIconSize = 24.0;
  static const double _kTitlePaddingLeft = 6.0;
  // Dead space between the hamburger's touch area and the sword.
  static const double _kMenuGap = 8.0;
  static const double _kFlexibleHeight = 42.0;
  static const double _kSwordSize = 32.0;
  static const double _kSwordPadding = 0.15;
  static const double _kSelectingTitleMinWidth = 90.0;

  const TopBar({super.key, this.settings});

  final Settings? settings;

  /// Swerski: the sword button. Tap to start picking standees; while picking,
  /// tap again to attack with them (or to cancel when none are picked).
  ///
  /// It sits in the title area (which already gives way on narrow screens),
  /// not among the element buttons, so nothing there is pushed off the bar.
  Widget _swordButton(BuildContext context, AttackModeController attack,
      double userScaling, TextStyle style) {
    final l10n = AppLocalizations.of(context);
    final lit = attack.phase.value != AttackPhase.off;
    final size = _kSwordSize * userScaling;
    final count = attack.picked.value.length;
    return Tooltip(
      message: l10n?.attackSeveralTooltip ?? 'Attack several monsters',
      child: GestureDetector(
        onTap: () {
          switch (attack.phase.value) {
            case AttackPhase.off:
              attack.startSelecting();
            case AttackPhase.selecting:
              attack.picked.value.isEmpty ? attack.end() : attack.startAttack();
            case AttackPhase.attacking:
              attack.end();
          }
        },
        // Cancels picking even where the title has no room for a close button.
        onLongPress: attack.end,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            key: const ValueKey('attack-sword'),
            width: size,
            height: size,
            padding: EdgeInsets.all(size * _kSwordPadding),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Dark disc when idle, so the white sword shows on the
                // light bar too.
                color: lit ? kSwerskiAccent : Colors.black54,
                border: Border.all(color: Colors.white70)),
            child: Image.asset('assets/images/abilities/attack.png'),
          ),
          if (attack.isSelecting && count > 0)
            Positioned(
                right: -2 * userScaling,
                bottom: -2 * userScaling,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4 * userScaling),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8 * userScaling)),
                  child: Text('$count',
                      style: TextStyle(
                          color: kSwerskiAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: kFontSizeSmall * userScaling * 0.8)),
                )),
        ]),
      ),
    );
  }

  /// "3 selected" and a close button, but only where the title has room.
  Widget _selectingTitle(BuildContext context, AttackModeController attack,
      double userScaling, TextStyle style) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < _kSelectingTitleMinWidth * userScaling) {
        return const SizedBox.shrink();
      }
      final closeSize = _kMenuIconSize * userScaling;
      return Row(children: [
        Flexible(
          child: Text(
            l10n?.attackSelectedCount(attack.picked.value.length) ??
                '${attack.picked.value.length}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        IconButton(
          tooltip: l10n?.attackCancel ?? 'Cancel',
          onPressed: attack.end,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(
              width: closeSize * 1.5, height: closeSize * 1.5),
          icon: Icon(Icons.close, color: Colors.white, size: closeSize),
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = this.settings ?? getIt<Settings>();
    final attack = attackModeController();
    return ValueListenableBuilder<double>(
        valueListenable: settings.userScalingBars,
        builder: (context, value, child) {
          final userScaling = settings.userScalingBars.value;
          final shadow = textShadow(userScaling);
          return AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            leading: _MenuButton(
                iconSize: _kMenuIconSize * userScaling,
                shadow: shadow,
                gap: _kMenuGap * userScaling),
            title: Container(
              padding: EdgeInsets.only(left: _kTitlePaddingLeft * userScaling),
              child: ListenableBuilder(
                listenable: Listenable.merge(
                    [settings.attackSeveral, attack.phase, attack.picked]),
                builder: (context, _) {
                  final style =
                      getWhiteShadowStyle(kFontSizeBody * userScaling, shadow);
                  final on = settings.attackSeveral.value;
                  // Swerski: while picking standees the title becomes the
                  // count (and a way out), so nothing on the bar moves.
                  final Widget text = on && attack.isSelecting
                      ? _selectingTitle(context, attack, userScaling, style)
                      : Text("X-haven Assistant\n(Swerski Edition)",
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: style);
                  return Row(children: [
                    if (on) ...[
                      _swordButton(context, attack, userScaling, style),
                      SizedBox(width: 6 * userScaling),
                    ],
                    Flexible(child: text),
                  ]);
                },
              ),
            ),
            toolbarHeight: kBarHeight * settings.userScalingBars.value,
            flexibleSpace: ValueListenableBuilder<bool>(
                valueListenable: settings.darkMode,
                builder: (context, value, child) {
                  final darkMode = settings.darkMode.value;
                  return Container(
                    height: _kFlexibleHeight * userScaling,
                    decoration: BoxDecoration(
                      color: darkMode ? Colors.black : Colors.transparent,
                      image: DecorationImage(
                        opacity: darkMode ? kDarkModeOpacity : 1,
                        fit: BoxFit.cover,
                        repeat: ImageRepeat.repeatX,
                        image: ResizeImage(
                            AssetImage(darkMode
                                ? 'assets/images/psd/gloomhaven-bar.png'
                                : 'assets/images/psd/frosthaven-bar.png'),
                            height: quantizeDecodeSize(
                                kBarHeight * settings.userScalingBars.value,
                                quantum: kBarDecodeSizeQuantum)),
                      ),
                    ),
                  );
                }),
            actions: [
              ElementButton(
                  key: UniqueKey(),
                  color: const Color.fromARGB(255, 226, 66, 30),
                  element: Elements.fire,
                  icon: 'assets/images/psd/element-fire.png'),
              ElementButton(
                  key: UniqueKey(),
                  color: const Color.fromARGB(255, 85, 200, 239),
                  element: Elements.ice,
                  icon: 'assets/images/psd/element-ice.png'),
              ElementButton(
                  key: UniqueKey(),
                  color: const Color.fromARGB(255, 152, 176, 181),
                  element: Elements.air,
                  icon: 'assets/images/psd/element-air.png'),
              ElementButton(
                  key: UniqueKey(),
                  color: const Color.fromARGB(255, 124, 168, 42),
                  element: Elements.earth,
                  icon: 'assets/images/psd/element-earth.png'),
              ElementButton(
                  key: UniqueKey(),
                  color: const Color.fromARGB(255, 236, 166, 15),
                  element: Elements.light,
                  icon: 'assets/images/psd/element-light.png'),
              ElementButton(
                  key: UniqueKey(),
                  color: const Color.fromARGB(255, 31, 50, 131),
                  element: Elements.dark,
                  icon: 'assets/images/psd/element-dark.png'),
            ],
          );
        });
  }
}

/// The hamburger. Opens the main menu only on a real tap on the icon itself:
/// the press and the release must both land here, close together. A stray
/// release (one whose press happened elsewhere, such as on an element button)
/// does nothing.
class _MenuButton extends StatefulWidget {
  const _MenuButton(
      {required this.iconSize, required this.shadow, required this.gap});

  final double iconSize;
  final Shadow shadow;

  /// Dead space on the right of the touch area.
  final double gap;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  int? _pointer;
  Offset? _downAt;

  @override
  Widget build(BuildContext context) {
    // Fills the bar's left slot (the strip before the sword): a roomy target
    // for fingers, with a dead gap on its right so a press that misses the
    // sword never opens the menu.
    return Padding(
        padding: EdgeInsets.only(right: widget.gap),
        child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          _pointer = event.pointer;
          _downAt = event.localPosition;
        },
        onPointerCancel: (event) {
          if (event.pointer == _pointer) _pointer = null;
        },
        onPointerUp: (event) {
          final downAt = _downAt;
          final pressedHere = event.pointer == _pointer && downAt != null;
          _pointer = null;
          if (!pressedHere) return;
          if ((event.localPosition - downAt).distance > kTouchSlop) return;
          // Filter out phantom events at (0,0) caused by Flutter/iPadOS bug
          if (event.localPosition.dx > 1 || event.localPosition.dy > 1) {
            // One tick later: the screen-edge swipe zone (left 20 px) cancels
            // its own gesture right after the release and would close a menu
            // opened this instant.
            final scaffold = Scaffold.of(context);
            Future<void>(() {
              if (mounted) scaffold.openDrawer();
            });
          }
        },
        child: Center(
          child: Icon(Icons.menu,
              shadows: [widget.shadow], size: widget.iconSize),
        )));
  }
}
