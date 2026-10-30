import 'package:flutter/material.dart';
import 'borde_punteado.dart';

/// Pantalla o bloque vacio con un solo boton (DESIGN.md seccion 6 y pantalla 03b).
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final String textoBoton;
  final VoidCallback onPressed;
  final String? tip;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.textoBoton,
    required this.onPressed,
    this.tip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Ilustracion(icono: icono),
        const SizedBox(height: 28),
        Text(titulo, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(texto, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_rounded),
            label: Text(textoBoton),
          ),
        ),
        if (tip != null) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_rounded, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tip!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Tarjetas apiladas: la de abajo punteada con el icono "+" (pantalla 03b).
class _Ilustracion extends StatelessWidget {
  final IconData icono;

  const _Ilustracion({required this.icono});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget tarjeta(double ancho, Color fondo, {Widget? child}) => Container(
          width: ancho,
          height: 52,
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: child,
        );

    return ExcludeSemantics(
      child: SizedBox(
        width: 200,
        height: 132,
        child: Stack(
          children: [
            Positioned(
              left: 24,
              top: 0,
              child: tarjeta(
                152,
                scheme.surfaceContainerHigh,
              ),
            ),
            Positioned(
              left: 12,
              top: 18,
              child: tarjeta(
                176,
                scheme.surfaceContainerLowest,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icono, size: 18, color: scheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 70,
                      height: 8,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 78,
              child: BordePunteado(
                color: scheme.outline,
                radio: 16,
                child: SizedBox(
                  width: 200,
                  height: 52,
                  child: Icon(Icons.add_rounded, color: scheme.primary, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
