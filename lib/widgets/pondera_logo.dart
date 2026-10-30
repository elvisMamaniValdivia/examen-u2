import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Logo de Pondera (DESIGN.md seccion 1): cuadrado redondeado con tres barras
/// que suben y una linea punteada ambar en el umbral 10.5.
///
/// [sobreMarca] = true: cuadrado blanco con barras indigo (para fondos indigo).
/// [sobreMarca] = false: cuadrado indigo con barras blancas (para fondos claros).
/// [animado] hace subir las barras en cascada y luego dibuja la linea (< 900 ms).
class PonderaLogo extends StatefulWidget {
  final double size;
  final bool sobreMarca;
  final bool animado;

  const PonderaLogo({
    super.key,
    this.size = 64,
    this.sobreMarca = false,
    this.animado = false,
  });

  @override
  State<PonderaLogo> createState() => _PonderaLogoState();
}

class _PonderaLogoState extends State<PonderaLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (widget.animado && !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo de Pondera',
      image: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _PintorLogo(
            progreso: _controller.value,
            fondo: widget.sobreMarca ? Colors.white : AppTheme.indigoMarca,
            barras: widget.sobreMarca ? AppTheme.indigoMarca : Colors.white,
            linea: widget.sobreMarca ? AppTheme.ambarMarcaOscuro : AppTheme.ambarMarca,
          ),
        ),
      ),
    );
  }
}

class _PintorLogo extends CustomPainter {
  final double progreso;
  final Color fondo;
  final Color barras;
  final Color linea;

  _PintorLogo({
    required this.progreso,
    required this.fondo,
    required this.barras,
    required this.linea,
  });

  // Geometria en una cuadricula de 64 unidades.
  static const double _ancho = 9;
  static const double _base = 52;
  static const List<(double x, double tope)> _barras = [(12.7, 35.7), (27.0, 27.0), (41.3, 14.0)];
  static const double _lineaY = 31.3;
  static const double _lineaInicio = 7.5;
  static const double _lineaFin = 56.5;

  double _intervalo(double inicio, double fin) {
    final t = ((progreso - inicio) / (fin - inicio)).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 64;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(18 * u)),
      Paint()..color = fondo,
    );

    final pincelBarra = Paint()..color = barras;
    for (var i = 0; i < _barras.length; i++) {
      final (x, tope) = _barras[i];
      final p = _intervalo(i * 0.1, 0.45 + i * 0.1);
      if (p <= 0) continue;
      final y = _base - (_base - tope) * p;
      canvas.drawRRect(
        RRect.fromLTRBR(x * u, y * u, (x + _ancho) * u, _base * u, Radius.circular(_ancho / 2 * u)),
        pincelBarra,
      );
    }

    final pl = _intervalo(0.6, 1.0);
    if (pl <= 0) return;
    final pincelLinea = Paint()..color = linea;
    final limite = _lineaInicio + (_lineaFin - _lineaInicio) * pl;
    for (var x = _lineaInicio; x <= limite; x += 5) {
      canvas.drawCircle(Offset(x * u, _lineaY * u), 1.5 * u, pincelLinea);
    }
  }

  @override
  bool shouldRepaint(_PintorLogo old) =>
      old.progreso != progreso || old.fondo != fondo || old.barras != barras || old.linea != linea;
}
