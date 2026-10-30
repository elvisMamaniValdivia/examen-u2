import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/unidad.dart';
import 'borrado_cascada.dart';

class UnidadesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _unidadesRef(
    String uid,
    String cursoId,
  ) {
    return _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('cursos')
        .doc(cursoId)
        .collection('unidades');
  }

  Stream<List<Unidad>> obtenerUnidades(
    String uid,
    String cursoId,
  ) {
    return _unidadesRef(uid, cursoId).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Unidad.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => compararNatural(a.nombre, b.nombre)),
    );
  }

  /// Orden natural: "Unidad 2" va antes que "Unidad 10".
  /// Sin esto Firestore las devuelve por id aleatorio.
  static int compararNatural(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final pa = re.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
    final pb = re.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final na = int.tryParse(pa[i]);
      final nb = int.tryParse(pb[i]);
      final c = (na != null && nb != null) ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }

  Future<void> crearUnidad(
    String uid,
    String cursoId,
    String nombre,
    double porcentaje,
  ) async {
    final ref = _unidadesRef(uid, cursoId).doc();

    final unidad = Unidad(
      id: ref.id,
      nombre: nombre.trim(),
      cursoId: cursoId,
      porcentaje: porcentaje,
    );

    await ref.set(unidad.toMap());
  }

  Future<void> actualizarUnidad(
    String uid,
    String cursoId,
    Unidad unidad,
    String nombre,
    double porcentaje,
  ) async {
    await _unidadesRef(uid, cursoId).doc(unidad.id).update({
      'nombre': nombre.trim(),
      'porcentaje': porcentaje,
    });
  }

  Future<void> eliminarUnidad(
    String uid,
    String cursoId,
    String unidadId,
  ) async {
    await BorradoCascada.unidad(_unidadesRef(uid, cursoId).doc(unidadId));
  }
}