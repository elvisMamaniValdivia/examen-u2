import 'package:flutter/material.dart';

import '../services/calculos_prioridades.dart';
import '../theme/app_theme.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/formato_nota.dart';

/// Piezas visuales de H23 (Prioridades). No calculan: reciben los datos de
/// [CalculosPrioridades].

/// Chip "Alta / Media / Baja prioridad" con icono + texto (nunca solo color).
class ChipPrioridad extends StatelessWidget {
  final NivelPrioridad nivel;

  const ChipPrioridad({super.key, required this.nivel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    final (IconData icono, String texto, Color fondo, Color color) = switch (nivel) {
      NivelPrioridad.alta => (Icons.keyboard_double_arrow_up_rounded, 'Alta prioridad', scheme.primaryContainer, scheme.onPrimaryContainer),
      NivelPrioridad.media => (Icons.keyboard_arrow_up_rounded, 'Media', estado.avisoFondo, estado.onAvisoFondo),
      NivelPrioridad.baja => (Icons.remove_rounded, 'Baja', scheme.surfaceContainerHigh, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 3),
          Text(texto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Fila de un componente: su peso real, barra proporcional, prioridad e impacto.
///
/// Con [enCiclo] muestra el peso en el promedio del ciclo en vez del curso.
class FilaComponentePrioridad extends StatelessWidget {
  final ComponentePrioridad componente;

  /// Peso más alto de la lista, para que la barra sea proporcional.
  final double pesoMaximo;
  final bool enCiclo;
  final VoidCallback? onTap;

  const FilaComponentePrioridad({
    super.key,
    required this.componente,
    required this.pesoMaximo,
    this.enCiclo = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    final c = componente;
    final peso = enCiclo ? (c.pesoCiclo ?? 0) : c.pesoCurso;
    final ambito = enCiclo ? 'del ciclo' : 'del curso';
    final subtitulo = switch ((enCiclo, c.sinTipos)) {
      (true, true) => '${c.curso?.nombre ?? ''} · aún sin tipos de evaluación',
      (true, false) => '${c.curso?.nombre ?? ''} · ${c.unidadNombre}',
      (false, true) => 'Aún sin tipos de evaluación · toca para agregarlos',
      (false, false) => '${c.unidadNombre} · ${FormatoNota.porcentaje(c.pesoTipo)}% de la unidad',
    };
    final aprobado = (c.promedio ?? 0) >= 10.5;

    final String detalle;
    if (c.pendiente) {
      final puntos = enCiclo ? c.puntosEnCiclo ?? 0 : c.puntosEnCurso;
      detalle = 'Cada punto que saques aquí suma ${FormatoNota.puntos(puntos)} '
          '${enCiclo ? 'a tu promedio del ciclo' : 'a tu nota del curso'}.';
    } else {
      final notas = c.cantidadNotas == 1 ? '1 nota' : '${c.cantidadNotas} notas';
      detalle = 'Evaluado · promedio ${FormatoNota.nota(c.promedio)} ($notas)';
    }

    return Semantics(
      button: onTap != null,
      label: '${c.tipoNombre}, $subtitulo. Vale ${FormatoNota.porcentaje(peso)} por ciento $ambito. $detalle',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.tipoNombre,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitulo,
                            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${FormatoNota.porcentaje(peso)}%',
                          style: AppTheme.estiloNota(22, color: c.pendiente ? scheme.primary : scheme.onSurfaceVariant),
                        ),
                        Text(ambito, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pesoMaximo <= 0 ? 0 : (peso / pesoMaximo).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHigh,
                    color: c.pendiente ? scheme.primary : scheme.outline,
                  ),
                ),
                const SizedBox(height: 10),
                if (c.pendiente)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChipPrioridad(nivel: c.nivel),
                      Text(detalle, style: TextStyle(fontSize: 13, height: 1.3, color: scheme.onSurfaceVariant)),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(
                        aprobado ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 16,
                        color: aprobado ? estado.aprobado : estado.desaprobado,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(detalle, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                      ),
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

/// Unidad con su peso en el curso: parte evaluada (llena) y pendiente (vacía).
class BarraUnidadPrioridad extends StatelessWidget {
  final ResumenUnidadPrioridad unidad;

  const BarraUnidadPrioridad({super.key, required this.unidad});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = unidad;
    final evaluado = u.peso <= 0 ? 0.0 : (u.pesoEvaluado / u.peso).clamp(0.0, 1.0);
    final falta = u.pesoPendiente <= 0.05
        ? 'Completa'
        : 'Falta evaluar ${FormatoNota.porcentaje(u.pesoPendiente)}% del curso';

    return Semantics(
      label: '${u.nombre}, vale ${FormatoNota.porcentaje(u.peso)} por ciento del curso. $falta',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    u.nombre,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${FormatoNota.porcentaje(u.peso)}% del curso',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: evaluado,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHigh,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(falta, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Acceso a Prioridades desde el curso o el ciclo, mostrando la prioridad número 1.
class TarjetaPrioridad extends StatelessWidget {
  final ComponentePrioridad principal;
  final bool enCiclo;
  final VoidCallback onTap;

  const TarjetaPrioridad({super.key, required this.principal, required this.onTap, this.enCiclo = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = principal;
    final nombre = c.sinTipos ? c.unidadNombre : '${c.tipoNombre} de ${c.unidadNombre}';
    final texto = enCiclo
        ? '${c.sinTipos ? c.unidadNombre : c.tipoNombre} de ${c.curso?.nombre ?? c.unidadNombre} '
            'es lo que más mueve tu ciclo (${FormatoNota.porcentaje(c.pesoCiclo ?? 0)}%).'
        : '$nombre vale ${FormatoNota.porcentaje(c.pesoCurso)}% del curso y aún no tiene notas.';

    return Semantics(
      button: true,
      label: 'Tu prioridad ahora. $texto Ver prioridades',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.flag_rounded, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu prioridad ahora',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(texto, style: const TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
