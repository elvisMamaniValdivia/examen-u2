import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/nota.dart';
import '../models/tipo_evaluacion.dart';

class EvaluacionesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tiposRef(
    String uid,
    String cursoId,
    String unidadId,
  ) {
    return _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('cursos')
        .doc(cursoId)
        .collection('unidades')
        .doc(unidadId)
        .collection('tiposEvaluacion');
  }

  CollectionReference<Map<String, dynamic>> _notasRef(
    String uid,
    String cursoId,
    String unidadId,
    String tipoId,
  ) {
    return _tiposRef(uid, cursoId, unidadId)
        .doc(tipoId)
        .collection('notas');
  }

  // --- CRUD TIPOS DE EVALUACIÓN ---

  Stream<List<TipoEvaluacion>> obtenerTiposEvaluacion(
    String uid,
    String cursoId,
    String unidadId,
  ) {
    return _tiposRef(uid, cursoId, unidadId).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => TipoEvaluacion.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> crearTipoEvaluacion(
    String uid,
    String cursoId,
    String unidadId,
    String nombre,
    double porcentaje,
  ) async {
    final ref = _tiposRef(uid, cursoId, unidadId).doc();
    final tipo = TipoEvaluacion(
      id: ref.id,
      nombre: nombre.trim(),
      porcentaje: porcentaje,
    );
    await ref.set(tipo.toMap());
  }

  /// Crea o actualiza un tipo junto con su única nota en un solo lote, para que
  /// sin conexión ambos cambios se apliquen a la vez en el teléfono.
  ///
  /// - [tipo] `null` crea un tipo nuevo.
  /// - [notaActual] es la nota que ya tenía; [nota] `null` la borra.
  /// - Con [conNota] en false solo se cambian nombre y peso.
  Future<void> guardarComponente(
    String uid,
    String cursoId,
    String unidadId, {
    TipoEvaluacion? tipo,
    required String nombre,
    required double porcentaje,
    Nota? notaActual,
    double? nota,
    bool conNota = true,
  }) {
    final batch = _firestore.batch();
    final tipoRef = tipo == null ? _tiposRef(uid, cursoId, unidadId).doc() : _tiposRef(uid, cursoId, unidadId).doc(tipo.id);
    final datosTipo = {'nombre': nombre.trim(), 'porcentaje': porcentaje};
    if (tipo == null) {
      batch.set(tipoRef, datosTipo);
    } else {
      batch.update(tipoRef, datosTipo);
    }

    if (conNota) {
      final notas = tipoRef.collection('notas');
      if (nota == null) {
        if (notaActual != null) batch.delete(notas.doc(notaActual.id));
      } else if (notaActual == null) {
        final ref = notas.doc();
        batch.set(
          ref,
          Nota(id: ref.id, valor: nota, fecha: DateTime.now(), tipoEvaluacionId: tipoRef.id).toMap(),
        );
      } else if (nota != notaActual.valor) {
        batch.update(notas.doc(notaActual.id), {'valor': nota});
      }
    }
    return batch.commit();
  }

  Future<void> actualizarTipoEvaluacion(
    String uid,
    String cursoId,
    String unidadId,
    TipoEvaluacion tipo,
    String nombre,
    double porcentaje,
  ) async {
    await _tiposRef(uid, cursoId, unidadId).doc(tipo.id).update({
      'nombre': nombre.trim(),
      'porcentaje': porcentaje,
    });
  }

  Future<void> eliminarTipoEvaluacion(
    String uid,
    String cursoId,
    String unidadId,
    String tipoId,
  ) async {
    // Eliminar notas anidadas en la subcolección
    final notasSnapshot = await _notasRef(uid, cursoId, unidadId, tipoId).get();
    final batch = _firestore.batch();
    for (final doc in notasSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_tiposRef(uid, cursoId, unidadId).doc(tipoId));
    await batch.commit();
  }

  // --- CRUD NOTAS ---

  Stream<List<Nota>> obtenerNotas(
    String uid,
    String cursoId,
    String unidadId,
    String tipoId,
  ) {
    return _notasRef(uid, cursoId, unidadId, tipoId)
        .orderBy('fecha', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Nota.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> crearNota(
    String uid,
    String cursoId,
    String unidadId,
    String tipoId,
    double valor, {
    String nombre = '',
    DateTime? fecha,
  }) async {
    final ref = _notasRef(uid, cursoId, unidadId, tipoId).doc();
    final nota = Nota(
      id: ref.id,
      valor: valor,
      nombre: nombre.trim(),
      fecha: fecha ?? DateTime.now(),
      tipoEvaluacionId: tipoId,
    );
    await ref.set(nota.toMap());
  }

  Future<void> actualizarNota(
    String uid,
    String cursoId,
    String unidadId,
    String tipoId,
    String notaId,
    double valor, {
    String? nombre,
    DateTime? fecha,
  }) async {
    final Map<String, dynamic> data = {'valor': valor};
    if (nombre != null) {
      data['nombre'] = nombre.trim();
    }
    if (fecha != null) {
      data['fecha'] = Timestamp.fromDate(fecha);
    }
    await _notasRef(uid, cursoId, unidadId, tipoId).doc(notaId).update(data);
  }

  Future<void> eliminarNota(
    String uid,
    String cursoId,
    String unidadId,
    String tipoId,
    String notaId,
  ) async {
    await _notasRef(uid, cursoId, unidadId, tipoId).doc(notaId).delete();
  }
}
