import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_moviles2_grupo03/models/componente_evaluacion.dart';
import 'package:proyecto_moviles2_grupo03/services/calculadora_promedio.dart';

void main() {
  group('CalculadoraPromedio', () {
    test('Calcula correctamente el promedio ponderado cuando los pesos suman 100%', () {
      final componentes = [
        const ComponenteEvaluacion(id: '1', nombre: 'Evaluación 1', nota: 14.0, peso: 50.0),
        const ComponenteEvaluacion(id: '2', nombre: 'Evaluación 2', nota: 16.0, peso: 50.0),
      ];

      final promedio = CalculadoraPromedio.calcularPromedio(componentes);
      expect(promedio, 15.0);
    });

    test('Retorna null si los pesos no suman 100%', () {
      final componentes = [
        const ComponenteEvaluacion(id: '1', nombre: 'Evaluación 1', nota: 12.0, peso: 30.0),
        const ComponenteEvaluacion(id: '2', nombre: 'Evaluación 2', nota: 14.0, peso: 30.0),
      ];

      final promedio = CalculadoraPromedio.calcularPromedio(componentes);
      expect(promedio, isNull);
    });

    test('Retorna null si tiene menos de 2 componentes', () {
      final componentes = [
        const ComponenteEvaluacion(id: '1', nombre: 'Evaluación Única', nota: 15.0, peso: 100.0),
      ];

      final promedio = CalculadoraPromedio.calcularPromedio(componentes);
      expect(promedio, isNull);
    });

    test('Evalua correctamente estado aprobado y desaprobado', () {
      expect(CalculadoraPromedio.esAprobado(10.5), isTrue);
      expect(CalculadoraPromedio.esAprobado(10.4), isFalse);
    });
  });
}
