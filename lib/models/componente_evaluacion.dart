/// Modelo de datos que representa una evaluación universitaria (ej. Examen Parcial, Tarea 1).
class ComponenteEvaluacion {
  /// Identificador único para mantener referencias consistentes en listas de Flutter (keys).
  final String id;

  /// Nombre o descripción del componente de evaluación.
  final String nombre;

  /// Calificación obtenida o proyectada (rango 0.0 - 20.0).
  final double nota;

  /// Peso o porcentaje ponderado en el curso (rango 0.0 - 100.0).
  final double peso;

  const ComponenteEvaluacion({
    required this.id,
    required this.nombre,
    required this.nota,
    required this.peso,
  });

  /// Método para clonar e iterar sobre copias inmutables del objeto al modificar campos.
  ComponenteEvaluacion copyWith({
    String? id,
    String? nombre,
    double? nota,
    double? peso,
  }) {
    return ComponenteEvaluacion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      nota: nota ?? this.nota,
      peso: peso ?? this.peso,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'nota': nota,
      'peso': peso,
    };
  }

  factory ComponenteEvaluacion.fromMap(Map<String, dynamic> map) {
    return ComponenteEvaluacion(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      nota: (map['nota'] ?? 0.0).toDouble(),
      peso: (map['peso'] ?? 0.0).toDouble(),
    );
  }
}
