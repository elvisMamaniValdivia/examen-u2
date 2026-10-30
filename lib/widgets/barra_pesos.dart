import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/estado_nota_colors.dart';
import 'borde_punteado.dart';

/// Barra segmentada con el peso de cada parte (DESIGN.md "IndicadorPeso").
/// Si falta para 100 %, el resto se dibuja punteado en ambar;
/// si se excede, los segmentos pasan a rojo.
class BarraPesos extends StatelessWidget {
  final List<double> pesos;

  const BarraPesos({super.key, required this.pesos});

  @override
  Widget build(BuildContext context) {
    final estado = EstadoNotaColors.of(context);
    final tonos = AppTheme.tonosPeso(Theme.of(context).brightness);
    final total = pesos.fold<double>(0, (a, b) => a + b);
    final excede = total > 100.1;
    final falta = 100 - total;

    int flex(double v) => (v * 10).round().clamp(1, 100000);

    final segmentos = <Widget>[
      for (var i = 0; i < pesos.length; i++)
        if (pesos[i] > 0)
          Expanded(
            flex: flex(pesos[i]),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: excede ? estado.desaprobado : tonos[i % tonos.length],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      if (falta > 0.1)
        Expanded(
          flex: flex(falta),
          child: BordePunteado(
            color: estado.aviso,
            radio: 4,
            grosor: 1.2,
            child: const SizedBox(height: 8),
          ),
        ),
    ];

    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < segmentos.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            segmentos[i],
          ],
        ],
      ),
    );
  }
}
