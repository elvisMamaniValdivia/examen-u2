import 'package:flutter/material.dart';
import 'estado_nota_colors.dart';

/// Tema centralizado de Pondera (DESIGN.md secciones 2, 3 y 4).
/// Paleta A "Indigo tinta", modo claro y oscuro.
class AppTheme {
  static const String fuenteTitulos = 'BricolageGrotesque';
  static const String fuenteTexto = 'Figtree';

  // Colores de marca que no cambian con el modo (logo y regla de la bienvenida).
  static const Color indigoMarca = Color(0xFF3B36C4);
  static const Color ambarMarca = Color(0xFFFFB547);
  static const Color ambarMarcaOscuro = Color(0xFFE08A00);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: indigoMarca,
    brightness: Brightness.light,
  ).copyWith(
    primary: indigoMarca,
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFE3E1FF),
    onPrimaryContainer: const Color(0xFF17126B),
    surface: const Color(0xFFF7F6FB),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerHigh: const Color(0xFFEEEDF5),
    onSurface: const Color(0xFF17161F),
    onSurfaceVariant: const Color(0xFF55546A),
    outline: const Color(0xFFC9C7D6),
    outlineVariant: const Color(0xFFE4E2EE),
    error: EstadoNotaColors.light.desaprobado,
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: indigoMarca,
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFFBDBAFF),
    onPrimary: const Color(0xFF1E1880),
    primaryContainer: const Color(0xFF2E2A8F),
    onPrimaryContainer: const Color(0xFFE3E1FF),
    surface: const Color(0xFF111018),
    surfaceContainerLowest: const Color(0xFF1B1A24),
    surfaceContainerHigh: const Color(0xFF262433),
    onSurface: const Color(0xFFECEAF5),
    onSurfaceVariant: const Color(0xFFABA9BE),
    outline: const Color(0xFF47455A),
    outlineVariant: const Color(0xFF2C2A3A),
    error: EstadoNotaColors.dark.desaprobado,
  );

  /// Tonos de marca para los segmentos de peso, de mayor a menor (DESIGN.md 2.1).
  static List<Color> tonosPeso(Brightness brillo) => brillo == Brightness.dark
      ? const [Color(0xFFBDBAFF), Color(0xFF8F8AF0), Color(0xFF5F5AD0), Color(0xFF423DA8)]
      : const [Color(0xFF3B36C4), Color(0xFF6E69E0), Color(0xFFA9A5F3), Color(0xFFCFCDFF)];

  static ThemeData get lightTheme => _build(_lightScheme, EstadoNotaColors.light);

  static ThemeData get darkTheme => _build(_darkScheme, EstadoNotaColors.dark);

  /// Estilo para mostrar una nota: Bricolage, cifras tabulares y tracking -0.02em.
  static TextStyle estiloNota(double size, {Color? color, FontWeight weight = FontWeight.w700}) {
    return TextStyle(
      fontFamily: fuenteTitulos,
      fontSize: size,
      fontWeight: weight,
      height: 1.0,
      letterSpacing: size * -0.02,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    TextStyle titulo(double size, double lineHeight) => TextStyle(
          fontFamily: fuenteTitulos,
          fontSize: size,
          height: lineHeight / size,
          fontWeight: FontWeight.w700,
          letterSpacing: size * -0.02,
        );

    TextStyle texto(double size, double lineHeight, FontWeight weight) => TextStyle(
          fontFamily: fuenteTexto,
          fontSize: size,
          height: lineHeight / size,
          fontWeight: weight,
        );

    return TextTheme(
      displayLarge: titulo(76, 72),
      displayMedium: titulo(60, 60),
      displaySmall: titulo(44, 44),
      headlineLarge: titulo(34, 40),
      headlineMedium: titulo(30, 36),
      headlineSmall: titulo(28, 30),
      titleLarge: titulo(21, 26),
      titleMedium: texto(16, 22, FontWeight.w700),
      titleSmall: texto(14, 20, FontWeight.w700),
      bodyLarge: texto(16, 24, FontWeight.w400),
      bodyMedium: texto(15, 22, FontWeight.w400),
      bodySmall: texto(13, 18, FontWeight.w500),
      labelLarge: texto(15, 20, FontWeight.w700),
      labelMedium: texto(13, 18, FontWeight.w600),
      labelSmall: texto(12, 16, FontWeight.w600),
    ).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
  }

  static ThemeData _build(ColorScheme scheme, EstadoNotaColors estado) {
    final textTheme = _textTheme(scheme);

    OutlineInputBorder borde(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    final botonForma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    final botonTexto = textTheme.labelLarge?.copyWith(fontSize: 17);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fuenteTexto,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [estado],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      // Tarjetas planas: fondo surfaceContainerLowest + borde outlineVariant, sin sombra.
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        hintStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        border: borde(scheme.outline, 1),
        enabledBorder: borde(scheme.outline, 1),
        focusedBorder: borde(scheme.primary, 2),
        errorBorder: borde(scheme.error, 2),
        focusedErrorBorder: borde(scheme.error, 2),
        disabledBorder: borde(scheme.outlineVariant, 1),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        errorMaxLines: 2,
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.error)
              ? scheme.error
              : scheme.onSurfaceVariant,
        ),
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: botonForma,
          textStyle: botonTexto,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: botonForma,
          textStyle: botonTexto,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    );
  }
}
