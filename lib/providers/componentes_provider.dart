import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/componente_evaluacion.dart';
import '../services/calculos_service.dart';
import '../main.dart'; // Para el scaffoldMessengerKey

class ComponentesProvider extends ChangeNotifier {
  final List<ComponenteEvaluacion> _componentes = [];
  int _nextId = 1;
  final CalculosService _calculosService = CalculosService();
  Timer? _debounceTimer;
  
  // Guardamos el uid solo si el usuario esta autenticado y verifico su correo.
  // Una cuenta sin verificar se comporta como modo sin cuenta (no guarda).
  String? get currentUid {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !user.emailVerified) return null;
      return user.uid;
    } catch (e) {
      return null;
    }
  }

  ComponentesProvider() {
    _cargarDatos();
  }
  
  Future<void> _cargarDatos() async {
    final uid = currentUid;
    if (uid != null) {
      final guardados = await _calculosService.cargar(uid);
      if (guardados.isNotEmpty) {
        _componentes.clear();
        _componentes.addAll(guardados);
        
        // Actualizar _nextId basado en los guardados para evitar colisiones
        int maxId = 0;
        for (var c in guardados) {
          if (c.id.startsWith('comp_')) {
            final numId = int.tryParse(c.id.substring(5));
            if (numId != null && numId > maxId) {
              maxId = numId;
            }
          }
        }
        _nextId = maxId + 1;
        notifyListeners();
        return; // Si cargo datos, no inicializa por defecto
      }
    }
    _inicializarFilas();
    notifyListeners();
  }

  void _guardarEnFirestore() {
    final uid = currentUid;
    if (uid == null) return; // Si entra "Sin cuenta", no guardar

    // Debounce de 1 segundo para no spammar writes mientras escribe en el textfield
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      try {
        await _calculosService.guardar(uid, _componentes);
      } catch (e) {
        // En caso de timeout o excepcion de Firestore, mostrar mensaje sin romper el state local
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar: sin conexión a internet. Se guardará cuando vuelva la señal.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  List<ComponenteEvaluacion> get componentes => List.unmodifiable(_componentes);

  double get sumaPesos => _componentes.fold(0.0, (sum, item) => sum + item.peso);

  bool get esSumaPesosValida => (sumaPesos - 100.0).abs() <= 0.1;

  bool get puedeEliminar => _componentes.length > 2;

  void _inicializarFilas() {
    _componentes.add(
      ComponenteEvaluacion(
        id: _generarId(),
        nombre: 'Evaluación 1',
        nota: 0.0,
        peso: 50.0,
      ),
    );
    _componentes.add(
      ComponenteEvaluacion(
        id: _generarId(),
        nombre: 'Evaluación 2',
        nota: 0.0,
        peso: 50.0,
      ),
    );
  }

  String _generarId() {
    final id = 'comp_$_nextId';
    _nextId++;
    return id;
  }

  void agregarComponente() {
    _componentes.add(
      ComponenteEvaluacion(
        id: _generarId(),
        nombre: '',
        nota: 0.0,
        peso: 0.0,
      ),
    );
    notifyListeners();
    _guardarEnFirestore();
  }

  /// Vuelve a las 2 filas iniciales (accion "reiniciar" de la calculadora).
  void reiniciar() {
    _componentes.clear();
    _inicializarFilas();
    notifyListeners();
    _guardarEnFirestore();
  }

  /// Guarda los componentes actuales en la cuenta recien vinculada
  /// (por ejemplo, al verificar el correo desde la calculadora sin cuenta).
  void sincronizar() {
    _guardarEnFirestore();
  }

  void eliminarComponente(String id) {
    if (!puedeEliminar) return;
    _componentes.removeWhere((item) => item.id == id);
    notifyListeners();
    _guardarEnFirestore();
  }

  void actualizarComponente(
    String id, {
    String? nombre,
    double? nota,
    double? peso,
  }) {
    final index = _componentes.indexWhere((item) => item.id == id);
    if (index != -1) {
      _componentes[index] = _componentes[index].copyWith(
        nombre: nombre,
        nota: nota,
        peso: peso,
      );
      notifyListeners();
      _guardarEnFirestore();
    }
  }
}
