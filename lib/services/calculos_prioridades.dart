import '../models/curso.dart';
import 'calculos_multinivel.dart';
import 'unidades_service.dart';

/// Nivel de prioridad de un componente según su peso real en el curso (H23).
enum NivelPrioridad { alta, media, baja }

/// Un tipo de evaluación (Examen, Prácticas...) con su peso real en el curso.
class ComponentePrioridad {
  final String unidadId;
  final String unidadNombre;
  final String tipoId;
  final String tipoNombre;

  /// Curso al que pertenece (solo en la vista del ciclo).
  final Curso? curso;

  /// Peso del tipo dentro de su unidad (0-100).
  final double pesoTipo;

  /// Peso de la unidad dentro del curso (0-100).
  final double pesoUnidad;

  /// Peso real en el curso: pesoTipo x pesoUnidad / 100.
  final double pesoCurso;

  /// Peso real en el promedio del ciclo, ponderado por créditos (solo en la vista del ciclo).
  final double? pesoCiclo;

  /// Promedio de sus notas; `null` si aún no tiene notas (pendiente).
  final double? promedio;
  final int cantidadNotas;

  /// La unidad aún no tiene tipos de evaluación: representa a toda la unidad.
  final bool sinTipos;

  const ComponentePrioridad({
    required this.unidadId,
    required this.unidadNombre,
    required this.tipoId,
    required this.tipoNombre,
    required this.pesoTipo,
    required this.pesoUnidad,
    required this.pesoCurso,
    required this.promedio,
    required this.cantidadNotas,
    this.curso,
    this.pesoCiclo,
    this.sinTipos = false,
  });

  bool get pendiente => promedio == null;

  NivelPrioridad get nivel => CalculosPrioridades.nivelDe(pesoCurso);

  /// Lo que suma a la nota del curso cada punto (de 20) que se saque aquí.
  double get puntosEnCurso => pesoCurso / 100.0;

  /// Lo que suma al promedio del ciclo cada punto que se saque aquí.
  double? get puntosEnCiclo => pesoCiclo == null ? null : pesoCiclo! / 100.0;

  ComponentePrioridad _enCiclo(Curso curso, double pesoCiclo) => ComponentePrioridad(
        unidadId: unidadId,
        unidadNombre: unidadNombre,
        tipoId: tipoId,
        tipoNombre: tipoNombre,
        pesoTipo: pesoTipo,
        pesoUnidad: pesoUnidad,
        pesoCurso: pesoCurso,
        promedio: promedio,
        cantidadNotas: cantidadNotas,
        curso: curso,
        pesoCiclo: pesoCiclo,
        sinTipos: sinTipos,
      );
}

/// Cuánto vale una unidad en el curso y cuánto le falta evaluar.
class ResumenUnidadPrioridad {
  final String unidadId;
  final String nombre;

  /// Peso de la unidad en el curso (0-100).
  final double peso;

  /// Parte del curso ya evaluada en esta unidad (0-peso).
  final double pesoEvaluado;

  const ResumenUnidadPrioridad({
    required this.unidadId,
    required this.nombre,
    required this.peso,
    required this.pesoEvaluado,
  });

  /// Parte del curso que falta evaluar en esta unidad.
  double get pesoPendiente => (peso - pesoEvaluado).clamp(0.0, peso);
}

/// Prioridades de un curso: componentes ordenados y resumen de unidades.
class PrioridadesCurso {
  /// Pendientes primero (de mayor a menor peso), luego los ya evaluados.
  final List<ComponentePrioridad> componentes;

  /// Unidades en orden natural (Unidad 1, 2, 3...).
  final List<ResumenUnidadPrioridad> unidades;

  const PrioridadesCurso({required this.componentes, required this.unidades});

  List<ComponentePrioridad> get pendientes => componentes.where((c) => c.pendiente).toList();

  List<ComponentePrioridad> get evaluados => componentes.where((c) => !c.pendiente).toList();

  /// El componente pendiente que más pesa, o `null` si no queda nada por evaluar.
  ComponentePrioridad? get principal => pendientes.firstOrNull;

  /// Parte del curso que falta evaluar (0-100).
  double get pesoPendiente => pendientes.fold<double>(0.0, (acc, c) => acc + c.pesoCurso);

  /// El curso no tiene pesos configurados (sin tipos o todos en 0 %).
  bool get sinPesos => componentes.every((c) => c.pesoCurso <= 0);

  /// Peso real más alto, para dibujar las barras de forma proporcional.
  double get pesoMaximo => componentes.fold<double>(0.0, (acc, c) => c.pesoCurso > acc ? c.pesoCurso : acc);
}

/// H23 - Prioridades: qué evaluaciones pesan más en la nota.
///
/// Los pesos del sílabo están anidados (tipo dentro de la unidad, unidad dentro
/// del curso). Aquí se calcula el peso real de cada tipo en el curso y, para el
/// ciclo, en el promedio ponderado por créditos (H21). Lógica pura, sin Firebase.
class CalculosPrioridades {
  static const double umbralAlta = 20;
  static const double umbralMedia = 10;

  static NivelPrioridad nivelDe(double pesoCurso) {
    if (pesoCurso >= umbralAlta) return NivelPrioridad.alta;
    if (pesoCurso >= umbralMedia) return NivelPrioridad.media;
    return NivelPrioridad.baja;
  }

  /// Prioridades de un curso a partir de la estructura usada en su cálculo.
  static PrioridadesCurso deCurso(List<EstructuraUnidad> estructuras) {
    final ordenadas = [...estructuras]
      ..sort((a, b) => UnidadesService.compararNatural(a.unidad.nombre, b.unidad.nombre));

    final componentes = <ComponentePrioridad>[];
    final unidades = <ResumenUnidadPrioridad>[];
    for (final e in ordenadas) {
      final u = e.unidad;
      unidades.add(ResumenUnidadPrioridad(
        unidadId: u.id,
        nombre: u.nombre,
        peso: u.porcentaje,
        pesoEvaluado: (u.porcentaje * e.porcentajeTiposEvaluados / 100.0).clamp(0.0, u.porcentaje),
      ));
      // Unidad sin tipos todavia: toda su parte del curso esta pendiente.
      if (e.tipos.isEmpty && u.porcentaje > 0) {
        componentes.add(ComponentePrioridad(
          unidadId: u.id,
          unidadNombre: u.nombre,
          tipoId: 'unidad-${u.id}',
          tipoNombre: u.nombre,
          pesoTipo: 100,
          pesoUnidad: u.porcentaje,
          pesoCurso: u.porcentaje,
          promedio: null,
          cantidadNotas: 0,
          sinTipos: true,
        ));
      }
      for (final t in e.tipos) {
        componentes.add(ComponentePrioridad(
          unidadId: u.id,
          unidadNombre: u.nombre,
          tipoId: t.tipo.id,
          tipoNombre: t.tipo.nombre,
          pesoTipo: t.tipo.porcentaje,
          pesoUnidad: u.porcentaje,
          pesoCurso: t.tipo.porcentaje * u.porcentaje / 100.0,
          promedio: t.promedio,
          cantidadNotas: t.notas.length,
        ));
      }
    }

    // Orden estable: dentro del mismo peso se respeta el orden de las unidades.
    final indice = {for (var i = 0; i < componentes.length; i++) componentes[i]: i};
    componentes.sort((a, b) {
      if (a.pendiente != b.pendiente) return a.pendiente ? -1 : 1;
      final c = b.pesoCurso.compareTo(a.pesoCurso);
      return c != 0 ? c : indice[a]!.compareTo(indice[b]!);
    });

    return PrioridadesCurso(componentes: componentes, unidades: unidades);
  }

  /// Las evaluaciones pendientes que más mueven el promedio del ciclo.
  ///
  /// Peso en el ciclo = peso real en el curso x créditos del curso / créditos del ciclo.
  static List<ComponentePrioridad> delCiclo(
    List<Curso> cursos,
    Map<String, ResultadoCalculoCurso> resultados, {
    int limite = 5,
  }) {
    final creditosCiclo = cursos.fold<int>(0, (acc, c) => acc + c.creditosEfectivos);
    if (creditosCiclo == 0) return [];

    final pendientes = <ComponentePrioridad>[];
    for (final curso in cursos) {
      final estructuras = resultados[curso.id]?.estructuras ?? const [];
      for (final c in deCurso(estructuras).pendientes) {
        if (c.pesoCurso <= 0) continue;
        pendientes.add(c._enCiclo(curso, c.pesoCurso * curso.creditosEfectivos / creditosCiclo));
      }
    }

    pendientes.sort((a, b) => b.pesoCiclo!.compareTo(a.pesoCiclo!));
    return pendientes.take(limite).toList();
  }

  /// Parte del promedio del ciclo que depende de estos componentes (0-100).
  static double pesoEnCiclo(Iterable<ComponentePrioridad> componentes) =>
      componentes.fold<double>(0.0, (acc, c) => acc + (c.pesoCiclo ?? 0));
}
