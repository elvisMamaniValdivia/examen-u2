import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:printing/printing.dart';

import '../models/curso.dart';
import '../services/calculo_curso_service.dart';
import '../services/calculos_multinivel.dart';
import '../services/calculos_prioridades.dart';
import '../services/ciclos_service.dart';
import '../services/cursos_service.dart';
import '../services/reporte_ciclo_pdf.dart';
import '../theme/estado_nota_colors.dart';
import '../widgets/app_bar_nivel.dart';
import '../widgets/card_resultado.dart';
import '../widgets/dialogos.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/prioridades.dart';
import '../widgets/seccion_titulo.dart';
import '../widgets/tarjeta_curso.dart';
import 'escanear_notas_screen.dart';
import 'evolucion_screen.dart';
import 'prioridades_screen.dart';
import 'unidades_screen.dart';
import 'vista_previa_pdf_screen.dart';

class CursosScreen extends StatefulWidget {
  final String cicloId;
  final String cicloNombre;

  const CursosScreen({
    super.key,
    required this.cicloId,
    required this.cicloNombre,
  });

  @override
  State<CursosScreen> createState() => _CursosScreenState();
}

class _CursosScreenState extends State<CursosScreen> {
  final CursosService _service = CursosService();
  final CiclosService _ciclosService = CiclosService();
  final CalculoCursoService _calculoService = CalculoCursoService();

  String? _uid;
  Stream<List<Curso>>? _cursosStream;

  String _claveCalculos = '';
  Future<Map<String, ResultadoCalculoCurso>>? _calculos;

  List<Curso> _ultimosCursos = const [];
  Map<String, ResultadoCalculoCurso> _ultimosResultados = const {};
  double? _ultimoPromedio;
  int _ultimosCreditos = 0;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    final uid = _uid;

    if (uid != null) {
      _cursosStream = _service.obtenerCursos(uid, widget.cicloId);
    }
  }

  Future<Map<String, ResultadoCalculoCurso>> _calculosPara(
    List<Curso> cursos,
  ) {
    final clave = cursos.map((c) => c.id).join(',');

    if (_calculos == null || clave != _claveCalculos) {
      _claveCalculos = clave;
      _calculos = _calculoService.obtenerCalculosCursos(_uid!, cursos);
    }

    return _calculos!;
  }

  void _recalcular() {
    setState(() {
      _calculos = null;
    });
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _crearOEditarCurso({Curso? curso}) async {
    final uid = _uid;
    if (uid == null) return;

    final resultado = await pedirNombreYCreditos(
      context,
      titulo: curso == null ? 'Agregar curso' : 'Editar curso',
      etiquetaNombre: 'Nombre del curso',
      hintNombre: 'Ej. Soluciones Móviles II',
      inicialNombre: curso?.nombre ?? '',
      inicialCreditos: curso?.creditos ?? 3,
      textoBoton: curso == null ? 'Agregar' : 'Guardar',
    );

    if (resultado == null) return;

    try {
      if (curso == null) {
        await _service.crearCurso(
          uid,
          widget.cicloId,
          resultado.nombre,
          creditos: resultado.creditos,
        );
      } else {
        await _service.actualizarCurso(
          uid,
          curso,
          resultado.nombre,
          creditos: resultado.creditos,
        );
      }

      if (mounted) {
        _mostrarMensaje(
          curso == null ? 'Curso agregado.' : 'Curso actualizado.',
        );
      }
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo guardar el curso.');
    }
  }

  Future<void> _eliminarCurso(Curso curso) async {
    final uid = _uid;
    if (uid == null) return;

    final ok = await confirmarEliminar(
      context,
      titulo: 'Eliminar curso',
      mensaje:
          'Se eliminará "${curso.nombre}" con todas sus unidades y notas.',
    );

    if (!ok) return;

    try {
      await _service.eliminarCurso(uid, curso.id);
      if (mounted) _mostrarMensaje('Curso eliminado.');
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo eliminar el curso.');
    }
  }

  Future<void> _eliminarCiclo() async {
    final uid = _uid;
    if (uid == null) return;

    final ok = await confirmarEliminar(
      context,
      titulo: 'Eliminar ciclo',
      mensaje:
          'Se eliminará "${widget.cicloNombre}" con todos sus cursos, unidades y notas.',
    );

    if (!ok) return;

    try {
      await _ciclosService.eliminarCiclo(uid, widget.cicloId);

      if (!mounted) return;

      _mostrarMensaje('Ciclo eliminado.');
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo eliminar el ciclo.');
    }
  }

  Future<void> _escanearReporte() async {
    final cursoId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EscanearNotasScreen(
          cicloId: widget.cicloId,
          cicloNombre: widget.cicloNombre,
        ),
      ),
    );

    if (cursoId != null) _recalcular();
  }

  /// H20: grafico comparando los cursos del ciclo.
  Future<void> _abrirEvolucion() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EvolucionScreen(
          vistaInicial: VistaEvolucion.entreCursos,
          cicloId: widget.cicloId,
          cicloNombre: widget.cicloNombre,
        ),
      ),
    );
    if (mounted) _recalcular();
  }

  /// H23: evaluaciones pendientes que mas mueven el promedio del ciclo.
  Future<void> _abrirPrioridades() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrioridadesScreen(
          vistaInicial: VistaPrioridades.ciclo,
          cicloId: widget.cicloId,
          cicloNombre: widget.cicloNombre,
        ),
      ),
    );
    if (mounted) _recalcular();
  }

  Future<void> _abrirCurso(Curso curso) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UnidadesScreen(
          cursoId: curso.id,
          cursoNombre: curso.nombre,
        ),
      ),
    );

    if (mounted) _recalcular();
  }

  Future<void> _exportarPdf({
    required List<Curso> cursos,
    required Map<String, ResultadoCalculoCurso> resultados,
    required double? promedioCiclo,
    required int totalCreditos,
  }) async {
    if (cursos.isEmpty) {
      _mostrarMensaje('No hay cursos para exportar en este ciclo.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final nombreEstudiante = user?.displayName ??
        (user?.isAnonymous == true ? 'Estudiante Invitado' : 'Estudiante');
    final correoEstudiante = user?.email;

    final nombreLimpio =
        widget.cicloNombre.replaceAll(RegExp(r'[^\w\-]'), '_');
    final nombreArchivo = 'Reporte_Pondera_$nombreLimpio.pdf';

    Future<Uint8List> construirPdf() => ReporteCicloPdf.generarPdf(
          cicloNombre: widget.cicloNombre,
          cursos: cursos,
          resultados: resultados,
          promedioCiclo: promedioCiclo,
          totalCreditos: totalCreditos,
          nombreEstudiante: nombreEstudiante,
          correoEstudiante: correoEstudiante,
        );

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Reporte del ciclo (${widget.cicloNombre})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_rounded,
                    color: Color(0xFF3B36C4)),
                title: const Text('Ver e imprimir reporte'),
                subtitle:
                    const Text('Visualiza el PDF con zoom e impresión directa'),
                onTap: () {
                  Navigator.of(bottomContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VistaPreviaPdfScreen(
                        titulo: 'Reporte - ${widget.cicloNombre}',
                        nombreArchivo: nombreArchivo,
                        generadorPdf: construirPdf,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded,
                    color: Color(0xFF157A45)),
                title: const Text('Compartir archivo PDF'),
                subtitle:
                    const Text('Enviar por WhatsApp, correo o guardar'),
                onTap: () async {
                  Navigator.of(bottomContext).pop();
                  try {
                    _mostrarMensaje('Generando reporte PDF…');
                    final pdfBytes = await construirPdf();
                    await Printing.sharePdf(
                      bytes: pdfBytes,
                      filename: nombreArchivo,
                    );
                  } catch (_) {
                    if (mounted) {
                      _mostrarMensaje('No se pudo compartir el PDF.');
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _cursosStream;

    if (stream == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión.')),
      );
    }

    return Scaffold(
      appBar: AppBarNivel(
        padre: 'Ciclo',
        titulo: widget.cicloNombre,
        acciones: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Comparar cursos',
            onPressed: _abrirEvolucion,
          ),
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded),
            tooltip: 'Escanear reporte de notas',
            onPressed: _escanearReporte,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Más opciones',
            onPressed: () => mostrarOpciones(
              context,
              titulo: widget.cicloNombre,
              opciones: [
                if (_ultimosCursos.isNotEmpty)
                  OpcionMenu(
                    icono: Icons.picture_as_pdf_rounded,
                    texto: 'Exportar reporte (PDF)',
                    onTap: () => _exportarPdf(
                      cursos: _ultimosCursos,
                      resultados: _ultimosResultados,
                      promedioCiclo: _ultimoPromedio,
                      totalCreditos: _ultimosCreditos,
                    ),
                  ),
                OpcionMenu(
                  icono: Icons.delete_outline_rounded,
                  texto: 'Eliminar ciclo',
                  onTap: _eliminarCiclo,
                  destructiva: true,
                ),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Curso>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudieron cargar los cursos.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cursos = snapshot.data!;

          if (cursos.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                EstadoVacio(
                  icono: Icons.menu_book_rounded,
                  titulo: 'Aún no tienes cursos',
                  texto:
                      'Agrega los cursos que llevas en ${widget.cicloNombre}. '
                      'Luego registra sus unidades y notas.',
                  textoBoton: 'Agregar primer curso',
                  onPressed: _crearOEditarCurso,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _escanearReporte,
                    icon: const Icon(Icons.document_scanner_rounded),
                    label: const Text('Escanear reporte de notas'),
                  ),
                ),
              ],
            );
          }

          return FutureBuilder<Map<String, ResultadoCalculoCurso>>(
            future: _calculosPara(cursos),
            builder: (context, calc) {
              final resultados = calc.data ?? const {};
              final cargando =
                  calc.connectionState != ConnectionState.done;

              return RefreshIndicator(
                onRefresh: () async {
                  _recalcular();
                  await _calculosPara(cursos);
                },
                child: _lista(context, cursos, resultados, cargando),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearOEditarCurso,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar curso'),
      ),
    );
  }

  Widget _lista(
    BuildContext context,
    List<Curso> cursos,
    Map<String, ResultadoCalculoCurso> resultados,
    bool cargando,
  ) {
    final estado = EstadoNotaColors.of(context);
    final totalCreditos = CalculoCursoService.totalCreditos(cursos);
    final promedio = CalculoCursoService.promedioPonderadoCiclo(
      cursos: cursos,
      resultados: resultados,
    );
    final conNotas =
        resultados.values.where((r) => r.notaActual != null).length;
    final enRiesgo =
        resultados.values.where((r) => (r.notaActual ?? 99) < 10.5).length;
    final principal = cargando ? null : CalculosPrioridades.delCiclo(cursos, resultados, limite: 1).firstOrNull;

    _ultimosCursos = cursos;
    _ultimosResultados = resultados;
    _ultimoPromedio = promedio;
    _ultimosCreditos = totalCreditos;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
      children: [
        CardResultado(
          nota: cargando ? null : promedio,
          titulo: 'Promedio ponderado del ciclo',
          subtitulo: cargando
              ? 'Calculando…'
              : '$totalCreditos créditos · $conNotas de ${cursos.length} cursos con notas',
        ),
        if (principal != null) ...[
          const SizedBox(height: 12),
          TarjetaPrioridad(principal: principal, enCiclo: true, onTap: _abrirPrioridades),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _exportarPdf(
              cursos: cursos,
              resultados: resultados,
              promedioCiclo: promedio,
              totalCreditos: totalCreditos,
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Exportar reporte del ciclo (PDF)'),
          ),
        ),
        const SizedBox(height: 22),
        SeccionTitulo(
          'Cursos · ${cursos.length}',
          trailing: enRiesgo == 0
              ? null
              : Text(
                  enRiesgo == 1 ? '1 en riesgo' : '$enRiesgo en riesgo',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: estado.desaprobado,
                  ),
                ),
        ),
        const SizedBox(height: 10),
        for (final curso in cursos) ...[
          TarjetaCurso(
            key: ValueKey(curso.id),
            nombre: curso.nombre,
            creditos: curso.creditos,
            avance: resultados[curso.id]?.avance,
            nota: resultados[curso.id]?.notaActual,
            pctEvaluado:
                resultados[curso.id]?.porcentajeEvaluado ?? 0,
            cargando: cargando,
            onTap: () => _abrirCurso(curso),
            onLongPress: () => mostrarOpciones(
              context,
              titulo: curso.nombre,
              opciones: [
                OpcionMenu(
                  icono: Icons.edit_rounded,
                  texto: 'Editar curso',
                  onTap: () => _crearOEditarCurso(curso: curso),
                ),
                OpcionMenu(
                  icono: Icons.delete_outline_rounded,
                  texto: 'Eliminar curso',
                  onTap: () => _eliminarCurso(curso),
                  destructiva: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}