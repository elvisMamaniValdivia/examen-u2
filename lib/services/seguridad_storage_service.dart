import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Modelo de negocio para los registros guardados sin conexión.
class RegistroOffline {
  final String id;
  final String nombre;
  final String detalle;
  final double valor;
  final String? fecha;

  const RegistroOffline({
    required this.id,
    required this.nombre,
    this.detalle = '',
    this.valor = 0.0,
    this.fecha,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'detalle': detalle,
        'valor': valor,
        if (fecha != null) 'fecha': fecha,
      };

  factory RegistroOffline.fromJson(Map<String, dynamic> json) =>
      RegistroOffline(
        id: json['id'] as String? ?? '',
        nombre: json['nombre'] as String? ?? '',
        detalle: json['detalle'] as String? ?? '',
        valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
        fecha: json['fecha'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegistroOffline &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre &&
          detalle == other.detalle &&
          valor == other.valor;

  @override
  int get hashCode =>
      id.hashCode ^ nombre.hashCode ^ detalle.hashCode ^ valor.hashCode;

  @override
  String toString() =>
      'RegistroOffline(id: $id, nombre: $nombre, valor: $valor)';
}

/// Resultado de la operación de lectura local.
class ResultadoLecturaOffline {
  final List<RegistroOffline> registros;
  final String? mensaje;
  final bool exito;

  const ResultadoLecturaOffline({
    required this.registros,
    this.mensaje,
    required this.exito,
  });
}

/// Contrato para el almacenamiento físico de bytes en archivo.
abstract class IFileStorage {
  Future<void> escribirBytes(Uint8List bytes);
  Future<Uint8List?> leerBytes();
  Future<bool> existe();
  Future<void> borrar();
  Future<int> tamano();
}

/// Contrato para la custodia de la clave criptográfica en el almacén seguro.
abstract class ISecureKeyVault {
  Future<String?> obtenerClaveHex();
  Future<void> guardarClaveHex(String claveHex);
  Future<void> borrarClave();
}

/// Implementación real de almacenamiento de archivos en el almacenamiento privado de la app.
class DeviceFileStorage implements IFileStorage {
  final String nombreArchivo;

  DeviceFileStorage({this.nombreArchivo = 'datos_offline.dat'});

  Future<List<File>> _obtenerArchivos() async {
    final dir = await getApplicationDocumentsDirectory();
    final list = <File>[File('${dir.path}/$nombreArchivo')];
    try {
      final filesDir = Directory('${dir.parent.path}/files');
      if (await filesDir.exists()) {
        list.add(File('${filesDir.path}/$nombreArchivo'));
      }
    } catch (_) {}
    return list;
  }

  @override
  Future<void> escribirBytes(Uint8List bytes) async {
    final files = await _obtenerArchivos();
    for (final file in files) {
      await file.writeAsBytes(bytes, flush: true);
    }
  }

  @override
  Future<Uint8List?> leerBytes() async {
    final files = await _obtenerArchivos();
    for (final file in files) {
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    }
    return null;
  }

  @override
  Future<bool> existe() async {
    final files = await _obtenerArchivos();
    for (final file in files) {
      if (await file.exists()) return true;
    }
    return false;
  }

  @override
  Future<void> borrar() async {
    final files = await _obtenerArchivos();
    for (final file in files) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  @override
  Future<int> tamano() async {
    final files = await _obtenerArchivos();
    for (final file in files) {
      if (await file.exists()) {
        return await file.length();
      }
    }
    return 0;
  }
}

/// Implementación real del almacén seguro utilizando Android Keystore (vía FlutterSecureStorage).
class KeystoreSecureKeyVault implements ISecureKeyVault {
  static const String _keyAlias = 'clave_cifrado_pondera_aes256';
  final FlutterSecureStorage _storage;

  KeystoreSecureKeyVault()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  @override
  Future<String?> obtenerClaveHex() async {
    return await _storage.read(key: _keyAlias);
  }

  @override
  Future<void> guardarClaveHex(String claveHex) async {
    await _storage.write(key: _keyAlias, value: claveHex);
  }

  @override
  Future<void> borrarClave() async {
    await _storage.delete(key: _keyAlias);
  }
}

/// Simulación en memoria de archivo para pruebas unitarias sin emulador.
class FakeFileStorage implements IFileStorage {
  Uint8List? _bytes;

  Uint8List? get bytesActuales => _bytes;

  @override
  Future<void> escribirBytes(Uint8List bytes) async {
    _bytes = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List?> leerBytes() async {
    return _bytes;
  }

  @override
  Future<bool> existe() async {
    return _bytes != null && _bytes!.isNotEmpty;
  }

  @override
  Future<void> borrar() async {
    _bytes = null;
  }

  @override
  Future<int> tamano() async {
    return _bytes?.length ?? 0;
  }
}

/// Simulación en memoria del almacén seguro para pruebas unitarias sin emulador.
class FakeKeyVault implements ISecureKeyVault {
  String? _claveHex;

  String? get claveActual => _claveHex;

  @override
  Future<String?> obtenerClaveHex() async {
    return _claveHex;
  }

  @override
  Future<void> guardarClaveHex(String claveHex) async {
    _claveHex = claveHex;
  }

  @override
  Future<void> borrarClave() async {
    _claveHex = null;
  }
}

/// Servicio principal de almacenamiento seguro offline con AES-GCM 256 bits,
/// generación de IV único por guardado y custodia de clave en Android Keystore.
class OfflineStorageService {
  final IFileStorage _fileStorage;
  final ISecureKeyVault _keyVault;
  final AesGcm _cipher;

  /// Si es false, almacena en texto claro (JSON UTF-8) para demostrar el Ítem 1.
  /// Si es true, cifra con AES-GCM 256 bits para el Ítem 2.
  bool cifradoHabilitado;

  OfflineStorageService({
    IFileStorage? fileStorage,
    ISecureKeyVault? keyVault,
    this.cifradoHabilitado = true,
  })  : _fileStorage = fileStorage ?? DeviceFileStorage(),
        _keyVault = keyVault ?? KeystoreSecureKeyVault(),
        _cipher = AesGcm.with256bits();

  /// Obtiene o genera la clave AES-256 custodiada en el almacén seguro del sistema.
  Future<SecretKey> _obtenerOCrearClave() async {
    String? claveHex = await _keyVault.obtenerClaveHex();
    if (claveHex == null || claveHex.isEmpty) {
      final nuevaClave = await _cipher.newSecretKey();
      final bytesClave = await nuevaClave.extractBytes();
      claveHex = bytesClave
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await _keyVault.guardarClaveHex(claveHex);
      return nuevaClave;
    }

    final bytes = <int>[];
    for (int i = 0; i < claveHex.length; i += 2) {
      bytes.add(int.parse(claveHex.substring(i, i + 2), radix: 16));
    }
    return SecretKey(bytes);
  }

  /// Guarda una lista de registros sin conexión.
  /// Si [cifradoHabilitado] es true: Cifra con AES-GCM con un IV aleatorio único.
  /// Si es false: Guarda en texto claro (JSON) para la evidencia del Ítem 1.
  Future<void> guardarLista(List<RegistroOffline> registros) async {
    final jsonString = jsonEncode(registros.map((r) => r.toJson()).toList());
    final clearBytes = utf8.encode(jsonString);

    if (!cifradoHabilitado) {
      // Ítem 1: Guardado en texto claro para evidenciar lectura con `adb shell run-as`
      await _fileStorage.escribirBytes(Uint8List.fromList(clearBytes));
      return;
    }

    // Ítem 2: Cifrado AES-GCM con IV aleatorio de 12 bytes
    final secretKey = await _obtenerOCrearClave();
    final nonce = _cipher.newNonce(); // 12 bytes aleatorios (IV único)

    final secretBox = await _cipher.encrypt(
      clearBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Concatena [nonce (12b)] + [ciphertext] + [mac (16b)]
    final payload = secretBox.concatenation();
    await _fileStorage.escribirBytes(Uint8List.fromList(payload));
  }

  /// Lee los registros almacenados localmente sin conexión.
  /// Maneja fallos de descifrado retornando lista vacía y mensaje descriptivo.
  Future<ResultadoLecturaOffline> leerLista() async {
    final existe = await _fileStorage.existe();
    if (!existe) {
      return const ResultadoLecturaOffline(
        registros: [],
        mensaje: null,
        exito: true,
      );
    }

    final bytes = await _fileStorage.leerBytes();
    if (bytes == null || bytes.isEmpty) {
      return const ResultadoLecturaOffline(
        registros: [],
        mensaje: null,
        exito: true,
      );
    }

    if (!cifradoHabilitado) {
      try {
        final rawText = utf8.decode(bytes);
        final decoded = jsonDecode(rawText) as List<dynamic>;
        final lista = decoded
            .map((item) =>
                RegistroOffline.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        return ResultadoLecturaOffline(
          registros: lista,
          mensaje: null,
          exito: true,
        );
      } catch (_) {
        return const ResultadoLecturaOffline(
          registros: [],
          mensaje: 'Datos locales no disponibles, conéctese para actualizar',
          exito: false,
        );
      }
    }

    try {
      final secretKey = await _obtenerOCrearClave();
      final secretBox = SecretBox.fromConcatenation(
        bytes,
        nonceLength: 12,
        macLength: 16,
      );

      final decryptedBytes = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      final clearText = utf8.decode(decryptedBytes);
      final decoded = jsonDecode(clearText) as List<dynamic>;
      final lista = decoded
          .map((item) =>
              RegistroOffline.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      return ResultadoLecturaOffline(
        registros: lista,
        mensaje: null,
        exito: true,
      );
    } catch (_) {
      // Ítem 5 - Tarea 1: Si el descifrado falla, devuelve lista vacía y mensaje exacto
      return const ResultadoLecturaOffline(
        registros: [],
        mensaje: 'Datos locales no disponibles, conéctese para actualizar',
        exito: false,
      );
    }
  }

  /// Borra físicamente el archivo local y elimina la clave del almacén seguro (Ítem 3 y 5).
  Future<void> borrarDatosLocales() async {
    await _fileStorage.borrar();
    await _keyVault.borrarClave();
  }
}
