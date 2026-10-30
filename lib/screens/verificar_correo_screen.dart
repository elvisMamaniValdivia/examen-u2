import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/componentes_provider.dart';
import '../theme/estado_nota_colors.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

/// Pantalla que bloquea el acceso hasta que el usuario confirme su correo.
///
/// Firebase envia un enlace de verificacion al registrarse. Esta pantalla
/// revisa cada pocos segundos si ya se confirmo y permite reenviar el correo.
/// Mientras el correo no este verificado, la cuenta no guarda nada en Firestore.
class VerificarCorreoScreen extends StatefulWidget {
  /// true si se llego desde la calculadora sin cuenta: al verificar se vuelve
  /// a la calculadora con los componentes intactos.
  final bool modoVincular;

  /// true si el correo se acaba de enviar (recien registrado).
  final bool recienEnviado;

  const VerificarCorreoScreen({
    super.key,
    this.modoVincular = false,
    this.recienEnviado = false,
  });

  @override
  State<VerificarCorreoScreen> createState() => _VerificarCorreoScreenState();
}

class _VerificarCorreoScreenState extends State<VerificarCorreoScreen> {
  static const _intervaloRevision = Duration(seconds: 4);
  static const _esperaReenvio = 60;

  Timer? _revision;
  Timer? _cuentaRegresiva;
  int _segundosParaReenviar = 0;
  bool _comprobando = false;
  bool _terminado = false;
  String? _error;
  String? _info;

  String get _correo => FirebaseAuth.instance.currentUser?.email ?? 'tu correo';

  @override
  void initState() {
    super.initState();
    if (widget.recienEnviado) _iniciarEspera();
    _revision = Timer.periodic(_intervaloRevision, (_) => _comprobar(silencioso: true));
  }

  @override
  void dispose() {
    _revision?.cancel();
    _cuentaRegresiva?.cancel();
    super.dispose();
  }

  void _iniciarEspera() {
    _cuentaRegresiva?.cancel();
    setState(() => _segundosParaReenviar = _esperaReenvio);
    _cuentaRegresiva = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _segundosParaReenviar--);
      if (_segundosParaReenviar <= 0) t.cancel();
    });
  }

  Future<void> _comprobar({bool silencioso = false}) async {
    if (_comprobando || _terminado) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!silencioso) setState(() => _comprobando = true);
    try {
      await user.reload();
      final actualizado = FirebaseAuth.instance.currentUser;
      if (actualizado != null && actualizado.emailVerified) {
        // Refresca el token para que las reglas de Firestore vean email_verified = true.
        await actualizado.getIdToken(true);
        _alVerificar();
        return;
      }
      if (!silencioso && mounted) {
        setState(() {
          _info = null;
          _error = 'Aún no vemos la confirmación. Abre el enlace del correo y vuelve a intentarlo.';
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!silencioso && mounted) {
        setState(() => _error = e.code == 'network-request-failed'
            ? 'Sin conexión. Revisa tu internet e inténtalo de nuevo.'
            : 'No pudimos comprobar tu cuenta. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted && !silencioso) setState(() => _comprobando = false);
    }
  }

  void _alVerificar() {
    if (_terminado || !mounted) return;
    _terminado = true;
    _revision?.cancel();

    if (widget.modoVincular) {
      // Vuelve a la calculadora y guarda lo que el usuario ya tenia escrito.
      final provider = context.read<ComponentesProvider>();
      provider.sincronizar();
      final n = provider.componentes.length;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Cuenta verificada. $n componentes guardados.')),
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _reenviar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseAuth.instance.setLanguageCode('es');
      await user.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _error = null;
        _info = 'Te enviamos un nuevo enlace a $_correo.';
      });
      _iniciarEspera();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _info = null;
        _error = e.code == 'too-many-requests'
            ? 'Enviamos varios correos seguidos. Espera unos minutos antes de pedir otro.'
            : 'No pudimos reenviar el correo. Inténtalo de nuevo.';
      });
    }
  }

  /// Cierra la sesion sin verificar y vuelve atras.
  Future<void> _usarOtraCuenta() async {
    _terminado = true;
    _revision?.cancel();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    if (widget.modoVincular) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final estado = EstadoNotaColors.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _usarOtraCuenta();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Volver',
            onPressed: _usarOtraCuenta,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(Icons.mark_email_unread_rounded, size: 36, color: scheme.primary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Confirma tu correo', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                      children: [
                        const TextSpan(text: 'Te enviamos un enlace a '),
                        TextSpan(
                          text: _correo,
                          style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
                        ),
                        const TextSpan(
                          text: '. Ábrelo para activar tu cuenta; esta pantalla avanzará sola.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Esperando la confirmación…\n¿No lo ves? Revisa spam o promociones.',
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _error != null
                        ? _Mensaje(
                            key: ValueKey(_error),
                            texto: _error!,
                            icono: Icons.error_rounded,
                            color: estado.desaprobado,
                            fondo: estado.desaprobadoFondo,
                            textoColor: estado.onDesaprobadoFondo,
                          )
                        : _info != null
                            ? _Mensaje(
                                key: ValueKey(_info),
                                texto: _info!,
                                icono: Icons.mark_email_read_rounded,
                                color: scheme.primary,
                                fondo: scheme.primaryContainer,
                                textoColor: scheme.onPrimaryContainer,
                              )
                            : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _comprobando ? null : () => _comprobar(),
                    icon: _comprobando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Ya confirmé mi correo'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _segundosParaReenviar > 0 ? null : _reenviar,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      _segundosParaReenviar > 0
                          ? 'Reenviar en $_segundosParaReenviar s'
                          : 'Reenviar correo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _usarOtraCuenta,
                    child: Text(widget.modoVincular ? 'Cancelar y seguir sin cuenta' : 'Usar otra cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final Color fondo;
  final Color textoColor;

  const _Mensaje({
    super.key,
    required this.texto,
    required this.icono,
    required this.color,
    required this.fondo,
    required this.textoColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(texto, style: TextStyle(fontSize: 15, height: 1.35, color: textoColor)),
            ),
          ],
        ),
      ),
    );
  }
}
