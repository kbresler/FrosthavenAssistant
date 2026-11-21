import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Swerski: height of the deck area drawn over the bottom of the board
/// (character decks strip, monster/allies/loot decks, section list). The
/// board list uses it so its last row can always be scrolled clear.
final ValueNotifier<double> bottomOverlayHeight = ValueNotifier<double>(0);

/// Reports its child's laid-out height to [bottomOverlayHeight].
class ReportBottomOverlayHeight extends SingleChildRenderObjectWidget {
  const ReportBottomOverlayHeight({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportHeight();
}

class _RenderReportHeight extends RenderProxyBox {
  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (bottomOverlayHeight.value != height) {
      // Not during layout: listeners rebuild the board.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bottomOverlayHeight.value = height;
      });
    }
  }
}
