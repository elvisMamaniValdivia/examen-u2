import '../services/calculos_multinivel.dart';

class ResultadoSimuladorCurso {
  final double objetivo;
  final double notaActual;
  final double porcentajePendiente;
  final double notaNecesaria;
  final double maximoAlcanzable;
  final int unidadesPendientes;
  final bool objetivoAlcanzable;

  const ResultadoSimuladorCurso({
    required this.objetivo,
    required this.notaActual,
    required this.porcentajePendiente,
    required this.notaNecesaria,
    required this.maximoAlcanzable,
    required this.unidadesPendientes,
    required this.objetivoAlcanzable,
  });
}

class SimuladorCursoService {
  static ResultadoSimuladorCurso calcular({
    required double objetivo,
    required Map<String, double?> notasPorUnidad,
    required Map<String, bool> unidadCompleta,
    required Map<String, double> pesosPorUnidad,
  }) {
    double acumulado = 0;
    double pesoPendiente = 0;
    int cantidadPendientes = 0;

    for (final entry in pesosPorUnidad.entries) {
      final id = entry.key;
      final peso = entry.value;
      final nota = notasPorUnidad[id];
      final completa = unidadCompleta[id] == true && nota != null;

      if (completa) {
        acumulado += nota * peso / 100;
      } else {
        pesoPendiente += peso;
        cantidadPendientes++;
      }
    }

    final maximo = acumulado + (pesoPendiente * 20 / 100);
    final necesaria = pesoPendiente > 0
        ? (objetivo - acumulado) * 100 / pesoPendiente
        : 0.0;

    final notaActual = pesoPendiente < 100
        ? acumulado * 100 / (100 - pesoPendiente)
        : 0.0;

    final pesosValidos =
        (pesosPorUnidad.values.fold<double>(0, (a, b) => a + b) - 100).abs() <=
        0.1;

    final alcanzable =
        pesosValidos && pesoPendiente > 0 && necesaria >= 0 && necesaria <= 20;

    return ResultadoSimuladorCurso(
      objetivo: objetivo,
      notaActual: CalculosMultinivel.redondearUnDecimal(notaActual),
      porcentajePendiente: CalculosMultinivel.redondearUnDecimal(pesoPendiente),
      notaNecesaria: CalculosMultinivel.redondearUnDecimal(necesaria),
      maximoAlcanzable: CalculosMultinivel.redondearUnDecimal(maximo),
      unidadesPendientes: cantidadPendientes,
      objetivoAlcanzable: alcanzable,
    );
  }
}
