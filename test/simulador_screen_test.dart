import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_moviles2_grupo03/screens/simulador_screen.dart';
import 'package:proyecto_moviles2_grupo03/theme/app_theme.dart';

void main() {
  Widget crearApp({
    required Size screenSize,
    required Map<String, double?> notasPorUnidad,
    required Map<String, bool> unidadCompleta,
    required Map<String, double> pesosPorUnidad,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: SimuladorScreen(
          cursoId: 'c1',
          cursoNombre: 'Soluciones Móviles II',
          cicloNombre: '2026-I',
          notasPorUnidad: notasPorUnidad,
          unidadCompleta: unidadCompleta,
          pesosPorUnidad: pesosPorUnidad,
        ),
      ),
    );
  }

  group('SimuladorScreen UI (H17)', () {
    testWidgets('Renderiza campo de nota objetivo (0-20) y tarjeta de meta alcanzable', (tester) async {
      // 2 unidades de 50% cada una: U1 completa con 14.0, U2 pendiente
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        crearApp(
          screenSize: const Size(400, 800),
          notasPorUnidad: {'u1': 14.0, 'u2': null},
          unidadCompleta: {'u1': true, 'u2': false},
          pesosPorUnidad: {'u1': 50.0, 'u2': 50.0},
        ),
      );
      await tester.pumpAndSettle();

      // Verifica que el campo de texto exista
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Nota objetivo del curso'), findsOneWidget);

      // Con objetivo por defecto (10.5):
      // Acumulado U1 = 14 * 0.5 = 7.0. Pendiente U2 (50%).
      // Necesaria = (10.5 - 7.0) * 100 / 50 = 3.5 * 2 = 7.0
      expect(find.text('Meta alcanzable'), findsOneWidget);
      expect(find.text('7.0'), findsOneWidget);
      expect(find.text('/ 20'), findsWidgets);
    });

    testWidgets('Diferencia visualmente cuando la meta es inalcanzable', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      // U1 completa con 05.0 (peso 50%), U2 pendiente (peso 50%).
      // Máximo posible = 05*0.5 + 20*0.5 = 2.5 + 10 = 12.5.
      // Si objetivo es 18.0 -> Es INALCANZABLE.
      await tester.pumpWidget(
        crearApp(
          screenSize: const Size(400, 800),
          notasPorUnidad: {'u1': 5.0, 'u2': null},
          unidadCompleta: {'u1': true, 'u2': false},
          pesosPorUnidad: {'u1': 50.0, 'u2': 50.0},
        ),
      );
      await tester.pumpAndSettle();

      // Ingresar nota objetivo 18.0
      final textField = find.byType(TextField);
      await tester.enterText(textField, '18');
      await tester.pumpAndSettle();

      // Debe mostrar tarjeta de meta inalcanzable
      expect(find.text('Meta inalcanzable'), findsOneWidget);
      expect(find.text('> 20'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('Valida rango de nota (error si > 20 o < 0)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        crearApp(
          screenSize: const Size(400, 800),
          notasPorUnidad: {'u1': 12.0, 'u2': null},
          unidadCompleta: {'u1': true, 'u2': false},
          pesosPorUnidad: {'u1': 50.0, 'u2': 50.0},
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, '25');
      await tester.pumpAndSettle();

      expect(find.text('Ingresa una nota válida entre 0 y 20'), findsOneWidget);
    });

    testWidgets('Se adapta responsivamente en pantalla grande de computadora (>= 600px)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        crearApp(
          screenSize: const Size(1000, 800),
          notasPorUnidad: {'u1': 15.0, 'u2': null},
          unidadCompleta: {'u1': true, 'u2': false},
          pesosPorUnidad: {'u1': 50.0, 'u2': 50.0},
        ),
      );
      await tester.pumpAndSettle();

      // Debe renderizar la estructura en Row (2 columnas) en pantalla grande
      expect(find.byType(Row), findsWidgets);
      expect(find.text('Nota objetivo del curso'), findsOneWidget);
      expect(find.text('Meta alcanzable'), findsOneWidget);
    });
  });
}
