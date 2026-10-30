import 'package:flutter/services.dart';

/// Servicio para controlar la protección de pantalla contra capturas
/// y ocultar el contenido en la vista de aplicaciones recientes de Android (FLAG_SECURE).
class SeguridadPantallaService {
  static const MethodChannel _channel =
      MethodChannel('com.example.pondera/seguridad');

  static bool _pantallaProtegida = false;

  static bool get estaProtegida => _pantallaProtegida;

  /// Activa FLAG_SECURE en la ventana de Android.
  static Future<bool> activarProteccion() async {
    try {
      final res = await _channel.invokeMethod<bool>('activarFlagSecure');
      _pantallaProtegida = res ?? true;
      return _pantallaProtegida;
    } catch (_) {
      return false;
    }
  }

  /// Desactiva FLAG_SECURE en la ventana de Android.
  static Future<bool> desactivarProteccion() async {
    try {
      final res = await _channel.invokeMethod<bool>('desactivarFlagSecure');
      _pantallaProtegida = !(res ?? true);
      return !_pantallaProtegida;
    } catch (_) {
      return false;
    }
  }
}
