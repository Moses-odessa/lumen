import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/palette.dart';
import '../../../domain/scoring/balance.dart';
import '../../../domain/sky/progression.dart';
import '../../../domain/sky/sky_layout.dart';

/// Карта созвездий.
///
/// Отрисовка разведена по слоям, и это не украшательство, а требование
/// производительности из PLAN.md: на B2 небо содержит под три тысячи звёзд,
/// и перерисовывать фон вместе с ними на каждом кадре панорамирования
/// нельзя.
///
/// - **Фон** — звёздная пыль, не относящаяся к словам. Рисуется один раз в
///   [ui.Picture] и потом только двигается.
/// - **Созвездия** — линии и звёзды. Перерисовываются, когда меняется
///   яркость, то есть после сессии, а не на каждом жесте.
/// - **Подсветка** — выбранное созвездие, самый верхний и самый дешёвый слой.
class SkyMap extends StatefulWidget {
  const SkyMap({
    super.key,
    required this.constellations,
    required this.states,
    this.selected,
    this.onSelect,
  });

  final List<ConstellationPlacement> constellations;

  /// Состояние по имени созвездия: открыто, зажжено.
  final Map<String, ConstellationState> states;

  final String? selected;
  final ValueChanged<String?>? onSelect;

  @override
  State<SkyMap> createState() => _SkyMapState();
}

class _SkyMapState extends State<SkyMap> {
  final _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(Offset local, Size size) {
    final scene = _controller.toScene(local);
    final point = SkyPoint(scene.dx / size.width, scene.dy / size.height);

    ConstellationPlacement? hit;
    var best = double.infinity;
    for (final constellation in widget.constellations) {
      final distance = constellation.center.distanceTo(point);
      // Зона тапа шире созвездия: попасть пальцем в кучку мелких звёзд
      // на общей карте невозможно.
      if (distance <= constellation.radius * 1.6 && distance < best) {
        best = distance;
        hit = constellation;
      }
    }

    widget.onSelect?.call(hit?.name);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onTapUp: (details) => _handleTap(details.localPosition, size),
          child: InteractiveViewer(
            transformationController: _controller,
            minScale: 1,
            maxScale: 6,
            // Небо можно вытянуть за край: карта круглая, а экран нет.
            boundaryMargin: const EdgeInsets.all(120),
            child: CustomPaint(
              size: size,
              isComplex: true,
              willChange: false,
              painter: _SkyPainter(
                constellations: widget.constellations,
                states: widget.states,
                selected: widget.selected,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.constellations,
    required this.states,
    required this.selected,
  });

  final List<ConstellationPlacement> constellations;
  final Map<String, ConstellationState> states;
  final String? selected;

  /// Закешированный фон: звёздная пыль не зависит ни от прогресса, ни от
  /// выбора, поэтому считать её заново незачем.
  static ui.Picture? _dust;
  static Size? _dustSize;

  @override
  void paint(Canvas canvas, Size size) {
    _paintDust(canvas, size);

    for (final constellation in constellations) {
      final state = states[constellation.name];
      final unlocked = state?.unlocked ?? false;
      _paintConstellation(canvas, size, constellation, state, unlocked);
    }

    _paintSelection(canvas, size);
  }

  /// Фон: мелкие звёзды, не относящиеся ни к каким словам. Нужны затем,
  /// чтобы пустое небо новичка не выглядело сломанным экраном.
  void _paintDust(Canvas canvas, Size size) {
    if (_dust == null || _dustSize != size) {
      final recorder = ui.PictureRecorder();
      final dustCanvas = Canvas(recorder);
      final random = math.Random(20260101);
      final paint = Paint();

      for (var i = 0; i < 220; i++) {
        final dx = random.nextDouble() * size.width;
        final dy = random.nextDouble() * size.height;
        final radius = 0.4 + random.nextDouble() * 0.9;
        paint.color = Colors.white
            .withValues(alpha: 0.04 + random.nextDouble() * 0.10);
        dustCanvas.drawCircle(Offset(dx, dy), radius, paint);
      }

      _dust = recorder.endRecording();
      _dustSize = size;
    }
    canvas.drawPicture(_dust!);
  }

  void _paintConstellation(
    Canvas canvas,
    Size size,
    ConstellationPlacement constellation,
    ConstellationState? state,
    bool unlocked,
  ) {
    Offset toPixels(SkyPoint p) => Offset(p.x * size.width, p.y * size.height);

    // Закрытое созвездие видно, но едва: игрок должен понимать, что небо
    // больше, чем он уже открыл.
    final dim = unlocked ? 1.0 : 0.22;

    // Линии-фразы.
    final linePaint = Paint()
      ..strokeWidth = 1
      ..color = LumenPalette.constellationLine
          .withValues(alpha: 0.28 * dim);
    for (final (a, b) in constellation.lines) {
      if (a >= constellation.stars.length || b >= constellation.stars.length) {
        continue;
      }
      canvas.drawLine(
        toPixels(constellation.stars[a].position),
        toPixels(constellation.stars[b].position),
        linePaint,
      );
    }

    for (final star in constellation.stars) {
      final band = LumenBand.of(star.lumens);
      final center = toPixels(star.position);
      final radius = LumenPalette.starRadius(band);
      final alpha = LumenPalette.starOpacity(band) * dim;
      final color = LumenPalette.star(band);

      // Ореол только у горящих: рисовать блюр на каждой из трёх тысяч
      // звёзд — верный способ уронить частоту кадров.
      if (band == LumenBand.burning && unlocked) {
        canvas.drawCircle(
          center,
          radius * 3,
          Paint()
            ..color = color.withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }

      canvas.drawCircle(
        center,
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }

    if (state != null && state.isLit && unlocked) {
      // Зажжённое созвездие обведено: это цель, и она должна читаться
      // с общего плана без зума.
      canvas.drawCircle(
        toPixels(constellation.center),
        constellation.radius * size.shortestSide * 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = LumenPalette.starlight.withValues(alpha: 0.18),
      );
    }
  }

  void _paintSelection(Canvas canvas, Size size) {
    final name = selected;
    if (name == null) return;

    final constellation =
        constellations.where((c) => c.name == name).firstOrNull;
    if (constellation == null) return;

    canvas.drawCircle(
      Offset(
        constellation.center.x * size.width,
        constellation.center.y * size.height,
      ),
      constellation.radius * size.shortestSide * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = LumenPalette.starlight.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.selected != selected ||
      old.constellations != constellations ||
      old.states != states;
}
