import 'package:flutter/material.dart';
import '../models/nota.dart';
import '../models/tipo_evaluacion.dart';
import '../theme/app_theme.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/formato_nota.dart';

/// Icono segun el nombre del tipo de evaluacion (DESIGN.md seccion 5).
IconData iconoTipoEvaluacion(String nombre) {
  final n = nombre.toLowerCase();
  if (n.contains('exam') || n.contains('parcial') || n.contains('final')) return Icons.quiz_rounded;
  if (n.contains('lab')) return Icons.science_rounded;
  if (n.contains('asist')) return Icons.how_to_reg_rounded;
  if (n.contains('proyect')) return Icons.rocket_launch_rounded;
  if (n.contains('expos')) return Icons.co_present_rounded;
  if (n.contains('práct') || n.contains('pract') || n.contains('tarea')) return Icons.assignment_rounded;
  return Icons.category_rounded;
}

/// Nombre a mostrar de una nota: su descripcion, o "Nota N" si no tiene.
String nombreDeNota(Nota nota, int indice) =>
    nota.nombre.trim().isEmpty ? 'Nota $indice' : nota.nombre.trim();

/// Tarjeta de un tipo de evaluacion (componente) con sus notas
/// (DESIGN.md seccion 6, pantalla 06).
///
/// Cada componente tiene una nota, como en el portal. Al tocarlo se edita
/// todo junto (nombre, peso y nota). Si quedaron varias notas de versiones
/// anteriores, la tarjeta se despliega para verlas y se usa su promedio.
class GrupoTipoEvaluacion extends StatelessWidget {
  final TipoEvaluacion tipo;
  final List<Nota> notas;
  final double? promedio;
  final bool expandido;
  final VoidCallback onToggle;
  final ValueChanged<Nota> onEditarNota;
  final ValueChanged<Nota> onEliminarNota;

  /// Edita el tipo completo: nombre, peso y su nota.
  final VoidCallback onEditarTipo;
  final VoidCallback onEliminarTipo;

  const GrupoTipoEvaluacion({
    super.key,
    required this.tipo,
    required this.notas,
    required this.promedio,
    required this.expandido,
    required this.onToggle,
    required this.onEditarNota,
    required this.onEliminarNota,
    required this.onEditarTipo,
    required this.onEliminarTipo,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    final duracion = Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200);
    final varias = notas.length > 1;
    final abierto = varias && expandido;
    final peso = '${FormatoNota.porcentaje(tipo.porcentaje)}%';

    final String detalle;
    final String pista;
    final VoidCallback alTocar;
    if (notas.isEmpty) {
      detalle = 'Sin nota · toca para ponerla';
      pista = 'Editar';
      alTocar = onEditarTipo;
    } else if (!varias) {
      detalle = notas.first.nombre.trim();
      pista = 'Editar';
      alTocar = onEditarTipo;
    } else {
      detalle = 'Promedio de ${notas.length} notas';
      pista = abierto ? 'Ocultar notas' : 'Ver notas';
      alTocar = onToggle;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  expanded: varias ? abierto : null,
                  label: '${tipo.nombre}, $peso por ciento, $detalle, '
                      'nota ${promedio == null ? 'sin registrar' : FormatoNota.nota(promedio)}',
                  hint: pista,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: alTocar,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(iconoTipoEvaluacion(tipo.nombre), color: scheme.onPrimaryContainer, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tipo.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  detalle.isEmpty ? peso : '$peso · $detalle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            FormatoNota.nota(promedio),
                            style: AppTheme.estiloNota(22, color: estado.colorDeNota(promedio, scheme.onSurfaceVariant)),
                          ),
                          if (varias)
                            AnimatedRotation(
                              turns: abierto ? 0.5 : 0,
                              duration: duracion,
                              child: SizedBox(
                                width: 32,
                                height: 40,
                                child: Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones de ${tipo.nombre}',
                icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
                onSelected: (opcion) {
                  if (opcion == 'editar') {
                    onEditarTipo();
                  } else {
                    onEliminarTipo();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'editar',
                    child: ListTile(
                      leading: Icon(Icons.edit_rounded),
                      title: Text('Editar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'eliminar',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Eliminar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          AnimatedSize(
            duration: duracion,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !abierto
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      for (var i = 0; i < notas.length; i++)
                        FilaNota(
                          key: ValueKey(notas[i].id),
                          nota: notas[i],
                          nombre: nombreDeNota(notas[i], i + 1),
                          onEditar: () => onEditarNota(notas[i]),
                          onEliminar: () => onEliminarNota(notas[i]),
                        ),
                      const SizedBox(height: 4),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Fila de una nota: nombre, valor coloreado y boton editar.
/// Se elimina deslizando a la izquierda (microinteraccion 3).
class FilaNota extends StatelessWidget {
  final Nota nota;
  final String nombre;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const FilaNota({
    super.key,
    required this.nota,
    required this.nombre,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);

    return Dismissible(
      key: ValueKey('dismiss-${nota.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onEliminar(),
      background: Container(
        color: estado.desaprobadoFondo,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w700, color: estado.onDesaprobadoFondo)),
            const SizedBox(width: 8),
            Icon(Icons.delete_rounded, color: estado.desaprobado),
          ],
        ),
      ),
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.only(left: 18, right: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
              ),
              Text(
                FormatoNota.nota(nota.valor),
                style: AppTheme.estiloNota(18, color: estado.colorDeNota(nota.valor, scheme.onSurface)),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                color: scheme.onSurfaceVariant,
                tooltip: 'Editar $nombre',
                onPressed: onEditar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
