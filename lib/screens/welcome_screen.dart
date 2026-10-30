import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/pondera_logo.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

/// Pantalla 01 - Splash / Bienvenida (DESIGN.md seccion 7).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isVisible = true);
      }
    });
  }

  void _irA(Widget pantalla) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => pantalla,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    // En claro el fondo es primary; en oscuro primary es lavanda clara,
    // asi que se usa primaryContainer para mantener el contraste con el texto.
    final fondo = esOscuro ? scheme.primaryContainer : scheme.primary;
    final frente = esOscuro ? scheme.onPrimaryContainer : scheme.onPrimary;
    final tagline = esOscuro ? scheme.onPrimaryContainer.withValues(alpha: 0.85) : scheme.primaryContainer;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: fondo,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 80),
                    child: IntrinsicHeight(
                      child: AnimatedOpacity(
                        opacity: _isVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: PonderaLogo(size: 96, sobreMarca: true, animado: true),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'Pondera',
                              style: TextStyle(
                                fontFamily: AppTheme.fuenteTitulos,
                                fontSize: 60,
                                height: 1.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.8,
                                color: frente,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tu promedio ponderado, claro y al día. Del ciclo 1 al 10.',
                              style: TextStyle(fontSize: 19, height: 27 / 19, color: tagline),
                            ),
                            const Spacer(),
                            const SizedBox(height: 40),
                            _ReglaNota(color: frente),
                            const SizedBox(height: 40),
                            const Spacer(),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: frente,
                                foregroundColor: fondo,
                              ),
                              onPressed: () => _irA(const AuthScreen()),
                              icon: const Icon(Icons.login_rounded),
                              label: const Text('Iniciar sesión o registrarme'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: frente,
                                side: BorderSide(color: frente.withValues(alpha: 0.5)),
                              ),
                              onPressed: () => _irA(const HomeScreen()),
                              icon: const Icon(Icons.calculate_rounded),
                              label: const Text('Continuar sin cuenta'),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Sin cuenta usas la calculadora rápida; tus notas no se guardan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, height: 18 / 13, color: tagline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Regla decorativa 0-20 con la marca ambar en 10.5.
class _ReglaNota extends StatelessWidget {
  final Color color;

  const _ReglaNota({required this.color});

  @override
  Widget build(BuildContext context) {
    final estiloEtiqueta = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: color.withValues(alpha: 0.75),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return ExcludeSemantics(
      child: Column(
        children: [
          SizedBox(
            height: 40,
            width: double.infinity,
            child: CustomPaint(painter: _PintorRegla(marcas: color.withValues(alpha: 0.45))),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 18,
            child: Stack(
              children: [
                Align(alignment: Alignment.centerLeft, child: Text('0', style: estiloEtiqueta)),
                // 10.5 / 20 = 52.5 % del ancho -> Alignment x = 0.05
                Align(
                  alignment: const Alignment(0.05, 0),
                  child: Text('10.5', style: estiloEtiqueta.copyWith(color: AppTheme.ambarMarca)),
                ),
                Align(alignment: Alignment.centerRight, child: Text('20', style: estiloEtiqueta)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PintorRegla extends CustomPainter {
  final Color marcas;

  _PintorRegla({required this.marcas});

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = marcas
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final ancho = size.width - 2;
    for (var i = 0; i <= 20; i++) {
      final x = 1 + ancho * i / 20;
      final alto = i % 5 == 0 ? 26.0 : 18.0;
      canvas.drawLine(Offset(x, size.height), Offset(x, size.height - alto), pincel);
    }
    final umbral = Paint()
      ..color = AppTheme.ambarMarca
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final xUmbral = 1 + ancho * 10.5 / 20;
    canvas.drawLine(Offset(xUmbral, size.height), Offset(xUmbral, 0), umbral);
  }

  @override
  bool shouldRepaint(_PintorRegla old) => old.marcas != marcas;
}
