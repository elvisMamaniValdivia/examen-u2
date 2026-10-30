import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_moviles2_grupo03/screens/home_screen.dart';
import 'package:proyecto_moviles2_grupo03/providers/componentes_provider.dart';
import 'package:proyecto_moviles2_grupo03/widgets/fila_componente.dart';

void main() {
  testWidgets('PromedioApp renderiza formulario con minimo 2 filas', (WidgetTester tester) async {
    final provider = ComponentesProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verifica que el titulo del AppBar este presente
    expect(find.text('Calculadora rápida'), findsOneWidget);

    // Verifica que el indicador de pesos aparezca correctamente
    expect(find.text('Los pesos suman 100%'), findsOneWidget);

    // Verifica que el provider contenga al menos 2 componentes
    expect(provider.componentes.length, greaterThanOrEqualTo(2));

    // Verifica que al menos 1 FilaComponente sea visible en pantalla
    expect(find.byType(FilaComponente), findsAtLeastNWidgets(1));
  });
}
