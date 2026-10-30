
class CalculadoraPromedio {
  /// Valida que existan al menos 2 componentes
  static bool tieneComponentesSuficientes(List componentes) {
    return componentes.length >= 2;
  }

  /// Valida notas (0-20) y pesos (0-100)
  static bool validarRangos(List componentes) {
    for (var c in componentes) {
      if (c.nota < 0 || c.nota > 20 || c.peso <= 0 || c.peso > 100) {
        return false;
      }
    }
    return true;
  }

  /// Valida que los pesos sumen 100 con tolerancia de 0.1
  static bool validarSumaPesos(List componentes) {
    if (componentes.isEmpty) return false;
    double suma = componentes.fold(0.0, (prev, elem) => prev + elem.peso);
    return (suma - 100.0).abs() <= 0.1;
  }

  /// Retorna el promedio ponderado o null si las validaciones no pasan
  static double? calcularPromedio(List componentes) {
    if (!tieneComponentesSuficientes(componentes) ||
        !validarRangos(componentes) ||
        !validarSumaPesos(componentes)) {
      return null;
    }
    return componentes.fold<double>(
      0.0,
      (prev, c) => prev + (c.nota * (c.peso / 100.0)),
    );
  }

  /// Nota aprobatoria mínima: 10.5
  static bool esAprobado(double promedio) {
    return promedio >= 10.5;
  }
}