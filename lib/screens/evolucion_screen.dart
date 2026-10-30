import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/curso.dart';
import '../services/calculo_curso_service.dart';
import '../services/calculos_multinivel.dart';
import '../services/cursos_service.dart';
import '../services/datos_graficos.dart';
import '../theme/app_theme.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/formato_nota.dart';
import '../widgets/app_bar_nivel.dart';
import '../widgets/graficos_evolucion.dart';
import '../widgets/seccion_titulo.dart';
import 'unidades_screen.dart';

/// Vista inicial de la pantalla de evolucion.
enum VistaEvolucion { porUnidad, entreCursos }

/// H20 - Pantalla "Evolucion" (DESIGN.md pantalla 09).
///
/// - Desde el detalle de un curso se abre en "Por unidad" ([cursoId]).
/// - Desde el detalle de un ciclo se abre en "Entre cursos" ([cicloId]).
/// Los datos salen de la logica de H14 via [CalculoCursoService] y
/// [DatosGraficos]; no se repiten formulas.
class EvolucionScreen extends StatefulWidget {
  final VistaEvolucion vistaInicial;
  final String? cursoId;
  final String? cursoNombre;
  final String? cicloId;
  final String? cicloNombre;

  const EvolucionScreen({
    super.key,
    required this.vistaInicial,
    this.cursoId,
    this.cursoNombre,
    this.cicloId,
    this.cicloNombre,
  }) : assert(cursoId != null || cicloId != null);

  @override
  State<EvolucionScreen> createState() => _EvolucionScreenState();
}

class _EvolucionScreenState extends State<EvolucionScreen> {
  final CursosService _cursosService = CursosService();
  final CalculoCursoService _calculoService = CalculoCursoService();

  late VistaEvolucion _vista = widget.vistaInicial;
  String? _cicloId;
  List<Curso> _cursos = [];
  Map<String, ResultadoCalculoCurso> _resultados = {};
  String? _cursoSeleccionado;
  bool _cargando = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _cicloId = widget.cicloId;
    _cursoSeleccionado = widget.cursoId;
    _cargar();
  }

  Future<void> _cargar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // Desde un curso: se busca su ciclo para poder comparar con los demas cursos.
      if ((_cicloId == null || _cicloId!.isEmpty) && widget.cursoId != null) {
        _cicloId = (await _cursosService.obtenerCurso(uid, widget.cursoId!))?.cicloId;
      }
      final cicloId = _cicloId;
      final cursos = cicloId != null && cicloId.isNotEmpty
          ? await _cursosService.obtenerCursos(uid, cicloId).first
          : [Curso(id: widget.cursoId!, nombre: widget.cursoNombre ?? 'Curso', cicloId: '')];
      final resultados = await _calculoService.obtenerCalculosCursos(uid, cursos);
      if (!mounted) return;
      setState(() {
        _cursos = cursos;
        _resultados = resultados;
        _cargando = false;
        _error = false;
        if (_cursoSeleccionado == null || !cursos.any((c) => c.id == _cursoSeleccionado)) {
          // Por defecto, el primer curso que ya tenga notas.
          _cursoSeleccionado = (cursos.where((c) => resultados[c.id]?.notaActual != null).firstOrNull ??
                  cursos.firstOrNull)
              ?.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  Curso? get _curso => _cursos.where((c) => c.id == _cursoSeleccionado).firstOrNull;

  bool get _puedeCompararCursos => _cicloId != null && _cicloId!.isNotEmpty;

  /// Abre el curso para registrar notas y, al volver, actualiza los graficos.
  Future<void> _irAlCurso(Curso curso) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UnidadesScreen(cursoId: curso.id, cursoNombre: curso.nombre)),
    );
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarNivel(
        padre: widget.cicloNombre ?? widget.cursoNombre ?? 'Pondera',
        titulo: 'Evolución',
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? _Vacio(
                  icono: Icons.cloud_off_rounded,
                  titulo: 'No pudimos cargar tus notas',
                  texto: 'Revisa tu conexión e inténtalo de nuevo.',
                  textoBoton: 'Reintentar',
                  onPressed: () {
                    setState(() => _cargando = true);
                    _cargar();
                  },
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      SegmentedButton<VistaEvolucion>(
                        showSelectedIcon: false,
                        segments: [
                          const ButtonSegment(
                            value: VistaEvolucion.porUnidad,
                            icon: Icon(Icons.show_chart_rounded),
                            label: Text('Por unidad'),
                          ),
                          ButtonSegment(
                            value: VistaEvolucion.entreCursos,
                            icon: const Icon(Icons.bar_chart_rounded),
                            label: const Text('Entre cursos'),
                            enabled: _puedeCompararCursos,
                          ),
                        ],
                        selected: {_vista},
                        onSelectionChanged: (s) => setState(() => _vista = s.first),
                      ),
                      const SizedBox(height: 18),
                      ...(_vista == VistaEvolucion.porUnidad ? _vistaPorUnidad(context) : _vistaEntreCursos(context)),
                    ],
                  ),
                ),
    );
  }

  // --- Por unidad ---

  List<Widget> _vistaPorUnidad(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    final curso = _curso;
    if (curso == null) {
      return [
        const _Vacio(
          icono: Icons.menu_book_rounded,
          titulo: 'Aún no hay cursos',
          texto: 'Agrega cursos al ciclo y registra sus notas para ver su evolución.',
        ),
      ];
    }
    final resultado = _resultados[curso.id];
    final serie = resultado == null ? null : DatosGraficos.porUnidad(resultado);
    final abreviaturas = {
      for (final b in DatosGraficos.entreCursos(_cursos, _resultados)) b.cursoId: b.abreviatura,
    };

    return [
      if (_cursos.length > 1) ...[
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _cursos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = _cursos[i];
              final activo = c.id == curso.id;
              return Tooltip(
                message: c.nombre,
                child: ChoiceChip(
                  selected: activo,
                  onSelected: (_) => setState(() => _cursoSeleccionado = c.id),
                  label: Text(abreviaturas[c.id] ?? c.nombre),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: activo ? scheme.onPrimaryContainer : scheme.onSurface,
                  ),
                  selectedColor: scheme.primaryContainer,
                  side: BorderSide(color: activo ? scheme.primary : scheme.outline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
      ],
      SeccionTitulo(curso.nombre),
      const SizedBox(height: 10),
      if (serie == null || !serie.tieneDatos)
        _Vacio(
          icono: Icons.show_chart_rounded,
          titulo: 'Aún no hay notas para graficar',
          texto: 'Registra notas en las unidades de ${curso.nombre} para ver cómo evolucionas.',
          textoBoton: 'Registrar notas',
          onPressed: () => _irAlCurso(curso),
        )
      else ...[
        _Tarjeta(
          child: Column(
            children: [
              GraficoUnidades(serie: serie),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  ItemLeyenda(color: scheme.primary, texto: 'Promedio por unidad', linea: true),
                  ItemLeyenda(color: estado.aviso, texto: 'Mínimo 10.5', punteado: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (serie.variacion != null) ...[
              Expanded(
                child: _MiniTarjeta(
                  titulo: serie.textoVariacion!,
                  valor: serie.variacion!,
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (serie.margen != null)
              Expanded(
                child: _MiniTarjeta(titulo: 'Margen sobre 10.5', valor: serie.margen!),
              ),
          ],
        ),
        if (serie.pendientes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Linea(
            icono: Icons.hourglass_empty_rounded,
            color: scheme.onSurfaceVariant,
            texto: 'Sin notas todavía: '
                '${serie.pendientes.map((p) => '${p.nombre} (${FormatoNota.porcentaje(p.peso)}%)').join(', ')}.',
          ),
        ],
      ],
    ];
  }

  // --- Entre cursos ---

  List<Widget> _vistaEntreCursos(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    if (_cursos.isEmpty) {
      return [
        _Vacio(
          icono: Icons.bar_chart_rounded,
          titulo: 'Este ciclo no tiene cursos',
          texto: 'Agrega los cursos del ciclo y sus notas para compararlos.',
          textoBoton: 'Volver al ciclo',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ];
    }
    final barras = DatosGraficos.entreCursos(_cursos, _resultados);
    if (barras.every((b) => b.sinNotas)) {
      return [
        _Vacio(
          icono: Icons.bar_chart_rounded,
          titulo: 'Ningún curso tiene notas todavía',
          texto: 'Registra notas en tus cursos para compararlos.',
          textoBoton: 'Registrar notas',
          onPressed: () => _irAlCurso(_cursos.first),
        ),
      ];
    }
    final avisos = DatosGraficos.avisosRiesgo(barras);

    return [
      if (widget.cicloNombre != null) ...[
        SeccionTitulo('Cursos de ${widget.cicloNombre}'),
        const SizedBox(height: 10),
      ],
      _Tarjeta(
        child: Column(
          children: [
            GraficoCursos(barras: barras),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                ItemLeyenda(color: scheme.primary, texto: 'Aprobado'),
                ItemLeyenda(color: estado.desaprobado, texto: 'En riesgo'),
                if (barras.any((b) => b.sinNotas)) ItemLeyenda(color: scheme.outline, texto: 'Sin notas', punteado: true),
                ItemLeyenda(color: estado.aviso, texto: 'Mínimo 10.5', punteado: true),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (avisos.isEmpty)
        _Linea(
          icono: Icons.check_circle_rounded,
          color: estado.aprobado,
          texto: 'Todos tus cursos con notas están sobre el mínimo de 10.5.',
        )
      else
        for (final aviso in avisos) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: estado.avisoFondo, borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_rounded, color: estado.onAvisoFondo, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(aviso, style: TextStyle(fontSize: 14, height: 1.35, color: estado.onAvisoFondo)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
    ];
  }
}

// --- Piezas de la pantalla ---

class _Tarjeta extends StatelessWidget {
  final Widget child;

  const _Tarjeta({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.fromLTRB(8, 18, 16, 14), child: child),
    );
  }
}

/// Mini tarjeta con una variacion: "De U1 a U2  -2.0" o "Margen sobre 10.5  +4.6".
class _MiniTarjeta extends StatelessWidget {
  final String titulo;
  final double valor;

  const _MiniTarjeta({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    final estado = EstadoNotaColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final sube = valor >= 0;
    final color = sube ? estado.aprobado : estado.desaprobado;
    final texto = '${sube ? '+' : '−'}${valor.abs().toStringAsFixed(1)}';
    return Semantics(
      label: '$titulo: $texto',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(sube ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: color),
                  const SizedBox(width: 6),
                  Text(texto, style: AppTheme.estiloNota(24, color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String texto;

  const _Linea({required this.icono, required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: TextStyle(fontSize: 14, height: 1.35, color: color))),
        ],
      ),
    );
  }
}

/// Estado vacio compacto, con un solo boton opcional.
class _Vacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final String? textoBoton;
  final VoidCallback? onPressed;

  const _Vacio({required this.icono, required this.titulo, required this.texto, this.textoBoton, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(22)),
            child: Icon(icono, size: 36, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Text(titulo, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (textoBoton != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onPressed, child: Text(textoBoton!)),
          ],
        ],
      ),
    );
  }
}
