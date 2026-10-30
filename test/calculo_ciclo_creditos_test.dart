import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_moviles2_grupo03/models/curso.dart';
import 'package:proyecto_moviles2_grupo03/services/calculo_curso_service.dart';
import 'package:proyecto_moviles2_grupo03/services/calculos_multinivel.dart';

void main() {
  group('H21 - Promedio del ciclo ponderado por créditos', () {
    test('Calcula correctamente el promedio ponderado según los créditos de cada curso', () {
      final curso1 = Curso(id: 'c1', nombre: 'Móviles 2', cicloId: 'ciclo1', creditos: 4);
      final curso2 = Curso(id: 'c2', nombre: 'Tesis', cicloId: 'ciclo1', creditos: 2);

      final resultados = {
        'c1': const ResultadoCalculoCurso(
          notaFinal: 16.0,
          notaAcumulada: 16.0,
          estado: EstadoCalculoCurso.completo,
          mensajeEstado: 'Completo',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
        'c2': const ResultadoCalculoCurso(
          notaFinal: 12.0,
          notaAcumulada: 12.0,
          estado: EstadoCalculoCurso.completo,
          mensajeEstado: 'Completo',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
      };

      // Cálculo: (16.0 * 4 + 12.0 * 2) / (4 + 2) = (64 + 24) / 6 = 88 / 6 = 14.666... -> 14.7
      final promedio = CalculoCursoService.promedioPonderadoCiclo(
        cursos: [curso1, curso2],
        resultados: resultados,
      );

      expect(promedio, 14.7);
    });

    test('Omite del promedio los cursos que no tienen notas pero respeta los ponderados con notas', () {
      final curso1 = Curso(id: 'c1', nombre: 'Móviles 2', cicloId: 'ciclo1', creditos: 3);
      final curso2 = Curso(id: 'c2', nombre: 'Redes', cicloId: 'ciclo1', creditos: 4);
      final cursoSinNotas = Curso(id: 'c3', nombre: 'Ética', cicloId: 'ciclo1', creditos: 2);

      final resultados = {
        'c1': const ResultadoCalculoCurso(
          notaFinal: 15.0,
          notaAcumulada: 15.0,
          estado: EstadoCalculoCurso.completo,
          mensajeEstado: 'Completo',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
        'c2': const ResultadoCalculoCurso(
          notaFinal: 11.0,
          notaAcumulada: 11.0,
          estado: EstadoCalculoCurso.completo,
          mensajeEstado: 'Completo',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
        'c3': const ResultadoCalculoCurso(
          notaFinal: null,
          notaAcumulada: null,
          estado: EstadoCalculoCurso.sinDatos,
          mensajeEstado: 'Sin notas',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
      };

      // Cálculo: (15.0 * 3 + 11.0 * 4) / (3 + 4) = (45 + 44) / 7 = 89 / 7 = 12.714... -> 12.7
      final promedio = CalculoCursoService.promedioPonderadoCiclo(
        cursos: [curso1, curso2, cursoSinNotas],
        resultados: resultados,
      );

      expect(promedio, 12.7);
    });

    test('Asigna 3 créditos por defecto si el curso tiene 0 o falta el campo en Firestore', () {
      final mapAntiguo = {
        'nombre': 'Curso Legado',
        'cicloId': 'ciclo1',
      };

      final cursoDesdeFirestore = Curso.fromMap('id_antiguo', mapAntiguo);
      expect(cursoDesdeFirestore.creditos, 3);

      final toMap = cursoDesdeFirestore.toMap();
      expect(toMap['creditos'], 3);
    });

    test('Retorna null si ningún curso tiene notas registradas', () {
      final curso = Curso(id: 'c1', nombre: 'Física', cicloId: 'ciclo1', creditos: 4);
      final resultados = {
        'c1': const ResultadoCalculoCurso(
          notaFinal: null,
          notaAcumulada: null,
          estado: EstadoCalculoCurso.sinDatos,
          mensajeEstado: 'Sin notas',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
      };

      final promedio = CalculoCursoService.promedioPonderadoCiclo(
        cursos: [curso],
        resultados: resultados,
      );

      expect(promedio, isNull);
    });

    test('Suma créditos usando 3 cuando el valor guardado no es válido', () {
      final cursos = [
        Curso(id: 'c1', nombre: 'Redes', cicloId: 'ciclo1', creditos: 4),
        Curso(id: 'c2', nombre: 'Ética', cicloId: 'ciclo1', creditos: 0),
      ];

      expect(CalculoCursoService.totalCreditos(cursos), 7);
    });

    test('Promedio acumulado pondera cada ciclo por sus créditos evaluados', () {
      const resumenes = [
        ResumenCiclo(cantidadCursos: 5, cursosConNotas: 5, totalCreditos: 20, creditosEvaluados: 20, promedio: 15.0),
        ResumenCiclo(cantidadCursos: 2, cursosConNotas: 2, totalCreditos: 6, creditosEvaluados: 6, promedio: 11.0),
        ResumenCiclo(cantidadCursos: 3, cursosConNotas: 0, totalCreditos: 9, creditosEvaluados: 0, promedio: null),
      ];

      // (15 * 20 + 11 * 6) / 26 = 366 / 26 = 14.07... -> 14.1 (el promedio simple daría 13.0)
      expect(CalculoCursoService.promedioAcumulado(resumenes), 14.1);
      expect(CalculoCursoService.promedioAcumulado(const []), isNull);
    });
  });
}
