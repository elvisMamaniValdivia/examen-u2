import 'package:flutter/material.dart';

/// AppBar de dos lineas: nivel padre pequeno arriba y titulo grande abajo
/// (DESIGN.md seccion 6). Alto 64.
class AppBarNivel extends StatelessWidget implements PreferredSizeWidget {
  final String padre;
  final String titulo;
  final List<Widget>? acciones;
  final bool mostrarAtras;

  const AppBarNivel({
    super.key,
    required this.padre,
    required this.titulo,
    this.acciones,
    this.mostrarAtras = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final puedeVolver = mostrarAtras && (ModalRoute.of(context)?.canPop ?? false);

    return AppBar(
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      titleSpacing: puedeVolver ? 0 : 16,
      leading: puedeVolver
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            padre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
      actions: [...?acciones, const SizedBox(width: 4)],
    );
  }
}
