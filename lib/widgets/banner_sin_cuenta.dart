import 'package:flutter/material.dart';
import '../theme/estado_nota_colors.dart';

/// Aviso ambar del modo sin cuenta (DESIGN.md seccion 6, pantalla 10).
class BannerSinCuenta extends StatelessWidget {
  const BannerSinCuenta({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = EstadoNotaColors.of(context);
    final estilo = TextStyle(fontSize: 15, height: 1.35, color: estado.onAvisoFondo);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: estado.avisoFondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, color: estado.onAvisoFondo, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: estilo,
                children: const [
                  TextSpan(text: 'No se guardará. ', style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: 'Al cerrar la app perderás estos datos.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
