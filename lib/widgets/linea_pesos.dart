import 'package:flutter/material.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/formato_nota.dart';

/// Linea de estado de la suma de pesos (pantalla 10):
/// verde = 100 %, ambar = falta, rojo = excede.
class LineaPesos extends StatelessWidget {
  final double suma;

  /// Version corta para cabeceras: "100%" o "90% · falta 10%".
  final bool compacta;

  const LineaPesos({super.key, required this.suma, this.compacta = false});

  @override
  Widget build(BuildContext context) {
    final estado = EstadoNotaColors.of(context);
    final diferencia = suma - 100.0;
    final esCompleta = diferencia.abs() <= 0.1;
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);

    final Color color;
    final IconData icono;
    final String texto;

    final prefijo = compacta ? '' : 'Los pesos suman ';
    if (esCompleta) {
      color = estado.aprobado;
      icono = Icons.check_circle_rounded;
      texto = '${prefijo}100%';
    } else if (diferencia < 0) {
      color = estado.aviso;
      icono = Icons.error_rounded;
      texto = '$prefijo${FormatoNota.porcentaje(suma)}% · falta ${FormatoNota.porcentaje(-diferencia)}%';
    } else {
      color = estado.desaprobado;
      icono = Icons.cancel_rounded;
      texto = '$prefijo${FormatoNota.porcentaje(suma)}% · te pasaste ${FormatoNota.porcentaje(diferencia)}%';
    }

    if (compacta) {
      return Semantics(
        label: 'Los pesos suman $texto',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: color, size: 18),
            const SizedBox(width: 4),
            Text(texto, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
    }

    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          // Microinteraccion 4: el aviso pasa a check con rebote al llegar a 100 %.
          AnimatedSwitcher(
            duration: Duration(milliseconds: sinAnimaciones ? 150 : 400),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: Tween(begin: 0.6, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: sinAnimaciones ? Curves.linear : Curves.elasticOut),
              ),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(icono, key: ValueKey(icono), color: color, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
