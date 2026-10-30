/// H19 - Lectura del reporte de notas del portal a partir del texto reconocido
/// por la camara (OCR).
///
/// Es logica pura (sin ML Kit ni Firebase) para poder probarla con tests.
/// Recibe las palabras detectadas con su posicion y reconstruye la tabla
/// Unidad / Criterio / Peso C. / Peso U. / Nota / Fecha / Descripcion.
///
/// Como las fotos llegan inclinadas, en perspectiva o con errores de lectura,
/// el lector no depende solo de la posicion:
/// 1. Endereza la imagen con el angulo de las palabras.
/// 2. Usa anclas fijas del formato ("Unidad I", "Evaluacion 01").
/// 3. Reconoce cada dato por su forma (peso "15 %", nota 0-20, fecha, hora).
/// 4. Aplica reglas del dominio (numeracion secuencial, pesos que suman 100)
///    y marca como dudoso lo que tuvo que deducir.
library;

import 'dart:math' as math;

/// Una palabra reconocida con su caja en la imagen (en pixeles).
class PalabraOcr {
  final String texto;
  final double izquierda;
  final double arriba;
  final double derecha;
  final double abajo;

  /// Inclinacion de la palabra en radianes (0 = horizontal).
  final double angulo;

  const PalabraOcr(this.texto, this.izquierda, this.arriba, this.derecha, this.abajo, {this.angulo = 0});

  /// Construye la palabra a partir de sus 4 esquinas (sup-izq, sup-der, inf-der, inf-izq),
  /// como las entrega ML Kit. Calcula la inclinacion con el borde superior.
  factory PalabraOcr.desdeEsquinas(String texto, List<(double, double)> esquinas) {
    final xs = esquinas.map((p) => p.$1);
    final ys = esquinas.map((p) => p.$2);
    var angulo = 0.0;
    if (esquinas.length >= 2) {
      angulo = math.atan2(esquinas[1].$2 - esquinas[0].$2, esquinas[1].$1 - esquinas[0].$1);
    }
    return PalabraOcr(texto, xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max),
        angulo: angulo);
  }

  double get centroX => (izquierda + derecha) / 2;
  double get centroY => (arriba + abajo) / 2;
  double get alto => abajo - arriba;
  double get ancho => derecha - izquierda;
}

/// Un criterio de evaluacion leido (una fila "Evaluacion 01 ...").
class CriterioDetectado {
  /// Nombre del criterio en el portal (ej. "Evaluacion 01").
  String nombre;

  /// Descripcion (ej. "Examen de unidad"); se usa como nombre del tipo.
  String descripcion;
  double? peso;

  /// `null` si el criterio aun no tiene nota (pendiente).
  double? nota;

  /// Valores que el lector dedujo o corrigio y conviene revisar.
  bool pesoDudoso;
  bool notaDudosa;

  CriterioDetectado({
    required this.nombre,
    this.descripcion = '',
    this.peso,
    this.nota,
    this.pesoDudoso = false,
    this.notaDudosa = false,
  });
}

/// Una unidad leida con sus criterios.
class UnidadDetectada {
  String nombre;
  double? peso;
  bool pesoDudoso;
  final List<CriterioDetectado> criterios;

  UnidadDetectada({required this.nombre, this.peso, this.pesoDudoso = false, List<CriterioDetectado>? criterios})
      : criterios = criterios ?? [];
}

/// Resultado de leer un reporte completo.
class ReporteDetectado {
  final String? curso;
  final List<UnidadDetectada> unidades;

  const ReporteDetectado({this.curso, required this.unidades});

  bool get vacio => unidades.isEmpty || unidades.every((u) => u.criterios.isEmpty);
  int get cantidadNotas => unidades.fold(0, (a, u) => a + u.criterios.where((c) => c.nota != null).length);
  int get cantidadDudosos => unidades.fold(
        0,
        (a, u) => a + (u.pesoDudoso ? 1 : 0) + u.criterios.where((c) => c.pesoDudoso || c.notaDudosa).length,
      );
}

enum _Columna { unidad, criterio, pesoC, pesoU, nota, fecha, descripcion }

enum _Tipo { porcentaje, numero, fecha, palabra }

/// Un dato de una fila ya clasificado por su forma.
class _Token {
  final String texto;
  final double x;
  final _Tipo tipo;
  final double? valor;

  /// Peso que se leyo con un "%" mal reconocido (ej. "1596" en vez de "15 %").
  final bool corregido;

  /// Ancho / alto de la caja: sirve para detectar un digito perdido.
  final double proporcion;

  const _Token(this.texto, this.x, this.tipo, {this.valor, this.corregido = false, this.proporcion = 0.6});
}

class LectorReporteNotas {
  static const _meses = {
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'set', 'sep', 'oct', 'nov', 'dic', //
    'jan', 'apr', 'aug', 'dec',
  };

  /// Lee el reporte. Devuelve un reporte vacio si no reconoce la tabla.
  static ReporteDetectado leer(List<PalabraOcr> palabras) {
    if (palabras.isEmpty) return const ReporteDetectado(unidades: []);
    final filas = _agruparEnFilas(palabras);

    // Columna de pesos aprendida de la propia imagen: donde estan los "25 %".
    // Sirve cuando no se leyo el encabezado y a una fila le falta el "%".
    final xPesos = <double>[];
    for (final fila in filas) {
      final inicio = _anclaCriterio(fila);
      if (inicio == null) continue;
      xPesos.addAll(_clasificar(fila.sublist(inicio)).where((t) => t.tipo == _Tipo.porcentaje).map((t) => t.x));
    }
    final xPesoTipico = _mediana(xPesos);
    final anchoImagen = palabras.map((p) => p.derecha).reduce(math.max);

    final filasTexto = <String>[];
    String? curso;
    List<(_Columna, double)>? columnas;
    final unidades = <UnidadDetectada>[];
    var tablaEmpezo = false;

    // Cada unidad tiene su propio encabezado. Si aparece uno nuevo y la fila
    // "Unidad X" no se pudo leer, los criterios siguientes van a una unidad nueva.
    var esperaUnidadNueva = false;

    for (final fila in filas) {
      final texto = fila.map((p) => p.texto).join(' ').trim();
      if (texto.isEmpty) continue;

      // "El promedio actual del curso es: 4" cierra la tabla del curso; lo que
      // sigue en la foto pertenece a otro curso.
      if (tablaEmpezo && RegExp(r'prom\S*\s+ac', caseSensitive: false).hasMatch(texto)) break;

      final encabezado = _leerEncabezado(fila);
      if (encabezado != null) {
        columnas = encabezado;
        if (!tablaEmpezo && curso == null) curso = _tituloAntes(filasTexto);
        tablaEmpezo = true;
        if (unidades.isNotEmpty && unidades.last.criterios.isNotEmpty) esperaUnidadNueva = true;
        continue;
      }
      filasTexto.add(texto);

      // Fila de unidad: "Unidad I ... 30 %"
      final inicioUnidad = _anclaUnidad(fila, anchoImagen);
      if (inicioUnidad != null) {
        if (!tablaEmpezo && curso == null) curso = _tituloAntes(filasTexto..removeLast());
        tablaEmpezo = true;
        esperaUnidadNueva = false;
        final tokens = _clasificar(fila.sublist(inicioUnidad));
        final porcentaje = tokens.where((t) => t.tipo == _Tipo.porcentaje).firstOrNull;
        final enColumna = columnas == null ? null : _enColumna(tokens, columnas, _Columna.pesoU);
        // Si el "%" no se leyo, cualquier numero de la fila de la unidad es su peso (dudoso).
        final peso = porcentaje ?? enColumna ?? tokens.where((t) => t.tipo == _Tipo.numero).firstOrNull;
        unidades.add(UnidadDetectada(
          // Numeracion por orden de aparicion: evita "Unidad 49" por un romano mal leido.
          nombre: 'Unidad ${unidades.length + 1}',
          peso: _pesoValido(peso?.valor) ? peso!.valor : null,
          pesoDudoso: peso == null || peso.corregido || porcentaje == null,
        ));
        continue;
      }

      // Fila de criterio: "Evaluacion 01  10 %  13  Oct 09 2026  Actitudinal"
      final inicioCriterio = _anclaCriterio(fila);
      if (inicioCriterio != null) {
        if (!tablaEmpezo && curso == null) curso = _tituloAntes(filasTexto.sublist(0, filasTexto.length - 1));
        tablaEmpezo = true;
        // "Evaluacion 01" otra vez: empezo otra unidad aunque no se leyo su fila ni su encabezado.
        final numero = _numeroCriterio(fila, inicioCriterio);
        if (numero == 1 && unidades.isNotEmpty && unidades.last.criterios.length >= 2) esperaUnidadNueva = true;
        if (unidades.isEmpty || esperaUnidadNueva) {
          unidades.add(UnidadDetectada(nombre: 'Unidad ${unidades.length + 1}', pesoDudoso: true));
          esperaUnidadNueva = false;
        }
        final u = unidades.last;
        u.criterios.add(_leerCriterio(
          fila.sublist(inicioCriterio),
          columnas,
          xPesoTipico,
          'Evaluacion ${(u.criterios.length + 1).toString().padLeft(2, '0')}',
        ));
      }
    }

    curso ??= tablaEmpezo ? null : _tituloAntes(filasTexto);
    unidades.removeWhere((u) => u.criterios.isEmpty && u.peso == null);
    _completarPesos(unidades);
    return ReporteDetectado(curso: curso, unidades: unidades);
  }

  // --- Geometria ---

  /// Agrupa las palabras en filas siguiendo la inclinacion local de la foto.
  ///
  /// Una foto de pantalla tiene perspectiva: arriba las filas pueden estar
  /// rectas y abajo inclinadas varios grados. Por eso cada palabra usa el
  /// angulo mediano de las palabras cercanas (no un angulo global) y se agrupa
  /// por el punto donde su fila cortaria el borde izquierdo de la imagen.
  static List<List<PalabraOcr>> _agruparEnFilas(List<PalabraOcr> palabras) {
    final altoTipico = _mediana(palabras.map((p) => p.alto).where((h) => h > 0).toList()) ?? 12;
    final confiables = palabras.where((p) => p.ancho > p.alto * 1.5).toList();
    final anguloGlobal = _mediana(confiables.map((p) => p.angulo).toList()) ?? 0;

    double anguloLocal(PalabraOcr p) {
      final cercanas = confiables
          .where((q) => (q.centroY - p.centroY).abs() <= altoTipico * 4)
          .map((q) => q.angulo)
          .toList();
      return _mediana(cercanas) ?? anguloGlobal;
    }

    final conCorte = [
      for (final p in palabras) (p, p.centroY - math.tan(anguloLocal(p)) * p.centroX),
    ]..sort((a, b) => a.$2.compareTo(b.$2));

    final tolerancia = altoTipico * 0.55;
    final filas = <List<PalabraOcr>>[];
    final cortes = <double>[];
    final sumas = <double>[];
    for (final (p, corte) in conCorte) {
      if (filas.isNotEmpty && (corte - cortes.last).abs() <= tolerancia) {
        filas.last.add(p);
        sumas[sumas.length - 1] += corte;
        cortes[cortes.length - 1] = sumas.last / filas.last.length;
      } else {
        filas.add([p]);
        cortes.add(corte);
        sumas.add(corte);
      }
    }
    for (final f in filas) {
      f.sort((a, b) => a.izquierda.compareTo(b.izquierda));
    }
    return filas;
  }

  /// Si la fila es el encabezado de la tabla, devuelve donde empieza cada columna.
  /// Tolera errores de lectura: basta con reconocer 3 de los titulos.
  static List<(_Columna, double)>? _leerEncabezado(List<PalabraOcr> fila) {
    final textos = fila.map((p) => _normalizar(p.texto)).toList();
    final columnas = <(_Columna, double)>[];
    var pesos = 0;
    for (var i = 0; i < fila.length; i++) {
      final t = textos[i];
      final x = fila[i].izquierda;
      if (t == 'unidad' || (t.length >= 4 && _distancia(t, 'unidad') <= 2)) {
        columnas.add((_Columna.unidad, x));
      } else if (t.startsWith('crit') || (t.length >= 6 && _distancia(t, 'criterio') <= 3)) {
        columnas.add((_Columna.criterio, x));
      } else if (t.startsWith('peso') || (t.length == 4 && _distancia(t, 'peso') <= 1)) {
        final siguiente = i + 1 < fila.length ? textos[i + 1] : '';
        final esU = t.endsWith('u') || t.endsWith('u.') || siguiente.startsWith('u');
        final esC = t.endsWith('c') || t.endsWith('c.') || siguiente.startsWith('c');
        columnas.add((esU || (!esC && pesos > 0) ? _Columna.pesoU : _Columna.pesoC, x));
        pesos++;
      } else if (t == 'nota' || (t.length == 4 && _distancia(t, 'nota') <= 1)) {
        columnas.add((_Columna.nota, x));
      } else if (t.startsWith('fech') || (t.length == 5 && _distancia(t, 'fecha') <= 1)) {
        columnas.add((_Columna.fecha, x));
      } else if (t.startsWith('descrip') || (t.length >= 7 && _distancia(t, 'descripcion') <= 3)) {
        columnas.add((_Columna.descripcion, x));
      }
    }
    final distintas = columnas.map((c) => c.$1).toSet();
    final sinNumeros = !textos.any((t) => RegExp(r'\d').hasMatch(t));
    final esEncabezado = (distintas.length >= 3 &&
            (distintas.contains(_Columna.criterio) || distintas.contains(_Columna.nota) || pesos > 0)) ||
        // Encabezado mal leido: al menos 2 titulos y ningun numero ("Griterno ... Descripclon").
        (distintas.length >= 2 &&
            sinNumeros &&
            (distintas.contains(_Columna.criterio) || distintas.contains(_Columna.descripcion)));
    if (!esEncabezado) return null;
    columnas.sort((a, b) => a.$2.compareTo(b.$2));
    return columnas;
  }

  /// Posicion de la palabra "Unidad" seguida de un numero romano o arabigo, o null.
  /// Tambien acepta "Unidad" sola (romano no leido) si esta en la parte izquierda
  /// de la imagen, donde va la columna "Unidad".
  static int? _anclaUnidad(List<PalabraOcr> fila, double anchoImagen) {
    for (var i = 0; i < fila.length && i < 3; i++) {
      final t = _normalizar(fila[i].texto);
      if (RegExp(r'^unid[a-z]*[ivxl1|]+$').hasMatch(t)) return i; // "UnidadII" pegado
      final esUnidad = t.startsWith('unid') || (t.length >= 4 && _distancia(t, 'unidad') <= 2);
      if (esUnidad && i + 1 < fila.length) {
        final siguiente = _normalizar(fila[i + 1].texto);
        if (RegExp(r'^([ivxl1|]{1,4}|\d{1,2})$').hasMatch(siguiente)) return i;
      }
      if (esUnidad && i == 0 && fila[i].izquierda < anchoImagen * 0.35) {
        final resto = fila.skip(1).map((p) => _normalizar(p.texto)).toList();
        final soloNumeros = resto.every((r) => RegExp(r'^[\d%.,o ]+$').hasMatch(r) || _esSignoPorcentaje(r));
        if (soloNumeros) return i;
      }
    }
    return null;
  }

  /// Numero del criterio ("01", "o1", "ol", "0335%" -> 3), o null si no se lee.
  static int? _numeroCriterio(List<PalabraOcr> fila, int inicio) {
    final pegado = RegExp(r'(\S{2})$').firstMatch(fila[inicio].texto)?.group(1) ?? '';
    final candidatos = [if (inicio + 1 < fila.length) fila[inicio + 1].texto, pegado];
    for (final c in candidatos) {
      final limpio = c.replaceAll(RegExp('[oOD]'), '0').replaceAll(RegExp('[lIi|!]'), '1');
      final m = RegExp(r'^(\d{1,2})').firstMatch(limpio);
      if (m != null) {
        final n = int.parse(m.group(1)!.length == 2 || limpio.length == 1 ? m.group(1)! : m.group(1)!.substring(0, 1));
        if (n >= 1 && n <= 12) return n;
      }
    }
    return null;
  }

  static bool _esSignoPorcentaje(String t) =>
      const {'%', '96', '9%', '%o', '%0', '9/o', 'o/o', '°/o', '9%o', '%.'}.contains(t.trim().toLowerCase());

  /// Posicion de la palabra "Evaluacion" (o una lectura parecida), o null.
  static int? _anclaCriterio(List<PalabraOcr> fila) {
    for (var i = 0; i < fila.length && i < 3; i++) {
      final t = _normalizar(fila[i].texto);
      // Tolera lecturas como "Evaluaeien", "Exaluscian" o "byeluecion".
      if (t.startsWith('evalu') || t.startsWith('evai')) return i;
      final letras = t.replaceAll(RegExp(r'[^a-z]'), '');
      if (letras.length >= 7 && letras.length <= 13 && _distancia(letras, 'evaluacion') <= 4) return i;
      if (i + 1 < fila.length && letras.length >= 4) {
        final unidas = letras + _normalizar(fila[i + 1].texto).replaceAll(RegExp(r'[^a-z]'), '');
        if (unidas.length >= 7 && unidas.length <= 13 && _distancia(unidas, 'evaluacion') <= 4) {
          // "Ewalua in": se unen las dos palabras para que "in" no quede como descripcion.
          final a = fila[i], b = fila[i + 1];
          fila[i] = PalabraOcr('${a.texto}${b.texto}', a.izquierda, math.min(a.arriba, b.arriba), b.derecha,
              math.max(a.abajo, b.abajo), angulo: a.angulo);
          fila.removeAt(i + 1);
          return i;
        }
      }
    }
    return null;
  }

  // --- Clasificacion por forma ---

  /// Clasifica los datos de una fila: porcentajes, numeros, fechas/horas y palabras.
  /// Se salta el ancla ("Unidad II", "Evaluacion 01").
  static List<_Token> _clasificar(List<PalabraOcr> fila) {
    final palabras = [...fila];
    if (palabras.isNotEmpty) palabras.removeAt(0); // "Unidad" o "Evaluacion"
    // Numero del ancla: "01" o el romano.
    if (palabras.isNotEmpty &&
        (RegExp(r'^([ivxl1|]{1,4}|\d{1,2})$').hasMatch(_normalizar(palabras.first.texto)) ||
            RegExp(r'^\d{1,2}$').hasMatch(_limpiarNumero(palabras.first.texto)))) {
      palabras.removeAt(0); // tambien "O1" leido en vez de "01"
    } else if (palabras.isNotEmpty) {
      // "0335%": numero de criterio pegado al peso -> se deja solo "35%".
      final pegado = RegExp(r'^[0oO][\dOolI](\d{1,3}%?)$').firstMatch(palabras.first.texto.trim());
      if (pegado != null) {
        final p0 = palabras.first;
        palabras[0] = PalabraOcr(pegado.group(1)!, p0.izquierda, p0.arriba, p0.derecha, p0.abajo);
      }
    }

    // "15Oct" o "5Oct15": la nota quedo pegada a la fecha; se separan.
    final reMesPegado = RegExp(r'^(\d{1,2}(?:[.,]\d)?)?([A-Za-z]{3}\.?)(\d{1,2})?$');
    for (var i = 0; i < palabras.length; i++) {
      final p = palabras[i];
      final m = reMesPegado.firstMatch(p.texto.trim().replaceAllMapped(RegExp(r'(?<=\D)0|0(?=\D)'), (_) => 'o'));
      if (m == null || (m.group(1) == null && m.group(3) == null)) continue;
      if (!_meses.contains(_normalizar(m.group(2)!).replaceAll('.', ''))) continue;
      final partes = [?m.group(1), m.group(2)!, ?m.group(3)];
      final ancho = p.ancho / partes.join().length;
      var x = p.izquierda;
      final nuevas = <PalabraOcr>[];
      for (final parte in partes) {
        nuevas.add(PalabraOcr(parte, x, p.arriba, x + ancho * parte.length, p.abajo));
        x += ancho * parte.length;
      }
      palabras
        ..removeAt(i)
        ..insertAll(i, nuevas);
      i += nuevas.length - 1;
    }

    final tokens = <_Token>[];
    var restoFecha = 0;
    for (var i = 0; i < palabras.length; i++) {
      final p = palabras[i];
      final crudo = p.texto.trim();
      if (crudo.isEmpty) continue;
      final siguiente = i + 1 < palabras.length ? palabras[i + 1].texto.trim() : '';

      // Fechas y horas: "Oct 09 2026", "O2026", "01:47:00AM".
      final normal = _normalizar(crudo.replaceAll('0', 'o'));
      // Solo palabras cortas ("Oct", "oct.", "Sept"): "Dictado" no es una fecha.
      final mes = normal.replaceAll('.', '');
      if (mes.length >= 3 && mes.length <= 4 && _meses.contains(mes.substring(0, 3))) {
        tokens.add(_Token(crudo, p.izquierda, _Tipo.fecha));
        restoFecha = 2;
        continue;
      }
      if (RegExp(r'\d{1,2}:\d{2}').hasMatch(crudo) ||
          RegExp(r'^[oO]?20\d\d$').hasMatch(crudo) ||
          RegExp(r'^(am|pm|a\.m\.|p\.m\.)$', caseSensitive: false).hasMatch(crudo)) {
        tokens.add(_Token(crudo, p.izquierda, _Tipo.fecha));
        continue;
      }
      if (restoFecha > 0 && RegExp(r'^[\dOo]{1,4}$').hasMatch(crudo)) {
        tokens.add(_Token(crudo, p.izquierda, _Tipo.fecha));
        restoFecha--;
        continue;
      }
      restoFecha = 0;

      // Signo "%" suelto (o mal leido como "96", "9%"): convierte el numero anterior en porcentaje.
      if (_esSignoPorcentaje(crudo) && tokens.isNotEmpty && tokens.last.tipo == _Tipo.numero && tokens.last.valor! <= 100) {
        final previo = tokens.removeLast();
        tokens.add(_Token(previo.texto, previo.x, _Tipo.porcentaje,
            valor: previo.valor, corregido: crudo != '%', proporcion: previo.proporcion));
        continue;
      }
      if (crudo == '%') continue;

      final limpio = _limpiarNumero(crudo);
      final esNumerico = RegExp(r'^\d+(?:\.\d+)?%?$').hasMatch(limpio) && RegExp(r'\d').hasMatch(crudo);
      if (esNumerico) {
        final conPorcentaje = limpio.endsWith('%') || siguiente == '%';
        final valor = double.tryParse(limpio.replaceAll('%', ''))!;
        final proporcion = p.alto > 0 ? p.ancho / p.alto : 0.6;
        final pegadoNueve = RegExp(r'^(\d{1,2})9%$').firstMatch(limpio);
        if (valor > 100 && pegadoNueve != null) {
          // "259%": el "%" se leyo como "9%" -> 25 %.
          tokens.add(_Token(crudo, p.izquierda, _Tipo.porcentaje,
              valor: double.parse(pegadoNueve.group(1)!), corregido: true));
        } else if (conPorcentaje) {
          tokens.add(_Token(crudo, p.izquierda, _Tipo.porcentaje, valor: valor));
        } else if (valor > 100 && RegExp(r'^\d{1,3}96$').hasMatch(limpio)) {
          // "%" leido como "96": "1596" -> 15 %.
          tokens.add(_Token(crudo, p.izquierda, _Tipo.porcentaje,
              valor: double.parse(limpio.substring(0, limpio.length - 2)), corregido: true));
        } else {
          tokens.add(_Token(crudo, p.izquierda, _Tipo.numero, valor: valor, proporcion: proporcion));
        }
        continue;
      }

      if (RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]{2,}').hasMatch(crudo)) {
        tokens.add(_Token(crudo, p.izquierda, _Tipo.palabra));
      }
    }
    return tokens;
  }

  static _Token? _enColumna(List<_Token> tokens, List<(_Columna, double)> columnas, _Columna buscada) {
    final inicio = columnas.where((c) => c.$1 == buscada).map((c) => c.$2).firstOrNull;
    if (inicio == null) return null;
    final siguientes = columnas.where((c) => c.$2 > inicio + 1).map((c) => c.$2);
    final fin = siguientes.isEmpty ? double.infinity : siguientes.reduce(math.min);
    final margen = (fin == double.infinity ? 40.0 : (fin - inicio)) * 0.35;
    return tokens
        .where((t) => t.tipo == _Tipo.numero || t.tipo == _Tipo.porcentaje)
        .where((t) => t.x >= inicio - margen && t.x < fin - margen * 0.2)
        .firstOrNull;
  }

  static CriterioDetectado _leerCriterio(
    List<PalabraOcr> fila,
    List<(_Columna, double)>? columnas,
    double? xPesoTipico,
    String nombre,
  ) {
    final tokens = _clasificar(fila);

    // Peso: el primer porcentaje; si el "%" no se leyo, el numero en la columna "Peso C.".
    var peso = tokens.where((t) => t.tipo == _Tipo.porcentaje).firstOrNull;
    var pesoDudoso = peso?.corregido ?? false;
    if (peso == null && columnas != null) {
      peso = _enColumna(tokens, columnas, _Columna.pesoC);
      pesoDudoso = true;
    }
    if (peso == null && xPesoTipico != null) {
      // Sin "%": solo es peso el numero que esta en la columna de pesos; uno mas a
      // la derecha es la nota (evita tomar la nota "4" como peso).
      final alto = fila.isEmpty ? 40.0 : fila.map((p) => p.alto).reduce(math.max);
      peso = tokens
          .where((t) => t.tipo == _Tipo.numero && (t.x - xPesoTipico).abs() <= alto * 2.5)
          .firstOrNull;
    } else {
      peso ??= tokens.where((t) => t.tipo == _Tipo.numero).firstOrNull;
    }
    if (peso != null && peso.tipo == _Tipo.numero) pesoDudoso = true;

    // Nota: un numero 0-20 que no sea el peso ni parte de una fecha.
    final candidatas = tokens
        .where((t) => t.tipo == _Tipo.numero && !identical(t, peso) && t.valor! >= 0 && t.valor! <= 20)
        .toList();
    _Token? nota;
    var notaDudosa = false;
    if (columnas != null) {
      nota = _enColumna(candidatas, columnas, _Columna.nota);
      if (nota == null && candidatas.isNotEmpty) {
        nota = candidatas.first;
        notaDudosa = true;
      }
    } else {
      nota = candidatas.firstOrNull;
      notaDudosa = candidatas.length > 1;
    }

    // Una nota de un solo digito con caja muy ancha o muy angosta suele ser un
    // "15" o "14" al que el OCR le perdio el "1": se marca para revisarla.
    if (nota != null && _limpiarNumero(nota.texto).length == 1 && (nota.proporcion > 0.85 || nota.proporcion < 0.4)) {
      notaDudosa = true;
    }

    // Descripcion: las palabras que quedan (sin meses ni fechas).
    var descripcion =
        tokens.where((t) => t.tipo == _Tipo.palabra).map((t) => _corregirPalabra(t.texto)).join(' ').trim();
    // Por contexto: despues de "Examen de" va "unidad" ("Examen de unHdd").
    final examenDe = RegExp(r'^(Examen de) (\S+)$').firstMatch(descripcion);
    if (examenDe != null && _distancia(_normalizar(examenDe.group(2)!), 'unidad') <= 3) {
      descripcion = '${examenDe.group(1)} unidad';
    }

    return CriterioDetectado(
      nombre: nombre,
      descripcion: _capitalizar(descripcion),
      peso: _pesoValido(peso?.valor) ? peso!.valor : null,
      nota: nota?.valor,
      pesoDudoso: pesoDudoso || peso == null || !_pesoValido(peso.valor),
      notaDudosa: notaDudosa,
    );
  }

  // --- Reglas del dominio ---

  /// Si falta exactamente un peso para llegar a 100 %, lo deduce y lo marca dudoso.
  static void _completarPesos(List<UnidadDetectada> unidades) {
    void completar<T>(List<T> items, double? Function(T) leer, void Function(T, double) escribir) {
      final faltan = items.where((i) => leer(i) == null).toList();
      if (faltan.length != 1) return;
      final suma = items.map(leer).whereType<double>().fold<double>(0, (a, b) => a + b);
      final resto = 100 - suma;
      if (resto > 0 && resto <= 100) escribir(faltan.single, resto);
    }

    // Con una sola unidad no se deduce su peso: puede ser una foto de una parte del curso.
    if (unidades.length >= 2) {
      completar<UnidadDetectada>(unidades, (u) => u.peso, (u, v) {
        u.peso = v;
        u.pesoDudoso = true;
      });
    }
    for (final u in unidades) {
      completar<CriterioDetectado>(u.criterios, (c) => c.peso, (c, v) {
        c.peso = v;
        c.pesoDudoso = true;
      });
    }
  }

  static bool _pesoValido(double? v) => v != null && v > 0 && v <= 100;

  // --- Utilidades ---

  /// Palabras frecuentes en las descripciones del portal, para corregir el OCR
  /// ("Procedinmental" -> "Procedimental", "xamen" -> "Examen").
  static const _vocabulario = [
    'Actitudinal', 'Cognitivo', 'Procedimental', 'Examen', 'unidad', 'Trabajos', 'Trabajo', 'encargado', //
    'encargados', 'investigación', 'Informes', 'laboratorio', 'Laboratorio', 'Práctica', 'Prácticas', //
    'Proyecto', 'Exposición', 'Participación', 'Asistencia', 'Parcial', 'Final',
  ];

  static String _corregirPalabra(String palabra) {
    if (palabra.length < 4) return palabra;
    final buscada = _normalizar(palabra);
    // El OCR perdio las primeras letras: "amen" -> "Examen".
    for (final v in _vocabulario) {
      final nv = _normalizar(v);
      if (buscada.length >= 4 && nv.length > buscada.length && nv.endsWith(buscada) && nv.length - buscada.length <= 2) {
        return v;
      }
    }
    if (palabra.length < 5) return palabra;
    // "Examende" -> "Examen de"
    if (buscada.length > 6 && buscada.endsWith('de')) {
      final sinDe = _corregirPalabra(palabra.substring(0, palabra.length - 2));
      if (_vocabulario.contains(sinDe)) return '$sinDe de';
    }
    String? mejor;
    var menor = 4;
    for (final v in _vocabulario) {
      final d = _distancia(buscada, _normalizar(v));
      if (d < menor && d <= (v.length >= 10 ? 3 : (v.length >= 8 ? 2 : 1))) {
        menor = d;
        mejor = v;
      }
    }
    return mejor ?? palabra;
  }

  /// Distancia de edicion (Levenshtein) entre dos textos.
  static int _distancia(String a, String b) {
    if ((a.length - b.length).abs() > 4) return 99;
    var anterior = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final actual = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final costo = a[i - 1] == b[j - 1] ? 0 : 1;
        actual[j] = math.min(math.min(actual[j - 1] + 1, anterior[j] + 1), anterior[j - 1] + costo);
      }
      anterior = actual;
    }
    return anterior[b.length];
  }

  /// Ultima fila "tipo titulo" (mayusculas) antes de la tabla.
  static String? _tituloAntes(List<String> filas) {
    for (final f in filas.reversed) {
      if (_esTitulo(f)) return f;
    }
    return null;
  }

  static bool _esTitulo(String texto) {
    final letras = texto.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÑáéíóúñ]'), '');
    if (letras.length < 6) return false;
    final mayusculas = letras.replaceAll(RegExp(r'[^A-ZÁÉÍÓÚÑ]'), '').length;
    return mayusculas / letras.length >= 0.7;
  }

  static String _capitalizar(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

  static String _normalizar(String t) => t
      .toLowerCase()
      .replaceAll('ó', 'o')
      .replaceAll('í', 'i')
      .replaceAll('é', 'e')
      .replaceAll('á', 'a')
      .replaceAll('ú', 'u')
      .trim();

  /// Corrige confusiones tipicas del OCR en celdas numericas (O->0, l->1, coma decimal).
  static String _limpiarNumero(String t) => t
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll(',', '.')
      .replaceAll(RegExp('[Oo]'), '0')
      .replaceAll(RegExp('[lI|]'), '1');

  static double? _mediana(List<double> valores) {
    if (valores.isEmpty) return null;
    final v = [...valores]..sort();
    return v[v.length ~/ 2];
  }
}
