import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Dibuja un borde punteado redondeado sobre su hijo.
/// Se usa para elementos vacios o de "agregar" (DESIGN.md seccion 4).
class BordePunteado extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radio;
  final double grosor;

  const BordePunteado({
    super.key,
    required this.child,
    required this.color,
    this.radio = 20,
    this.grosor = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _PintorBordePunteado(color: color, radio: radio, grosor: grosor),
      child: child,
    );
  }
}

class _PintorBordePunteado extends CustomPainter {
  final Color color;
  final double radio;
  final double grosor;

  static const double _guion = 6;
  static const double _espacio = 4;

  _PintorBordePunteado({required this.color, required this.radio, required this.grosor});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(grosor / 2),
      Radius.circular(radio),
    );
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;

    for (final metrica in (Path()..addRRect(rrect)).computeMetrics()) {
      double distancia = 0;
      while (distancia < metrica.length) {
        final fin = math.min(distancia + _guion, metrica.length);
        canvas.drawPath(metrica.extractPath(distancia, fin), pincel);
        distancia += _guion + _espacio;
      }
    }
  }

  @override
  bool shouldRepaint(_PintorBordePunteado old) =>
      old.color != color || old.radio != radio || old.grosor != grosor;
}
