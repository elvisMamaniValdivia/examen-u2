import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/ciclo.dart';
import '../services/calculo_curso_service.dart';
import '../services/ciclos_service.dart';
import '../services/seguridad_storage_service.dart';
import '../services/seguridad_pantalla_service.dart';
import '../widgets/card_resultado.dart';
import '../widgets/dialogos.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/pondera_logo.dart';
import '../widgets/seccion_titulo.dart';
import '../widgets/tarjeta_ciclo.dart';
import 'cursos_screen.dart';

/// Pantalla 03 - Tus ciclos (H10), con su estado vacio (03b)
/// y soporte para examen Tipo 4 (almacenamiento offline seguro y FLAG_SECURE).
class CiclosScreen extends StatefulWidget {
  const CiclosScreen({super.key});

  @override
  State<CiclosScreen> createState() => _CiclosScreenState();
}

class _CiclosScreenState extends State<CiclosScreen> {
  final CiclosService _service = CiclosService();
  final CalculoCursoService _calculoService = CalculoCursoService();
  final OfflineStorageService _offlineService = OfflineStorageService();

  User? _user;
  Stream<List<Ciclo>>? _ciclosStream;

  /// Resumen por ciclo, cacheado para no recalcular en cada build.
  final Map<String, Future<ResumenCiclo>> _resumenes = {};

  List<Ciclo> _ultimosCiclos = const [];
  List<RegistroOffline>? _datosOfflineMostrados;
  String? _errorOfflineMensaje;
  bool _cifradoActivo = true;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    final uid = _user?.uid;
    if (uid != null) _ciclosStream = _service.obtenerCiclos(uid);
  }

  Future<ResumenCiclo> _resumenDe(String cicloId) =>
      _resumenes.putIfAbsent(cicloId, () => _calculoService.obtenerResumenCiclo(_user!.uid, cicloId));

  void _recalcular() => setState(_resumenes.clear);

  String get _nombreUsuario => _user?.email?.split('@').first ?? '';

  String get _iniciales {
    final partes = _nombreUsuario.split(RegExp(r'[._\-\s]+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, partes.first.length.clamp(1, 2)).toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _crearCiclo() async {
    final uid = _user?.uid;
    if (uid == null) return;
    final nombre = await pedirNombre(
      context,
      titulo: 'Nuevo ciclo',
      etiqueta: 'Nombre del ciclo',
      hint: 'Ej. 2026-II',
      textoBoton: 'Crear',
    );
    if (nombre == null) return;
    try {
      await _service.crearCiclo(uid, nombre);
      if (mounted) _mostrarMensaje('Ciclo creado.');
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo crear el ciclo.');
    }
  }

  Future<void> _eliminarCiclo(Ciclo ciclo) async {
    final uid = _user?.uid;
    if (uid == null) return;
    final ok = await confirmarEliminar(
      context,
      titulo: 'Eliminar ciclo',
      mensaje: 'Se eliminará "${ciclo.nombre}" con todos sus cursos, unidades y notas.',
    );
    if (!ok) return;
    try {
      await _service.eliminarCiclo(uid, ciclo.id);
      if (mounted) _mostrarMensaje('Ciclo eliminado.');
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo eliminar el ciclo.');
    }
  }

  Future<void> _abrirCiclo(Ciclo ciclo) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CursosScreen(cicloId: ciclo.id, cicloNombre: ciclo.nombre)),
    );
    _recalcular();
  }

  Future<void> _guardarSinConexion() async {
    _offlineService.cifradoHabilitado = _cifradoActivo;
    final listaAGuardar = <RegistroOffline>[
      const RegistroOffline(
        id: 'cliente_prueba',
        nombre: 'Cliente Prueba',
        detalle: 'Registro de prueba para verificación de cifrado y terminal',
        valor: 19.5,
      ),
      if (_ultimosCiclos.isNotEmpty)
        for (final c in _ultimosCiclos)
          RegistroOffline(
            id: c.id,
            nombre: c.nombre,
            detalle: 'Ciclo académico Pondera',
            valor: 0.0,
          )
      else ...[
        const RegistroOffline(id: 'c1', nombre: 'Cálculo I', detalle: '4 créditos', valor: 16.0),
        const RegistroOffline(id: 'c2', nombre: 'Física II', detalle: '4 créditos', valor: 15.0),
        const RegistroOffline(id: 'c3', nombre: 'Programación Móvil II', detalle: '4 créditos', valor: 19.0),
      ],
    ];

    try {
      await _offlineService.guardarLista(listaAGuardar);
      if (mounted) {
        _mostrarMensaje(
          'Guardado sin conexión (${_cifradoActivo ? "Cifrado AES-GCM" : "Texto claro"}).',
        );
      }
    } catch (e) {
      if (mounted) _mostrarMensaje('Error al guardar sin conexión: $e');
    }
  }

  Future<void> _cargarDatosOffline() async {
    _offlineService.cifradoHabilitado = _cifradoActivo;
    final res = await _offlineService.leerLista();
    setState(() {
      if (res.mensaje != null) {
        _errorOfflineMensaje = res.mensaje;
        _datosOfflineMostrados = null;
      } else {
        _datosOfflineMostrados = res.registros;
        _errorOfflineMensaje = null;
      }
    });
    if (res.mensaje != null && mounted) {
      _mostrarMensaje(res.mensaje!);
    } else if (mounted) {
      _mostrarMensaje('Se cargaron ${_datosOfflineMostrados?.length ?? 0} registros locales.');
    }
  }

  Future<void> _confirmarBorradoDatosLocales() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar datos de este teléfono?'),
        content: const Text(
          'Se eliminará el archivo guardado localmente en la carpeta privada y la clave de cifrado del almacén seguro (Android Keystore).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar datos'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await _offlineService.borrarDatosLocales();
      setState(() {
        _datosOfflineMostrados = null;
        _errorOfflineMensaje = null;
      });
      _mostrarMensaje('Archivo local y clave del sistema eliminados.');
    }
  }

  Future<void> _alternarProteccionPantalla() async {
    if (SeguridadPantallaService.estaProtegida) {
      await SeguridadPantallaService.desactivarProteccion();
      if (mounted) _mostrarMensaje('Protección de pantalla desactivada.');
    } else {
      await SeguridadPantallaService.activarProteccion();
      if (mounted) {
        _mostrarMensaje('FLAG_SECURE activo: capturas bloqueadas y oculta en recientes.');
      }
    }
    setState(() {});
  }

  Widget _construirVistaOffline(BuildContext context, List<RegistroOffline> lista) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade700),
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.amber.shade900),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Modo sin conexión · Datos leídos de la carpeta privada de la app (${_cifradoActivo ? "Descifrado AES-GCM" : "Texto claro"})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.brown.shade900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Registros locales', style: Theme.of(context).textTheme.headlineMedium),
            TextButton.icon(
              icon: const Icon(Icons.cloud_done_rounded, size: 18),
              label: const Text('En línea'),
              onPressed: () {
                setState(() {
                  _datosOfflineMostrados = null;
                  _errorOfflineMensaje = null;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final reg in lista) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.shield_rounded, color: scheme.primary),
              ),
              title: Text(reg.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(reg.detalle.isNotEmpty ? reg.detalle : 'Registro protegido'),
              trailing: reg.valor > 0
                  ? Chip(
                      label: Text(
                        '${reg.valor.toStringAsFixed(1)} pts',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: scheme.secondaryContainer,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _ciclosStream;
    if (stream == null) {
      return const Scaffold(body: Center(child: Text('Debes iniciar sesión para gestionar tus ciclos.')));
    }
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 0,
        title: Row(
          children: [
            const PonderaLogo(size: 32),
            const SizedBox(width: 10),
            Text('Pondera', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_rounded),
            tooltip: 'Guardar sin conexión',
            onPressed: _guardarSinConexion,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.security_rounded),
            tooltip: 'Seguridad y Modo Offline',
            onSelected: (value) async {
              switch (value) {
                case 'guardar':
                  await _guardarSinConexion();
                  break;
                case 'cargar':
                  await _cargarDatosOffline();
                  break;
                case 'cifrado':
                  setState(() => _cifradoActivo = !_cifradoActivo);
                  _mostrarMensaje(
                    _cifradoActivo
                        ? 'Cifrado AES-GCM habilitado (Ítem 2)'
                        : 'Guardado en texto claro habilitado (Ítem 1)',
                  );
                  break;
                case 'flag_secure':
                  await _alternarProteccionPantalla();
                  break;
                case 'borrar':
                  await _confirmarBorradoDatosLocales();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'guardar',
                child: ListTile(
                  leading: Icon(Icons.download_for_offline_rounded),
                  title: Text('Guardar sin conexión'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'cifrado',
                child: ListTile(
                  leading: Icon(_cifradoActivo ? Icons.lock_rounded : Icons.lock_open_rounded),
                  title: Text(_cifradoActivo ? 'Cifrado: AES-GCM (Ítem 2)' : 'Cifrado: Texto claro (Ítem 1)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'cargar',
                child: const ListTile(
                  leading: Icon(Icons.folder_shared_rounded),
                  title: Text('Ver datos guardados (Modo avión)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'flag_secure',
                child: ListTile(
                  leading: Icon(
                    SeguridadPantallaService.estaProtegida
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  title: Text(
                    SeguridadPantallaService.estaProtegida
                        ? 'FLAG_SECURE: Activo (Oculto)'
                        : 'FLAG_SECURE: Inactivo',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'borrar',
                child: ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: Colors.red),
                  title: Text(
                    'Borrar datos de este teléfono',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          Semantics(
            label: 'Cuenta de $_nombreUsuario',
            child: CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                _iniciales,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _datosOfflineMostrados != null
          ? _construirVistaOffline(context, _datosOfflineMostrados!)
          : _errorOfflineMensaje != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _errorOfflineMensaje!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _errorOfflineMensaje = null;
                              _datosOfflineMostrados = null;
                            });
                          },
                          child: const Text('Reintentar en línea'),
                        ),
                      ],
                    ),
                  ),
                )
              : StreamBuilder<List<Ciclo>>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      // Si la carga desde backend falla (modo avión), mostrar automáticamente los datos locales
                      return FutureBuilder<ResultadoLecturaOffline>(
                        future: _offlineService.leerLista(),
                        builder: (context, offlineSnap) {
                          if (offlineSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final res = offlineSnap.data;
                          if (res != null && res.mensaje != null) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  res.mensaje!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (res != null && res.registros.isNotEmpty) {
                            return _construirVistaOffline(context, res.registros);
                          }
                          return const Center(child: Text('No se pudieron cargar los ciclos ni hay datos sin conexión.'));
                        },
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final ciclos = snapshot.data!;
                    _ultimosCiclos = ciclos;

          return RefreshIndicator(
            onRefresh: () async {
              _recalcular();
              await Future.wait(ciclos.map((c) => _resumenDe(c.id)));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
              children: [
                if (_nombreUsuario.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Hola, $_nombreUsuario',
                      style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('Tus ciclos', style: Theme.of(context).textTheme.headlineMedium),
                ),
                const SizedBox(height: 18),
                if (ciclos.isEmpty)
                  EstadoVacio(
                    icono: Icons.school_rounded,
                    titulo: 'Aún no tienes ciclos',
                    texto: 'Crea tu ciclo actual y empieza a registrar tus cursos y notas. '
                        'Pondera calcula el resto.',
                    textoBoton: 'Crear mi primer ciclo',
                    onPressed: _crearCiclo,
                    tip: 'Puedes registrar desde el ciclo 1 hasta el 10.',
                  )
                else ...[
                  _PromedioAcumulado(resumenes: [for (final c in ciclos) _resumenDe(c.id)]),
                  const SizedBox(height: 22),
                  SeccionTitulo(
                    'Ciclos',
                    trailing: Text(
                      'Más reciente primero',
                      style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < ciclos.length; i++) ...[
                    FutureBuilder<ResumenCiclo>(
                      key: ValueKey(ciclos[i].id),
                      future: _resumenDe(ciclos[i].id),
                      builder: (context, resumen) {
                        final r = resumen.data;
                        final cursos = r == null
                            ? 'Cargando cursos…'
                            : r.cantidadCursos == 0
                                ? 'Sin cursos'
                                : '${r.cantidadCursos == 1 ? '1 curso' : '${r.cantidadCursos} cursos'} · ${r.totalCreditos} créditos';
                        return TarjetaCiclo(
                          numero: ciclos.length - i,
                          nombre: ciclos[i].nombre,
                          subtitulo: cursos,
                          promedio: r?.promedio,
                          destacado: i == 0,
                          cargando: resumen.connectionState != ConnectionState.done,
                          onTap: () => _abrirCiclo(ciclos[i]),
                          onLongPress: () => mostrarOpciones(
                            context,
                            titulo: ciclos[i].nombre,
                            opciones: [
                              OpcionMenu(
                                icono: Icons.delete_outline_rounded,
                                texto: 'Eliminar ciclo',
                                onTap: () => _eliminarCiclo(ciclos[i]),
                                destructiva: true,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearCiclo,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo ciclo'),
      ),
    );
  }
}

/// Promedio acumulado: ciclos con notas ponderados por sus créditos evaluados (H21).
class _PromedioAcumulado extends StatelessWidget {
  final List<Future<ResumenCiclo>> resumenes;

  const _PromedioAcumulado({required this.resumenes});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ResumenCiclo>>(
      future: Future.wait(resumenes),
      builder: (context, snapshot) {
        final datos = snapshot.data;
        if (datos == null) {
          return const CardResultado(nota: null, titulo: 'Promedio acumulado', subtitulo: 'Calculando…');
        }
        final promedio = CalculoCursoService.promedioAcumulado(datos);
        final registrados = datos.length == 1 ? '1 ciclo registrado' : '${datos.length} ciclos registrados';
        return CardResultado(
          nota: promedio,
          titulo: 'Promedio acumulado',
          subtitulo: registrados,
        );
      },
    );
  }
}
