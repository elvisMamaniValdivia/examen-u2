import 'package:flutter/material.dart';

/// Colores fijos de estado de una nota (DESIGN.md 2.2).
/// No dependen del color de marca: aprobado, desaprobado y aviso.
@immutable
class EstadoNotaColors extends ThemeExtension<EstadoNotaColors> {
  const EstadoNotaColors({
    required this.aprobado,
    required this.aprobadoFondo,
    required this.onAprobadoFondo,
    required this.desaprobado,
    required this.desaprobadoFondo,
    required this.onDesaprobadoFondo,
    required this.aviso,
    required this.avisoFondo,
    required this.onAvisoFondo,
    required this.pistaAprobado,
    required this.pistaDesaprobado,
  });

  final Color aprobado, aprobadoFondo, onAprobadoFondo;
  final Color desaprobado, desaprobadoFondo, onDesaprobadoFondo;
  final Color aviso, avisoFondo, onAvisoFondo;

  /// Pista (parte no rellena) de la EscalaNota segun el estado.
  final Color pistaAprobado, pistaDesaprobado;

  static const light = EstadoNotaColors(
    aprobado: Color(0xFF157A45),
    aprobadoFondo: Color(0xFFD7F3E1),
    onAprobadoFondo: Color(0xFF0B3D22),
    desaprobado: Color(0xFFC0352B),
    desaprobadoFondo: Color(0xFFFDE1DD),
    onDesaprobadoFondo: Color(0xFF5E1610),
    aviso: Color(0xFF8A5200),
    avisoFondo: Color(0xFFFFE7C2),
    onAvisoFondo: Color(0xFF4A2A00),
    pistaAprobado: Color(0xFFB4E4C6),
    pistaDesaprobado: Color(0xFFF2B8B1),
  );

  static const dark = EstadoNotaColors(
    aprobado: Color(0xFF6ED79B),
    aprobadoFondo: Color(0xFF0F3B24),
    onAprobadoFondo: Color(0xFFC9F5DA),
    desaprobado: Color(0xFFFF9A8F),
    desaprobadoFondo: Color(0xFF4A1712),
    onDesaprobadoFondo: Color(0xFFFFDAD5),
    aviso: Color(0xFFF5B867),
    avisoFondo: Color(0xFF4A3000),
    onAvisoFondo: Color(0xFFFFE7C2),
    pistaAprobado: Color(0xFF1E5537),
    pistaDesaprobado: Color(0xFF6B2620),
  );

  /// Obtiene la extension del tema. Si el tema no la registra (por ejemplo
  /// en un test con MaterialApp sin tema), usa la variante segun el brillo.
  static EstadoNotaColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<EstadoNotaColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// Color de texto para una nota: verde si aprueba, rojo si no,
  /// y [neutro] si no hay nota.
  Color colorDeNota(double? nota, Color neutro, {double umbral = 10.5}) {
    if (nota == null) return neutro;
    return nota >= umbral ? aprobado : desaprobado;
  }

  @override
  EstadoNotaColors copyWith({
    Color? aprobado,
    Color? aprobadoFondo,
    Color? onAprobadoFondo,
    Color? desaprobado,
    Color? desaprobadoFondo,
    Color? onDesaprobadoFondo,
    Color? aviso,
    Color? avisoFondo,
    Color? onAvisoFondo,
    Color? pistaAprobado,
    Color? pistaDesaprobado,
  }) {
    return EstadoNotaColors(
      aprobado: aprobado ?? this.aprobado,
      aprobadoFondo: aprobadoFondo ?? this.aprobadoFondo,
      onAprobadoFondo: onAprobadoFondo ?? this.onAprobadoFondo,
      desaprobado: desaprobado ?? this.desaprobado,
      desaprobadoFondo: desaprobadoFondo ?? this.desaprobadoFondo,
      onDesaprobadoFondo: onDesaprobadoFondo ?? this.onDesaprobadoFondo,
      aviso: aviso ?? this.aviso,
      avisoFondo: avisoFondo ?? this.avisoFondo,
      onAvisoFondo: onAvisoFondo ?? this.onAvisoFondo,
      pistaAprobado: pistaAprobado ?? this.pistaAprobado,
      pistaDesaprobado: pistaDesaprobado ?? this.pistaDesaprobado,
    );
  }

  @override
  EstadoNotaColors lerp(ThemeExtension<EstadoNotaColors>? other, double t) {
    if (other is! EstadoNotaColors) return this;
    return EstadoNotaColors(
      aprobado: Color.lerp(aprobado, other.aprobado, t)!,
      aprobadoFondo: Color.lerp(aprobadoFondo, other.aprobadoFondo, t)!,
      onAprobadoFondo: Color.lerp(onAprobadoFondo, other.onAprobadoFondo, t)!,
      desaprobado: Color.lerp(desaprobado, other.desaprobado, t)!,
      desaprobadoFondo:
          Color.lerp(desaprobadoFondo, other.desaprobadoFondo, t)!,
      onDesaprobadoFondo:
          Color.lerp(onDesaprobadoFondo, other.onDesaprobadoFondo, t)!,
      aviso: Color.lerp(aviso, other.aviso, t)!,
      avisoFondo: Color.lerp(avisoFondo, other.avisoFondo, t)!,
      onAvisoFondo: Color.lerp(onAvisoFondo, other.onAvisoFondo, t)!,
      pistaAprobado: Color.lerp(pistaAprobado, other.pistaAprobado, t)!,
      pistaDesaprobado: Color.lerp(pistaDesaprobado, other.pistaDesaprobado, t)!,
    );
  }
}
