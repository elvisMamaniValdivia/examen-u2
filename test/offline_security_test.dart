import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_moviles2_grupo03/services/seguridad_storage_service.dart';

void main() {
  group('Ítem 4 - Guardado sin conexión y cifrado (3 pruebas unitarias)', () {
    test(
        'Prueba (a): Al guardar una lista con el registro "Cliente Prueba", el contenido del archivo no contiene ese texto',
        () async {
      final fakeStorage = FakeFileStorage();
      final fakeVault = FakeKeyVault();
      final service = OfflineStorageService(
        fileStorage: fakeStorage,
        keyVault: fakeVault,
        cifradoHabilitado: true,
      );

      final lista = [
        const RegistroOffline(
          id: 'test_1',
          nombre: 'Cliente Prueba',
          detalle: 'Registro de verificación de cifrado',
          valor: 19.5,
        ),
      ];

      await service.guardarLista(lista);

      final bytes = await fakeStorage.leerBytes();
      expect(bytes, isNotNull);
      expect(bytes, isNotEmpty);

      // Convertimos los bytes crudos a cadena y confirmamos que "Cliente Prueba" no aparece en claro
      final textoCrudo = String.fromCharCodes(bytes!);
      expect(
        textoCrudo.contains('Cliente Prueba'),
        isFalse,
        reason: 'El archivo está cifrado con AES-GCM y no debe exponer texto plano.',
      );
    });

    test(
        'Prueba (b): Una lista de tres registros guardada y luego leída es igual a la original',
        () async {
      final fakeStorage = FakeFileStorage();
      final fakeVault = FakeKeyVault();
      final service = OfflineStorageService(
        fileStorage: fakeStorage,
        keyVault: fakeVault,
        cifradoHabilitado: true,
      );

      final listaOriginal = [
        const RegistroOffline(
            id: 'c1', nombre: 'Cálculo I', detalle: 'Créditos: 4', valor: 16.0),
        const RegistroOffline(
            id: 'c2', nombre: 'Física II', detalle: 'Créditos: 4', valor: 14.5),
        const RegistroOffline(
            id: 'c3',
            nombre: 'Programación Móvil',
            detalle: 'Créditos: 3',
            valor: 18.0),
      ];

      // Guardar lista de 3 registros
      await service.guardarLista(listaOriginal);

      // Leer la lista descifrada
      final resultado = await service.leerLista();

      expect(resultado.exito, isTrue);
      expect(resultado.registros.length, equals(3));
      expect(resultado.registros, equals(listaOriginal));
    });

    test(
        'Prueba (c): Sin archivo guardado, la lectura devuelve una lista vacía sin error',
        () async {
      final fakeStorage = FakeFileStorage();
      final fakeVault = FakeKeyVault();
      final service = OfflineStorageService(
        fileStorage: fakeStorage,
        keyVault: fakeVault,
        cifradoHabilitado: true,
      );

      final resultado = await service.leerLista();

      expect(resultado.exito, isTrue);
      expect(resultado.registros, isEmpty);
      expect(resultado.mensaje, isNull);
    });
  });

  group('Ítem 5 - Archivo dañado y borrado seguro (2 pruebas unitarias)', () {
    test(
        'Prueba (a): Si el descifrado falla, la lectura devuelve una lista vacía con el mensaje «Datos locales no disponibles, conéctese para actualizar», sin error',
        () async {
      final fakeStorage = FakeFileStorage();
      final fakeVault = FakeKeyVault();
      final service = OfflineStorageService(
        fileStorage: fakeStorage,
        keyVault: fakeVault,
        cifradoHabilitado: true,
      );

      // 1. Guardar primero una lista válida
      await service.guardarLista([
        const RegistroOffline(
            id: 'corrupt_test', nombre: 'Curso Sensible', valor: 15.0),
      ]);

      // 2. Corromper intencionalmente los bytes del archivo (dañar payload / MAC tag)
      final bytesValidos = await fakeStorage.leerBytes();
      final bytesCorruptos = Uint8List.fromList(bytesValidos!);
      for (int i = 0; i < bytesCorruptos.length; i++) {
        bytesCorruptos[i] = bytesCorruptos[i] ^ 0xAA; // Alteración de bits
      }
      await fakeStorage.escribirBytes(bytesCorruptos);

      // 3. Ejecutar lectura: no debe lanzar excepción no controlada
      final resultado = await service.leerLista();

      expect(resultado.registros, isEmpty);
      expect(resultado.exito, isFalse);
      expect(
        resultado.mensaje,
        equals('Datos locales no disponibles, conéctese para actualizar'),
      );
    });

    test(
        'Prueba (b): Después de borrar los datos, el archivo queda vacío y la clave se eliminó',
        () async {
      final fakeStorage = FakeFileStorage();
      final fakeVault = FakeKeyVault();
      final service = OfflineStorageService(
        fileStorage: fakeStorage,
        keyVault: fakeVault,
        cifradoHabilitado: true,
      );

      // Guardar datos
      await service.guardarLista([
        const RegistroOffline(
            id: 'del_test', nombre: 'Dato Temporal', valor: 20.0),
      ]);

      expect(await fakeStorage.existe(), isTrue);
      expect(fakeVault.claveActual, isNotNull);

      // Ejecutar borrado seguro de datos locales
      await service.borrarDatosLocales();

      // Comprobar que el archivo ya no existe / está vacío
      expect(await fakeStorage.existe(), isFalse);
      expect(await fakeStorage.leerBytes(), isNull);

      // Comprobar que la clave se eliminó de la bóveda
      expect(fakeVault.claveActual, isNull);
    });
  });
}
