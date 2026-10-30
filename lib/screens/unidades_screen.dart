import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/curso.dart';
import '../models/unidad.dart';
import '../services/calculo_curso_service.dart';
import '../services/calculos_multinivel.dart';
import '../services/calculos_prioridades.dart';
import '../services/cursos_service.dart';
import '../services/unidades_service.dart';
import '../theme/app_theme.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/formato_nota.dart';
import '../widgets/app_bar_nivel.dart';
import '../widgets/barra_pesos.dart';
import '../widgets/card_resultado.dart';
import '../widgets/dialogos.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/linea_pesos.dart';
import '../widgets/prioridades.dart';
import '../widgets/seccion_titulo.dart';
import '../widgets/tarjeta_unidad.dart';
import 'escanear_notas_screen.dart';
import 'evolucion_screen.dart';
import 'prioridades_screen.dart';
import 'simulador_screen.dart';
import 'tipos_evaluacion_screen.dart';

/// Pantalla 05 - Detalle de curso: nota del curso y sus unidades (H12 + H14).
///
/// El stream de unidades se abre una sola vez en [initState]; antes se creaba
/// en build y cada recalculo reemplazaba la lista por el indicador de carga.
class UnidadesScreen extends StatefulWidget {
  final String cursoId;
  final String cursoNombre;

  const UnidadesScreen({
    super.key,
    required this.cursoId,
    required this.cursoNombre,
  });

  @override
  State<UnidadesScreen> createState() => _UnidadesScreenState();
}

class _UnidadesScreenState extends State<UnidadesScreen> {
  final UnidadesService _service = UnidadesService();
  final CursosService _cursosService = CursosService();
  final CalculoCursoService _calculoService = CalculoCursoService();

  late String _nombre = widget.cursoNombre;
  String? _uid;
  StreamSubscription<List<Unidad>>? _unidadesSub;
  List<Unidad> _unidades = [];
  bool _cargando = true;
  bool _error = false;

  ResultadoCalculoCurso? _resultado;
  bool _calculando = false;
  int _calculoActual = 0;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    final uid = _uid;
    if (uid == null) return;
    _unidadesSub = _service.obtenerUnidades(uid, widget.cursoId).listen(
      (unidades) {
        if (!mounted) return;
        setState(() {
          _unidades = unidades;
          _cargando = false;
          _error = false;
        });
        // Cualquier cambio en las unidades (crear, editar peso, borrar) recalcula.
        _actualizarCalculo();
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _cargando = false;
          _error = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _unidadesSub?.cancel();
    super.dispose();
  }

  Future<void> _actualizarCalculo() async {
    final uid = _uid;
    if (uid == null) return;
    final id = ++_calculoActual;
    setState(() => _calculando = true);
    try {
      final resultado = await _calculoService.obtenerCalculoCurso(uid, widget.cursoId);
      // Si mientras tanto empezo otro calculo, este resultado ya es viejo.
      if (!mounted || id != _calculoActual) return;
      setState(() => _resultado = resultado);
    } catch (_) {
      // Se conserva el ultimo resultado valido.
    } finally {
      if (mounted && id == _calculoActual) setState(() => _calculando = false);
    }
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  double get _totalUnidades => _unidades.fold<double>(0, (s, u) => s + u.porcentaje);

  // --- Curso ---

  Future<void> _editarCurso() async {
    final uid = _uid;
    if (uid == null) return;
    final nombre = await pedirNombre(
      context,
      titulo: 'Editar curso',
      etiqueta: 'Nombre del curso',
      hint: 'Ej. Soluciones Móviles II',
      inicial: _nombre,
      textoBoton: 'Guardar',
    );
    if (nombre == null) return;
    try {
      await _cursosService.actualizarCurso(uid, Curso(id: widget.cursoId, nombre: _nombre, cicloId: ''), nombre);
      if (!mounted) return;
      setState(() => _nombre = nombre);
      _mostrarMensaje('Curso actualizado.');
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo guardar el curso.');
    }
  }

  Future<void> _eliminarCurso() async {
    final uid = _uid;
    if (uid == null) return;
    final ok = await confirmarEliminar(
      context,
      titulo: 'Eliminar curso',
      mensaje: 'Se eliminará "$_nombre" con todas sus unidades y notas.',
    );
    if (!ok) return;
    try {
      await _cursosService.eliminarCurso(uid, widget.cursoId);
      if (!mounted) return;
      _mostrarMensaje('Curso eliminado.');
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo eliminar el curso.');
    }
  }

  // --- Unidades ---

  Future<void> _crearOEditarUnidad({Unidad? unidad}) async {
    final uid = _uid;
    if (uid == null) return;
    final r = await pedirNombreYPeso(
      context,
      titulo: unidad == null ? 'Nueva unidad' : 'Editar unidad',
      etiquetaNombre: 'Nombre de la unidad',
      hintNombre: 'Ej. Unidad ${_unidades.length + 1}',
      inicialNombre: unidad?.nombre ?? '',
      inicialPeso: unidad?.porcentaje,
      pesoDisponible: 100 - _totalUnidades + (unidad?.porcentaje ?? 0),
      textoBoton: unidad == null ? 'Crear' : 'Guardar',
    );
    if (r == null) return;
    try {
      if (unidad == null) {
        await _service.crearUnidad(uid, widget.cursoId, r.nombre, r.peso);
      } else {
        await _service.actualizarUnidad(uid, widget.cursoId, unidad, r.nombre, r.peso);
      }
      if (mounted) _mostrarMensaje(unidad == null ? 'Unidad creada.' : 'Unidad actualizada.');
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo guardar la unidad.');
    }
  }

  Future<void> _eliminarUnidad(Unidad unidad) async {
    final uid = _uid;
    if (uid == null) return;
    final ok = await confirmarEliminar(
      context,
      titulo: 'Eliminar unidad',
      mensaje: 'Se eliminará "${unidad.nombre}" con todos sus tipos de evaluación y notas.',
    );
    if (!ok) return;
    try {
      await _service.eliminarUnidad(uid, widget.cursoId, unidad.id);
      if (mounted) _mostrarMensaje('Unidad eliminada.');
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo eliminar la unidad.');
    }
  }

  /// H19: agrega al curso las unidades que faltan escaneandolas (una foto por unidad).
  Future<void> _escanearUnidades() async {
    final guardado = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EscanearNotasScreen(
          cicloId: '',
          cicloNombre: 'Curso',
          cursoId: widget.cursoId,
          cursoNombre: _nombre,
          unidadesPrevias: _unidades.length,
          pesoPrevio: _totalUnidades,
        ),
      ),
    );
    if (guardado != null) _actualizarCalculo();
  }

  /// H20: grafico de evolucion por unidad de este curso.
  Future<void> _abrirEvolucion() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EvolucionScreen(
          vistaInicial: VistaEvolucion.porUnidad,
          cursoId: widget.cursoId,
          cursoNombre: _nombre,
        ),
      ),
    );
    _actualizarCalculo();
  }

  /// H23: que evaluaciones pesan mas en la nota de este curso.
  Future<void> _abrirPrioridades() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrioridadesScreen(
          vistaInicial: VistaPrioridades.curso,
          cursoId: widget.cursoId,
          cursoNombre: _nombre,
        ),
      ),
    );
    _actualizarCalculo();
  }

  Future<void> _abrirUnidad(Unidad unidad) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiposEvaluacionScreen(
          cursoId: widget.cursoId,
          cursoNombre: _nombre,
          unidadId: unidad.id,
          unidadNombre: unidad.nombre,
          unidadPorcentaje: unidad.porcentaje,
        ),
      ),
    );
    // Al volver se recalcula con las notas nuevas o modificadas (H14).
    _actualizarCalculo();
  }

  String _resumenUnidad(Unidad unidad) {
    final cantidad = _resultado?.notasRegistradasPorUnidad[unidad.id] ?? 0;
    if (cantidad == 0) return 'Sin notas todavía';
    final notas = cantidad == 1 ? '1 nota' : '$cantidad notas';
    final completa = _resultado?.unidadCompleta[unidad.id] ?? false;
    return '${completa ? 'Completa' : 'En curso'} · $notas';
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Debes iniciar sesión.')));
    }

    return Scaffold(
      appBar: AppBarNivel(
        padre: 'Curso',
        titulo: _nombre,
        acciones: [
          IconButton(
            icon: const Icon(Icons.calculate_rounded),
            tooltip: 'Simulador de notas',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SimuladorScreen(
                    cursoId: widget.cursoId,
                    cursoNombre: _nombre,
                    notasPorUnidad: _resultado?.notasPorUnidad,
                    unidadCompleta: _resultado?.unidadCompleta,
                    pesosPorUnidad: {for (final u in _unidades) u.id: u.porcentaje},
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.show_chart_rounded),
            tooltip: 'Evolución por unidad',
            onPressed: _abrirEvolucion,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Más opciones',
            onPressed: () => mostrarOpciones(
              context,
              titulo: _nombre,
              opciones: [
                OpcionMenu(icono: Icons.document_scanner_rounded, texto: 'Escanear unidades', onTap: _escanearUnidades),
                OpcionMenu(icono: Icons.edit_rounded, texto: 'Editar curso', onTap: _editarCurso),
                OpcionMenu(
                  icono: Icons.delete_outline_rounded,
                  texto: 'Eliminar curso',
                  onTap: _eliminarCurso,
                  destructiva: true,
                ),
              ],
            ),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? const Center(child: Text('Error al cargar las unidades.'))
              : RefreshIndicator(
                  onRefresh: _actualizarCalculo,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: _unidades.isEmpty ? _contenidoVacio() : _contenido(context),
                  ),
                ),
    );
  }

  List<Widget> _contenidoVacio() => [
        const SizedBox(height: 16),
        EstadoVacio(
          icono: Icons.view_agenda_rounded,
          titulo: 'Aún no hay unidades',
          texto: 'Agrega las unidades del curso con su peso. Luego registra sus notas y '
              'Pondera calcula la nota final.',
          textoBoton: 'Agregar primera unidad',
          onPressed: _crearOEditarUnidad,
          tip: 'Los pesos de las unidades deben sumar 100%.',
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _escanearUnidades,
            icon: const Icon(Icons.document_scanner_rounded),
            label: const Text('Escanear unidades'),
          ),
        ),
      ];

  List<Widget> _contenido(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    final resultado = _resultado;
    final total = _totalUnidades;
    final tonos = AppTheme.tonosPeso(Theme.of(context).brightness);
    final principal = resultado == null ? null : CalculosPrioridades.deCurso(resultado.estructuras).principal;

    final completo = resultado?.estado == EstadoCalculoCurso.completo;
    final evaluado = FormatoNota.porcentaje(resultado?.porcentajeEvaluado ?? 0);
    final String pie;
    if (resultado == null) {
      pie = 'Calculando la nota del curso…';
    } else if (completo) {
      pie = 'Curso completo · nota final sobre 20';
    } else if (resultado.estado == EstadoCalculoCurso.sinDatos) {
      pie = 'Registra notas en las unidades para ver tu promedio.';
    } else {
      // Mientras falten notas no se da el curso por aprobado: se dice cuanto falta.
      final necesaria = resultado.notaNecesariaParaAprobar;
      final pendiente = FormatoNota.porcentaje(resultado.porcentajePendiente);
      pie = switch (resultado.avance) {
        AvanceCurso.asegurado => '$evaluado% evaluado · ya aseguraste el 10.5 aunque falte el $pendiente%',
        AvanceCurso.sinOpcion => '$evaluado% evaluado · ni con 20 en el $pendiente% que falta llegarías a 10.5',
        _ when necesaria != null =>
          '$evaluado% evaluado · necesitas ${FormatoNota.nota(necesaria)} en el $pendiente% que falta para aprobar',
        _ => '$evaluado% del curso evaluado',
      };
    }

    return [
      CardResultadoExpandida(
        nota: resultado?.notaActual,
        titulo: completo ? 'Nota final del curso' : 'Promedio parcial',
        pie: pie,
        avance: resultado?.avance,
      ),
      // H14: si falta informacion se dice que falta, sin dar la nota como final.
      if (resultado != null && !completo && resultado.estado != EstadoCalculoCurso.sinDatos) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: estado.avisoFondo, borderRadius: BorderRadius.circular(16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_rounded, color: estado.onAvisoFondo, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  resultado.mensajeEstado,
                  style: TextStyle(fontSize: 14, height: 1.35, color: estado.onAvisoFondo),
                ),
              ),
            ],
          ),
        ),
      ],
      if (_calculando && resultado != null)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      const SizedBox(height: 16),
      if (principal != null) ...[
        TarjetaPrioridad(principal: principal, onTap: _abrirPrioridades),
        const SizedBox(height: 12),
      ],
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Peso de las unidades', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  LineaPesos(suma: total, compacta: true),
                ],
              ),
              const SizedBox(height: 12),
              BarraPesos(pesos: [for (final u in _unidades) u.porcentaje]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _unidades.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: tonos[i % tonos.length], shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_unidades[i].nombre} ${FormatoNota.porcentaje(_unidades[i].porcentaje)}%',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      SeccionTitulo(
        'Unidades',
        trailing: TextButton.icon(
          onPressed: _crearOEditarUnidad,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Unidad'),
        ),
      ),
      const SizedBox(height: 6),
      for (final unidad in _unidades) ...[
        TarjetaUnidad(
          key: ValueKey(unidad.id),
          nombre: unidad.nombre,
          peso: unidad.porcentaje,
          nota: resultado?.promedioParcialPorUnidad[unidad.id],
          resumen: _resumenUnidad(unidad),
          onTap: () => _abrirUnidad(unidad),
          onLongPress: () => mostrarOpciones(
            context,
            titulo: unidad.nombre,
            opciones: [
              OpcionMenu(icono: Icons.edit_rounded, texto: 'Editar unidad', onTap: () => _crearOEditarUnidad(unidad: unidad)),
              OpcionMenu(
                icono: Icons.delete_outline_rounded,
                texto: 'Eliminar unidad',
                onTap: () => _eliminarUnidad(unidad),
                destructiva: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Mantén presionada una unidad para editarla o eliminarla.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      ),
    ];
  }
}
