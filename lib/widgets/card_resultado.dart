import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/calculos_multinivel.dart';
import '../theme/app_theme.dart';
import '../theme/estado_nota_colors.dart';
import '../utils/formato_nota.dart';
import 'borde_punteado.dart';
import 'escala_nota.dart';

/// Tarjeta de resultado compacta (DESIGN.md seccion 6 y pantalla 07).
/// Recibe la nota ya calculada; no calcula nada.
///
/// El estado siempre se comunica con icono + palabra + color.
/// Sin nota se muestra con fondo de tarjeta y borde punteado.
class CardResultado extends StatefulWidget {
  final double? nota;
  final String titulo;
  final String? subtitulo;

  /// Texto de estado cuando [nota] es null (por defecto "Sin notas aun").
  final String textoSinNota;
  final double umbral;

  const CardResultado({
    super.key,
    required this.nota,
    required this.titulo,
    this.subtitulo,
    this.textoSinNota = 'Sin notas aún',
    this.umbral = 10.5,
  });

  @override
  State<CardResultado> createState() => _CardResultadoState();
}

class _CardResultadoState extends State<CardResultado> {
  bool? get _aprobado => widget.nota == null ? null : widget.nota! >= widget.umbral;

  @override
  void didUpdateWidget(covariant CardResultado oldWidget) {
    super.didUpdateWidget(oldWidget);
    final antes = oldWidget.nota == null ? null : oldWidget.nota! >= oldWidget.umbral;
    final ahora = _aprobado;
    // Microinteraccion 1: vibracion leve al subir de 10.5, media al bajar.
    if (antes != null && ahora != null && antes != ahora) {
      ahora ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);
    final aprobado = _aprobado;

    final Color fondo;
    final Color texto;
    final Color circulo;
    final Color iconoColor;
    final Color colorNota;
    final IconData icono;
    final String etiqueta;

    if (aprobado == null) {
      fondo = scheme.surfaceContainerLowest;
      texto = scheme.onSurface;
      circulo = scheme.surfaceContainerHigh;
      iconoColor = scheme.onSurfaceVariant;
      colorNota = scheme.onSurfaceVariant;
      icono = Icons.hourglass_empty_rounded;
      etiqueta = widget.textoSinNota;
    } else if (aprobado) {
      fondo = estado.aprobadoFondo;
      texto = estado.onAprobadoFondo;
      circulo = estado.aprobado;
      iconoColor = esOscuro ? estado.aprobadoFondo : Colors.white;
      colorNota = esOscuro ? estado.aprobado : estado.onAprobadoFondo;
      icono = Icons.check_rounded;
      etiqueta = 'Aprobado';
    } else {
      fondo = estado.desaprobadoFondo;
      texto = estado.onDesaprobadoFondo;
      circulo = estado.desaprobado;
      iconoColor = esOscuro ? estado.desaprobadoFondo : Colors.white;
      colorNota = esOscuro ? estado.desaprobado : estado.onDesaprobadoFondo;
      icono = Icons.close_rounded;
      etiqueta = 'Desaprobado';
    }

    final duracion = Duration(milliseconds: sinAnimaciones ? 150 : 300);

    Widget tarjeta = AnimatedContainer(
      duration: duracion,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: duracion,
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: circulo, shape: BoxShape.circle),
            child: AnimatedSwitcher(
              duration: duracion,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(icono, key: ValueKey(icono), color: iconoColor, size: 26),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.titulo,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: texto),
                ),
                Text(
                  etiqueta,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: texto),
                ),
                if (widget.subtitulo != null)
                  Text(
                    widget.subtitulo!,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: texto),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _NumeroNota(
            nota: widget.nota,
            color: colorNota,
            duracion: Duration(milliseconds: sinAnimaciones ? 0 : 450),
          ),
        ],
      ),
    );

    if (aprobado == null) {
      tarjeta = BordePunteado(color: scheme.outline, radio: 22, grosor: 1.2, child: tarjeta);
    }

    final descripcion = aprobado == null
        ? '${widget.titulo}, ${widget.textoSinNota}'
        : '${widget.titulo} ${FormatoNota.nota(widget.nota)}, ${etiqueta.toLowerCase()}';

    return Semantics(
      container: true,
      label: descripcion,
      excludeSemantics: true,
      child: tarjeta,
    );
  }
}

/// Numero grande que "cuenta" hasta el nuevo valor (microinteraccion 1).
class _NumeroNota extends StatelessWidget {
  final double? nota;
  final Color color;
  final Duration duracion;

  const _NumeroNota({required this.nota, required this.color, required this.duracion});

  @override
  Widget build(BuildContext context) {
    final estilo = AppTheme.estiloNota(44, color: color);
    if (nota == null) return Text('—', style: estilo);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: nota),
      duration: duracion,
      curve: Curves.easeOutCubic,
      builder: (context, valor, _) => Text(FormatoNota.nota(valor), style: estilo),
    );
  }
}

/// Tarjeta de resultado expandida (DESIGN.md seccion 6 y pantalla 07):
/// titulo + pill de estado, numero grande "/ 20", EscalaNota y un pie.
///
/// Con [avance] (curso con notas pendientes) la pill no da el curso por
/// aprobado: dice "Asegurado", "Vas aprobando", "En riesgo" o "Desaprobado".
class CardResultadoExpandida extends StatelessWidget {
  final double? nota;
  final String titulo;
  final String pie;
  final double umbral;
  final AvanceCurso? avance;

  const CardResultadoExpandida({
    super.key,
    required this.nota,
    required this.titulo,
    required this.pie,
    this.umbral = 10.5,
    this.avance,
  });

  /// Texto e icono de la pill.
  static (String, IconData) _pill(bool aprobado, AvanceCurso? avance) => switch (avance) {
        AvanceCurso.asegurado => ('Asegurado', Icons.verified_rounded),
        AvanceCurso.vasAprobando => ('Vas aprobando', Icons.trending_up_rounded),
        AvanceCurso.enRiesgo => ('En riesgo', Icons.warning_rounded),
        AvanceCurso.sinOpcion => ('Desaprobado', Icons.cancel_rounded),
        null => aprobado ? ('Aprobado', Icons.check_circle_rounded) : ('Desaprobado', Icons.cancel_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estado = EstadoNotaColors.of(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);
    final valor = nota;
    final aprobado = valor == null ? null : valor >= umbral;

    final Color fondo;
    final Color texto;
    final Color colorEstado;
    final Color colorNota;
    if (aprobado == null) {
      fondo = scheme.surfaceContainerLowest;
      texto = scheme.onSurface;
      colorEstado = scheme.onSurfaceVariant;
      colorNota = scheme.onSurfaceVariant;
    } else if (aprobado) {
      fondo = estado.aprobadoFondo;
      texto = estado.onAprobadoFondo;
      colorEstado = estado.aprobado;
      colorNota = esOscuro ? estado.aprobado : estado.onAprobadoFondo;
    } else {
      fondo = estado.desaprobadoFondo;
      texto = estado.onDesaprobadoFondo;
      colorEstado = estado.desaprobado;
      colorNota = esOscuro ? estado.desaprobado : estado.onDesaprobadoFondo;
    }
    final textoPill = esOscuro ? fondo : Colors.white;
    final (etiquetaPill, iconoPill) = _pill(aprobado ?? false, avance);

    Widget tarjeta = AnimatedContainer(
      duration: Duration(milliseconds: sinAnimaciones ? 150 : 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: texto),
                ),
              ),
              if (aprobado != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                  decoration: BoxDecoration(color: colorEstado, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconoPill, size: 18, color: textoPill),
                      const SizedBox(width: 6),
                      Text(
                        etiquetaPill,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textoPill),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (valor == null)
                Text('—', style: AppTheme.estiloNota(76, color: colorNota))
              else
                TweenAnimationBuilder<double>(
                  tween: Tween(end: valor),
                  duration: Duration(milliseconds: sinAnimaciones ? 0 : 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) =>
                      Text(FormatoNota.nota(v), style: AppTheme.estiloNota(76, color: colorNota)),
                ),
              const SizedBox(width: 6),
              Text(
                '/ 20',
                style: AppTheme.estiloNota(22, color: colorNota.withValues(alpha: 0.7), weight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          EscalaNota(nota: valor, umbral: umbral),
          const SizedBox(height: 12),
          Text(pie, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: texto)),
        ],
      ),
    );

    if (aprobado == null) {
      tarjeta = BordePunteado(color: scheme.outline, radio: 28, grosor: 1.2, child: tarjeta);
    }

    return Semantics(
      container: true,
      label: aprobado == null
          ? '$titulo, sin notas. $pie'
          : '$titulo ${FormatoNota.nota(valor)}, ${etiquetaPill.toLowerCase()}. $pie',
      excludeSemantics: true,
      child: tarjeta,
    );
  }
}
