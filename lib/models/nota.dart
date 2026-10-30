import 'package:cloud_firestore/cloud_firestore.dart';

class Nota {
  final String id;
  final double valor;

  /// Descripcion opcional de la nota (ej. "Lab 4 · Widgets"). Vacia si no se indico.
  final String nombre;
  final DateTime? fecha;
  final String tipoEvaluacionId;

  Nota({
    required this.id,
    required this.valor,
    this.nombre = '',
    this.fecha,
    required this.tipoEvaluacionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'valor': valor,
      'nombre': nombre,
      'fecha': fecha != null ? Timestamp.fromDate(fecha!) : null,
      'tipoEvaluacionId': tipoEvaluacionId,
    };
  }

  factory Nota.fromMap(String documentId, Map<String, dynamic> map) {
    return Nota(
      id: documentId,
      valor: (map['valor'] ?? 0.0).toDouble(),
      nombre: map['nombre'] ?? '',
      fecha: (map['fecha'] as Timestamp?)?.toDate(),
      tipoEvaluacionId: map['tipoEvaluacionId'] ?? '',
    );
  }
}
