import 'package:flutter/material.dart';
import '../services/calculos_multinivel.dart';
import '../theme/estado_nota_colors.dart';

/// Estado de una nota con icono + texto (DESIGN.md seccion 6).
/// Nunca comunica el estado solo con color.
///
/// Con [avance] (curso con notas pendientes) no se da por aprobado:
/// dice "Asegurado", "Vas aprobando", "En riesgo" o "Desaprobado".
class ChipEstado extends StatelessWidget {
  final double? nota;
  final double umbral;
  final AvanceCurso? avance;

  const ChipEstado({super.key, required this.nota, this.umbral = 10.5, this.avance});

  /// Texto del estado, también para lectores de pantalla.
  static String textoDe(double? nota, {AvanceCurso? avance, double umbral = 10.5}) => switch (avance) {
        AvanceCurso.asegurado => 'Asegurado',
        AvanceCurso.vasAprobando => 'Vas aprobando',
        AvanceCurso.enRiesgo => 'En riesgo',
        AvanceCurso.sinOpcion => 'Desaprobado',
        null => nota == null ? 'Sin notas' : (nota >= umbral ? 'Aprobado' : 'Desaprobado'),
      };

  @override
  Widget build(BuildContext context) {
    final estado = EstadoNotaColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final valor = nota;

    final IconData icono;
    final Color color;
    if (valor == null) {
      icono = Icons.hourglass_empty_rounded;
      color = scheme.onSurfaceVariant;
    } else {
      final aprobando = valor >= umbral;
      icono = switch (avance) {
        AvanceCurso.asegurado => Icons.verified_rounded,
        AvanceCurso.vasAprobando => Icons.trending_up_rounded,
        AvanceCurso.enRiesgo => Icons.warning_rounded,
        _ => aprobando ? Icons.check_circle_rounded : Icons.cancel_rounded,
      };
      color = aprobando ? estado.aprobado : estado.desaprobado;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          textoDe(valor, avance: avance, umbral: umbral),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}
