import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/formato_nota.dart';
import 'borde_punteado.dart';

/// Tarjeta de una unidad dentro del curso (DESIGN.md seccion 6, pantalla 05).
/// Bloque con el peso, nombre + resumen, icono de estado y nota.
class TarjetaUnidad extends StatelessWidget {
  final String nombre;
  final double peso;
  final double? nota;
  final String resumen;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const TarjetaUnidad({
    super.key,
    required this.nombre,
    required this.peso,
    required this.nota,
    required this.resumen,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    final valor = nota;
    final colorNota = estado.colorDeNota(valor, scheme.onSurfaceVariant);

    Widget tarjeta = Card(
      shape: valor == null ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)) : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${FormatoNota.porcentaje(peso)}%',
                  style: AppTheme.estiloNota(17, color: scheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(resumen, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (valor != null) ...[
                Icon(
                  valor >= 10.5 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: colorNota,
                  size: 20,
                ),
                const SizedBox(width: 6),
              ],
              Text(FormatoNota.nota(valor), style: AppTheme.estiloNota(26, color: colorNota)),
            ],
          ),
        ),
      ),
    );

    if (valor == null) {
      tarjeta = BordePunteado(color: scheme.outline, radio: 20, grosor: 1.2, child: tarjeta);
    }

    return Semantics(
      button: true,
      label: '$nombre, vale ${FormatoNota.porcentaje(peso)} por ciento, $resumen, '
          '${valor == null ? 'sin nota' : 'nota ${FormatoNota.nota(valor)}, ${valor >= 10.5 ? 'aprobado' : 'desaprobado'}'}',
      excludeSemantics: true,
      child: tarjeta,
    );
  }
}
