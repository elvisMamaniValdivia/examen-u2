import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_moviles2_grupo03/models/curso.dart';
import 'package:proyecto_moviles2_grupo03/models/nota.dart';
import 'package:proyecto_moviles2_grupo03/models/tipo_evaluacion.dart';
import 'package:proyecto_moviles2_grupo03/models/unidad.dart';
import 'package:proyecto_moviles2_grupo03/services/calculos_multinivel.dart';
import 'package:proyecto_moviles2_grupo03/services/datos_graficos.dart';

/// Unidad con un solo tipo (100 %) y las notas dadas.
EstructuraUnidad unidad(String id, String nombre, double peso, List<double> notas) => EstructuraUnidad(
      unidad: Unidad(id: id, nombre: nombre, cursoId: 'c', porcentaje: peso),
      tipos: [
        EstructuraTipoEvaluacion(
          tipo: TipoEvaluacion(id: 't$id', nombre: 'Examen', porcentaje: 100),
          notas: [for (var i = 0; i < notas.length; i++) Nota(id: 'n$id$i', valor: notas[i], tipoEvaluacionId: 't$id')],
        ),
      ],
    );

void main() {
  group('DatosGraficos - por unidad', () {
    // Ejemplo de DESIGN.md: U1 16.2, U2 14.2, U3 sin notas.
    final resultado = CalculosMultinivel.calcular([
      unidad('u3', 'Unidad 3', 35, []),
      unidad('u1', 'Unidad 1', 30, [16.2]),
      unidad('u2', 'Unidad 2', 35, [14.2]),
    ]);
    final serie = DatosGraficos.porUnidad(resultado);

    test('Ordena las unidades y las etiqueta U1, U2, U3', () {
      expect(serie.puntos.map((p) => p.nombre), ['Unidad 1', 'Unidad 2', 'Unidad 3']);
      expect(serie.puntos.map((p) => p.etiqueta), ['U1', 'U2', 'U3']);
    });

    test('Las unidades sin notas quedan pendientes, no en 0', () {
      expect(serie.puntos.map((p) => p.nota), [16.2, 14.2, null]);
      expect(serie.pendientes.single.nombre, 'Unidad 3');
      expect(serie.tieneDatos, isTrue);
    });

    test('Variacion entre las dos ultimas unidades con notas', () {
      expect(serie.variacion, -2.0);
      expect(serie.textoVariacion, 'De U1 a U2');
    });

    test('Margen del curso sobre 10.5 con el promedio parcial de H14', () {
      // (16.2 * 0.30 + 14.2 * 0.35) / 0.65 = 15.12 -> 15.1
      expect(serie.notaCurso, 15.1);
      expect(serie.margen, 4.6);
    });

    test('Sin notas no hay datos que graficar', () {
      final vacia = DatosGraficos.porUnidad(CalculosMultinivel.calcular([unidad('u1', 'Unidad 1', 100, [])]));
      expect(vacia.tieneDatos, isFalse);
      expect(vacia.variacion, isNull);
      expect(vacia.margen, isNull);
    });
  });

  group('DatosGraficos - entre cursos', () {
    ResultadoCalculoCurso curso(double? nota) =>
        CalculosMultinivel.calcular([unidad('u1', 'Unidad 1', 100, [?nota])]);

    final cursos = [
      Curso(id: 'sm', nombre: 'Soluciones Móviles II', cicloId: 'c7'),
      Curso(id: 'io', nombre: 'Investigación de Operaciones', cicloId: 'c7'),
      Curso(id: 'gp', nombre: 'Gestión de Proyectos TI', cicloId: 'c7'),
    ];
    final barras = DatosGraficos.entreCursos(cursos, {
      'sm': curso(15.1),
      'io': curso(9.4),
      'gp': curso(null),
    });

    test('Una barra por curso con su nota actual y abreviatura', () {
      expect(barras.map((b) => b.abreviatura), ['SM II', 'IO', 'GP TI']);
      expect(barras.map((b) => b.nota), [15.1, 9.4, null]);
    });

    test('Marca en riesgo y sin notas', () {
      expect(barras.map((b) => b.enRiesgo), [false, true, false]);
      expect(barras[2].sinNotas, isTrue);
    });

    test('Aviso por cada curso en riesgo', () {
      expect(DatosGraficos.avisosRiesgo(barras), [
        'Investigación de Operaciones está 1.1 puntos por debajo del mínimo.',
      ]);
    });

    test('Abreviaturas repetidas se distinguen', () {
      final b = DatosGraficos.entreCursos([
        Curso(id: 'a', nombre: 'Ingeniería de Software', cicloId: 'c'),
        Curso(id: 'b', nombre: 'Inteligencia Simbólica', cicloId: 'c'),
      ], {});
      expect(b.map((x) => x.abreviatura), ['IS', 'IS 2']);
    });
  });
}
