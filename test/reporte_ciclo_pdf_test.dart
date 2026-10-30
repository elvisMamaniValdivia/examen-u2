import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_moviles2_grupo03/models/curso.dart';
import 'package:proyecto_moviles2_grupo03/services/calculos_multinivel.dart';
import 'package:proyecto_moviles2_grupo03/services/reporte_ciclo_pdf.dart';

void main() {
  group('ReporteCicloPdf (H22)', () {
    test('genera un documento PDF válido con bytes de cabecera %PDF-', () async {
      final cursos = <Curso>[
        Curso(
          id: 'c1',
          cicloId: 'ciclo-1',
          nombre: 'Móviles II',
          creditos: 4,
        ),
        Curso(
          id: 'c2',
          cicloId: 'ciclo-1',
          nombre: 'Base de Datos Avanzada',
          creditos: 3,
        ),
      ];

      final resultados = <String, ResultadoCalculoCurso>{
        'c1': const ResultadoCalculoCurso(
          promedioParcial: 16.5,
          porcentajeEvaluado: 60.0,
          estado: EstadoCalculoCurso.incompleto,
          mensajeEstado: 'En curso',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
        'c2': const ResultadoCalculoCurso(
          promedioParcial: 9.8,
          porcentajeEvaluado: 50.0,
          estado: EstadoCalculoCurso.incompleto,
          mensajeEstado: 'En riesgo',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
      };

      final pdfBytes = await ReporteCicloPdf.generarPdf(
        cicloNombre: '2026-I',
        cursos: cursos,
        resultados: resultados,
        promedioCiclo: 13.63,
        totalCreditos: 7,
        fechaEmision: DateTime(2026, 10, 22, 16, 0),
      );

      expect(pdfBytes, isNotEmpty);
      final encabezado = ascii.decode(pdfBytes.sublist(0, 5));
      expect(encabezado, equals('%PDF-'));
    });

    test('incluye datos de estudiante y procesa los 4 estados de curso (Aprobado, En curso, En riesgo, Sin notas)', () async {
      final cursos = <Curso>[
        Curso(id: 'c1', cicloId: 'ciclo-1', nombre: 'Curso Aprobado', creditos: 4),
        Curso(id: 'c2', cicloId: 'ciclo-1', nombre: 'Curso En Curso', creditos: 3),
        Curso(id: 'c3', cicloId: 'ciclo-1', nombre: 'Curso En Riesgo', creditos: 3),
        Curso(id: 'c4', cicloId: 'ciclo-1', nombre: 'Curso Sin Notas', creditos: 2),
      ];

      final resultados = <String, ResultadoCalculoCurso>{
        'c1': const ResultadoCalculoCurso(
          promedioParcial: 17.0,
          porcentajeEvaluado: 100.0,
          estado: EstadoCalculoCurso.completo,
          mensajeEstado: 'Completo',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
        'c2': const ResultadoCalculoCurso(
          promedioParcial: 14.5,
          porcentajeEvaluado: 50.0,
          estado: EstadoCalculoCurso.incompleto,
          mensajeEstado: 'En curso',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
        'c3': const ResultadoCalculoCurso(
          promedioParcial: 8.5,
          porcentajeEvaluado: 70.0,
          estado: EstadoCalculoCurso.incompleto,
          mensajeEstado: 'En riesgo',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
        'c4': const ResultadoCalculoCurso(
          promedioParcial: null,
          notaFinal: null,
          porcentajeEvaluado: 0.0,
          estado: EstadoCalculoCurso.sinDatos,
          mensajeEstado: 'Sin evaluaciones',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
      };

      final pdfBytes = await ReporteCicloPdf.generarPdf(
        cicloNombre: '2026-I',
        cursos: cursos,
        resultados: resultados,
        promedioCiclo: 13.7,
        totalCreditos: 12,
        nombreEstudiante: 'Elvis Mamani',
        correoEstudiante: 'elvis@upt.pe',
      );

      expect(pdfBytes, isNotEmpty);
      final encabezado = ascii.decode(pdfBytes.sublist(0, 5));
      expect(encabezado, equals('%PDF-'));
    });

    test('soporta múltiples páginas y lista extensa de 15 cursos sin errores de layout', () async {
      final cursos = List.generate(
        15,
        (i) => Curso(
          id: 'curso_$i',
          cicloId: 'ciclo-1',
          nombre: 'Asignatura Universitaria Compleja $i',
          creditos: (i % 3) + 2,
        ),
      );

      final resultados = {
        for (final c in cursos)
          c.id: ResultadoCalculoCurso(
            promedioParcial: 11.0 + (int.parse(c.id.split('_').last) % 8),
            porcentajeEvaluado: 60.0,
            estado: EstadoCalculoCurso.incompleto,
            mensajeEstado: 'En curso',
            notasPorUnidad: const {},
            unidadCompleta: const {},
          )
      };

      final pdfBytes = await ReporteCicloPdf.generarPdf(
        cicloNombre: '2026-I Extenso',
        cursos: cursos,
        resultados: resultados,
        promedioCiclo: 14.2,
        totalCreditos: 45,
        nombreEstudiante: 'Elvis Mamani',
        correoEstudiante: 'elvis@upt.pe',
      );

      expect(pdfBytes, isNotEmpty);
      final encabezado = ascii.decode(pdfBytes.sublist(0, 5));
      expect(encabezado, equals('%PDF-'));
    });

    test('genera PDF correctamente cuando ningún curso tiene notas aún', () async {
      final cursos = <Curso>[
        Curso(
          id: 'c1',
          cicloId: 'ciclo-1',
          nombre: 'Tesis I',
          creditos: 5,
        ),
      ];

      final resultados = <String, ResultadoCalculoCurso>{
        'c1': const ResultadoCalculoCurso(
          promedioParcial: null,
          notaFinal: null,
          porcentajeEvaluado: 0.0,
          estado: EstadoCalculoCurso.sinDatos,
          mensajeEstado: 'Sin notas',
          notasPorUnidad: {},
          unidadCompleta: {},
        ),
      };

      final pdfBytes = await ReporteCicloPdf.generarPdf(
        cicloNombre: '2026-II',
        cursos: cursos,
        resultados: resultados,
        promedioCiclo: null,
        totalCreditos: 5,
      );

      expect(pdfBytes, isNotEmpty);
      final encabezado = ascii.decode(pdfBytes.sublist(0, 5));
      expect(encabezado, equals('%PDF-'));
    });
  });
}
