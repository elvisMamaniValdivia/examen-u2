class Ciclo {
  final String id;
  final String nombre;
  final DateTime fechaInicio;

  Ciclo({
    required this.id,
    required this.nombre,
    required this.fechaInicio,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'fechaInicio': fechaInicio.toIso8601String(),
    };
  }

  factory Ciclo.fromMap(
    String documentId,
    Map<String, dynamic> map,
  ) {
    return Ciclo(
      id: documentId,
      nombre: map['nombre'] ?? '',
      fechaInicio: map['fechaInicio'] is String
          ? DateTime.tryParse(map['fechaInicio']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}