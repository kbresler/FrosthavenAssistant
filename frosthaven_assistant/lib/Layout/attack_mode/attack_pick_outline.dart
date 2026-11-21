import 'package:flutter/material.dart';

import '../theme.dart';
import 'attack_mode_controller.dart';

/// Swerski attack mode: draws a dark-red outline round a standee while it is
/// picked. Adds no size, so nothing on the board moves.
class AttackPickOutline extends StatelessWidget {
  static const double _kRadius = 6.0;
  static const double _kWidth = 2.5;

  const AttackPickOutline(
      {super.key,
      required this.ownerId,
      required this.figureId,
      required this.child,
      this.controller});

  final String ownerId;
  final String figureId;
  final Widget child;

  // injected for testing
  final AttackModeController? controller;

  @override
  Widget build(BuildContext context) {
    final attack = controller ?? attackModeController();
    return ListenableBuilder(
      listenable: attack.picked,
      builder: (context, child) {
        if (!attack.isSelecting || !attack.isPicked(ownerId, figureId)) {
          return child!;
        }
        return Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: kSwerskiAccent, width: _kWidth),
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}
