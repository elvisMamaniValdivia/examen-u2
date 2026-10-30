import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/datos_graficos.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/formato_nota.dart';

/// H20 - Graficos de la pantalla "Evolucion" (DESIGN.md pantalla 09).
/// Eje Y de 0 a 20, guias en 5/10/15/20 y linea punteada ambar en 10.5.

const _duracion = Duration(milliseconds: 600);

/// Linea de referencia "min. 10.5" comun a ambos graficos.
ExtraLinesData _lineaMinima(EstadoNotaColors estado) => ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: notaMinima,
          color: estado.aviso,
          strokeWidth: 1.5,
          dashArray: const [6, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 4, bottom: 2),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: estado.aviso),
            labelResolver: (_) => 'mín. 10.5',
          ),
        ),
      ],
    );

FlGridData _guias(ColorScheme scheme) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: 5,
      getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant, strokeWidth: 1),
    );

AxisTitles _ejeNotas(ColorScheme scheme) => AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 5,
        reservedSize: 30,
        getTitlesWidget: (valor, meta) => SideTitleWidget(
          meta: meta,
          child: Text(
            valor.toInt().toString(),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );

const _sinTitulos = AxisTitles(sideTitles: SideTitles(showTitles: false));

/// Anima de 0 a 1 una vez (o salta a 1 si el sistema pide menos animaciones).
class _Entrada extends StatelessWidget {
  final Object clave;
  final Widget Function(double t) builder;

  const _Entrada({required this.clave, required this.builder});

  @override
  Widget build(BuildContext context) {
    final sinAnimacion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(clave),
      tween: Tween(begin: sinAnimacion ? 1 : 0, end: 1),
      duration: sinAnimacion ? Duration.zero : _duracion,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => builder(t),
    );
  }
}

/// Grafico de linea: promedio de cada unidad del curso.
/// Las unidades pendientes aparecen en el eje pero sin punto (no valen 0).
class GraficoUnidades extends StatelessWidget {
  final SerieUnidades serie;

  const GraficoUnidades({super.key, required this.serie});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    final puntos = serie.puntos;
    final ultimo = math.max(0, puntos.length - 1);

    final descripcion = [
      for (final p in puntos) '${p.nombre}: ${p.pendiente ? 'sin notas' : FormatoNota.nota(p.nota)}',
    ].join('; ');

    return Semantics(
      label: 'Gráfico de evolución por unidad. $descripcion',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1.45,
        child: _Entrada(
          clave: descripcion,
          builder: (t) {
            // La linea se dibuja de izquierda a derecha.
            final spots = [
              for (var i = 0; i < puntos.length; i++)
                if (!puntos[i].pendiente && (ultimo == 0 || i <= t * ultimo + 0.001))
                  FlSpot(i.toDouble(), puntos[i].nota!),
            ];
            return LineChart(
              duration: Duration.zero,
              LineChartData(
                minX: -0.4,
                maxX: ultimo + 0.4,
                minY: 0,
                maxY: 20,
                gridData: _guias(scheme),
                borderData: FlBorderData(show: false),
                extraLinesData: _lineaMinima(estado),
                titlesData: FlTitlesData(
                  topTitles: _sinTitulos,
                  rightTitles: _sinTitulos,
                  leftTitles: _ejeNotas(scheme),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 28,
                      getTitlesWidget: (valor, meta) {
                        final i = valor.round();
                        if (i < 0 || i >= puntos.length || (valor - i).abs() > 0.01) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            puntos[i].etiqueta,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: puntos[i].pendiente ? scheme.outline : scheme.onSurface,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    // El cuadro se queda dentro del grafico (no se corta arriba).
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => scheme.inverseSurface,
                    getTooltipItems: (tocados) => [
                      for (final s in tocados)
                        LineTooltipItem(
                          '${puntos[s.x.round()].nombre}\n${FormatoNota.nota(s.y)}',
                          TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    color: scheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                        radius: 5,
                        color: estado.colorDeNota(spot.y, scheme.primary),
                        strokeWidth: 2.5,
                        strokeColor: scheme.surfaceContainerLowest,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Grafico de barras: nota actual de cada curso del ciclo.
/// Rojo si esta por debajo de 10.5; contorno punteado si no tiene notas.
class GraficoCursos extends StatelessWidget {
  final List<BarraCurso> barras;

  const GraficoCursos({super.key, required this.barras});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    final n = barras.length;
    final ancho = n <= 5 ? 34.0 : math.max(14.0, 190 / n);
    const escalon = 0.12; // retraso entre barras

    final descripcion = [
      for (final b in barras) '${b.nombre}: ${b.sinNotas ? 'sin notas' : FormatoNota.nota(b.nota)}',
    ].join('; ');

    Color colorBarra(BarraCurso b) => b.enRiesgo ? estado.desaprobado : scheme.primary;

    return Semantics(
      label: 'Gráfico de notas entre cursos. $descripcion',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1.35,
        child: _Entrada(
          clave: descripcion,
          builder: (t) => BarChart(
            duration: Duration.zero,
            BarChartData(
              minY: 0,
              maxY: 20,
              alignment: BarChartAlignment.spaceAround,
              gridData: _guias(scheme),
              borderData: FlBorderData(show: false),
              extraLinesData: _lineaMinima(estado),
              titlesData: FlTitlesData(
                rightTitles: _sinTitulos,
                leftTitles: _ejeNotas(scheme),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (valor, meta) {
                      final i = valor.toInt();
                      if (i < 0 || i >= n) return const SizedBox.shrink();
                      final b = barras[i];
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          b.sinNotas ? '—' : FormatoNota.nota(b.nota),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: b.sinNotas ? scheme.outline : colorBarra(b),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (valor, meta) {
                      final i = valor.toInt();
                      if (i < 0 || i >= n) return const SizedBox.shrink();
                      final b = barras[i];
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          b.abreviatura,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: b.enRiesgo ? estado.desaprobado : scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => scheme.inverseSurface,
                  getTooltipItem: (grupo, _, _, _) {
                    final b = barras[grupo.x];
                    return BarTooltipItem(
                      '${b.nombre}\n${b.sinNotas ? 'Sin notas' : FormatoNota.nota(b.nota)}',
                      TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < n; i++)
                  () {
                    final b = barras[i];
                    // Las barras crecen escalonadas.
                    final avance = Curves.easeOutCubic.transform(
                      (t * (1 + escalon * (n - 1)) - escalon * i).clamp(0.0, 1.0),
                    );
                    final radio = BorderRadius.vertical(top: Radius.circular(math.min(7, ancho / 2)));
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        b.sinNotas
                            ? BarChartRodData(
                                toY: 4 * avance,
                                width: ancho,
                                color: Colors.transparent,
                                borderRadius: radio,
                                borderSide: BorderSide(color: scheme.outline, width: 1.5),
                                borderDashArray: const [4, 3],
                              )
                            : BarChartRodData(
                                toY: b.nota! * avance,
                                width: ancho,
                                color: colorBarra(b),
                                borderRadius: radio,
                              ),
                      ],
                    );
                  }(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Elemento de leyenda: muestra de color (o linea punteada) + texto.
class ItemLeyenda extends StatelessWidget {
  final Color color;
  final String texto;
  final bool punteado;
  final bool linea;

  const ItemLeyenda({super.key, required this.color, required this.texto, this.punteado = false, this.linea = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget muestra = linea || punteado
        ? SizedBox(
            width: 18,
            height: 10,
            child: CustomPaint(painter: _PintorMuestra(color: color, punteado: punteado)),
          )
        : Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        muestra,
        const SizedBox(width: 6),
        Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _PintorMuestra extends CustomPainter {
  final Color color;
  final bool punteado;

  _PintorMuestra({required this.color, required this.punteado});

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..strokeWidth = punteado ? 2 : 3
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!punteado) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pincel);
      return;
    }
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, size.width), y), pincel);
    }
  }

  @override
  bool shouldRepaint(_PintorMuestra old) => old.color != color || old.punteado != punteado;
}
