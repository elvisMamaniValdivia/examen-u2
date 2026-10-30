import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/nota.dart';
import '../models/tipo_evaluacion.dart';
import '../models/unidad.dart';
import '../services/calculos_evaluaciones.dart';
import '../services/evaluaciones_service.dart';
import '../services/importacion_notas_service.dart';
import '../services/lector_reporte_notas.dart';
import '../services/unidades_service.dart';
import '../utils/formato_nota.dart';
import '../widgets/app_bar_nivel.dart';
import '../widgets/barra_pesos.dart';
import '../widgets/boton_punteado.dart';
import '../widgets/card_resultado.dart';
import '../widgets/dialogos.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/grupo_tipo_evaluacion.dart';
import '../widgets/hoja_nota.dart';
import '../widgets/hoja_simulador_unidad.dart';
import '../widgets/linea_pesos.dart';
import '../widgets/seccion_titulo.dart';
import 'escanear_notas_screen.dart';

/// Pantalla 06 - Detalle de unidad: tipos de evaluacion y notas (H13).
///
/// Los streams de Firestore se abren una sola vez en [initState]. Antes se
/// creaban dentro de build y cada tarjeta avisaba sus notas al padre desde su
/// build, lo que provocaba un ciclo de reconstrucciones sin fin.
class TiposEvaluacionScreen extends StatefulWidget {
  final String cursoId;
  final String cursoNombre;
  final String unidadId;
  final String unidadNombre;
  final double unidadPorcentaje;

  const TiposEvaluacionScreen({
    super.key,
    required this.cursoId,
    required this.cursoNombre,
    required this.unidadId,
    required this.unidadNombre,
    required this.unidadPorcentaje,
  });

  @override
  State<TiposEvaluacionScreen> createState() => _TiposEvaluacionScreenState();
}

class _TiposEvaluacionScreenState extends State<TiposEvaluacionScreen> {
  final EvaluacionesService _service = EvaluacionesService();
  final UnidadesService _unidadesService = UnidadesService();

  late String _nombre = widget.unidadNombre;
  late double _porcentaje = widget.unidadPorcentaje;

  String? _uid;
  StreamSubscription<List<TipoEvaluacion>>? _tiposSub;
  final Map<String, StreamSubscription<List<Nota>>> _notasSubs = {};

  List<TipoEvaluacion> _tipos = [];
  final Map<String, List<Nota>> _notasPorTipo = {};

  /// Notas borradas que se ocultan hasta que Firestore confirme el cambio.
  final Set<String> _ocultas = {};
  bool _cargando = true;
  bool _error = false;
  String? _expandido;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    final uid = _uid;
    if (uid == null) return;
    _tiposSub = _service.obtenerTiposEvaluacion(uid, widget.cursoId, widget.unidadId).listen(
      (tipos) {
        if (!mounted) return;
        setState(() {
          _tipos = tipos;
          _cargando = false;
          _error = false;
          if (_expandido == null || !tipos.any((t) => t.id == _expandido)) {
            _expandido = tipos.isEmpty ? null : tipos.first.id;
          }
        });
        _sincronizarNotas(uid, tipos);
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

  /// Abre un stream de notas por cada tipo nuevo y cierra los de tipos borrados.
  void _sincronizarNotas(String uid, List<TipoEvaluacion> tipos) {
    final ids = tipos.map((t) => t.id).toSet();
    for (final id in _notasSubs.keys.where((id) => !ids.contains(id)).toList()) {
      _notasSubs.remove(id)?.cancel();
      _notasPorTipo.remove(id);
    }
    for (final id in ids.where((id) => !_notasSubs.containsKey(id))) {
      _notasSubs[id] = _service.obtenerNotas(uid, widget.cursoId, widget.unidadId, id).listen((notas) {
        if (!mounted) return;
        setState(() {
          _notasPorTipo[id] = notas;
          final vigentes = notas.map((n) => n.id).toSet();
          _ocultas.removeWhere((oculta) => !vigentes.contains(oculta));
        });
      });
    }
  }

  @override
  void dispose() {
    _tiposSub?.cancel();
    for (final sub in _notasSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  Map<String, List<Nota>> get _notasVisibles => {
        for (final e in _notasPorTipo.entries)
          e.key: e.value.where((n) => !_ocultas.contains(n.id)).toList(),
      };

  /// Primer tipo que aun no tiene nota (para el boton "+ Nota").
  String? get _primerTipoSinNota {
    final notas = _notasVisibles;
    return _tipos.where((t) => (notas[t.id] ?? const []).isEmpty).firstOrNull?.id;
  }

  void _mostrarMensaje(String texto, {SnackBarAction? accion}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), action: accion, duration: const Duration(seconds: 4)));
  }

  // --- Unidad ---

  Future<void> _editarUnidad() async {
    final uid = _uid;
    if (uid == null) return;
    final r = await pedirNombreYPeso(
      context,
      titulo: 'Editar unidad',
      etiquetaNombre: 'Nombre de la unidad',
      hintNombre: 'Ej. Unidad 1',
      inicialNombre: _nombre,
      inicialPeso: _porcentaje,
      textoBoton: 'Guardar',
    );
    if (r == null) return;
    try {
      await _unidadesService.actualizarUnidad(
        uid,
        widget.cursoId,
        Unidad(id: widget.unidadId, nombre: _nombre, cursoId: widget.cursoId, porcentaje: _porcentaje),
        r.nombre,
        r.peso,
      );
      if (!mounted) return;
      setState(() {
        _nombre = r.nombre;
        _porcentaje = r.peso;
      });
      _mostrarMensaje('Unidad actualizada.');
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo guardar la unidad.');
    }
  }

  Future<void> _eliminarUnidad() async {
    final uid = _uid;
    if (uid == null) return;
    final ok = await confirmarEliminar(
      context,
      titulo: 'Eliminar unidad',
      mensaje: 'Se eliminará "$_nombre" con todos sus tipos de evaluación y notas.',
    );
    if (!ok) return;
    try {
      await _unidadesService.eliminarUnidad(uid, widget.cursoId, widget.unidadId);
      if (!mounted) return;
      _mostrarMensaje('Unidad eliminada.');
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo eliminar la unidad.');
    }
  }

  // --- Escaner (H19) ---

  /// Escanea el reporte del portal y guarda sus criterios dentro de esta unidad.
  Future<void> _escanearUnidad() async {
    final uid = _uid;
    if (uid == null) return;
    if (_tipos.isNotEmpty) {
      final ok = await confirmarEliminar(
        context,
        titulo: 'Reemplazar tipos de evaluación',
        mensaje: 'Lo que escanees reemplazará los ${_tipos.length} tipos actuales de $_nombre y sus notas.',
      );
      if (!ok || !mounted) return;
    }
    final leida = await Navigator.of(context).push<UnidadDetectada>(
      MaterialPageRoute(
        builder: (_) => EscanearNotasScreen(
          cicloId: '',
          cicloNombre: 'Curso',
          cursoId: widget.cursoId,
          cursoNombre: widget.cursoNombre,
          unidadNombre: _nombre,
          unidadPeso: _porcentaje,
        ),
      ),
    );
    if (leida == null || !mounted) return;
    final peso = leida.peso;
    if (peso != null) setState(() => _porcentaje = peso);
    try {
      await ImportacionNotasService()
          .llenarUnidad(
            uid: uid,
            cursoId: widget.cursoId,
            unidadId: widget.unidadId,
            unidad: leida,
            tiposAnteriores: {
              for (final t in _tipos) t.id: [for (final n in _notasPorTipo[t.id] ?? const <Nota>[]) n.id],
            },
          )
          .timeout(const Duration(seconds: 8));
      if (mounted) _mostrarMensaje('Notas de $_nombre guardadas.');
    } on TimeoutException {
      if (mounted) _mostrarMensaje('Guardado en este teléfono. Se subirá a tu cuenta cuando haya conexión.');
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo guardar lo escaneado.');
    }
  }

  // --- Tipos de evaluacion ---

  double get _totalTipos => CalculosEvaluaciones.calcularTotalPorcentaje(_tipos);

  Future<void> _crearOEditarTipo({TipoEvaluacion? tipo}) async {
    final uid = _uid;
    if (uid == null) return;
    // Una nota por tipo: se edita junto con el nombre y el peso. Si quedaron
    // varias de versiones anteriores, esas se editan en su lista.
    final notas = tipo == null ? const <Nota>[] : (_notasVisibles[tipo.id] ?? const <Nota>[]);
    final unica = notas.length == 1 ? notas.first : null;
    final r = await pedirComponente(
      context,
      titulo: tipo == null ? 'Nuevo tipo de evaluación' : 'Editar tipo de evaluación',
      inicialNombre: tipo?.nombre ?? '',
      inicialPeso: tipo?.porcentaje,
      inicialNota: unica?.valor,
      pesoDisponible: 100 - _totalTipos + (tipo?.porcentaje ?? 0),
      textoBoton: tipo == null ? 'Crear' : 'Guardar',
      conNota: notas.length <= 1,
    );
    if (r == null) return;
    try {
      // Sin conexion el cambio ya se ve en la pantalla (cache local), pero el
      // servidor no confirma: no se espera indefinidamente.
      await _service
          .guardarComponente(
            uid,
            widget.cursoId,
            widget.unidadId,
            tipo: tipo,
            nombre: r.nombre,
            porcentaje: r.peso,
            notaActual: unica,
            nota: r.nota,
            conNota: notas.length <= 1,
          )
          .timeout(const Duration(seconds: 8));
      if (mounted) _mostrarMensaje(tipo == null ? 'Tipo de evaluación creado.' : 'Cambios guardados.');
    } on TimeoutException {
      if (mounted) _mostrarMensaje('Guardado en este teléfono. Se subirá a tu cuenta cuando haya conexión.');
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo guardar el tipo de evaluación.');
    }
  }

  Future<void> _eliminarTipo(TipoEvaluacion tipo) async {
    final uid = _uid;
    if (uid == null) return;
    final ok = await confirmarEliminar(
      context,
      titulo: 'Eliminar tipo de evaluación',
      mensaje: 'Se eliminará "${tipo.nombre}" y todas sus notas.',
    );
    if (!ok) return;
    try {
      await _service.eliminarTipoEvaluacion(uid, widget.cursoId, widget.unidadId, tipo.id);
      if (mounted) _mostrarMensaje('Tipo de evaluación eliminado.');
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo eliminar el tipo de evaluación.');
    }
  }

  // --- Simulador (H15) ---

  /// "¿Qué nota necesito?": nota necesaria en una evaluacion pendiente para
  /// llegar al promedio objetivo de la unidad.
  void _abrirSimulador() {
    final notas = _notasVisibles;
    if (_tipos.isEmpty) {
      _mostrarMensaje('Primero registra los tipos de evaluación.');
      return;
    }
    if (!CalculosEvaluaciones.validarSumaPorcentajes(_tipos)) {
      _mostrarMensaje('Los pesos deben sumar 100% para simular '
          '(ahora suman ${FormatoNota.porcentaje(_totalTipos)}%).');
      return;
    }
    if (_tipos.every((t) => (notas[t.id] ?? []).isNotEmpty)) {
      _mostrarMensaje('Todas las evaluaciones ya tienen notas: no hay nada pendiente que simular.');
      return;
    }
    mostrarSimuladorUnidad(
      context,
      tipos: _tipos,
      notasPorTipo: notas,
      subtitulo: '$_nombre · ${widget.cursoNombre}',
    );
  }

  // --- Notas ---

  Future<void> _abrirHojaNota({String? tipoId, Nota? nota}) async {
    final uid = _uid;
    if (uid == null || _tipos.isEmpty) return;
    final r = await mostrarHojaNota(
      context,
      tipos: _tipos,
      notasPorTipo: _notasVisibles,
      tipoInicialId: tipoId ?? _primerTipoSinNota ?? _tipos.first.id,
      subtitulo: '$_nombre · ${widget.cursoNombre}',
      nota: nota,
    );
    if (r == null) return;
    if (r.borrar && nota != null) {
      final tipo = _tipos.where((t) => t.id == r.tipoId).firstOrNull;
      if (tipo != null) await _eliminarNota(tipo, nota);
      return;
    }
    try {
      if (nota == null) {
        await _service.crearNota(uid, widget.cursoId, widget.unidadId, r.tipoId, r.valor, nombre: r.nombre);
        if (mounted) setState(() => _expandido = r.tipoId);
        if (mounted) _mostrarMensaje('Nota agregada.');
      } else {
        await _service.actualizarNota(uid, widget.cursoId, widget.unidadId, r.tipoId, nota.id, r.valor, nombre: r.nombre);
        if (mounted) _mostrarMensaje('Nota actualizada.');
      }
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo guardar la nota.');
    }
  }

  /// Borra una nota deslizada y ofrece deshacer durante 4 segundos.
  Future<void> _eliminarNota(TipoEvaluacion tipo, Nota nota) async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _ocultas.add(nota.id));
    try {
      await _service.eliminarNota(uid, widget.cursoId, widget.unidadId, tipo.id, nota.id);
      if (!mounted) return;
      _mostrarMensaje(
        'Nota eliminada',
        accion: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _service.crearNota(
            uid,
            widget.cursoId,
            widget.unidadId,
            tipo.id,
            nota.valor,
            nombre: nota.nombre,
            fecha: nota.fecha,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _ocultas.remove(nota.id));
      _mostrarMensaje('No se pudo eliminar la nota.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Debes iniciar sesión.')));
    }

    final notas = _notasVisibles;
    final total = _totalTipos;
    final pesosValidos = CalculosEvaluaciones.validarSumaPorcentajes(_tipos);
    final notaUnidad = CalculosEvaluaciones.calcularPromedioParcialUnidad(_tipos, notas);
    final todosConNotas = _tipos.isNotEmpty && _tipos.every((t) => (notas[t.id] ?? []).isNotEmpty);
    final esParcial = notaUnidad != null && !(pesosValidos && todosConNotas);

    return Scaffold(
      appBar: AppBarNivel(
        padre: widget.cursoNombre,
        titulo: _nombre,
        acciones: [
          IconButton(
            icon: const Icon(Icons.flag_rounded),
            tooltip: '¿Qué nota necesito?',
            onPressed: _cargando ? null : _abrirSimulador,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Más opciones',
            onPressed: () => mostrarOpciones(
              context,
              titulo: _nombre,
              opciones: [
                OpcionMenu(
                  icono: Icons.document_scanner_rounded,
                  texto: 'Escanear del portal',
                  onTap: _escanearUnidad,
                ),
                OpcionMenu(icono: Icons.edit_rounded, texto: 'Editar unidad', onTap: _editarUnidad),
                OpcionMenu(
                  icono: Icons.delete_outline_rounded,
                  texto: 'Eliminar unidad',
                  onTap: _eliminarUnidad,
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
              ? const Center(child: Text('Error al cargar los tipos de evaluación.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                  children: [
                    CardResultado(
                      nota: notaUnidad,
                      titulo: esParcial ? 'Nota parcial de la unidad' : 'Nota de la unidad',
                      subtitulo: 'Vale ${FormatoNota.porcentaje(_porcentaje)}% del curso',
                    ),
                    const SizedBox(height: 22),
                    if (_tipos.isEmpty) ...[
                      EstadoVacio(
                        icono: Icons.quiz_rounded,
                        titulo: 'Agrega cómo te evalúan',
                        texto: 'Registra los tipos de evaluación de la unidad (examen, laboratorio, '
                            'proyecto...) con su peso, y luego sus notas.',
                        textoBoton: 'Agregar tipo de evaluación',
                        onPressed: _crearOEditarTipo,
                        tip: 'Cada tipo lleva la nota que sale en el portal. Si aún no la tienes, déjala vacía.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _escanearUnidad,
                        icon: const Icon(Icons.document_scanner_rounded),
                        label: const Text('Escanear del portal'),
                      ),
                    ] else ...[
                      SeccionTitulo('Tipos de evaluación', trailing: LineaPesos(suma: total, compacta: true)),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: BarraPesos(pesos: [for (final t in _tipos) t.porcentaje]),
                      ),
                      const SizedBox(height: 16),
                      for (final tipo in _tipos) ...[
                        GrupoTipoEvaluacion(
                          key: ValueKey(tipo.id),
                          tipo: tipo,
                          notas: notas[tipo.id] ?? const [],
                          promedio: CalculosEvaluaciones.calcularPromedioTipo(notas[tipo.id] ?? const []),
                          expandido: _expandido == tipo.id,
                          onToggle: () => setState(() => _expandido = _expandido == tipo.id ? null : tipo.id),
                          onEditarNota: (n) => _abrirHojaNota(tipoId: tipo.id, nota: n),
                          onEliminarNota: (n) => _eliminarNota(tipo, n),
                          onEditarTipo: () => _crearOEditarTipo(tipo: tipo),
                          onEliminarTipo: () => _eliminarTipo(tipo),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 2),
                      BotonPunteado(texto: 'Tipo de evaluación', onPressed: _crearOEditarTipo),
                    ],
                  ],
                ),
    );
  }
}
