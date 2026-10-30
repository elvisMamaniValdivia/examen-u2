class Validators {
  /// Minimo de caracteres para crear una cuenta nueva.
  static const int minimoPasswordRegistro = 8;

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo es requerido';
    }
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) {
      return 'Ingresa un correo válido, ej. nombre@universidad.edu.pe';
    }
    return null;
  }

  /// Validacion para iniciar sesion (cuentas existentes).
  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  /// Validacion para registrarse: minimo 8 caracteres.
  static String? passwordRegistro(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < minimoPasswordRegistro) {
      return 'Usa al menos $minimoPasswordRegistro caracteres';
    }
    return null;
  }

  static String? confirmarPassword(String? value, String original) {
    if (value == null || value.isEmpty) {
      return 'Repite tu contraseña';
    }
    if (value != original) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }
}
