import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_moviles2_grupo03/models/curso.dart';
import 'package:proyecto_moviles2_grupo03/models/nota.dart';
import 'package:proyecto_moviles2_grupo03/models/tipo_evaluacion.dart';
import 'package:proyecto_moviles2_grupo03/models/unidad.dart';
import 'package:proyecto_moviles2_grupo03/services/calculos_multinivel.dart';
import 'package:proyecto_moviles2_grupo03/services/calculos_prioridades.dart';

EstructuraUnidad _unidad(String id, String nombre, double peso, Map<String, (double, List<double>)> tipos) {
  return EstructuraUnidad(
    unidad: Unidad(id: id, nombre: nombre, cursoId: 'c', porcentaje: peso),
    tipos: [
      for (final e in tipos.entries)
        EstructuraTipoEvaluacion(
          tipo: TipoEvaluacion(id: '$id-${e.key}', nombre: e.key, porcentaje: e.value.$1),
          notas: [
            for (var i = 0; i < e.value.$2.length; i++)
              Nota(id: '$id-${e.key}-$i', valor: e.value.$2[i], tipoEvaluacionId: '$id-${e.key}'),
          ],
        ),
    ],
  );
}

/// Curso del ejemplo del issue: U1 30 % (evaluada), U2 30 %, U3 40 %.
List<EstructuraUnidad> _cursoEjemplo() => [
      _unidad('u3', 'Unidad 3', 40, {'Examen': (60, []), 'Prácticas': (40, [])}),
      _unidad('u1', 'Unidad 1', 30, {'Examen': (60, [14]), 'Prácticas': (40, [16, 12])}),
      _unidad('u2', 'Unidad 2', 30, {'Examen': (80, []), 'Prácticas': (20, [15])}),
    ];

void main() {
  group('H23 - Prioridades del curso', () {
    test('Calcula el peso real de cada tipo: peso del tipo x peso de la unidad', () {
      final p = CalculosPrioridades.deCurso(_cursoEjemplo());
      final examenU3 = p.componentes.firstWhere((c) => c.unidadId == 'u3' && c.tipoNombre == 'Examen');
      final practicasU2 = p.componentes.firstWhere((c) => c.unidadId == 'u2' && c.tipoNombre == 'Prácticas');

      expect(examenU3.pesoCurso, closeTo(24, 1e-9));
      expect(practicasU2.pesoCurso, closeTo(6, 1e-9));
      expect(examenU3.puntosEnCurso, closeTo(0.24, 1e-9));
    });

    test('Ordena los pendientes primero y de mayor a menor peso', () {
      final p = CalculosPrioridades.deCurso(_cursoEjemplo());
      final orden = p.componentes.map((c) => '${c.unidadId} ${c.tipoNombre}').toList();

      expect(orden, [
        'u2 Examen', // 24 % (empate: se respeta el orden de las unidades)
        'u3 Examen', // 24 %
        'u3 Prácticas', // 16 %
        'u1 Examen', // 18 % evaluado
        'u1 Prácticas', // 12 % evaluado
        'u2 Prácticas', // 6 % evaluado
      ]);
      expect(p.principal?.unidadId, 'u2');
      expect(p.pesoPendiente, closeTo(64, 1e-9));
    });

    test('Asigna el nivel de prioridad según los umbrales del issue', () {
      expect(CalculosPrioridades.nivelDe(24), NivelPrioridad.alta);
      expect(CalculosPrioridades.nivelDe(20), NivelPrioridad.alta);
      expect(CalculosPrioridades.nivelDe(19.9), NivelPrioridad.media);
      expect(CalculosPrioridades.nivelDe(10), NivelPrioridad.media);
      expect(CalculosPrioridades.nivelDe(6), NivelPrioridad.baja);
    });

    test('Resume cuánto vale cada unidad y cuánto le falta evaluar, en orden natural', () {
      final p = CalculosPrioridades.deCurso(_cursoEjemplo());

      expect(p.unidades.map((u) => u.nombre), ['Unidad 1', 'Unidad 2', 'Unidad 3']);
      expect(p.unidades[0].pesoPendiente, closeTo(0, 1e-9));
      expect(p.unidades[1].pesoEvaluado, closeTo(6, 1e-9));
      expect(p.unidades[1].pesoPendiente, closeTo(24, 1e-9));
      expect(p.unidades[2].pesoPendiente, closeTo(40, 1e-9));
    });

    test('Sin unidades o con pesos en 0 se marca como curso sin pesos', () {
      expect(CalculosPrioridades.deCurso([]).sinPesos, isTrue);
      expect(CalculosPrioridades.deCurso([_unidad('u1', 'Unidad 1', 0, {'Examen': (100, [])})]).sinPesos, isTrue);
      expect(CalculosPrioridades.deCurso(_cursoEjemplo()).sinPesos, isFalse);
    });

    test('Una unidad sin tipos cuenta como pendiente con todo su peso', () {
      final p = CalculosPrioridades.deCurso([
        _unidad('u1', 'Unidad 1', 25, {'Examen': (100, [14])}),
        _unidad('u2', 'Unidad 2', 35, {'Examen': (100, [])}),
        _unidad('u3', 'Unidad 3', 40, {}),
      ]);

      expect(p.principal?.sinTipos, isTrue);
      expect(p.principal?.unidadId, 'u3');
      expect(p.principal?.pesoCurso, 40);
      expect(p.pesoPendiente, closeTo(75, 1e-9));
    });

    test('Curso totalmente evaluado no tiene prioridad principal', () {
      final p = CalculosPrioridades.deCurso([
        _unidad('u1', 'Unidad 1', 100, {'Examen': (100, [15])}),
      ]);
      expect(p.principal, isNull);
      expect(p.pendientes, isEmpty);
      expect(p.evaluados.single.promedio, 15);
    });
  });

  group('H23 - Prioridades del ciclo', () {
    test('Pondera el peso de cada pendiente por los créditos del curso', () {
      final redes = Curso(id: 'redes', nombre: 'Redes', cicloId: 'c', creditos: 5);
      final etica = Curso(id: 'etica', nombre: 'Ética', cicloId: 'c', creditos: 2);
      final resultados = {
        'redes': CalculosMultinivel.calcular([
          _unidad('r1', 'Unidad 1', 100, {'Examen': (50, []), 'Prácticas': (50, [13])}),
        ]),
        'etica': CalculosMultinivel.calcular([
          _unidad('e1', 'Unidad 1', 100, {'Examen': (100, [])}),
        ]),
      };

      final top = CalculosPrioridades.delCiclo([redes, etica], resultados);

      // Ética: 100 % x 2 / 7 = 28.6 %; Redes: 50 % x 5 / 7 = 35.7 %.
      expect(top.map((c) => c.curso!.id), ['redes', 'etica']);
      expect(top.first.pesoCiclo, closeTo(50 * 5 / 7, 1e-9));
      expect(top.last.puntosEnCiclo, closeTo(2 / 7, 1e-9));
      expect(CalculosPrioridades.pesoEnCiclo(top), closeTo((250 + 200) / 7, 1e-9));
    });

    test('Limita la lista y devuelve vacío si no hay pendientes', () {
      final curso = Curso(id: 'c1', nombre: 'Móviles', cicloId: 'c', creditos: 4);
      final muchos = {
        'c1': CalculosMultinivel.calcular([
          _unidad('u1', 'Unidad 1', 100, {for (var i = 0; i < 8; i++) 'Lab $i': (12.5, <double>[])}),
        ]),
      };
      expect(CalculosPrioridades.delCiclo([curso], muchos), hasLength(5));
      expect(CalculosPrioridades.delCiclo([curso], muchos, limite: 3), hasLength(3));

      final completo = {
        'c1': CalculosMultinivel.calcular([
          _unidad('u1', 'Unidad 1', 100, {'Examen': (100, [17])}),
        ]),
      };
      expect(CalculosPrioridades.delCiclo([curso], completo), isEmpty);
      expect(CalculosPrioridades.delCiclo([], {}), isEmpty);
    });
  });
}
