import '../models/nota.dart';
import '../models/tipo_evaluacion.dart';

/// Resultado del simulador de la unidad (H15).
class ResultadoSimulacionUnidad {
  /// Nota necesaria en la evaluacion elegida si las demas pendientes aportan cero.
  final double notaNecesaria;

  /// Promedio maximo que puede alcanzar la unidad (20 en todo lo pendiente).
  final double maximoPosible;
  final double objetivo;

  const ResultadoSimulacionUnidad({
    required this.notaNecesaria,
    required this.maximoPosible,
    required this.objetivo,
  });

  /// Ni con 20 en todo lo pendiente se llega al objetivo.
  bool get imposible => objetivo > maximoPosible + 0.000001;

  /// Con las notas actuales ya se llega al objetivo.
  bool get yaAlcanzado => !imposible && notaNecesaria <= 0;

  /// La evaluacion elegida sola no alcanza (necesitaria mas de 20), pero con
  /// las otras pendientes si se puede llegar.
  bool get necesitaOtrasPendientes => !imposible && notaNecesaria > 20;
}

/// Funciones puras de cálculo para tipos de evaluación y notas en una unidad académica.
class CalculosEvaluaciones {
  /// Calcula el promedio simple de una lista de notas dentro de un tipo de evaluación.
  /// Retorna `null` si no hay notas registradas.
  static double? calcularPromedioTipo(List<Nota> notas) {
    if (notas.isEmpty) return null;
    final suma = notas.fold<double>(0.0, (acc, n) => acc + n.valor);
    return suma / notas.length;
  }

  /// Calcula la suma total de los porcentajes de los tipos de evaluación.
  static double calcularTotalPorcentaje(List<TipoEvaluacion> tipos) {
    return tipos.fold<double>(0.0, (acc, t) => acc + t.porcentaje);
  }

  /// Valida si los porcentajes de los tipos de evaluación suman 100% (tolerancia de 0.1).
  static bool validarSumaPorcentajes(List<TipoEvaluacion> tipos) {
    if (tipos.isEmpty) return false;
    final total = calcularTotalPorcentaje(tipos);
    return (total - 100.0).abs() <= 0.1;
  }

  /// Calcula la nota final ponderada de la unidad a partir de los tipos de evaluación
  /// y sus notas asociadas.
  /// Cada tipo con notas aporta: `promedioTipo * (tipo.porcentaje / 100)`.
  /// Si ningún tipo tiene notas registradas, retorna `null`.
  static double? calcularNotaUnidad(
    List<TipoEvaluacion> tipos,
    Map<String, List<Nota>> notasPorTipo,
  ) {
    if (tipos.isEmpty) return null;

    double sumaPonderada = 0.0;
    bool tieneAlMenosUnaNota = false;

    for (final tipo in tipos) {
      final notas = notasPorTipo[tipo.id] ?? [];
      final promedioTipo = calcularPromedioTipo(notas);
      if (promedioTipo != null) {
        tieneAlMenosUnaNota = true;
        sumaPonderada += promedioTipo * (tipo.porcentaje / 100.0);
      }
    }

    if (!tieneAlMenosUnaNota) return null;
    return sumaPonderada;
  }

  /// Promedio de lo evaluado en la unidad (escala 0-20): no cuenta como 0
  /// los tipos que aun no tienen notas. Retorna `null` si no hay notas.
  /// Si todos los tipos tienen notas y suman 100 %, coincide con [calcularNotaUnidad].
  static double? calcularPromedioParcialUnidad(
    List<TipoEvaluacion> tipos,
    Map<String, List<Nota>> notasPorTipo,
  ) {
    final nota = calcularNotaUnidad(tipos, notasPorTipo);
    if (nota == null) return null;
    final evaluado = tipos
        .where((t) => (notasPorTipo[t.id] ?? []).isNotEmpty)
        .fold<double>(0.0, (acc, t) => acc + t.porcentaje);
    if (evaluado <= 0) return null;
    return nota / (evaluado / 100.0);
  }

  /// H15 - Simulador de la unidad: que nota se necesita en una evaluacion
  /// pendiente ([tipoPendienteId], sin notas) para que la unidad llegue a [objetivo].
  ///
  /// Supone que las demas evaluaciones pendientes aportan cero.
  /// Retorna `null` si los pesos no suman 100 % o si el tipo no esta pendiente.
  static ResultadoSimulacionUnidad? simularUnidad({
    required List<TipoEvaluacion> tipos,
    required Map<String, List<Nota>> notasPorTipo,
    required String tipoPendienteId,
    required double objetivo,
  }) {
    if (!validarSumaPorcentajes(tipos)) return null;
    final seleccionado = tipos.where((t) => t.id == tipoPendienteId).firstOrNull;
    if (seleccionado == null || (notasPorTipo[seleccionado.id] ?? []).isNotEmpty) return null;

    double aporteActual = 0;
    double pesoPendiente = 0;
    for (final t in tipos) {
      final promedio = calcularPromedioTipo(notasPorTipo[t.id] ?? []);
      if (promedio != null) {
        aporteActual += promedio * t.porcentaje / 100;
      } else {
        pesoPendiente += t.porcentaje / 100;
      }
    }

    return ResultadoSimulacionUnidad(
      notaNecesaria: (objetivo - aporteActual) / (seleccionado.porcentaje / 100),
      maximoPosible: aporteActual + pesoPendiente * 20,
      objetivo: objetivo,
    );
  }

  /// Determina si una nota es aprobatoria según el estándar peruano (>= 10.5).
  static bool esAprobado(double nota) {
    return nota >= 10.5;
  }
}
