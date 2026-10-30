class TipoEvaluacion {
  final String id;
  final String nombre;
  final double porcentaje;

  TipoEvaluacion({
    required this.id,
    required this.nombre,
    required this.porcentaje,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'porcentaje': porcentaje,
    };
  }

  factory TipoEvaluacion.fromMap(String documentId, Map<String, dynamic> map) {
    return TipoEvaluacion(
      id: documentId,
      nombre: map['nombre'] ?? '',
      porcentaje: (map['porcentaje'] ?? 0.0).toDouble(),
    );
  }
}
