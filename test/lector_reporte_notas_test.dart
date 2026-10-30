import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_moviles2_grupo03/services/lector_reporte_notas.dart';

/// Convierte frases en palabras con cajas aproximadas (7 px por caracter).
List<PalabraOcr> fila(double y, List<(double, String)> celdas, {double alto = 12}) {
  final palabras = <PalabraOcr>[];
  for (final (x, texto) in celdas) {
    var cursor = x;
    for (final w in texto.split(' ')) {
      final ancho = w.length * 7.0;
      palabras.add(PalabraOcr(w, cursor, y, cursor + ancho, y + alto));
      cursor += ancho + 4;
    }
  }
  return palabras;
}

List<PalabraOcr> encabezado(double y) => fila(y, [
      (80, 'Unidad'),
      (153, 'Criterio'),
      (255, 'Peso C.'),
      (301, 'Peso U.'),
      (348, 'Nota'),
      (385, 'Fecha'),
      (485, 'Descripción'),
    ]);

/// Reporte de "Taller de Tesis II" (imagen de referencia del issue H19).
List<PalabraOcr> reporteTallerTesis() => [
      ...fila(10, [(12, 'TALLER DE TESIS II / TRABAJO DE INVESTIGACIÓN')]),
      ...encabezado(40),
      ...fila(68, [(80, 'Unidad I'), (301, '30 %')]),
      ...fila(95, [(153, 'Evaluacion 01'), (255, '10 %'), (348, '13'), (387, 'Oct 09 2026'), (487, 'Actitudinal')]),
      ...fila(112, [(387, '01:47:00AM')]),
      ...fila(136, [(153, 'Evaluacion 02'), (255, '25 %'), (348, '13'), (387, 'Oct 12 2026'), (487, 'Trabajos de encargado')]),
      ...fila(153, [(387, '11:24:00:000PM')]),
      ...fila(178, [(153, 'Evaluacion 03'), (255, '35 %'), (348, '13'), (387, 'Oct 12 2026'), (487, 'Trabajo de investigación')]),
      ...fila(195, [(387, '11:59:00:000PM')]),
      ...fila(220, [(153, 'Evaluacion 04'), (255, '30 %'), (348, '18'), (387, 'Oct 09 2026'), (487, 'Examen de unidad')]),
      ...fila(237, [(387, '01:14:00:000AM')]),
      ...fila(262, [(262, '100 %'), (348, '14.50')]),
      ...encabezado(305),
      ...fila(332, [(80, 'Unidad II'), (301, '35 %')]),
      ...fila(358, [(153, 'Evaluacion 01'), (255, '10 %'), (482, 'Actitudinal')]),
      ...fila(386, [(153, 'Evaluacion 02'), (255, '25 %'), (482, 'Trabajos de encargado')]),
      ...fila(412, [(153, 'Evaluacion 03'), (255, '40 %'), (482, 'Trabajo de investigación')]),
      ...fila(440, [(153, 'Evaluacion 04'), (255, '25 %'), (482, 'Examen de unidad')]),
      ...fila(465, [(262, '100 %'), (348, '0.00')]),
      ...encabezado(510),
      ...fila(537, [(80, 'Unidad III'), (301, '35 %')]),
      ...fila(563, [(153, 'Evaluacion 01'), (255, '10 %'), (482, 'Actitudinal')]),
      ...fila(590, [(153, 'Evaluacion 02'), (255, '25 %'), (482, 'Trabajos de encargado')]),
      ...fila(616, [(153, 'Evaluacion 03'), (255, '45 %'), (482, 'Trabajo de investigación')]),
      ...fila(643, [(153, 'Evaluacion 04'), (255, '20 %'), (482, 'Examen de unidad')]),
      ...fila(670, [(262, '100 %'), (348, '0.00')]),
      ...fila(712, [(225, 'El promedio actual del curso es: 4')]),
    ];

/// Carga una lectura real de ML Kit guardada con el registro de depuracion
/// (formato "izq,arriba,der,abajo,angulo|texto").
List<PalabraOcr> cargarLectura(String ruta) => [
      for (final l in File(ruta).readAsLinesSync().where((l) => l.contains('|')))
        () {
          final i = l.indexOf('|');
          final n = l.substring(0, i).split(',').map(double.parse).toList();
          return PalabraOcr(l.substring(i + 1), n[0], n[1], n[2], n[3], angulo: n[4]);
        }(),
    ];

void main() {
  group('LectorReporteNotas - reporte del portal', () {
    final reporte = LectorReporteNotas.leer(reporteTallerTesis());

    test('Lee el nombre del curso', () {
      expect(reporte.curso, 'TALLER DE TESIS II / TRABAJO DE INVESTIGACIÓN');
    });

    test('Lee las 3 unidades con su peso y en numeros arabigos', () {
      expect(reporte.unidades.map((u) => u.nombre), ['Unidad 1', 'Unidad 2', 'Unidad 3']);
      expect(reporte.unidades.map((u) => u.peso), [30, 35, 35]);
    });

    test('Lee los criterios con peso, nota y descripcion', () {
      final u1 = reporte.unidades[0].criterios;
      expect(u1.length, 4);
      expect(u1.map((c) => c.peso), [10, 25, 35, 30]);
      expect(u1.map((c) => c.nota), [13, 13, 13, 18]);
      expect(u1[0].nombre, 'Evaluacion 01');
      expect(u1[0].descripcion, 'Actitudinal');
      expect(u1[3].descripcion, 'Examen de unidad');
    });

    test('Las evaluaciones sin nota quedan pendientes, no en 0', () {
      for (final u in reporte.unidades.skip(1)) {
        expect(u.criterios.length, 4);
        expect(u.criterios.every((c) => c.nota == null), isTrue);
      }
      expect(reporte.cantidadNotas, 4);
    });

    test('Ignora horas, totales y el pie del reporte', () {
      final todos = reporte.unidades.expand((u) => u.criterios).toList();
      expect(todos.length, 12);
      expect(todos.any((c) => c.descripcion.contains(':')), isFalse);
      expect(reporte.unidades[2].criterios.map((c) => c.peso), [10, 25, 45, 20]);
    });
  });

  group('LectorReporteNotas - OCR imperfecto', () {
    test('Corrige O por 0 y comas en celdas numericas', () {
      final r = LectorReporteNotas.leer([
        ...encabezado(0),
        ...fila(30, [(80, 'Unidad I'), (301, '3O %')]),
        ...fila(60, [(153, 'Evaluacion 01'), (255, '1O%'), (348, '15,5'), (487, 'Examen')]),
      ]);
      expect(r.unidades.single.peso, 30);
      expect(r.unidades.single.criterios.single.peso, 10);
      expect(r.unidades.single.criterios.single.nota, 15.5);
    });

    test('Sin encabezado detectado, interpreta la fila completa', () {
      final r = LectorReporteNotas.leer([
        ...fila(30, [(80, 'Unidad I'), (301, '30 %')]),
        ...fila(60, [(153, 'Evaluacion 01'), (255, '40 %'), (348, '16'), (387, 'Oct 09 2026'), (487, 'Examen de unidad')]),
      ]);
      final c = r.unidades.single.criterios.single;
      expect(c.peso, 40);
      expect(c.nota, 16);
      expect(c.descripcion, 'Examen de unidad');
    });

    test('Foto inclinada 5 grados: se endereza y lee igual', () {
      final angulo = 5 * math.pi / 180;
      final c = math.cos(angulo), s = math.sin(angulo);
      (double, double) girar(double x, double y) => (x * c - y * s, x * s + y * c);
      final inclinadas = [
        for (final p in reporteTallerTesis())
          PalabraOcr.desdeEsquinas(p.texto, [
            girar(p.izquierda, p.arriba),
            girar(p.derecha, p.arriba),
            girar(p.derecha, p.abajo),
            girar(p.izquierda, p.abajo),
          ]),
      ];
      final r = LectorReporteNotas.leer(inclinadas);
      expect(r.unidades.length, 3);
      expect(r.unidades[0].criterios.map((c) => c.nota), [13, 13, 13, 18]);
      expect(r.unidades[0].criterios.map((c) => c.peso), [10, 25, 35, 30]);
      expect(r.unidades[2].criterios.map((c) => c.peso), [10, 25, 45, 20]);
    });

    test('Fechas y horas no se mezclan con la descripcion ni con la nota', () {
      final r = LectorReporteNotas.leer([
        ...fila(30, [(80, 'Unidad I'), (301, '30 %')]),
        ...fila(60, [(153, 'Evaluacion 01'), (255, '15 %'), (387, 'Oct O2026 AM'), (487, 'Informes de laboratorio')]),
        ...fila(90, [(153, 'Evaluacion 02'), (255, '85 %'), (348, '7'), (387, 'Oct 12 2026 11:24:00PM'), (487, 'Proyecto')]),
      ]);
      final cs = r.unidades.single.criterios;
      expect(cs[0].descripcion, 'Informes de laboratorio');
      expect(cs[0].nota, isNull);
      expect(cs[1].descripcion, 'Proyecto');
      expect(cs[1].nota, 7);
    });

    test('"%" leido como "96" y numero de criterio leido como "O1"', () {
      final r = LectorReporteNotas.leer([
        ...encabezado(0),
        ...fila(30, [(80, 'Unidad I'), (301, '100 %')]),
        ...fila(60, [(153, 'Evaluacion O1'), (255, '4096'), (348, '12'), (487, 'Examen')]),
        ...fila(90, [(153, 'Evaluacion 02'), (255, '60 %'), (348, '14'), (487, 'Practicas')]),
      ]);
      final cs = r.unidades.single.criterios;
      expect(cs.map((c) => c.peso), [40, 60]);
      expect(cs[0].pesoDudoso, isTrue);
      expect(cs.map((c) => c.nota), [12, 14]);
    });

    test('Deduce el unico peso faltante para llegar a 100 y lo marca dudoso', () {
      final r = LectorReporteNotas.leer([
        ...fila(30, [(80, 'Unidad I'), (301, '30 %')]),
        ...fila(60, [(153, 'Evaluacion 01'), (255, '40 %'), (348, '15'), (487, 'Examen')]),
        ...fila(90, [(153, 'Evaluacion 02'), (487, 'Laboratorio')]),
        ...fila(130, [(80, 'Unidad II')]),
        ...fila(160, [(153, 'Evaluacion 01'), (255, '100 %'), (487, 'Examen')]),
      ]);
      expect(r.unidades[0].criterios[1].peso, 60);
      expect(r.unidades[0].criterios[1].pesoDudoso, isTrue);
      expect(r.unidades[1].peso, 70);
      expect(r.unidades[1].pesoDudoso, isTrue);
    });

    test('Numera las unidades en orden aunque el romano se lea mal', () {
      final r = LectorReporteNotas.leer([
        ...fila(30, [(80, 'Unidad l'), (301, '50 %')]),
        ...fila(60, [(153, 'Evaluacion 01'), (255, '100 %'), (348, '16'), (487, 'Examen')]),
        ...fila(90, [(80, 'Unidad Il'), (301, '50 %')]),
        ...fila(120, [(153, 'Evaluacion 01'), (255, '100 %'), (487, 'Examen')]),
      ]);
      expect(r.unidades.map((u) => u.nombre), ['Unidad 1', 'Unidad 2']);
    });

    test('Ignora el texto del navegador y toma el titulo justo antes de la tabla', () {
      final r = LectorReporteNotas.leer([
        ...fila(0, [(10, 'https://portal.upt.edu.pe/notas')]),
        ...fila(20, [(10, 'MENU PRINCIPAL')]),
        ...fila(40, [(12, 'BASE DE DATOS II')]),
        ...encabezado(70),
        ...fila(100, [(80, 'Unidad I'), (301, '100 %')]),
        ...fila(130, [(153, 'Evaluacion 01'), (255, '100 %'), (348, '17'), (487, 'Examen')]),
      ]);
      expect(r.curso, 'BASE DE DATOS II');
      expect(r.unidades.single.criterios.single.nota, 17);
    });

    test('Una imagen que no es un reporte devuelve un reporte vacio', () {
      final r = LectorReporteNotas.leer(fila(10, [(10, 'Hola mundo'), (200, 'esto no es una tabla')]));
      expect(r.vacio, isTrue);
    });
  });

  group('LectorReporteNotas - lectura real (foto de pantalla con perspectiva)', () {
    final r = LectorReporteNotas.leer(cargarLectura('test/fixtures/ocr_foto_pantalla_1.txt'));

    test('Lee el curso y se detiene antes del siguiente curso de la foto', () {
      expect(r.curso, 'SOLUCIONES MOVILES I');
      expect(r.unidades.length, 3);
    });

    test('Unidad 1 completa y sin dudas', () {
      final u = r.unidades[0];
      expect(u.peso, 25);
      expect(u.criterios.map((c) => c.peso), [15, 25, 35, 25]);
      expect(u.criterios.map((c) => c.nota), [15, 16, 14, 15]);
      expect(u.criterios.map((c) => c.descripcion), ['Actitudinal', 'Cognitivo', 'Procedimental', 'Examen de unidad']);
      expect(u.criterios.any((c) => c.pesoDudoso || c.notaDudosa), isFalse);
    });

    test('Unidad 2 con descripciones corregidas y notas pendientes', () {
      final u = r.unidades[1];
      expect(u.peso, 35);
      expect(u.criterios.map((c) => c.descripcion), ['Actitudinal', 'Cognitivo', 'Procedimental', 'Examen de unidad']);
      expect(u.criterios.every((c) => c.nota == null), isTrue);
    });

    test('Unidad 3 sin fila "Unidad III": se crea y su peso se deduce como dudoso', () {
      final u = r.unidades[2];
      expect(u.peso, 40);
      expect(u.pesoDudoso, isTrue);
      expect(u.criterios, isNotEmpty);
    });
  });

  group('LectorReporteNotas - lecturas reales de baja calidad', () {
    test('Foto 2: sin encabezados ni romanos, separa las unidades por "Evaluacion 01"', () {
      final r = LectorReporteNotas.leer(cargarLectura('test/fixtures/ocr_foto_pantalla_2.txt'));
      expect(r.curso, 'SOLUCIONES MOVILES I');
      expect(r.unidades.length, 2);
      for (final u in r.unidades) {
        expect(u.criterios.map((c) => c.peso), [15, 25, 35, 25]);
        expect(u.criterios.map((c) => c.descripcion), ['Actitudinal', 'Cognitivo', 'Procedimental', 'Examen de unidad']);
      }
      // "5" y "4" con caja sospechosa (el OCR perdio el "1" de 15 y 14): quedan para revisar.
      final u1 = r.unidades[0].criterios;
      expect(u1[0].notaDudosa, isTrue);
      expect(u1[1].nota, 16);
      expect(u1[1].notaDudosa, isFalse);
      expect(u1[2].notaDudosa, isTrue);
    });

    test('Foto 3: "%" leido como "9%" y encabezados deformados', () {
      final r = LectorReporteNotas.leer(cargarLectura('test/fixtures/ocr_foto_pantalla_3.txt'));
      expect(r.curso, 'SOLUCIONES MÓVILES II');
      expect(r.unidades.length, 3);
      expect(r.unidades[0].criterios.map((c) => c.nota), [15, 16, 14, 15]);
      expect(r.unidades[1].criterios.map((c) => c.peso), [15, 25, 35, 25]);
      expect(r.unidades[2].criterios.map((c) => c.peso), [25, 35, 40]);
      expect(r.unidades[2].criterios.any((c) => c.descripcion == 'In'), isFalse);
    });
  });

  group('LectorReporteNotas - imagen recortada a una unidad', () {
    final r = LectorReporteNotas.leer(cargarLectura('test/fixtures/ocr_recorte_unidad_1.txt'));

    test('Separa la nota pegada a la fecha ("5oct", "5Oct5") de la descripcion', () {
      final cs = r.unidades.single.criterios;
      expect(cs.map((c) => c.descripcion), ['Actitudinal', 'Cognitivo', 'Procedimental', 'Examen de unidad']);
      expect(cs.map((c) => c.peso), [15, 25, 35, 25]);
    });

    test('Notas con digito perdido quedan para revisar', () {
      final cs = r.unidades.single.criterios;
      expect(cs[0].notaDudosa, isTrue);
      expect(cs[2].notaDudosa, isTrue);
      expect(cs[3].notaDudosa, isTrue);
    });

    test('Con una sola unidad no se asume que pesa 100%', () {
      expect(r.unidades.single.peso, isNull);
      expect(r.unidades.single.pesoDudoso, isTrue);
    });
  });

  group('LectorReporteNotas - recorte borroso', () {
    final r = LectorReporteNotas.leer(cargarLectura('test/fixtures/ocr_recorte_unidad_2.txt'));

    test('Sin "%" en una fila, la nota no se toma como peso (columna aprendida)', () {
      final c3 = r.unidades.single.criterios[2];
      expect(c3.nota, 4);
      expect(c3.peso, isNot(4));
      expect(c3.pesoDudoso, isTrue);
    });

    test('Corrige palabras a las que el OCR les perdio el inicio ("amen" -> "Examen")', () {
      expect(r.unidades.single.criterios[3].descripcion, 'Examen de unidad');
      expect(r.unidades.single.criterios[0].descripcion, 'Actitudinal');
    });

    test('Todo lo leido con dudas queda marcado para revisar', () {
      final cs = r.unidades.single.criterios;
      expect(cs[0].pesoDudoso, isTrue);
      expect(cs[0].notaDudosa, isTrue);
      expect(cs[3].notaDudosa, isTrue);
    });
  });

  group('LectorReporteNotas - recorte nitido', () {
    test('Lee la unidad completa sin dudas y corrige "Examen de unHdd" por contexto', () {
      final r = LectorReporteNotas.leer(cargarLectura('test/fixtures/ocr_recorte_nitido.txt'));
      expect(r.curso, 'SOLUCIONES MOVILES II');
      final u = r.unidades.single;
      expect(u.peso, 25);
      expect(u.criterios.map((c) => c.peso), [15, 25, 35, 25]);
      expect(u.criterios.map((c) => c.nota), [15, 16, 14, 15]);
      expect(u.criterios.last.descripcion, 'Examen de unidad');
      expect(r.cantidadDudosos, 0);
    });
  });

  group('LectorReporteNotas - captura de pantalla pequena (letras de 8 px)', () {
    test('Lee curso, unidad, pesos, notas y descripciones sin dudas', () {
      final r = LectorReporteNotas.leer(cargarLectura('test/fixtures/ocr_captura_pequena.txt'));
      expect(r.curso, 'sOLUCIONES MÓVILES I');
      final u = r.unidades.single;
      expect(u.peso, 25);
      expect(u.criterios.map((c) => c.peso), [15, 25, 35, 25]);
      expect(u.criterios.map((c) => c.nota), [15, 16, 14, 15]);
      expect(u.criterios.map((c) => c.descripcion), ['Actitudinal', 'Cognitivo', 'Procedimental', 'Examen de unidad']);
      expect(r.cantidadDudosos, 0);
    });
  });
}
