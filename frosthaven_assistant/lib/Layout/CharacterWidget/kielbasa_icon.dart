import 'package:flutter/material.dart';

/// A small sausage icon for the character card's stat column, sized like the
/// XP star and level crown. The heart-attack count is drawn next to it by the
/// card (same font as the XP and level numbers), not inside the icon.
///
/// [recovering] draws the pale grey version used for a long rest.
///
/// Fixed size ([height] x [height] * [aspect]), paints only inside it, so it
/// never changes the layout around it.
class KielbasaIcon extends StatelessWidget {
  const KielbasaIcon({
    super.key,
    this.height = 20,
    this.recovering = false,
    this.semanticLabel,
  });

  final double height;
  final bool recovering;
  final String? semanticLabel;

  static const double aspect = 1.7;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: CustomPaint(
        size: Size(height * aspect, height),
        painter: _KielbasaIconPainter(recovering: recovering),
      ),
    );
  }
}

class _KielbasaIconPainter extends CustomPainter {
  _KielbasaIconPainter({required this.recovering});

  final bool recovering;

  static const _body = Color(0xFFD85A30);
  static const _outline = Color(0xFF993C1D);
  static const _highlight = Color(0xFFF0997B);
  static const _bodyPale = Color(0xFFC9C5BC);
  static const _outlinePale = Color(0xFF8A867D);
  static const _highlightPale = Color(0xFFE6E3DC);

  // cos and sin of 0.5 radians: the lean of the grill marks.
  static const double _cosLean = 0.8775825618903728;
  static const double _sinLean = 0.479425538604203;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyColor = recovering ? _bodyPale : _body;
    final outlineColor = recovering ? _outlinePale : _outline;
    final highlightColor = recovering ? _highlightPale : _highlight;

    final bodyW = h * 0.56;
    final path = Path()
      ..moveTo(w * 0.22, h * 0.58)
      ..quadraticBezierTo(w * 0.50, h * 0.40, w * 0.78, h * 0.58);
    final metric = path.computeMetrics().first;
    final len = metric.length;

    Paint stroke(Color c, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = c
      ..isAntiAlias = true;

    canvas.drawPath(path, stroke(outlineColor, bodyW + h * 0.12));
    canvas.drawPath(path, stroke(bodyColor, bodyW));

    final hl = metric
        .extractPath(len * 0.2, len * 0.8)
        .shift(Offset(0, -bodyW * 0.22));
    canvas.drawPath(
        hl, stroke(highlightColor.withValues(alpha: 0.9), bodyW * 0.16));

    final grill = stroke(outlineColor.withValues(alpha: 0.65), h * 0.07);
    for (final f in [0.38, 0.62]) {
      final t = metric.getTangentForOffset(len * f)!;
      final v = t.vector;
      final n = Offset(-v.dy, v.dx);
      final d = n * _cosLean + v * _sinLean;
      canvas.drawLine(
        t.position - d * (bodyW * 0.28),
        t.position + d * (bodyW * 0.28),
        grill,
      );
    }
  }

  @override
  bool shouldRepaint(_KielbasaIconPainter old) => old.recovering != recovering;
}
