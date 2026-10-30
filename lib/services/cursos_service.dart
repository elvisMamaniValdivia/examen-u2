import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/curso.dart';
import 'borrado_cascada.dart';

class CursosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Curso>> obtenerCursos(String uid, String cicloId) {
    return _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('cursos')
        .where('cicloId', isEqualTo: cicloId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Curso.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Lee un curso por su id (null si no existe).
  Future<Curso?> obtenerCurso(String uid, String cursoId) async {
    final doc = await _firestore.collection('usuarios').doc(uid).collection('cursos').doc(cursoId).get();
    final data = doc.data();
    return data == null ? null : Curso.fromMap(doc.id, data);
  }

  Future<void> crearCurso(
    String uid,
    String cicloId,
    String nombre, {
    int creditos = 3,
  }) async {
    final ref = _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('cursos')
        .doc();

    final curso = Curso(
      id: ref.id,
      nombre: nombre.trim(),
      cicloId: cicloId,
      creditos: creditos,
    );

    await ref.set(curso.toMap());
  }

  Future<void> actualizarCurso(
    String uid,
    Curso curso,
    String nombre, {
    int? creditos,
  }) async {
    final datos = <String, dynamic>{
      'nombre': nombre.trim(),
    };
    if (creditos != null) {
      datos['creditos'] = creditos;
    }
    await _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('cursos')
        .doc(curso.id)
        .update(datos);
  }

  Future<void> eliminarCurso(
    String uid,
    String cursoId,
  ) async {
    await BorradoCascada.curso(
      _firestore.collection('usuarios').doc(uid).collection('cursos').doc(cursoId),
    );
  }
}