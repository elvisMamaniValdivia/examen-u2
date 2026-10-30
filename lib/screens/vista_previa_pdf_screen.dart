import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Pantalla para visualizar, rotar, imprimir y compartir el reporte PDF (H22).
class VistaPreviaPdfScreen extends StatelessWidget {
  final String titulo;
  final String nombreArchivo;
  final Future<Uint8List> Function() generadorPdf;

  const VistaPreviaPdfScreen({
    super.key,
    required this.titulo,
    required this.nombreArchivo,
    required this.generadorPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: PdfPreview(
        build: (format) => generadorPdf(),
        pdfFileName: nombreArchivo,
        canChangeOrientation: false,
        canChangePageFormat: false,
        maxPageWidth: 720,
        previewPageMargin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      ),
    );
  }
}
