import 'package:flutter/material.dart';

/// Titulo de seccion en mayusculas con un elemento opcional a la derecha
/// (DESIGN.md seccion 3, rol "Seccion").
class SeccionTitulo extends StatelessWidget {
  final String texto;
  final Widget? trailing;

  const SeccionTitulo(this.texto, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                texto.toUpperCase(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
