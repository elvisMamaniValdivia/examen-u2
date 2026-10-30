import '../models/curso.dart';
import 'calculos_multinivel.dart';

/// H20 - Preparacion de los datos de los graficos de evolucion.
///
/// Logica pura (sin Firebase ni widgets) para poder probarla con tests.
/// Usa los resultados de H14 ([CalculosMultinivel]); no repite formulas.

const double notaMinima = 10.5;

/// Un punto del grafico "Por unidad".
class PuntoUnidad {
  /// Etiqueta corta del eje X: "U1", "U2"...
  final String etiqueta;
  final String nombre;
  final double peso;

  /// Promedio de lo evaluado en la unidad, a 1 decimal. `null` = pendiente.
  final double? nota;

  const PuntoUnidad({required this.etiqueta, required this.nombre, required this.peso, required this.nota});

  bool get pendiente => nota == null;
}

/// Datos del grafico "Por unidad" de un curso.
class SerieUnidades {
  final List<PuntoUnidad> puntos;

  /// Nota actual del curso (final o promedio parcial), para el margen sobre 10.5.
  final double? notaCurso;

  const SerieUnidades({required this.puntos, required this.notaCurso});

  List<PuntoUnidad> get conNotas => puntos.where((p) => !p.pendiente).toList();
  List<PuntoUnidad> get pendientes => puntos.where((p) => p.pendiente).toList();

  /// Hay algo que graficar.
  bool get tieneDatos => conNotas.isNotEmpty;

  /// Variacion entre las dos ultimas unidades con notas (ej. -2.0), o null.
  double? get variacion {
    final c = conNotas;
    if (c.length < 2) return null;
    return CalculosMultinivel.redondearUnDecimal(c.last.nota! - c[c.length - 2].nota!);
  }

  /// "De U1 a U2", o null si no hay variacion.
  String? get textoVariacion {
    final c = conNotas;
    if (c.length < 2) return null;
    return 'De ${c[c.length - 2].etiqueta} a ${c.last.etiqueta}';
  }

  /// Puntos por encima (o por debajo, si es negativo) de 10.5.
  double? get margen => notaCurso == null ? null : CalculosMultinivel.redondearUnDecimal(notaCurso! - notaMinima);
}

/// Una barra del grafico "Entre cursos".
class BarraCurso {
  final String cursoId;
  final String nombre;

  /// Abreviatura para el eje X: "SM II", "IO", "BD II".
  final String abreviatura;

  /// Nota actual del curso a 1 decimal. `null` = sin notas.
  final double? nota;

  const BarraCurso({required this.cursoId, required this.nombre, required this.abreviatura, required this.nota});

  bool get sinNotas => nota == null;
  bool get enRiesgo => nota != null && nota! < notaMinima;
}

class DatosGraficos {
  /// Serie "Por unidad" a partir del calculo de H14 de un curso.
  /// Las unidades sin notas quedan pendientes (no se grafican como 0).
  static SerieUnidades porUnidad(ResultadoCalculoCurso resultado) {
    final puntos = <PuntoUnidad>[];
    for (var i = 0; i < resultado.unidades.length; i++) {
      final u = resultado.unidades[i];
      final nota = resultado.promedioParcialPorUnidad[u.id];
      puntos.add(PuntoUnidad(
        etiqueta: 'U${i + 1}',
        nombre: u.nombre,
        peso: u.porcentaje,
        nota: nota == null ? null : CalculosMultinivel.redondearUnDecimal(nota),
      ));
    }
    return SerieUnidades(puntos: puntos, notaCurso: resultado.notaActual);
  }

  /// Barras "Entre cursos", en el mismo orden que la lista de cursos.
  static List<BarraCurso> entreCursos(List<Curso> cursos, Map<String, ResultadoCalculoCurso> resultados) {
    final barras = <BarraCurso>[];
    final usadas = <String>{};
    for (final c in cursos) {
      var abreviatura = abreviar(c.nombre);
      // Evita dos barras con la misma etiqueta ("IS", "IS 2").
      var n = 2;
      final base = abreviatura;
      while (usadas.contains(abreviatura)) {
        abreviatura = '$base $n';
        n++;
      }
      usadas.add(abreviatura);
      barras.add(BarraCurso(
        cursoId: c.id,
        nombre: c.nombre,
        abreviatura: abreviatura,
        nota: resultados[c.id]?.notaActual,
      ));
    }
    return barras;
  }

  /// Avisos de cursos en riesgo: "Investigacion de Operaciones esta 1.1 puntos por debajo del minimo."
  static List<String> avisosRiesgo(List<BarraCurso> barras) => [
        for (final b in barras.where((b) => b.enRiesgo))
          () {
            final falta = CalculosMultinivel.redondearUnDecimal(notaMinima - b.nota!);
            final puntos = falta == 1 ? 'punto' : 'puntos';
            return '${b.nombre} está ${falta.toStringAsFixed(1)} $puntos por debajo del mínimo.';
          }(),
      ];

  static const _conectores = {'de', 'del', 'la', 'las', 'el', 'los', 'y', 'e', 'en', 'a', 'para', 'por', 'con', '/'};

  /// Abreviatura de un curso: iniciales de las palabras importantes y, al final,
  /// numeros romanos o siglas tal cual.
  /// "Soluciones Moviles II" -> "SM II"; "Gestion de Proyectos TI" -> "GP TI".
  static String abreviar(String nombre) {
    final palabras = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final iniciales = StringBuffer();
    final sufijos = <String>[];
    for (final p in palabras) {
      if (_conectores.contains(p.toLowerCase())) continue;
      final esRomano = RegExp(r'^[IVXL]+$').hasMatch(p);
      final esSigla = p.length <= 3 && p == p.toUpperCase() && RegExp(r'[A-Z]').hasMatch(p);
      final esNumero = RegExp(r'^\d+$').hasMatch(p);
      if (esRomano || esSigla || esNumero) {
        sufijos.add(p);
      } else {
        iniciales.write(p[0].toUpperCase());
      }
    }
    final texto = [if (iniciales.isNotEmpty) iniciales.toString(), ...sufijos].join(' ');
    if (texto.isNotEmpty) return texto;
    return nombre.length <= 4 ? nombre : nombre.substring(0, 4);
  }
}
