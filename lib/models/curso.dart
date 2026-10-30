class Curso {
  final String id;
  final String nombre;
  final String cicloId;
  final int creditos;

  Curso({
    required this.id,
    required this.nombre,
    required this.cicloId,
    this.creditos = 3,
  });

  /// Créditos usados en los promedios: 3 si el valor guardado no es válido (H21).
  int get creditosEfectivos => creditos > 0 ? creditos : 3;

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'cicloId': cicloId,
      'creditos': creditos,
    };
  }

  factory Curso.fromMap(String documentId, Map<String, dynamic> map) {
    return Curso(
      id: documentId,
      nombre: map['nombre'] ?? '',
      cicloId: map['cicloId'] ?? '',
      creditos: (map['creditos'] as num?)?.toInt() ?? 3,
    );
  }
}
