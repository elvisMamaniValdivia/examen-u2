import 'package:flutter/material.dart';
import '../theme/estado_nota_colors.dart';

/// Escala 0-20 con el relleno hasta la nota y una marca en el umbral 10.5
/// (DESIGN.md seccion 6). El relleno se desliza al cambiar la nota.
class EscalaNota extends StatelessWidget {
  final double? nota;
  final double umbral;
  final double max;

  const EscalaNota({super.key, required this.nota, this.umbral = 10.5, this.max = 20});

  @override
  Widget build(BuildContext context) {
    final estado = EstadoNotaColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final valor = nota;
    final aprobado = valor != null && valor >= umbral;

    final relleno = valor == null ? scheme.outline : (aprobado ? estado.aprobado : estado.desaprobado);
    final pista = valor == null
        ? scheme.surfaceContainerHigh
        : (aprobado ? estado.pistaAprobado : estado.pistaDesaprobado);
    final marca = valor == null
        ? scheme.onSurfaceVariant
        : (aprobado ? estado.onAprobadoFondo : estado.onDesaprobadoFondo);

    return ExcludeSemantics(
      child: SizedBox(
        height: 18,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ancho = constraints.maxWidth;
            return TweenAnimationBuilder<double>(
              tween: Tween(end: ((valor ?? 0) / max).clamp(0.0, 1.0)),
              duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 450),
              curve: Curves.easeOutCubic,
              builder: (context, fraccion, _) => Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(color: pista, borderRadius: BorderRadius.circular(4)),
                  ),
                  Container(
                    width: ancho * fraccion,
                    height: 8,
                    decoration: BoxDecoration(color: relleno, borderRadius: BorderRadius.circular(4)),
                  ),
                  Positioned(
                    left: ancho * umbral / max - 1,
                    child: Container(
                      width: 2,
                      height: 18,
                      decoration: BoxDecoration(color: marca, borderRadius: BorderRadius.circular(1)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
