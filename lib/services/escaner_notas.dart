import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'lector_reporte_notas.dart';

/// Origen de la imagen del reporte.
enum OrigenImagen { camara, galeria }

/// H19 - Toma o elige la foto del reporte, deja recortarla y la lee con ML Kit
/// en el dispositivo.
///
/// Recortar solo la tabla (por ejemplo una unidad) quita ruido y agranda el
/// texto, lo que mejora mucho la lectura. La imagen no sale del telefono ni se
/// guarda: los archivos temporales se borran apenas termina el reconocimiento.
class EscanerNotas {
  final ImagePicker _picker = ImagePicker();
  final ImageCropper _recortador = ImageCropper();

  /// ML Kit solo funciona en Android e iOS.
  static bool get disponible =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Devuelve `null` si el usuario cancelo la camara, la galeria o el recorte.
  /// [colorPrincipal] y [colorSobrePrincipal] pintan la barra del editor de recorte.
  Future<ReporteDetectado?> escanear(
    OrigenImagen origen, {
    required Color colorPrincipal,
    required Color colorSobrePrincipal,
  }) async {
    final foto = await _picker.pickImage(
      source: origen == OrigenImagen.camara ? ImageSource.camera : ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (foto == null) return null;

    CroppedFile? recorte;
    try {
      recorte = await _recortador.cropImage(
        sourcePath: foto.path,
        compressFormat: ImageCompressFormat.png, // sin perdida: el texto queda nitido
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recorta la tabla',
            toolbarColor: colorPrincipal,
            toolbarWidgetColor: colorSobrePrincipal,
            activeControlsWidgetColor: colorPrincipal,
            statusBarLight: false,
            lockAspectRatio: false,
            initAspectRatio: CropAspectRatioPreset.original,
            hideBottomControls: false,
          ),
          IOSUiSettings(title: 'Recorta la tabla', aspectRatioLockEnabled: false),
        ],
      );
    } finally {
      if (recorte == null) await _borrar(foto.path);
    }
    if (recorte == null) return null;

    final reconocedor = TextRecognizer(script: TextRecognitionScript.latin);
    String? ampliada;
    try {
      // Las capturas de pantalla suelen tener letras de 7-9 px y ML Kit necesita
      // ~16 px por caracter: con letras tan chicas a veces no lee casi nada.
      ampliada = await Isolate.run(() => _ampliarSiEsPequena(recorte!.path));
      final texto = await reconocedor.processImage(InputImage.fromFilePath(ampliada ?? recorte.path));
      final palabras = <PalabraOcr>[
        for (final bloque in texto.blocks)
          for (final linea in bloque.lines)
            for (final e in linea.elements)
              // Las esquinas permiten calcular la inclinacion y enderezar la foto.
              e.cornerPoints.length == 4
                  ? PalabraOcr.desdeEsquinas(e.text, [
                      for (final p in e.cornerPoints) (p.x.toDouble(), p.y.toDouble()),
                    ])
                  : PalabraOcr(e.text, e.boundingBox.left, e.boundingBox.top, e.boundingBox.right, e.boundingBox.bottom),
      ];
      _registrarParaDepurar(palabras);
      return LectorReporteNotas.leer(palabras);
    } finally {
      await reconocedor.close();
      // Criterio 9: la imagen no se almacena.
      await _borrar(foto.path);
      await _borrar(recorte.path);
      if (ampliada != null) await _borrar(ampliada);
    }
  }

  /// Ancho minimo para leer bien una tabla del portal.
  static const _anchoMinimo = 1800;

  /// Amplia la imagen (2x a 4x, interpolacion cubica) si es pequena.
  /// Devuelve la ruta del archivo temporal ampliado, o null si no hacia falta.
  /// Corre en otro isolate para no congelar la pantalla.
  static String? _ampliarSiEsPequena(String ruta) {
    final imagen = img.decodeImage(File(ruta).readAsBytesSync());
    if (imagen == null || imagen.width >= _anchoMinimo) return null;
    final factor = (_anchoMinimo / imagen.width).clamp(1.0, 4.0);
    if (factor < 1.3) return null;
    final grande = img.copyResize(
      imagen,
      width: (imagen.width * factor).round(),
      interpolation: img.Interpolation.cubic,
    );
    final salida = '${ruta}_ocr.png';
    File(salida).writeAsBytesSync(img.encodePng(grande, level: 1));
    return salida;
  }

  static Future<void> _borrar(String ruta) async {
    try {
      await File(ruta).delete();
    } catch (_) {}
  }

  /// Solo en modo debug: imprime lo que leyo el OCR para convertir pruebas
  /// reales en casos de test. No se ejecuta en la app publicada.
  static void _registrarParaDepurar(List<PalabraOcr> palabras) {
    if (!kDebugMode) return;
    debugPrint('OCR_INICIO ${palabras.length} palabras');
    for (final p in palabras) {
      debugPrint('OCR ${p.izquierda.round()},${p.arriba.round()},${p.derecha.round()},${p.abajo.round()},'
          '${p.angulo.toStringAsFixed(3)}|${p.texto}');
    }
    debugPrint('OCR_FIN');
  }
}
