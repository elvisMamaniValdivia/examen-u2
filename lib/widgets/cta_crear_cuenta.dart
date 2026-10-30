import 'package:flutter/material.dart';

/// Barra fija inferior que invita a crear cuenta (DESIGN.md seccion 6, pantalla 10).
class CtaCrearCuenta extends StatelessWidget {
  final int cantidadComponentes;
  final VoidCallback onCrearCuenta;

  const CtaCrearCuenta({
    super.key,
    required this.cantidadComponentes,
    required this.onCrearCuenta,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palabra = cantidadComponentes == 1 ? 'componente' : 'componentes';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 15, height: 1.35, color: scheme.onSurface),
                    children: [
                      const TextSpan(text: 'Guarda estos '),
                      TextSpan(
                        text: '$cantidadComponentes $palabra',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: ' en tu cuenta.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18)),
                onPressed: onCrearCuenta,
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Crear cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
