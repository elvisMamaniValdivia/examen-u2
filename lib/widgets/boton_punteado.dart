import 'package:flutter/material.dart';
import 'borde_punteado.dart';

/// Boton punteado de "agregar" al final de una lista
/// (ej. "+ Agregar componente", "+ Tipo de evaluacion").
class BotonPunteado extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;
  final IconData icono;

  const BotonPunteado({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BordePunteado(
      color: scheme.primary.withValues(alpha: 0.5),
      radio: 16,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, color: scheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    texto,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
