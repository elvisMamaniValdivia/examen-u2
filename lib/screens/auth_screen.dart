import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/validators.dart';
import 'home_screen.dart';
import 'verificar_correo_screen.dart';

/// Pantalla 02 - Login / Registro (DESIGN.md seccion 7).
///
/// Al registrarse se envia un correo de verificacion y la cuenta queda
/// bloqueada en [VerificarCorreoScreen] hasta que el usuario lo confirme.
class AuthScreen extends StatefulWidget {
  final bool modoVincular;
  const AuthScreen({super.key, this.modoVincular = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _esRegistro = false;
  bool _cargando = false;
  bool _verPassword = false;
  bool _intentoEnviar = false;

  String? _errorTitulo;
  String? _errorDetalle;
  String? _info;

  @override
  void initState() {
    super.initState();
    // Si la cuenta viene de la calculadora, lo natural es crear una cuenta nueva.
    _esRegistro = widget.modoVincular;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String _mapErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'El correo o la contraseña no coinciden. Revisa e intenta otra vez.';
      case 'email-already-in-use':
        return 'Este correo ya está registrado. Inicia sesión con él.';
      case 'invalid-email':
        return 'El formato del correo es inválido.';
      case 'weak-password':
        return 'La contraseña es muy débil. Usa al menos ${Validators.minimoPasswordRegistro} caracteres.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
      default:
        return 'Ocurrió un error. Por favor, intenta de nuevo.';
    }
  }

  void _limpiarMensajes() {
    if (_errorTitulo != null || _info != null) {
      setState(() {
        _errorTitulo = null;
        _errorDetalle = null;
        _info = null;
      });
    }
  }

  void _cambiarModo(bool registro) {
    if (registro == _esRegistro) return;
    setState(() {
      _esRegistro = registro;
      _intentoEnviar = false;
      _errorTitulo = null;
      _errorDetalle = null;
      _info = null;
      _confirmCtrl.clear();
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _intentoEnviar = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorTitulo = null;
      _errorDetalle = null;
      _info = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final UserCredential cred;
      if (_esRegistro) {
        cred = await auth.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
        await auth.setLanguageCode('es');
        await cred.user?.sendEmailVerification();
      } else {
        cred = await auth.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      }

      if (!mounted) return;
      final user = cred.user;

      // Cuenta sin verificar: no entra hasta confirmar el correo.
      if (user != null && !user.emailVerified) {
        final verificar = VerificarCorreoScreen(
          modoVincular: widget.modoVincular,
          recienEnviado: _esRegistro,
        );
        if (widget.modoVincular) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => verificar));
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => verificar),
            (route) => false,
          );
        }
        return;
      }

      if (widget.modoVincular) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorTitulo = _esRegistro ? 'No pudimos crear tu cuenta' : 'No pudimos iniciar sesión';
          _errorDetalle = _mapErrorMessage(e.code);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorTitulo = 'Error inesperado';
          _errorDetalle = 'Inténtalo de nuevo en un momento.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _recuperarPassword() async {
    final errorCorreo = Validators.email(_emailCtrl.text);
    if (errorCorreo != null) {
      setState(() {
        _info = null;
        _errorTitulo = 'Escribe tu correo';
        _errorDetalle = 'Ingresa arriba el correo de tu cuenta y vuelve a tocar "¿Olvidaste tu contraseña?".';
      });
      return;
    }
    try {
      await FirebaseAuth.instance.setLanguageCode('es');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailCtrl.text.trim());
    } on FirebaseAuthException catch (e) {
      // Por seguridad no revelamos si el correo existe; solo se informan errores de red o abuso.
      if (e.code == 'too-many-requests' || e.code == 'network-request-failed') {
        if (mounted) {
          setState(() {
            _info = null;
            _errorTitulo = 'No pudimos enviar el enlace';
            _errorDetalle = _mapErrorMessage(e.code);
          });
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _errorTitulo = null;
      _errorDetalle = null;
      _info = 'Si existe una cuenta con ${_emailCtrl.text.trim()}, te enviamos un enlace para restablecer tu contraseña.';
    });
  }

  void _continuarSinCuenta() {
    if (widget.modoVincular) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final estado = EstadoNotaColors.of(context);

    final errorEmail = _intentoEnviar ? Validators.email(_emailCtrl.text) : null;
    final errorPass = _intentoEnviar
        ? (_esRegistro ? Validators.passwordRegistro(_passCtrl.text) : Validators.password(_passCtrl.text))
        : null;
    final errorConfirm = _intentoEnviar ? Validators.confirmarPassword(_confirmCtrl.text, _passCtrl.text) : null;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      autovalidateMode:
                          _intentoEnviar ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            layoutBuilder: (actual, anteriores) => Stack(
                              alignment: Alignment.topLeft,
                              children: [...anteriores, ?actual],
                            ),
                            child: Column(
                              key: ValueKey(_esRegistro),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _esRegistro ? 'Crea tu cuenta' : 'Hola de nuevo',
                                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 34, height: 40 / 34),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _esRegistro
                                      ? 'Guarda tus notas y revísalas desde cualquier dispositivo.'
                                      : 'Inicia sesión para ver tus notas guardadas.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontSize: 17,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _SelectorModo(esRegistro: _esRegistro, onCambiar: _cambiarModo),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0, -0.04), end: Offset.zero).animate(anim),
                                child: child,
                              ),
                            ),
                            child: _errorTitulo != null
                                ? _BannerMensaje(
                                    key: ValueKey('error$_errorTitulo$_errorDetalle'),
                                    titulo: _errorTitulo!,
                                    detalle: _errorDetalle,
                                    icono: Icons.error_rounded,
                                    color: estado.desaprobado,
                                    fondo: estado.desaprobadoFondo,
                                    texto: estado.onDesaprobadoFondo,
                                  )
                                : _info != null
                                    ? _BannerMensaje(
                                        key: ValueKey('info$_info'),
                                        titulo: 'Revisa tu correo',
                                        detalle: _info,
                                        icono: Icons.mark_email_read_rounded,
                                        color: scheme.primary,
                                        fondo: scheme.primaryContainer,
                                        texto: scheme.onPrimaryContainer,
                                      )
                                    : const SizedBox(key: ValueKey('vacio'), width: double.infinity),
                          ),
                          const SizedBox(height: 24),
                          _Etiqueta('Correo', error: errorEmail != null),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'nombre@universidad.edu.pe',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: Validators.email,
                            onChanged: (_) {
                              _limpiarMensajes();
                              if (_intentoEnviar) setState(() {});
                            },
                          ),
                          const SizedBox(height: 20),
                          _Etiqueta('Contraseña', error: errorPass != null),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: !_verPassword,
                            autofillHints: [_esRegistro ? AutofillHints.newPassword : AutofillHints.password],
                            textInputAction: _esRegistro ? TextInputAction.next : TextInputAction.done,
                            onFieldSubmitted: _esRegistro ? null : (_) => _submit(),
                            decoration: InputDecoration(
                              hintText: _esRegistro ? 'Crea una contraseña' : 'Tu contraseña',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_verPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                tooltip: _verPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                                onPressed: () => setState(() => _verPassword = !_verPassword),
                              ),
                            ),
                            validator: _esRegistro ? Validators.passwordRegistro : Validators.password,
                            onChanged: (_) {
                              _limpiarMensajes();
                              setState(() {}); // actualiza la ayuda de "Minimo 8 caracteres"
                            },
                          ),
                          if (_esRegistro && errorPass == null) ...[
                            const SizedBox(height: 8),
                            _AyudaPassword(cumple: _passCtrl.text.length >= Validators.minimoPasswordRegistro),
                          ],
                          if (_esRegistro) ...[
                            const SizedBox(height: 20),
                            _Etiqueta('Confirmar contraseña', error: errorConfirm != null),
                            TextFormField(
                              controller: _confirmCtrl,
                              obscureText: !_verPassword,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                hintText: 'Repite tu contraseña',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                              validator: (v) => Validators.confirmarPassword(v, _passCtrl.text),
                              onChanged: (_) {
                                _limpiarMensajes();
                                if (_intentoEnviar) setState(() {});
                              },
                            ),
                          ],
                          if (!_esRegistro)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextButton(
                                  onPressed: _cargando ? null : _recuperarPassword,
                                  child: const Text('¿Olvidaste tu contraseña?'),
                                ),
                              ),
                            ),
                          const Spacer(),
                          const SizedBox(height: 32),
                          FilledButton(
                            onPressed: _cargando ? null : _submit,
                            child: _cargando
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary),
                                  )
                                : Text(_esRegistro ? 'Crear cuenta' : 'Iniciar sesión'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _cargando ? null : _continuarSinCuenta,
                            child: const Text('Continuar sin cuenta'),
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
    );
  }
}

/// Toggle segmentado en pill: "Iniciar sesion" | "Crear cuenta".
class _SelectorModo extends StatelessWidget {
  final bool esRegistro;
  final ValueChanged<bool> onCambiar;

  const _SelectorModo({required this.esRegistro, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget opcion(String texto, bool activa, bool valor) {
      return Expanded(
        child: Semantics(
          button: true,
          selected: activa,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onCambiar(valor),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activa ? scheme.surfaceContainerLowest : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: activa
                    ? [BoxShadow(color: scheme.shadow.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: activa ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          opcion('Iniciar sesión', !esRegistro, false),
          opcion('Crear cuenta', esRegistro, true),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final bool error;

  const _Etiqueta(this.texto, {this.error = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: error ? scheme.error : scheme.onSurface,
        ),
      ),
    );
  }
}

class _AyudaPassword extends StatelessWidget {
  final bool cumple;

  const _AyudaPassword({required this.cumple});

  @override
  Widget build(BuildContext context) {
    final estado = EstadoNotaColors.of(context);
    final color = cumple ? estado.aprobado : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(cumple ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          'Mínimo ${Validators.minimoPasswordRegistro} caracteres',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
        ),
      ],
    );
  }
}

class _BannerMensaje extends StatelessWidget {
  final String titulo;
  final String? detalle;
  final IconData icono;
  final Color color;
  final Color fondo;
  final Color texto;

  const _BannerMensaje({
    super.key,
    required this.titulo,
    this.detalle,
    required this.icono,
    required this.color,
    required this.fondo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: color, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: texto)),
                    if (detalle != null) ...[
                      const SizedBox(height: 4),
                      Text(detalle!, style: TextStyle(fontSize: 15, height: 1.35, color: texto)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
