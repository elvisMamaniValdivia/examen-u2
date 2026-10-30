import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/formato_nota.dart';
import 'chip_estado.dart';

/// Tarjeta de un ciclo en la lista "Tus ciclos" (DESIGN.md seccion 6, pantalla 03).
class TarjetaCiclo extends StatelessWidget {
  final int numero;
  final String nombre;
  final String subtitulo;
  final double? promedio;

  /// Resalta el bloque del numero (el ciclo mas reciente).
  final bool destacado;
  final bool cargando;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const TarjetaCiclo({
    super.key,
    required this.numero,
    required this.nombre,
    required this.subtitulo,
    required this.promedio,
    required this.onTap,
    this.destacado = false,
    this.cargando = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);

    return Semantics(
      button: true,
      label: '$nombre, $subtitulo, '
          '${promedio == null ? 'sin notas' : 'promedio ${FormatoNota.nota(promedio)}'}',
      excludeSemantics: true,
      child: Card(
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: destacado ? scheme.primary : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$numero',
                    style: AppTheme.estiloNota(
                      26,
                      color: destacado ? scheme.onPrimary : scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitulo,
                        style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (cargando)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: scheme.outline),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        FormatoNota.nota(promedio),
                        style: AppTheme.estiloNota(
                          28,
                          color: estado.colorDeNota(promedio, scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ChipEstado(nota: promedio),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
