import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nota.dart';
import '../models/tipo_evaluacion.dart';
import '../services/calculos_evaluaciones.dart';
import '../theme/app_theme.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/formato_nota.dart';
import 'grupo_tipo_evaluacion.dart';

/// H15 - Simulador "¿Qué nota necesito?" de una unidad (DESIGN.md pantalla 08).
///
/// Recibe los tipos y notas ya cargados por la pantalla; el calculo esta en
/// [CalculosEvaluaciones.simularUnidad]. Se recalcula mientras se escribe.
Future<void> mostrarSimuladorUnidad(
  BuildContext context, {
  required List<TipoEvaluacion> tipos,
  required Map<String, List<Nota>> notasPorTipo,
  required String subtitulo,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: scheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _HojaSimulador(tipos: tipos, notasPorTipo: notasPorTipo, subtitulo: subtitulo),
  );
}

class _HojaSimulador extends StatefulWidget {
  final List<TipoEvaluacion> tipos;
  final Map<String, List<Nota>> notasPorTipo;
  final String subtitulo;

  const _HojaSimulador({required this.tipos, required this.notasPorTipo, required this.subtitulo});

  @override
  State<_HojaSimulador> createState() => _HojaSimuladorState();
}

class _HojaSimuladorState extends State<_HojaSimulador> {
  late final List<TipoEvaluacion> _pendientes =
      widget.tipos.where((t) => (widget.notasPorTipo[t.id] ?? []).isEmpty).toList();
  late String _tipoId = _pendientes.first.id;
  final _objetivoCtrl = TextEditingController(text: '14');

  @override
  void dispose() {
    _objetivoCtrl.dispose();
    super.dispose();
  }

  double? get _objetivo {
    final v = double.tryParse(_objetivoCtrl.text.trim().replaceAll(',', '.'));
    return v != null && v >= 0 && v <= 20 ? v : null;
  }

  void _usarObjetivo(double v) {
    _objetivoCtrl.text = FormatoNota.porcentaje(v);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final objetivo = _objetivo;
    final resultado = objetivo == null
        ? null
        : CalculosEvaluaciones.simularUnidad(
            tipos: widget.tipos,
            notasPorTipo: widget.notasPorTipo,
            tipoPendienteId: _tipoId,
            objetivo: objetivo,
          );
    final tipo = _pendientes.firstWhere((t) => t.id == _tipoId);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
                      Text('¿Qué nota necesito?', style: theme.textTheme.headlineSmall),
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
            Text('Evaluación pendiente', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _pendientes)
                  ChoiceChip(
                    selected: t.id == _tipoId,
                    onSelected: (_) => setState(() => _tipoId = t.id),
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
            Text('¿Con qué promedio quieres terminar la unidad?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: TextField(
                controller: _objetivoCtrl,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*'))],
                onChanged: (_) => setState(() {}),
                style: AppTheme.estiloNota(40, color: scheme.onSurface),
                decoration: InputDecoration(
                  suffixText: '/ 20',
                  errorText: objetivo == null && _objetivoCtrl.text.isNotEmpty ? 'Entre 0 y 20' : null,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final (texto, valor) in [('Aprobar · 10.5', 10.5), ('14', 14.0), ('16', 16.0), ('18', 18.0)])
                  ActionChip(
                    label: Text(texto),
                    onPressed: () => _usarObjetivo(valor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (resultado != null) _TarjetaResultado(resultado: resultado, tipo: tipo),
            const SizedBox(height: 8),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('¿Cómo se calcula?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                children: [
                  Text(
                    'Nota necesaria = (objetivo − puntos que ya tienes) ÷ peso de la evaluación elegida.\n'
                    'Se supone que las otras evaluaciones pendientes aportan 0. El máximo posible es lo que '
                    'tendrías sacando 20 en todo lo pendiente.',
                    style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaResultado extends StatelessWidget {
  final ResultadoSimulacionUnidad resultado;
  final TipoEvaluacion tipo;

  const _TarjetaResultado({required this.resultado, required this.tipo});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    final maximo = FormatoNota.nota(resultado.maximoPosible);

    final Color fondo;
    final Color texto;
    final IconData icono;
    final String titulo;
    final String detalle;
    String? numero;
    String? nivel;

    if (resultado.imposible) {
      fondo = estado.avisoFondo;
      texto = estado.onAvisoFondo;
      icono = Icons.error_rounded;
      titulo = 'Meta inalcanzable';
      detalle = 'Ni con 20 en todo lo pendiente llegas. Lo máximo posible es $maximo.';
    } else if (resultado.yaAlcanzado) {
      fondo = estado.aprobadoFondo;
      texto = estado.onAprobadoFondo;
      icono = Icons.check_circle_rounded;
      titulo = '¡Ya la tienes asegurada!';
      detalle = 'Con tus notas actuales ya llegas, aunque lo pendiente aporte 0. Máximo posible: $maximo.';
    } else if (resultado.necesitaOtrasPendientes) {
      fondo = estado.avisoFondo;
      texto = estado.onAvisoFondo;
      icono = Icons.call_split_rounded;
      titulo = 'Solo con ${tipo.nombre} no alcanza';
      detalle = 'Necesitarías ${FormatoNota.nota(resultado.notaNecesaria)} en ${tipo.nombre}. '
          'Puedes llegar repartiendo entre las demás evaluaciones pendientes. Máximo posible: $maximo.';
    } else {
      fondo = scheme.primary;
      texto = scheme.onPrimary;
      icono = Icons.flag_rounded;
      titulo = 'Necesitas en ${tipo.nombre}';
      numero = FormatoNota.nota(resultado.notaNecesaria);
      nivel = resultado.notaNecesaria <= 12
          ? 'Alcanzable'
          : (resultado.notaNecesaria <= 16 ? 'Exigente' : 'Muy exigente');
      detalle = 'Supone que las otras pendientes aportan 0. Máximo posible: $maximo.';
    }

    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: texto),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(titulo, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: texto)),
                ),
              ],
            ),
            if (numero != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(numero, style: AppTheme.estiloNota(72, color: texto)),
                  const SizedBox(width: 6),
                  Text('/ 20', style: AppTheme.estiloNota(20, color: texto.withValues(alpha: 0.7))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: texto.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(nivel!, style: TextStyle(fontWeight: FontWeight.w700, color: texto)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(detalle, style: TextStyle(fontSize: 14, height: 1.4, color: texto)),
          ],
        ),
      ),
    );
  }
}
