import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/calculo_curso_service.dart';
import '../services/calculos_multinivel.dart';
import '../services/simulador_curso_service.dart';
import '../theme/app_theme.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/formato_nota.dart';
import '../widgets/app_bar_nivel.dart';

/// H17 - Pantalla del simulador de notas del curso (UI responsiva y adaptativa).
class SimuladorScreen extends StatefulWidget {
  final String cursoId;
  final String cursoNombre;
  final String? cicloNombre;
  final Map<String, double?>? notasPorUnidad;
  final Map<String, bool>? unidadCompleta;
  final Map<String, double>? pesosPorUnidad;
  final CalculoCursoService? calculoService;
  final double? notaEstimadaInicial;

  const SimuladorScreen({
    super.key,
    required this.cursoId,
    required this.cursoNombre,
    this.cicloNombre,
    this.notasPorUnidad,
    this.unidadCompleta,
    this.pesosPorUnidad,
    this.calculoService,
    this.notaEstimadaInicial,
  });

  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  late final CalculoCursoService _calculoService = widget.calculoService ?? CalculoCursoService();
  final TextEditingController _objetivoCtrl = TextEditingController(text: '10.5');

  late double _notaEstimadaPendientes = widget.notaEstimadaInicial ?? 11.0;

  late bool _cargando = widget.notasPorUnidad == null ||
      widget.unidadCompleta == null ||
      widget.pesosPorUnidad == null;
  String? _error;

  Map<String, double?> _notasPorUnidad = {};
  Map<String, bool> _unidadCompleta = {};
  Map<String, double> _pesosPorUnidad = {};

  final List<double> _presets = [10.5, 12.0, 14.0, 16.0, 18.0];

  @override
  void initState() {
    super.initState();
    if (_cargando) {
      _cargarDatos();
    } else {
      _notasPorUnidad = widget.notasPorUnidad!;
      _unidadCompleta = widget.unidadCompleta!;
      _pesosPorUnidad = widget.pesosPorUnidad!;
    }
  }

  @override
  void dispose() {
    _objetivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _error = 'Debes iniciar sesión para usar el simulador.';
        _cargando = false;
      });
      return;
    }

    try {
      final resultados = await Future.wait<dynamic>([
        _calculoService.obtenerCalculoCurso(uid, widget.cursoId),
        _calculoService.obtenerPesosUnidades(uid, widget.cursoId),
      ]);

      if (!mounted) return;

      final calculo = resultados[0] as ResultadoCalculoCurso;
      final pesos = resultados[1] as Map<String, double>;

      setState(() {
        _notasPorUnidad = calculo.notasPorUnidad;
        _unidadCompleta = calculo.unidadCompleta;
        _pesosPorUnidad = pesos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los datos del curso.';
        _cargando = false;
      });
    }
  }

  double? get _objetivoActual {
    final t = _objetivoCtrl.text.trim().replaceAll(',', '.');
    final num = double.tryParse(t);
    if (num == null || !num.isFinite || num < 0 || num > 20) {
      return null;
    }
    return num;
  }

  void _seleccionarPreset(double valor) {
    setState(() {
      _objetivoCtrl.text = FormatoNota.nota(valor);
    });
  }

  int get _unidadesPendientesCount {
    int total = _pesosPorUnidad.length;
    int completas = _unidadCompleta.values.where((c) => c).length;
    return total - completas;
  }

  /// Calcula el promedio final resultante proyectado combinando las unidades
  /// ya registradas con la nota estimada en las unidades pendientes (Criterio H18).
  double? get _promedioFinalSimulado {
    if (_pesosPorUnidad.isEmpty) return null;
    double totalPonderado = 0.0;
    double sumaPesos = 0.0;

    for (final entry in _pesosPorUnidad.entries) {
      final unidadId = entry.key;
      final peso = entry.value;
      final completada = _unidadCompleta[unidadId] ?? false;
      final nota = _notasPorUnidad[unidadId];

      if (completada && nota != null) {
        totalPonderado += (nota * peso);
        sumaPesos += peso;
      } else {
        totalPonderado += (_notaEstimadaPendientes * peso);
        sumaPesos += peso;
      }
    }

    if (sumaPesos == 0) return null;
    return totalPonderado / sumaPesos;
  }

  Widget _buildCardPromedioFinalInteractivo() {
    return _TarjetaPromedioFinalInteractivo(
      promedioFinal: _promedioFinalSimulado,
      hayPendientes: _unidadesPendientesCount > 0,
      notaEstimada: _notaEstimadaPendientes,
      onNotaEstimadaChanged: _unidadesPendientesCount > 0
          ? (nuevaNota) {
              setState(() {
                _notaEstimadaPendientes = nuevaNota;
              });
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarNivel(
        padre: widget.cicloNombre ?? 'Curso',
        titulo: 'Simulador · ${widget.cursoNombre}',
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _pesosPorUnidad.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'Este curso no tiene unidades registradas todavía.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final esPantallaGrande = constraints.maxWidth >= 600;

                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 24,
                              ),
                              child: esPantallaGrande
                                  ? _buildLayoutGrande()
                                  : _buildLayoutMovil(),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  /// Layout para pantallas de escritorio, tablets y computadoras (2 columnas)
  Widget _buildLayoutGrande() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna izquierda: Promedio final interactivo y entrada de nota
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCardPromedioFinalInteractivo(),
              const SizedBox(height: 16),
              _buildCardEntrada(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Columna derecha: Tarjeta destacada de resultado y resumen de unidades
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPanelResultado(),
              const SizedBox(height: 16),
              _buildCardResumenCurso(),
            ],
          ),
        ),
      ],
    );
  }

  /// Layout para pantallas móviles (1 columna vertical)
  Widget _buildLayoutMovil() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCardPromedioFinalInteractivo(),
        const SizedBox(height: 16),
        _buildCardEntrada(),
        const SizedBox(height: 16),
        _buildPanelResultado(),
        const SizedBox(height: 16),
        _buildCardResumenCurso(),
      ],
    );
  }

  /// Formulario de ingreso de la nota objetivo (0-20)
  Widget _buildCardEntrada() {
    final objetivo = _objetivoActual;
    final esInvalido = _objetivoCtrl.text.isNotEmpty && objetivo == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nota objetivo del curso',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ingresa la nota final con la que deseas aprobar o terminar el curso (escala 0 - 20).',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _objetivoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
              ],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Nota objetivo (0 - 20)',
                hintText: 'Ej. 14.0',
                prefixIcon: const Icon(Icons.flag_rounded),
                suffixText: '/ 20',
                errorText: esInvalido ? 'Ingresa una nota válida entre 0 y 20' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            const Text(
              'Metas frecuentes:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  ChoiceChip(
                    label: Text(
                      '${FormatoNota.nota(p)} ${p == 10.5 ? "(Mínimo)" : ""}',
                    ),
                    selected: objetivo == p,
                    onSelected: (selected) {
                      if (selected) _seleccionarPreset(p);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Panel con la tarjeta destacada de resultado y su diferenciación visual
  Widget _buildPanelResultado() {
    final objetivo = _objetivoActual;

    if (objetivo == null) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: const Padding(
          padding: EdgeInsets.all(28.0),
          child: Column(
            children: [
              Icon(Icons.edit_note_rounded, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Ingresa una nota objetivo válida (0 a 20) para calcular la nota necesaria.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final simulacion = SimuladorCursoService.calcular(
      objetivo: objetivo,
      notasPorUnidad: _notasPorUnidad,
      unidadCompleta: _unidadCompleta,
      pesosPorUnidad: _pesosPorUnidad,
    );

    return _TarjetaResultadoSimulador(simulacion: simulacion);
  }

  /// Resumen del curso con unidades y pesos
  Widget _buildCardResumenCurso() {
    final scheme = Theme.of(context).colorScheme;

    int totalUnidades = _pesosPorUnidad.length;
    int unidadesCompletas = _unidadCompleta.values.where((c) => c).length;
    int unidadesPendientes = totalUnidades - unidadesCompletas;

    return Card(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_outlined, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estado actual del curso',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FilaDetalle(
              etiqueta: 'Total de unidades:',
              valor: '$totalUnidades',
            ),
            const SizedBox(height: 4),
            _FilaDetalle(
              etiqueta: 'Unidades completas:',
              valor: '$unidadesCompletas',
            ),
            const SizedBox(height: 4),
            _FilaDetalle(
              etiqueta: 'Unidades pendientes:',
              valor: '$unidadesPendientes',
            ),
            const Divider(height: 16),
            _FilaDetalle(
              etiqueta: 'Suma total de pesos:',
              valor: '${FormatoNota.porcentaje(_pesosPorUnidad.values.fold(0.0, (a, b) => a + b))}%',
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta destacada del resultado del simulador (Criterios 2 y 3 de H17)
class _TarjetaResultadoSimulador extends StatelessWidget {
  final ResultadoSimuladorCurso simulacion;

  const _TarjetaResultadoSimulador({required this.simulacion});

  @override
  Widget build(BuildContext context) {
    final estadoTema = EstadoNotaColors.of(context);
    final sinPendientes = simulacion.unidadesPendientes == 0;
    final yaAlcanzado = !sinPendientes &&
        simulacion.objetivoAlcanzable &&
        simulacion.notaNecesaria <= 0;
    final esAlcanzable = simulacion.objetivoAlcanzable && !yaAlcanzado;
    final esInalcanzable = !sinPendientes && !simulacion.objetivoAlcanzable;

    Color colorFondo;
    Color colorTexto;
    IconData icono;
    String titulo;
    String mensaje;
    String valorNota;

    if (sinPendientes) {
      colorFondo = Theme.of(context).colorScheme.surfaceContainerHigh;
      colorTexto = Theme.of(context).colorScheme.onSurface;
      icono = Icons.fact_check_rounded;
      titulo = 'Curso completado';
      valorNota = FormatoNota.nota(simulacion.notaActual);
      mensaje = 'Ya no tienes unidades pendientes por evaluar en este curso.';
    } else if (yaAlcanzado) {
      colorFondo = estadoTema.aprobadoFondo;
      colorTexto = estadoTema.onAprobadoFondo;
      icono = Icons.emoji_events_rounded;
      titulo = '¡Objetivo asegurado!';
      valorNota = '0.0';
      mensaje =
          'Con tus notas actuales ya superas la meta de ${FormatoNota.nota(simulacion.objetivo)}. '
          '¡No necesitas puntos adicionales!';
    } else if (esAlcanzable) {
      colorFondo = estadoTema.aprobadoFondo;
      colorTexto = estadoTema.onAprobadoFondo;
      icono = Icons.check_circle_rounded;
      titulo = 'Meta alcanzable';
      valorNota = FormatoNota.nota(simulacion.notaNecesaria);
      mensaje =
          'Necesitas un promedio de $valorNota en las ${simulacion.unidadesPendientes} '
          'unidades pendientes (${FormatoNota.porcentaje(simulacion.porcentajePendiente)}% del curso) '
          'para alcanzar ${FormatoNota.nota(simulacion.objetivo)}.';
    } else {
      // Inalcanzable
      colorFondo = estadoTema.avisoFondo;
      colorTexto = estadoTema.onAvisoFondo;
      icono = Icons.error_outline_rounded;
      titulo = 'Meta inalcanzable';
      valorNota = '> 20';
      mensaje =
          'Aun sacando 20 en todas las unidades pendientes, el promedio máximo que '
          'puedes alcanzar en este curso es ${FormatoNota.nota(simulacion.maximoAlcanzable)}.';
    }

    return Card(
      color: colorFondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorTexto.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: colorTexto, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Nota necesaria en lo que falta:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  valorNota,
                  style: AppTheme.estiloNota(
                    48,
                    color: colorTexto,
                    weight: FontWeight.w800,
                  ),
                ),
                if (!esInalcanzable && !sinPendientes) ...[
                  const SizedBox(width: 8),
                  Text(
                    '/ 20',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorTexto.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mensaje,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: colorTexto,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _FilaDetalle(
              etiqueta: 'Máximo promedio posible:',
              valor: '${FormatoNota.nota(simulacion.maximoAlcanzable)} / 20',
            ),
            const SizedBox(height: 4),
            _FilaDetalle(
              etiqueta: 'Unidades pendientes:',
              valor: '${simulacion.unidadesPendientes}',
            ),
            const SizedBox(height: 4),
            _FilaDetalle(
              etiqueta: 'Porcentaje restante:',
              valor: '${FormatoNota.porcentaje(simulacion.porcentajePendiente)}%',
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaDetalle extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _FilaDetalle({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta interactiva de promedio final y condición Aprobado / Desaprobado (Criterios H18).
class _TarjetaPromedioFinalInteractivo extends StatefulWidget {
  final double? promedioFinal;
  final bool hayPendientes;
  final double notaEstimada;
  final ValueChanged<double>? onNotaEstimadaChanged;

  const _TarjetaPromedioFinalInteractivo({
    required this.promedioFinal,
    required this.hayPendientes,
    required this.notaEstimada,
    this.onNotaEstimadaChanged,
  });

  @override
  State<_TarjetaPromedioFinalInteractivo> createState() =>
      _TarjetaPromedioFinalInteractivoState();
}

class _TarjetaPromedioFinalInteractivoState
    extends State<_TarjetaPromedioFinalInteractivo> {
  bool? _aprobadoAnterior;

  @override
  void didUpdateWidget(covariant _TarjetaPromedioFinalInteractivo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.promedioFinal != null) {
      final ahora = widget.promedioFinal! >= 10.5;
      if (_aprobadoAnterior != null && _aprobadoAnterior != ahora) {
        ahora ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
      }
      _aprobadoAnterior = ahora;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoTema = EstadoNotaColors.of(context);
    final promedio = widget.promedioFinal;

    if (promedio == null) {
      return const SizedBox.shrink();
    }

    final esAprobado = promedio >= 10.5;
    final colorFondo = esAprobado
        ? estadoTema.aprobadoFondo
        : estadoTema.desaprobadoFondo;
    final colorTexto = esAprobado
        ? estadoTema.onAprobadoFondo
        : estadoTema.onDesaprobadoFondo;
    final colorAcento = esAprobado
        ? estadoTema.aprobado
        : estadoTema.desaprobado;
    final icono = esAprobado
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;
    final textoCondicion = esAprobado ? 'Aprobado' : 'Desaprobado';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorAcento.withValues(alpha: 0.6),
          width: 2.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    widget.hayPendientes
                        ? 'Promedio final proyectado'
                        : 'Promedio final del curso',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorAcento,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icono, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        textoCondicion,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  FormatoNota.nota(promedio),
                  style: AppTheme.estiloNota(
                    44,
                    color: colorTexto,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/ 20',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorTexto.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              esAprobado
                  ? '¡Condición aprobatoria para este promedio del curso!'
                  : 'Condición desaprobatoria. Se requiere mejorar en lo que falta.',
              style: TextStyle(
                fontSize: 13,
                color: colorTexto,
              ),
            ),
            if (widget.hayPendientes && widget.onNotaEstimadaChanged != null) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Simular nota en unidades pendientes:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorTexto,
                      ),
                    ),
                  ),
                  Text(
                    '${FormatoNota.nota(widget.notaEstimada)} / 20',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorTexto,
                    ),
                  ),
                ],
              ),
              Slider(
                value: widget.notaEstimada.clamp(0.0, 20.0),
                min: 0.0,
                max: 20.0,
                divisions: 40,
                activeColor: colorAcento,
                inactiveColor: colorAcento.withValues(alpha: 0.25),
                label: FormatoNota.nota(widget.notaEstimada),
                onChanged: widget.onNotaEstimadaChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
