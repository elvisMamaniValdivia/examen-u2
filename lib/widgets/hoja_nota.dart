import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/nota.dart';
import '../models/tipo_evaluacion.dart';
import '../services/calculos_evaluaciones.dart';
import '../theme/app_theme.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/formato_nota.dart';
import 'grupo_tipo_evaluacion.dart';

/// Lo que devuelve la hoja al guardar. Con [borrar] se pidio borrar la nota editada.
typedef DatosNota = ({String tipoId, String nombre, double valor, bool borrar});

/// Abre la hoja inferior para agregar o editar una nota (DESIGN.md pantalla 06b).
/// Al agregar solo se ofrecen los tipos sin nota (una nota por tipo).
/// Al editar, el tipo de evaluacion no se puede cambiar.
Future<DatosNota?> mostrarHojaNota(
  BuildContext context, {
  required List<TipoEvaluacion> tipos,
  required Map<String, List<Nota>> notasPorTipo,
  required String tipoInicialId,
  required String subtitulo,
  Nota? nota,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<DatosNota>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: scheme.surfaceContainerLowest,
    barrierColor: const Color(0x7A111018),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _HojaNota(
      tipos: tipos,
      notasPorTipo: notasPorTipo,
      tipoInicialId: tipoInicialId,
      subtitulo: subtitulo,
      nota: nota,
    ),
  );
}

class _HojaNota extends StatefulWidget {
  final List<TipoEvaluacion> tipos;
  final Map<String, List<Nota>> notasPorTipo;
  final String tipoInicialId;
  final String subtitulo;
  final Nota? nota;

  const _HojaNota({
    required this.tipos,
    required this.notasPorTipo,
    required this.tipoInicialId,
    required this.subtitulo,
    this.nota,
  });

  @override
  State<_HojaNota> createState() => _HojaNotaState();
}

class _HojaNotaState extends State<_HojaNota> {
  late String _tipoId = widget.tipoInicialId;
  late final _nombreCtrl = TextEditingController(text: widget.nota?.nombre ?? '');
  late final _valorCtrl = TextEditingController(
    text: widget.nota == null ? '' : _formatear(widget.nota!.valor),
  );
  bool _intentoGuardar = false;

  bool get _editando => widget.nota != null;

  /// Tipos que se muestran: al agregar, solo los que aun no tienen nota.
  late final List<TipoEvaluacion> _tiposVisibles = _editando
      ? widget.tipos
      : [
          for (final t in widget.tipos)
            if ((widget.notasPorTipo[t.id] ?? const []).isEmpty || t.id == widget.tipoInicialId) t,
        ];

  static String _formatear(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  double? get _valor => double.tryParse(_valorCtrl.text.trim().replaceAll(',', '.'));

  String? get _error {
    final v = _valor;
    if (_valorCtrl.text.trim().isEmpty) return _intentoGuardar ? 'Escribe la nota' : null;
    if (v == null || v < 0 || v > 20) return 'La nota debe estar entre 0 y 20';
    return null;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  /// Nota de la unidad antes y despues de guardar, para la vista previa.
  (double?, double?) _vistaPrevia() {
    final antes = CalculosEvaluaciones.calcularPromedioParcialUnidad(widget.tipos, widget.notasPorTipo);
    final v = _valor;
    if (v == null || v < 0 || v > 20) return (antes, null);

    final simulado = {
      for (final e in widget.notasPorTipo.entries) e.key: List<Nota>.of(e.value),
    };
    final lista = simulado.putIfAbsent(_tipoId, () => []);
    final nueva = Nota(id: widget.nota?.id ?? '_nueva', valor: v, tipoEvaluacionId: _tipoId);
    final i = lista.indexWhere((n) => n.id == widget.nota?.id);
    if (_editando && i != -1) {
      lista[i] = nueva;
    } else {
      lista.add(nueva);
    }
    return (antes, CalculosEvaluaciones.calcularPromedioParcialUnidad(widget.tipos, simulado));
  }

  void _guardar() {
    setState(() => _intentoGuardar = true);
    if (_error != null || _valor == null) {
      HapticFeedback.mediumImpact();
      return;
    }
    Navigator.of(context).pop<DatosNota>(
      (tipoId: _tipoId, nombre: _nombreCtrl.text.trim(), valor: _valor!, borrar: false),
    );
  }

  void _borrar() {
    final nota = widget.nota!;
    Navigator.of(context).pop<DatosNota>((tipoId: _tipoId, nombre: nota.nombre, valor: nota.valor, borrar: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final estado = EstadoNotaColors.of(context);
    final error = _error;
    final (antes, despues) = _vistaPrevia();
    final colorValor = error != null ? scheme.error : estado.colorDeNota(_valor, scheme.onSurface);

    OutlineInputBorder borde(Color c, double w) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_editando ? 'Editar nota' : 'Agregar nota', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text(widget.subtitulo, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Tipo de evaluación', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _tiposVisibles)
                  ChoiceChip(
                    selected: t.id == _tipoId,
                    onSelected: _editando ? null : (_) => setState(() => _tipoId = t.id),
                    avatar: Icon(iconoTipoEvaluacion(t.nombre), size: 18),
                    label: Text('${t.nombre} · ${FormatoNota.porcentaje(t.porcentaje)}%'),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: t.id == _tipoId ? scheme.onPrimaryContainer : scheme.onSurface,
                    ),
                    selectedColor: scheme.primaryContainer,
                    backgroundColor: scheme.surfaceContainerLowest,
                    side: BorderSide(color: t.id == _tipoId ? scheme.primary : scheme.outline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nombre (opcional)', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nombreCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(hintText: 'Ej. Lab 7 · Firebase'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 124,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nota', style: theme.textTheme.titleSmall?.copyWith(color: error != null ? scheme.error : null)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _valorCtrl,
                        autofocus: !_editando,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*'))],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _guardar(),
                        onChanged: (_) => setState(() {}),
                        style: AppTheme.estiloNota(24, color: colorValor),
                        decoration: InputDecoration(
                          hintText: '0–20',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                          enabledBorder: error != null ? borde(scheme.error, 2) : null,
                          focusedBorder: error != null ? borde(scheme.error, 2) : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: error != null
                  ? Padding(
                      key: ValueKey(error),
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.error_rounded, size: 18, color: scheme.error),
                          const SizedBox(width: 6),
                          Text(error, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.error)),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (despues != null) ...[
              const SizedBox(height: 14),
              _VistaPrevia(antes: antes, despues: despues),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar', maxLines: 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                    onPressed: _guardar,
                    child: Text(_editando ? 'Guardar cambios' : 'Guardar nota', maxLines: 1),
                  ),
                ),
              ],
            ),
            if (_editando) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  onPressed: _borrar,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Borrar nota'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VistaPrevia extends StatelessWidget {
  final double? antes;
  final double despues;

  const _VistaPrevia({required this.antes, required this.despues});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    final previo = antes;
    final sube = previo == null || despues >= previo;
    final texto = previo == null
        ? 'La unidad quedaría en ${FormatoNota.nota(despues)}'
        : 'La unidad pasaría de ${FormatoNota.nota(previo)} a ${FormatoNota.nota(despues)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(
            sube ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: sube ? estado.aprobado : estado.desaprobado,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
