import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/componente_evaluacion.dart';
import '../providers/componentes_provider.dart';
import '../theme/app_theme.dart';
import '../theme/estado_nota_colors.dart';

/// Anchos de las columnas de la calculadora (DESIGN.md seccion 6).
/// Los usa tambien el encabezado de la tabla en HomeScreen.
class ColumnasComponente {
  static const double nota = 64;
  static const double peso = 72;
  static const double borrar = 40;
  static const double separacion = 8;
}

/// Fila editable de un componente: nombre (flex) | nota 64 | peso 72 | borrar 40.
class FilaComponente extends StatefulWidget {
  final ComponenteEvaluacion componente;
  final bool puedeEliminar;

  const FilaComponente({
    required super.key,
    required this.componente,
    required this.puedeEliminar,
  });

  @override
  State<FilaComponente> createState() => _FilaComponenteState();
}

class _FilaComponenteState extends State<FilaComponente> {
  late TextEditingController _nombreController;
  late TextEditingController _notaController;
  late TextEditingController _pesoController;

  /// Muestra 14 en vez de 14.0 al cargar valores enteros.
  static String _formatear(double valor) =>
      valor == valor.roundToDouble() ? valor.toInt().toString() : valor.toString();

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.componente.nombre);
    _notaController = TextEditingController(
      text: widget.componente.nota == 0.0 && widget.componente.nombre.isEmpty
          ? ''
          : _formatear(widget.componente.nota),
    );
    _pesoController = TextEditingController(
      text: widget.componente.peso == 0.0 && widget.componente.nombre.isEmpty
          ? ''
          : _formatear(widget.componente.peso),
    );
  }

  @override
  void didUpdateWidget(covariant FilaComponente oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.componente.nombre != widget.componente.nombre &&
        _nombreController.text != widget.componente.nombre) {
      _nombreController.text = widget.componente.nombre;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _notaController.dispose();
    _pesoController.dispose();
    super.dispose();
  }

  InputDecoration _decoracion(BuildContext context, {String? hint, bool fueraDeRango = false}) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder borde(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: fueraDeRango ? borde(scheme.error, 2) : borde(scheme.outline, 1),
      focusedBorder: fueraDeRango ? borde(scheme.error, 2) : borde(scheme.primary, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ComponentesProvider>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);

    final notaTexto = _notaController.text;
    final notaEscrita = double.tryParse(notaTexto);
    final notaFueraDeRango = notaEscrita != null && (notaEscrita < 0 || notaEscrita > 20);

    // La nota se colorea segun su estado: verde si aprueba, rojo si no.
    Color colorNota = scheme.onSurface;
    if (notaEscrita != null) {
      colorNota = notaFueraDeRango || notaEscrita < 10.5 ? estado.desaprobado : estado.aprobado;
    }

    final nombre = widget.componente.nombre.isEmpty ? 'componente' : widget.componente.nombre;

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nombreController,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: _decoracion(context, hint: 'Componente'),
              onChanged: (val) {
                provider.actualizarComponente(widget.componente.id, nombre: val);
              },
            ),
          ),
          const SizedBox(width: ColumnasComponente.separacion),
          SizedBox(
            width: ColumnasComponente.nota,
            child: Semantics(
              label: 'Nota de $nombre, de 0 a 20',
              child: TextField(
                controller: _notaController,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: AppTheme.estiloNota(18, color: colorNota),
                decoration: _decoracion(context, hint: '—', fueraDeRango: notaFueraDeRango),
                onChanged: (val) {
                  final notaVal = double.tryParse(val) ?? 0.0;
                  final notaClamped = notaVal.clamp(0.0, 20.0);
                  provider.actualizarComponente(widget.componente.id, nota: notaClamped);
                  setState(() {}); // recalcula color y borde de la nota
                },
              ),
            ),
          ),
          const SizedBox(width: ColumnasComponente.separacion),
          SizedBox(
            width: ColumnasComponente.peso,
            child: Semantics(
              label: 'Peso en porcentaje de $nombre',
              child: TextField(
                controller: _pesoController,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                decoration: _decoracion(context, hint: '0'),
                onChanged: (val) {
                  final pesoVal = double.tryParse(val) ?? 0.0;
                  final pesoClamped = pesoVal.clamp(0.0, 100.0);
                  provider.actualizarComponente(widget.componente.id, peso: pesoClamped);
                },
              ),
            ),
          ),
          SizedBox(
            width: ColumnasComponente.borrar + 8,
            child: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: scheme.onSurfaceVariant,
              tooltip: widget.puedeEliminar ? 'Eliminar $nombre' : 'Mínimo 2 componentes',
              onPressed: widget.puedeEliminar
                  ? () => provider.eliminarComponente(widget.componente.id)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
