import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore no elimina las subcolecciones al borrar un documento.
/// Estas funciones borran un nivel junto con todo lo que cuelga de el,
/// para no dejar unidades, tipos de evaluacion o notas huerfanas.
class BorradoCascada {
  /// Borra una unidad con sus tipos de evaluacion y notas.
  static Future<void> unidad(DocumentReference<Map<String, dynamic>> unidadRef) async {
    final tipos = await unidadRef.collection('tiposEvaluacion').get();
    final notasPorTipo = await Future.wait(
      tipos.docs.map((t) => t.reference.collection('notas').get()),
    );

    final batch = unidadRef.firestore.batch();
    for (final notas in notasPorTipo) {
      for (final nota in notas.docs) {
        batch.delete(nota.reference);
      }
    }
    for (final tipo in tipos.docs) {
      batch.delete(tipo.reference);
    }
    batch.delete(unidadRef);
    await batch.commit();
  }

  /// Borra un curso con sus unidades, tipos de evaluacion y notas.
  static Future<void> curso(DocumentReference<Map<String, dynamic>> cursoRef) async {
    final unidades = await cursoRef.collection('unidades').get();
    await Future.wait(unidades.docs.map((u) => unidad(u.reference)));
    await cursoRef.delete();
  }
}
