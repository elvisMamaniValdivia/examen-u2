import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/curso.dart';
import '../services/calculo_curso_service.dart';
import '../services/calculos_multinivel.dart';
import '../services/calculos_prioridades.dart';
import '../services/cursos_service.dart';
import '../services/datos_graficos.dart';
import '../theme/app_theme.dart';
import '../utils/formato_nota.dart';
import '../widgets/app_bar_nivel.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/prioridades.dart';
import '../widgets/seccion_titulo.dart';
import 'tipos_evaluacion_screen.dart';
import 'unidades_screen.dart';

/// Vista inicial de la pantalla de prioridades.
enum VistaPrioridades { curso, ciclo }

/// H23 - Prioridades: qué evaluaciones pesan más en la nota.
///
/// - Desde el detalle de un curso se abre en "Este curso" ([cursoId]).
/// - Desde el detalle de un ciclo se abre en "Todo el ciclo" ([cicloId]).
/// Los pesos salen de [CalculosPrioridades]; la pantalla no calcula.
class PrioridadesScreen extends StatefulWidget {
  final VistaPrioridades vistaInicial;
  final String? cursoId;
  final String? cursoNombre;
  final String? cicloId;
  final String? cicloNombre;

  const PrioridadesScreen({
    super.key,
    required this.vistaInicial,
    this.cursoId,
    this.cursoNombre,
    this.cicloId,
    this.cicloNombre,
  }) : assert(cursoId != null || cicloId != null);

  @override
  State<PrioridadesScreen> createState() => _PrioridadesScreenState();
}

class _PrioridadesScreenState extends State<PrioridadesScreen> {
  final CursosService _cursosService = CursosService();
  final CalculoCursoService _calculoService = CalculoCursoService();

  late VistaPrioridades _vista = widget.vistaInicial;
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
      // Desde un curso: se busca su ciclo para poder ver las prioridades del ciclo.
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
          // Por defecto, el primer curso que aún tenga algo pendiente.
          _cursoSeleccionado = (cursos.where((c) => _prioridadesDe(c).principal != null).firstOrNull ??
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

  PrioridadesCurso _prioridadesDe(Curso curso) =>
      CalculosPrioridades.deCurso(_resultados[curso.id]?.estructuras ?? const []);

  Curso? get _curso => _cursos.where((c) => c.id == _cursoSeleccionado).firstOrNull;

  bool get _puedeVerCiclo => _cicloId != null && _cicloId!.isNotEmpty;

  /// Abre la unidad del componente para registrar notas y, al volver, recalcula.
  Future<void> _irAUnidad(Curso curso, ComponentePrioridad c) async {
    final unidad = _resultados[curso.id]?.unidades.where((u) => u.id == c.unidadId).firstOrNull;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiposEvaluacionScreen(
          cursoId: curso.id,
          cursoNombre: curso.nombre,
          unidadId: c.unidadId,
          unidadNombre: c.unidadNombre,
          unidadPorcentaje: unidad?.porcentaje ?? c.pesoUnidad,
        ),
      ),
    );
    if (mounted) await _cargar();
  }

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
        titulo: 'Prioridades',
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: EstadoVacio(
                    icono: Icons.cloud_off_rounded,
                    titulo: 'No pudimos cargar tus notas',
                    texto: 'Revisa tu conexión e inténtalo de nuevo.',
                    textoBoton: 'Reintentar',
                    onPressed: () {
                      setState(() => _cargando = true);
                      _cargar();
                    },
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      SegmentedButton<VistaPrioridades>(
                        showSelectedIcon: false,
                        segments: [
                          const ButtonSegment(
                            value: VistaPrioridades.curso,
                            icon: Icon(Icons.menu_book_rounded),
                            label: Text('Este curso'),
                          ),
                          ButtonSegment(
                            value: VistaPrioridades.ciclo,
                            icon: const Icon(Icons.school_rounded),
                            label: const Text('Todo el ciclo'),
                            enabled: _puedeVerCiclo,
                          ),
                        ],
                        selected: {_vista},
                        onSelectionChanged: (s) => setState(() => _vista = s.first),
                      ),
                      const SizedBox(height: 18),
                      ...(_vista == VistaPrioridades.curso ? _vistaCurso(context) : _vistaCiclo(context)),
                    ],
                  ),
                ),
    );
  }

  // --- Este curso ---

  List<Widget> _vistaCurso(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final curso = _curso;
    if (curso == null) {
      return [
        EstadoVacio(
          icono: Icons.menu_book_rounded,
          titulo: 'Aún no hay cursos',
          texto: 'Agrega cursos al ciclo y configura sus pesos para ver qué evaluaciones valen más.',
          textoBoton: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ];
    }
    final p = _prioridadesDe(curso);
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
      if (p.sinPesos)
        EstadoVacio(
          icono: Icons.pie_chart_outline_rounded,
          titulo: 'Configura los pesos del curso',
          texto: 'Agrega las unidades de ${curso.nombre} con sus tipos de evaluación y porcentajes '
              'para saber cuánto vale cada uno.',
          textoBoton: 'Ir al curso',
          onPressed: () => _irAlCurso(curso),
        )
      else ...[
        _Resumen(
          valor: p.pesoPendiente,
          titulo: 'del curso aún por evaluar',
          texto: p.principal == null
              ? 'Ya tienes notas en todas las evaluaciones de ${curso.nombre}.'
              : 'El peso real de cada evaluación es su porcentaje en la unidad × el peso de la unidad en el curso.',
        ),
        if (p.pendientes.isNotEmpty) ...[
          const SizedBox(height: 22),
          SeccionTitulo('Pendientes', trailing: _Contador(p.pendientes.length)),
          const SizedBox(height: 10),
          for (final c in p.pendientes) ...[
            FilaComponentePrioridad(
              key: ValueKey('p-${c.tipoId}'),
              componente: c,
              pesoMaximo: p.pesoMaximo,
              onTap: () => _irAUnidad(curso, c),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (p.evaluados.isNotEmpty) ...[
          const SizedBox(height: 12),
          SeccionTitulo('Ya evaluadas', trailing: _Contador(p.evaluados.length)),
          const SizedBox(height: 10),
          for (final c in p.evaluados) ...[
            FilaComponentePrioridad(
              key: ValueKey('e-${c.tipoId}'),
              componente: c,
              pesoMaximo: p.pesoMaximo,
              onTap: () => _irAUnidad(curso, c),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 12),
        const SeccionTitulo('Unidades'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [for (final u in p.unidades) BarraUnidadPrioridad(unidad: u)],
            ),
          ),
        ),
      ],
    ];
  }

  // --- Todo el ciclo ---

  List<Widget> _vistaCiclo(BuildContext context) {
    if (_cursos.isEmpty) {
      return [
        EstadoVacio(
          icono: Icons.school_rounded,
          titulo: 'Este ciclo no tiene cursos',
          texto: 'Agrega los cursos del ciclo con sus créditos y pesos para ver tus prioridades.',
          textoBoton: 'Volver al ciclo',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ];
    }
    final top = CalculosPrioridades.delCiclo(_cursos, _resultados);
    if (top.isEmpty) {
      final sinPesos = _cursos.every((c) => _prioridadesDe(c).sinPesos);
      return [
        EstadoVacio(
          icono: sinPesos ? Icons.pie_chart_outline_rounded : Icons.check_circle_rounded,
          titulo: sinPesos ? 'Configura los pesos de tus cursos' : 'No tienes evaluaciones pendientes',
          texto: sinPesos
              ? 'Agrega unidades y tipos de evaluación con sus porcentajes para ver qué mueve tu promedio.'
              : 'Todas las evaluaciones del ciclo ya tienen notas.',
          textoBoton: 'Ir a un curso',
          onPressed: () => _irAlCurso(_cursos.first),
        ),
      ];
    }
    final creditos = CalculoCursoService.totalCreditos(_cursos);
    final maximo = top.first.pesoCiclo ?? 0;

    return [
      _Resumen(
        valor: CalculosPrioridades.pesoEnCiclo(top),
        titulo: top.length == 1
            ? 'del ciclo depende de esta evaluación'
            : 'del ciclo depende de estas ${top.length} evaluaciones',
        texto: 'Cada evaluación pesa según su peso real en el curso y los créditos del curso '
            '($creditos créditos en el ciclo).',
      ),
      const SizedBox(height: 22),
      const SeccionTitulo('Lo que más mueve tu ciclo'),
      const SizedBox(height: 10),
      for (final c in top) ...[
        FilaComponentePrioridad(
          key: ValueKey('c-${c.curso?.id}-${c.tipoId}'),
          componente: c,
          pesoMaximo: maximo,
          enCiclo: true,
          onTap: c.curso == null ? null : () => _irAUnidad(c.curso!, c),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

// --- Piezas de la pantalla ---

/// Cabecera con el porcentaje pendiente y una explicación corta.
class _Resumen extends StatelessWidget {
  final double valor;
  final String titulo;
  final String texto;

  const _Resumen({required this.valor, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${FormatoNota.porcentaje(valor)} por ciento $titulo. $texto',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${FormatoNota.porcentaje(valor)}%',
                  style: AppTheme.estiloNota(36, color: scheme.onPrimaryContainer, weight: FontWeight.w800),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      titulo,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(texto, style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  final int cantidad;

  const _Contador(this.cantidad);

  @override
  Widget build(BuildContext context) {
    return Text(
      '$cantidad',
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
