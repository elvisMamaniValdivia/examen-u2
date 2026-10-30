import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ciclo.dart';
import 'borrado_cascada.dart';

class CiclosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene todos los ciclos del usuario,
  /// ordenados del más reciente al más antiguo.
  Stream<List<Ciclo>> obtenerCiclos(String uid) {
    return _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('ciclos')
        .orderBy('fechaInicio', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Ciclo.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Crea un nuevo ciclo.
  Future<void> crearCiclo(
    String uid,
    String nombre,
  ) async {
    final cicloRef = _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('ciclos')
        .doc();

    final ciclo = Ciclo(
      id: cicloRef.id,
      nombre: nombre.trim(),
      fechaInicio: DateTime.now(),
    );

    await cicloRef.set(ciclo.toMap());
  }

  /// Elimina un ciclo y todos los cursos asociados, con sus unidades,
  /// tipos de evaluacion y notas.
  Future<void> eliminarCiclo(
    String uid,
    String cicloId,
  ) async {
    final usuarioRef = _firestore.collection('usuarios').doc(uid);

    final cursosSnapshot = await usuarioRef
        .collection('cursos')
        .where('cicloId', isEqualTo: cicloId)
        .get();

    await Future.wait(
      cursosSnapshot.docs.map((curso) => BorradoCascada.curso(curso.reference)),
    );

    await usuarioRef.collection('ciclos').doc(cicloId).delete();
  }
}