class Unidad {
  final String id;
  final String nombre;
  final String cursoId;
  final double porcentaje;

  Unidad({
    required this.id,
    required this.nombre,
    required this.cursoId,
    required this.porcentaje,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'cursoId': cursoId,
      'porcentaje': porcentaje,
    };
  }

  factory Unidad.fromMap(
    String documentId,
    Map<String, dynamic> map,
  ) {
    return Unidad(
      id: documentId,
      nombre: map['nombre'] ?? '',
      cursoId: map['cursoId'] ?? '',
      porcentaje: (map['porcentaje'] as num?)?.toDouble() ?? 0.0,
    );
  }
}