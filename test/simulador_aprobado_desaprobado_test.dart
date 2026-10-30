import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_moviles2_grupo03/screens/simulador_screen.dart';
import 'package:proyecto_moviles2_grupo03/theme/app_theme.dart';
import 'package:proyecto_moviles2_grupo03/theme/estado_nota_colors.dart';

void main() {
  group('SimuladorScreen - H18 Integración Aprobado / Desaprobado', () {
    testWidgets('Muestra promedio redondeado y tarjeta verde "Aprobado" cuando nota >= 10.5',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      // U1: 14.0 (peso 50%), U2: pendiente (peso 50%). Nota estimada = 12.0.
      // Promedio simulado = 14*0.5 + 12*0.5 = 13.0 (Aprobado).
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SimuladorScreen(
            cursoId: 'c1',
            cursoNombre: 'Móviles 2',
            notasPorUnidad: {'u1': 14.0, 'u2': null},
            unidadCompleta: {'u1': true, 'u2': false},
            pesosPorUnidad: {'u1': 50.0, 'u2': 50.0},
            notaEstimadaInicial: 12.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el texto exacto 'Aprobado'
      expect(find.text('Aprobado'), findsOneWidget);
      // Promedio redondeado: 13.0
      expect(find.text('13.0'), findsOneWidget);
      expect(find.text('Promedio final proyectado'), findsOneWidget);

      // Verificamos que el badge esté estilizado con verde
      final context = tester.element(find.text('Aprobado'));
      final estadoColors = EstadoNotaColors.of(context);

      final badgeContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Aprobado'),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = badgeContainer.decoration as BoxDecoration;
      expect(decoration.color, estadoColors.aprobado);
    });

    testWidgets('Muestra promedio redondeado y tarjeta roja "Desaprobado" cuando nota < 10.5',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      // U1: 08.0 (peso 50%), U2: pendiente (peso 50%). Nota estimada = 08.0.
      // Promedio simulado = 8*0.5 + 8*0.5 = 08.0 (Desaprobado).
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SimuladorScreen(
            cursoId: 'c1',
            cursoNombre: 'Móviles 2',
            notasPorUnidad: {'u1': 8.0, 'u2': null},
            unidadCompleta: {'u1': true, 'u2': false},
            pesosPorUnidad: {'u1': 50.0, 'u2': 50.0},
            notaEstimadaInicial: 8.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el texto exacto 'Desaprobado'
      expect(find.text('Desaprobado'), findsOneWidget);
      // Promedio redondeado: 08.0
      expect(find.text('8.0'), findsOneWidget);

      // Verificamos que el badge esté estilizado con rojo
      final context = tester.element(find.text('Desaprobado'));
      final estadoColors = EstadoNotaColors.of(context);

      final badgeContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Desaprobado'),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = badgeContainer.decoration as BoxDecoration;
      expect(decoration.color, estadoColors.desaprobado);
    });

    testWidgets('Cambia dinámicamente entre Desaprobado y Aprobado al mover el slider interactivo',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 950));

      // U1: 10.0 (50%), U2: pendiente (50%). Inicial con nota 6.0 -> Promedio = 8.0 (Desaprobado)
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SimuladorScreen(
            cursoId: 'c1',
            cursoNombre: 'Móviles 2',
            notasPorUnidad: {'u1': 10.0, 'u2': null},
            unidadCompleta: {'u1': true, 'u2': false},
            pesosPorUnidad: {'u1': 50.0, 'u2': 50.0},
            notaEstimadaInicial: 6.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Desaprobado'), findsOneWidget);
      expect(find.text('8.0'), findsOneWidget);

      // Deslizamos el slider hacia la derecha para subir la nota estimada a 16
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // Simulamos mover el slider
      final slider = tester.widget<Slider>(sliderFinder);
      slider.onChanged!(16.0);
      await tester.pumpAndSettle();

      // Con U1 = 10 (50%) y U2 = 16 (50%), promedio = 13.0 -> Aprobado
      expect(find.text('Aprobado'), findsOneWidget);
      expect(find.text('13.0'), findsOneWidget);
    });

    testWidgets('Diseño responsivo sin desbordamiento en computadoras (>= 600px)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SimuladorScreen(
            cursoId: 'c1',
            cursoNombre: 'Móviles 2',
            notasPorUnidad: {'u1': 15.0, 'u2': null},
            unidadCompleta: {'u1': true, 'u2': false},
            pesosPorUnidad: {'u1': 60.0, 'u2': 40.0},
            notaEstimadaInicial: 12.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe renderizar la tarjeta interactiva y las 2 columnas sin desbordamiento
      expect(find.text('Promedio final proyectado'), findsOneWidget);
      expect(find.text('Aprobado'), findsOneWidget);
      expect(find.byType(Row), findsWidgets);
    });
  });
}
