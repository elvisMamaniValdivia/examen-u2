import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/curso.dart';
import '../utils/formato_nota.dart';
import 'calculos_multinivel.dart';

/// Servicio para generar el reporte de avance académico del ciclo en formato PDF (H22).
class ReporteCicloPdf {
  // Paleta de colores de Pondera (DESIGN.md)
  static final PdfColor _colorPrimario = PdfColor.fromHex('#3B36C4');
  static final PdfColor _colorAprobado = PdfColor.fromHex('#157A45');
  static final PdfColor _colorDesaprobado = PdfColor.fromHex('#C0352B');
  static final PdfColor _colorFondoGris = PdfColor.fromHex('#F4F4F8');
  static final PdfColor _colorTexto = PdfColor.fromHex('#1A1A24');
  static final PdfColor _colorTextoSecundario = PdfColor.fromHex('#5E5E6E');

  /// Construye y retorna los bytes del PDF del ciclo con soporte multi-página.
  static Future<Uint8List> generarPdf({
    required String cicloNombre,
    required List<Curso> cursos,
    required Map<String, ResultadoCalculoCurso> resultados,
    required double? promedioCiclo,
    required int totalCreditos,
    String? nombreEstudiante,
    String? correoEstudiante,
    DateTime? fechaEmision,
  }) async {
    final pdf = pw.Document(
      title: 'Reporte Pondera - $cicloNombre',
      author: 'Pondera',
    );

    final fecha = fechaEmision ?? DateTime.now();
    final fechaStr =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    final conNotas =
        resultados.values.where((r) => r.notaActual != null).length;
    final enRiesgo =
        resultados.values.where((r) => (r.notaActual ?? 99) < 10.5).length;
    final creditosEvaluados = cursos
        .where((c) => resultados[c.id]?.notaActual != null)
        .fold<int>(0, (acc, c) => acc + (c.creditos > 0 ? c.creditos : 3));

    final esAprobado = promedioCiclo != null && promedioCiclo >= 10.5;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (pw.Context context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColor.fromHex('#DCDCE8'),
                    width: 0.8,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PONDERA - Reporte de Avance ($cicloNombre)',
                    style: pw.TextStyle(
                      color: _colorTextoSecundario,
                      fontSize: 9,
                    ),
                  ),
                  pw.Text(
                    fechaStr,
                    style: pw.TextStyle(
                      color: _colorTextoSecundario,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            );
          }
          return pw.SizedBox();
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColor.fromHex('#DCDCE8'), thickness: 0.8),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Pondera - Sistema de Gestion y Simulacion de Calificaciones',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: _colorTextoSecundario,
                    ),
                  ),
                  pw.Text(
                    'Pagina ${context.pageNumber} de ${context.pagesCount}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: _colorTextoSecundario,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // 1. Cabecera principal (Solo página 1)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PONDERA',
                        style: pw.TextStyle(
                          color: _colorPrimario,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Reporte de Avance Academico',
                        style: pw.TextStyle(
                          color: _colorTexto,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      if (nombreEstudiante != null &&
                          nombreEstudiante.trim().isNotEmpty) ...[
                        pw.Text(
                          'Estudiante: $nombreEstudiante${correoEstudiante != null && correoEstudiante.isNotEmpty ? ' ($correoEstudiante)' : ''}',
                          style: pw.TextStyle(
                            color: _colorTexto,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                      ],
                      pw.Text(
                        'Ciclo: $cicloNombre',
                        style: pw.TextStyle(
                          color: _colorTextoSecundario,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Fecha de emision:',
                      style: pw.TextStyle(
                        color: _colorTextoSecundario,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      fechaStr,
                      style: pw.TextStyle(
                        color: _colorTexto,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(color: _colorPrimario, thickness: 1.5),
            pw.SizedBox(height: 14),

            // 2. Resumen del Ciclo (Tarjeta destacada)
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: _colorFondoGris,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColor.fromHex('#DCDCE8')),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PROMEDIO PONDERADO DEL CICLO',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _colorTextoSecundario,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            promedioCiclo != null
                                ? FormatoNota.nota(promedioCiclo)
                                : '-',
                            style: pw.TextStyle(
                              fontSize: 32,
                              fontWeight: pw.FontWeight.bold,
                              color: promedioCiclo == null
                                  ? _colorTextoSecundario
                                  : esAprobado
                                      ? _colorAprobado
                                      : _colorDesaprobado,
                            ),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Text(
                            '/ 20',
                            style: pw.TextStyle(
                              fontSize: 14,
                              color: _colorTextoSecundario,
                            ),
                          ),
                          if (promedioCiclo != null) ...[
                            pw.SizedBox(width: 10),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: pw.BoxDecoration(
                                color: esAprobado
                                    ? _colorAprobado
                                    : _colorDesaprobado,
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Text(
                                esAprobado ? 'APROBADO' : 'DESAPROBADO',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Creditos matriculados: $totalCreditos cr.',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _colorTexto,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Creditos evaluados: $creditosEvaluados cr.',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _colorTextoSecundario,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Cursos con notas: $conNotas de ${cursos.length}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _colorTextoSecundario,
                        ),
                      ),
                      if (enRiesgo > 0) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Cursos en riesgo: $enRiesgo',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _colorDesaprobado,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // 3. Título de la tabla
            pw.Text(
              'Detalle de Cursos Matriculados',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _colorTexto,
              ),
            ),
            pw.SizedBox(height: 8),

            // 4. Tabla de Cursos
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfColor.fromHex('#E0E0EC'),
                  width: 0.8,
                ),
                bottom: pw.BorderSide(
                  color: PdfColor.fromHex('#B0B0C4'),
                  width: 1,
                ),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(4.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FlexColumnWidth(1.6),
                4: const pw.FlexColumnWidth(2.0),
              },
              children: [
                // Fila Encabezado
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: _colorPrimario),
                  children: [
                    _celdaEncabezado('Curso', align: pw.TextAlign.left),
                    _celdaEncabezado('Creditos'),
                    _celdaEncabezado('Avance'),
                    _celdaEncabezado('Nota'),
                    _celdaEncabezado('Condicion'),
                  ],
                ),
                // Filas de Datos
                for (var i = 0; i < cursos.length; i++)
                  _construirFilaCurso(
                    curso: cursos[i],
                    resultado: resultados[cursos[i].id],
                    par: i % 2 == 0,
                  ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _celdaEncabezado(
    String texto, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(
        texto,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.TableRow _construirFilaCurso({
    required Curso curso,
    required ResultadoCalculoCurso? resultado,
    required bool par,
  }) {
    final nota = resultado?.notaActual;
    final evaluado = resultado?.porcentajeEvaluado ?? 0;
    final esRiesgo = nota != null && nota < 10.5;

    String condicion = 'Sin notas';
    PdfColor colorCondicion = _colorTextoSecundario;

    if (nota != null) {
      if (esRiesgo) {
        condicion = 'En riesgo';
        colorCondicion = _colorDesaprobado;
      } else if (evaluado >= 99.9) {
        condicion = 'Aprobado';
        colorCondicion = _colorAprobado;
      } else {
        condicion = 'En curso';
        colorCondicion = _colorPrimario;
      }
    }

    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: par ? PdfColor.fromHex('#FAFAFD') : PdfColors.white,
      ),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Text(
            curso.nombre,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _colorTexto,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Text(
            '${curso.creditos} cr.',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10, color: _colorTexto),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Text(
            '${FormatoNota.porcentaje(evaluado)}%',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10, color: _colorTextoSecundario),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Text(
            nota != null ? FormatoNota.nota(nota) : '-',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: nota == null
                  ? _colorTextoSecundario
                  : esRiesgo
                      ? _colorDesaprobado
                      : _colorAprobado,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Text(
            condicion,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: colorCondicion,
            ),
          ),
        ),
      ],
    );
  }
}
