import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_moviles2_grupo03/models/nota.dart';
import 'package:proyecto_moviles2_grupo03/models/tipo_evaluacion.dart';
import 'package:proyecto_moviles2_grupo03/services/calculos_evaluaciones.dart';

void main() {
  group('CalculosEvaluaciones - calcularPromedioTipo', () {
    test('Retorna null si no hay notas registradas', () {
      final promedio = CalculosEvaluaciones.calcularPromedioTipo([]);
      expect(promedio, isNull);
    });

    test('Retorna el mismo valor si solo hay una nota', () {
      final notas = [
        Nota(id: '1', valor: 15.0, tipoEvaluacionId: 't1'),
      ];
      final promedio = CalculosEvaluaciones.calcularPromedioTipo(notas);
      expect(promedio, 15.0);
    });

    test('Promedia correctamente múltiples notas (ej. laboratorios)', () {
      final notas = [
        Nota(id: '1', valor: 14.0, tipoEvaluacionId: 't1'),
        Nota(id: '2', valor: 16.0, tipoEvaluacionId: 't1'),
        Nota(id: '3', valor: 18.0, tipoEvaluacionId: 't1'),
      ];
      final promedio = CalculosEvaluaciones.calcularPromedioTipo(notas);
      expect(promedio, 16.0);
    });

    test('Maneja decimales correctamente', () {
      final notas = [
        Nota(id: '1', valor: 13.5, tipoEvaluacionId: 't1'),
        Nota(id: '2', valor: 14.5, tipoEvaluacionId: 't1'),
      ];
      final promedio = CalculosEvaluaciones.calcularPromedioTipo(notas);
      expect(promedio, 14.0);
    });
  });

  group('CalculosEvaluaciones - validarSumaPorcentajes y calcularTotalPorcentaje', () {
    test('Valida correctamente cuando los tipos suman 100%', () {
      final tipos = [
        TipoEvaluacion(id: '1', nombre: 'Examen', porcentaje: 40.0),
        TipoEvaluacion(id: '2', nombre: 'Laboratorios', porcentaje: 60.0),
      ];
      expect(CalculosEvaluaciones.calcularTotalPorcentaje(tipos), 100.0);
      expect(CalculosEvaluaciones.validarSumaPorcentajes(tipos), isTrue);
    });

    test('Permite pequeña tolerancia de punto flotante (+-0.1)', () {
      final tipos = [
        TipoEvaluacion(id: '1', nombre: 'T1', porcentaje: 33.33),
        TipoEvaluacion(id: '2', nombre: 'T2', porcentaje: 33.33),
        TipoEvaluacion(id: '3', nombre: 'T3', porcentaje: 33.34),
      ];
      expect(CalculosEvaluaciones.validarSumaPorcentajes(tipos), isTrue);
    });

    test('Invalida si la suma es diferente de 100%', () {
      final tipos = [
        TipoEvaluacion(id: '1', nombre: 'Examen', porcentaje: 40.0),
        TipoEvaluacion(id: '2', nombre: 'Laboratorios', porcentaje: 50.0),
      ];
      expect(CalculosEvaluaciones.validarSumaPorcentajes(tipos), isFalse);
    });

    test('Invalida si no hay tipos de evaluación', () {
      expect(CalculosEvaluaciones.validarSumaPorcentajes([]), isFalse);
    });
  });

  group('CalculosEvaluaciones - calcularNotaUnidad', () {
    final tipos = [
      TipoEvaluacion(id: 't1', nombre: 'Laboratorios', porcentaje: 40.0),
      TipoEvaluacion(id: 't2', nombre: 'Examen', porcentaje: 60.0),
    ];

    test('Calcula la nota ponderada con promedio de notas por tipo', () {
      final notasPorTipo = {
        't1': [
          Nota(id: '1', valor: 14.0, tipoEvaluacionId: 't1'),
          Nota(id: '2', valor: 18.0, tipoEvaluacionId: 't1'), // Promedio t1 = 16.0
        ],
        't2': [
          Nota(id: '3', valor: 15.0, tipoEvaluacionId: 't2'), // Promedio t2 = 15.0
        ],
      };

      // 16.0 * 0.40 + 15.0 * 0.60 = 6.4 + 9.0 = 15.4
      final notaUnidad = CalculosEvaluaciones.calcularNotaUnidad(tipos, notasPorTipo);
      expect(notaUnidad, closeTo(15.4, 0.001));
    });

    test('Calcula la suma acumulada si solo un tipo tiene notas', () {
      final notasPorTipo = {
        't1': [
          Nota(id: '1', valor: 20.0, tipoEvaluacionId: 't1'),
        ],
      };

      // 20.0 * 0.40 = 8.0
      final notaUnidad = CalculosEvaluaciones.calcularNotaUnidad(tipos, notasPorTipo);
      expect(notaUnidad, closeTo(8.0, 0.001));
    });

    test('Retorna null si ningún tipo tiene notas', () {
      final notaUnidad = CalculosEvaluaciones.calcularNotaUnidad(tipos, {});
      expect(notaUnidad, isNull);
    });
  });

  group('CalculosEvaluaciones - esAprobado', () {
    test('10.5 o mas es aprobado', () {
      expect(CalculosEvaluaciones.esAprobado(10.5), isTrue);
      expect(CalculosEvaluaciones.esAprobado(18.0), isTrue);
    });

    test('Menor a 10.5 es desaprobado', () {
      expect(CalculosEvaluaciones.esAprobado(10.49), isFalse);
      expect(CalculosEvaluaciones.esAprobado(8.0), isFalse);
    });
  });

  group('CalculosEvaluaciones - simulador de unidad (H15)', () {
    final tipos = [
      TipoEvaluacion(id: 'ex', nombre: 'Examen', porcentaje: 40),
      TipoEvaluacion(id: 'lab', nombre: 'Laboratorio', porcentaje: 30),
      TipoEvaluacion(id: 'pro', nombre: 'Proyecto', porcentaje: 30),
    ];
    // Laboratorio: promedio 15 -> aporta 4.5. Examen y Proyecto pendientes.
    final notas = {
      'lab': [
        Nota(id: 'n1', valor: 14, tipoEvaluacionId: 'lab'),
        Nota(id: 'n2', valor: 16, tipoEvaluacionId: 'lab'),
      ],
    };

    test('Calcula la nota necesaria en la evaluacion pendiente', () {
      final r = CalculosEvaluaciones.simularUnidad(
        tipos: tipos, notasPorTipo: notas, tipoPendienteId: 'ex', objetivo: 10.5)!;
      expect(r.notaNecesaria, closeTo(15.0, 0.001)); // (10.5 - 4.5) / 0.4
      expect(r.maximoPosible, closeTo(18.5, 0.001)); // 4.5 + 0.7 * 20
      expect(r.imposible, isFalse);
      expect(r.yaAlcanzado, isFalse);
    });

    test('Detecta una meta imposible', () {
      final r = CalculosEvaluaciones.simularUnidad(
        tipos: tipos, notasPorTipo: notas, tipoPendienteId: 'ex', objetivo: 19)!;
      expect(r.imposible, isTrue);
    });

    test('Una sola evaluacion no basta pero con las otras pendientes si', () {
      final r = CalculosEvaluaciones.simularUnidad(
        tipos: tipos, notasPorTipo: notas, tipoPendienteId: 'pro', objetivo: 12)!;
      expect(r.notaNecesaria, greaterThan(20)); // (12 - 4.5) / 0.3 = 25
      expect(r.necesitaOtrasPendientes, isTrue);
    });

    test('Retorna null si los pesos no suman 100% o el tipo ya tiene notas', () {
      expect(
        CalculosEvaluaciones.simularUnidad(
            tipos: tipos.take(2).toList(), notasPorTipo: notas, tipoPendienteId: 'ex', objetivo: 12),
        isNull,
      );
      expect(
        CalculosEvaluaciones.simularUnidad(tipos: tipos, notasPorTipo: notas, tipoPendienteId: 'lab', objetivo: 12),
        isNull,
      );
    });
  });
}
