import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/componente_evaluacion.dart';

class CalculosService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<void> guardar(String uid, List<ComponenteEvaluacion> componentes) async {
    final data = componentes.map((c) => c.toMap()).toList();
    // Timeout para asegurar que detecte la falta de conexion
    await _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('calculos')
        .doc('actual')
        .set({'componentes': data})
        .timeout(const Duration(seconds: 5));
  }

  Future<List<ComponenteEvaluacion>> cargar(String uid) async {
    try {
      final doc = await _firestore
          .collection('usuarios')
          .doc(uid)
          .collection('calculos')
          .doc('actual')
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!['componentes'] as List<dynamic>?;
        if (data != null) {
          return data.map((e) => ComponenteEvaluacion.fromMap(e as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      // Si falla, retornamos vacio para que use los valores por defecto
      return [];
    }
  }
}
