import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_moviles2_grupo03/models/curso.dart';
import 'package:proyecto_moviles2_grupo03/services/calculos_prioridades.dart';
import 'package:proyecto_moviles2_grupo03/theme/app_theme.dart';
import 'package:proyecto_moviles2_grupo03/widgets/prioridades.dart';

const _examen = ComponentePrioridad(
  unidadId: 'u3',
  unidadNombre: 'Unidad 3',
  tipoId: 't1',
  tipoNombre: 'Examen',
  pesoTipo: 60,
  pesoUnidad: 40,
  pesoCurso: 24,
  promedio: null,
  cantidadNotas: 0,
);

Widget _app(Widget hijo, {ThemeData? tema}) => MaterialApp(
      theme: tema ?? AppTheme.lightTheme,
      home: Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [hijo])),
    );

void main() {
  group('H23 - Widgets de prioridades', () {
    testWidgets('Fila pendiente muestra peso real, prioridad e impacto por punto', (tester) async {
      await tester.pumpWidget(_app(const FilaComponentePrioridad(componente: _examen, pesoMaximo: 24)));

      expect(find.text('Examen'), findsOneWidget);
      expect(find.text('24%'), findsOneWidget);
      expect(find.text('Alta prioridad'), findsOneWidget);
      expect(find.text('Cada punto que saques aquí suma 0.24 a tu nota del curso.'), findsOneWidget);
    });

    testWidgets('Fila evaluada muestra su promedio y no el chip de prioridad', (tester) async {
      const evaluado = ComponentePrioridad(
        unidadId: 'u1',
        unidadNombre: 'Unidad 1',
        tipoId: 't2',
        tipoNombre: 'Prácticas',
        pesoTipo: 40,
        pesoUnidad: 30,
        pesoCurso: 12,
        promedio: 14,
        cantidadNotas: 2,
      );
      await tester.pumpWidget(_app(const FilaComponentePrioridad(componente: evaluado, pesoMaximo: 24)));

      expect(find.text('Evaluado · promedio 14.0 (2 notas)'), findsOneWidget);
      expect(find.byType(ChipPrioridad), findsNothing);
    });

    testWidgets('Tarjeta de acceso del ciclo nombra el curso y abre al tocar (modo oscuro)', (tester) async {
      var abierta = false;
      final enCiclo = ComponentePrioridad(
        unidadId: 'u3',
        unidadNombre: 'Unidad 3',
        tipoId: 't1',
        tipoNombre: 'Examen',
        pesoTipo: 60,
        pesoUnidad: 40,
        pesoCurso: 24,
        promedio: null,
        cantidadNotas: 0,
        curso: Curso(id: 'r', nombre: 'Redes', cicloId: 'c', creditos: 5),
        pesoCiclo: 6,
      );
      await tester.pumpWidget(_app(
        TarjetaPrioridad(principal: enCiclo, enCiclo: true, onTap: () => abierta = true),
        tema: AppTheme.darkTheme,
      ));

      expect(find.text('Examen de Redes es lo que más mueve tu ciclo (6%).'), findsOneWidget);
      await tester.tap(find.byType(TarjetaPrioridad));
      expect(abierta, isTrue);
    });
  });
}
