import '../models/nota.dart';
import '../models/tipo_evaluacion.dart';
import '../models/unidad.dart';

/// Contenedor de un tipo de evaluación con sus notas individuales.
class EstructuraTipoEvaluacion {
  final TipoEvaluacion tipo;
  final List<Nota> notas;

  const EstructuraTipoEvaluacion({
    required this.tipo,
    required this.notas,
  });

  /// Promedio simple de las notas de este tipo. Retorna `null` si no hay notas.
  double? get promedio {
    if (notas.isEmpty) return null;
    final suma = notas.fold<double>(0.0, (acc, n) => acc + n.valor);
    return suma / notas.length;
  }

  bool get estaCompleto => notas.isNotEmpty;
}

/// Contenedor de una unidad con sus tipos de evaluación y notas.
class EstructuraUnidad {
  final Unidad unidad;
  final List<EstructuraTipoEvaluacion> tipos;

  const EstructuraUnidad({
    required this.unidad,
    required this.tipos,
  });

  /// Suma de porcentajes de los tipos de evaluación en esta unidad.
  double get totalPorcentajeTipos {
    return tipos.fold<double>(0.0, (acc, t) => acc + t.tipo.porcentaje);
  }

  /// Valida si los tipos suman 100% (con tolerancia de 0.1).
  bool get porcentajesTiposValidos {
    if (tipos.isEmpty) return false;
    return (totalPorcentajeTipos - 100.0).abs() <= 0.1;
  }

  /// Indica si la unidad tiene todos sus tipos con al menos una nota y suma 100%.
  bool get estaCompleta {
    if (!porcentajesTiposValidos) return false;
    return tipos.every((t) => t.estaCompleto);
  }

  /// Suma de porcentajes de los tipos que ya tienen al menos una nota.
  double get porcentajeTiposEvaluados {
    return tipos
        .where((t) => t.estaCompleto)
        .fold<double>(0.0, (acc, t) => acc + t.tipo.porcentaje);
  }

  /// Cantidad total de notas registradas en la unidad.
  int get cantidadNotas => tipos.fold<int>(0, (acc, t) => acc + t.notas.length);

  /// Promedio de lo evaluado hasta ahora (escala 0-20).
  /// A diferencia de [notaCalculada], no cuenta como 0 los tipos sin notas:
  /// si solo hay Examen (40 %) con 13, el promedio parcial es 13 y no 5.2.
  double? get promedioParcial {
    final nota = notaCalculada;
    final evaluado = porcentajeTiposEvaluados;
    if (nota == null || evaluado <= 0) return null;
    return nota / (evaluado / 100.0);
  }

  /// Nota calculada ponderada de la unidad.
  /// Si ningún tipo tiene notas, retorna `null`.
  double? get notaCalculada {
    if (tipos.isEmpty) return null;
    double sumaPonderada = 0.0;
    bool tieneNotas = false;

    for (final t in tipos) {
      final prom = t.promedio;
      if (prom != null) {
        tieneNotas = true;
        sumaPonderada += prom * (t.tipo.porcentaje / 100.0);
      }
    }

    if (!tieneNotas) return null;
    return sumaPonderada;
  }
}

/// Estados posibles del cálculo multinivel de un curso.
enum EstadoCalculoCurso {
  completo,
  incompleto,
  sinDatos,
}

/// Resultado del cálculo multinivel del promedio final de un curso.
class ResultadoCalculoCurso {
  /// Nota final del curso redondeada a 1 decimal.
  /// Solo tiene valor si `estado == EstadoCalculoCurso.completo`.
  final double? notaFinal;

  /// Nota acumulada con las evaluaciones registradas hasta el momento.
  final double? notaAcumulada;

  /// Estado del cálculo.
  final EstadoCalculoCurso estado;

  /// Mensaje descriptivo para el usuario (indica qué información falta si está incompleto).
  final String mensajeEstado;

  /// Notas calculadas por cada unidad (id -> nota).
  final Map<String, double?> notasPorUnidad;

  /// Estado de completitud por cada unidad (id -> estaCompleta).
  final Map<String, bool> unidadCompleta;

  /// Promedio de lo evaluado hasta ahora, redondeado a 1 decimal.
  /// Es la nota que el curso tendria si se mantiene el rendimiento actual.
  final double? promedioParcial;

  /// Porcentaje del curso que ya tiene notas (0-100).
  final double porcentajeEvaluado;

  /// Promedio parcial de cada unidad (id -> promedio de lo evaluado).
  final Map<String, double?> promedioParcialPorUnidad;

  /// Cantidad de notas registradas por unidad (id -> cantidad).
  final Map<String, int> notasRegistradasPorUnidad;

  /// Unidades del curso en el orden en que se muestran (Unidad 1, 2, 3...).
  final List<Unidad> unidades;

  /// Estructura usada en el cálculo (unidades, tipos y notas), para H23.
  final List<EstructuraUnidad> estructuras;

  const ResultadoCalculoCurso({
    this.notaFinal,
    this.notaAcumulada,
    required this.estado,
    required this.mensajeEstado,
    required this.notasPorUnidad,
    required this.unidadCompleta,
    this.promedioParcial,
    this.porcentajeEvaluado = 0,
    this.promedioParcialPorUnidad = const {},
    this.notasRegistradasPorUnidad = const {},
    this.unidades = const [],
    this.estructuras = const [],
  });

  /// Nota a mostrar: la final si el calculo esta completo, si no el promedio parcial.
  double? get notaActual => notaFinal ?? promedioParcial;

  /// Determina si la nota es aprobatoria (>= 10.5).
  bool get esAprobado {
    final valor = notaActual;
    if (valor == null) return false;
    return valor >= 10.5;
  }

  /// Parte del curso que aún no tiene notas (0-100).
  double get porcentajePendiente => (100 - porcentajeEvaluado).clamp(0.0, 100.0);

  /// Nota que hace falta en lo pendiente para terminar con 10.5.
  /// `null` si el curso está completo o aún no tiene notas.
  /// <= 0 significa que ya está asegurado; > 20, que ya no se alcanza.
  double? get notaNecesariaParaAprobar {
    final acumulada = notaAcumulada;
    final pendiente = porcentajePendiente;
    if (estado == EstadoCalculoCurso.completo || acumulada == null || pendiente <= 0) return null;
    return CalculosMultinivel.redondearUnDecimal((10.5 - acumulada) / (pendiente / 100.0));
  }

  /// Situación del curso mientras faltan notas; `null` si está completo o sin notas.
  AvanceCurso? get avance {
    final necesaria = notaNecesariaParaAprobar;
    final parcial = promedioParcial;
    if (necesaria == null || parcial == null) return null;
    if (necesaria <= 0) return AvanceCurso.asegurado;
    if (necesaria > 20) return AvanceCurso.sinOpcion;
    return parcial >= 10.5 ? AvanceCurso.vasAprobando : AvanceCurso.enRiesgo;
  }
}

/// Cómo va un curso que todavía tiene evaluaciones pendientes.
enum AvanceCurso {
  /// Lo acumulado ya llega a 10.5.
  asegurado,

  /// El promedio de lo evaluado está sobre 10.5.
  vasAprobando,

  /// El promedio de lo evaluado está bajo 10.5, pero aún se puede aprobar.
  enRiesgo,

  /// Ni con 20 en lo pendiente se llega a 10.5.
  sinOpcion,
}

/// Lógica de cálculo multinivel para promedios de curso:
/// Promedio del tipo -> Nota de unidad -> Nota final del curso.
class CalculosMultinivel {
  /// Orden natural de nombres: "Unidad 2" antes que "Unidad 10".
  static int _compararNatural(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final pa = re.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
    final pb = re.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final na = int.tryParse(pa[i]);
      final nb = int.tryParse(pb[i]);
      final c = (na != null && nb != null) ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }

  /// '"Unidad 2"', '"Unidad 2" y "Unidad 3"', '"U1", "U2" y "U3"'.
  static String _listar(List<String> nombres) {
    final citados = [for (final n in nombres) '"$n"'];
    if (citados.length == 1) return citados.first;
    return '${citados.sublist(0, citados.length - 1).join(', ')} y ${citados.last}';
  }

  /// Redondea un valor numérico a un decimal según el criterio de aceptación.
  static double redondearUnDecimal(double valor) {
    return double.parse(valor.toStringAsFixed(1));
  }

  /// Ejecuta el cálculo multinivel completo sobre la lista de unidades del curso.
  static ResultadoCalculoCurso calcular(List<EstructuraUnidad> unidades) {
    final Map<String, double?> notasPorUnidad = {};
    final Map<String, bool> unidadCompleta = {};

    if (unidades.isEmpty) {
      return const ResultadoCalculoCurso(
        notaFinal: null,
        notaAcumulada: null,
        estado: EstadoCalculoCurso.sinDatos,
        mensajeEstado: 'No hay unidades registradas en este curso.',
        notasPorUnidad: {},
        unidadCompleta: {},
      );
    }

    // 1. Validar la suma de porcentajes de las unidades del curso (debe ser 100%)
    final totalPorcentajeUnidades = unidades.fold<double>(
      0.0,
      (acc, u) => acc + u.unidad.porcentaje,
    );
    final porcentajesUnidadesValidos =
        (totalPorcentajeUnidades - 100.0).abs() <= 0.1;

    final List<String> motivosIncompletos = [];

    if (!porcentajesUnidadesValidos) {
      motivosIncompletos.add(
        'Los pesos de las unidades deben sumar 100% (actualmente ${totalPorcentajeUnidades.toStringAsFixed(1)}%).',
      );
    }

    // 2. Procesar cada unidad
    double sumaPonderadaCurso = 0.0;
    double porcentajeEvaluado = 0.0;
    bool algunaNotaRegistrada = false;
    final Map<String, double?> promedioParcialPorUnidad = {};
    final Map<String, int> notasRegistradasPorUnidad = {};
    // En orden natural para que los avisos salgan como Unidad 1, 2, 3...
    final ordenadas = [...unidades]..sort((a, b) => _compararNatural(a.unidad.nombre, b.unidad.nombre));
    final unidadesOrdenadas = [for (final u in ordenadas) u.unidad];
    final List<String> unidadesSinTipos = [];

    for (final estUnidad in ordenadas) {
      final uId = estUnidad.unidad.id;
      final uNombre = estUnidad.unidad.nombre;
      final notaUnidad = estUnidad.notaCalculada;

      notasPorUnidad[uId] = notaUnidad;
      unidadCompleta[uId] = estUnidad.estaCompleta;
      promedioParcialPorUnidad[uId] = estUnidad.promedioParcial;
      notasRegistradasPorUnidad[uId] = estUnidad.cantidadNotas;
      porcentajeEvaluado +=
          estUnidad.unidad.porcentaje * (estUnidad.porcentajeTiposEvaluados / 100.0);

      if (estUnidad.tipos.isEmpty) {
        unidadesSinTipos.add(uNombre);
      } else if (!estUnidad.porcentajesTiposValidos) {
        motivosIncompletos.add(
          'Los tipos de evaluación en "$uNombre" deben sumar 100% (actualmente ${estUnidad.totalPorcentajeTipos.toStringAsFixed(1)}%).',
        );
      } else {
        // Verificar si algún tipo no tiene notas
        final tiposSinNotas = estUnidad.tipos
            .where((t) => !t.estaCompleto)
            .map((t) => t.tipo.nombre)
            .toList();

        if (tiposSinNotas.isNotEmpty) {
          motivosIncompletos.add(
            'Faltan notas en "$uNombre" (${tiposSinNotas.join(', ')}).',
          );
        }
      }

      if (notaUnidad != null) {
        algunaNotaRegistrada = true;
        sumaPonderadaCurso += notaUnidad * (estUnidad.unidad.porcentaje / 100.0);
      }
    }

    // Un solo aviso para todas las unidades sin tipos: "Unidad 2" y "Unidad 3".
    if (unidadesSinTipos.isNotEmpty) {
      motivosIncompletos.add(
        'Falta registrar tipos de evaluación en ${_listar(unidadesSinTipos)}.',
      );
    }
    // Se muestran todos los motivos, uno por línea.
    final mensajeIncompleto = motivosIncompletos.join('\n');

    // Si no hay ninguna nota en todo el curso
    if (!algunaNotaRegistrada) {
      return ResultadoCalculoCurso(
        notaFinal: null,
        notaAcumulada: null,
        estado: EstadoCalculoCurso.sinDatos,
        mensajeEstado: motivosIncompletos.isNotEmpty
            ? mensajeIncompleto
            : 'No hay notas registradas en este curso.',
        notasPorUnidad: notasPorUnidad,
        unidadCompleta: unidadCompleta,
        promedioParcialPorUnidad: promedioParcialPorUnidad,
        notasRegistradasPorUnidad: notasRegistradasPorUnidad,
        unidades: unidadesOrdenadas,
        estructuras: unidades,
      );
    }

    final promedioParcial = porcentajeEvaluado > 0
        ? redondearUnDecimal(sumaPonderadaCurso / (porcentajeEvaluado / 100.0))
        : null;
    final evaluadoRedondeado = redondearUnDecimal(porcentajeEvaluado);

    // Si falta información en alguna unidad o porcentaje
    if (motivosIncompletos.isNotEmpty) {
      return ResultadoCalculoCurso(
        notaFinal: null,
        notaAcumulada: redondearUnDecimal(sumaPonderadaCurso),
        estado: EstadoCalculoCurso.incompleto,
        mensajeEstado: mensajeIncompleto,
        notasPorUnidad: notasPorUnidad,
        unidadCompleta: unidadCompleta,
        promedioParcial: promedioParcial,
        porcentajeEvaluado: evaluadoRedondeado,
        promedioParcialPorUnidad: promedioParcialPorUnidad,
        notasRegistradasPorUnidad: notasRegistradasPorUnidad,
        unidades: unidadesOrdenadas,
        estructuras: unidades,
      );
    }

    // Cálculo multinivel completo y exacto
    final notaFinalRedondeada = redondearUnDecimal(sumaPonderadaCurso);

    return ResultadoCalculoCurso(
      notaFinal: notaFinalRedondeada,
      notaAcumulada: notaFinalRedondeada,
      estado: EstadoCalculoCurso.completo,
      mensajeEstado: 'Cálculo completo',
      notasPorUnidad: notasPorUnidad,
      unidadCompleta: unidadCompleta,
      promedioParcial: notaFinalRedondeada,
      porcentajeEvaluado: evaluadoRedondeado,
      promedioParcialPorUnidad: promedioParcialPorUnidad,
      notasRegistradasPorUnidad: notasRegistradasPorUnidad,
      unidades: unidadesOrdenadas,
      estructuras: unidades,
    );
  }
}
