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

    // Свечение рисуется отдельным слоем и до звёзд: иначе пятно соседнего
    // созвездия ложится поверх уже нарисованных звёзд этого и гасит их.
    for (final constellation in constellations) {
      _paintMilkyWay(canvas, size, constellation,
          states[constellation.name]?.unlocked ?? false);
    }

    for (final constellation in constellations) {
      final state = states[constellation.name];
      final unlocked = state?.unlocked ?? false;
      _paintConstellation(canvas, size, constellation, state, unlocked);
    }

    _paintSelection(canvas, size);
  }

  /// Млечный Путь: непроработанное созвездие — размытое пятно, а не набор
  /// тёмных точек.
  ///
  /// Так оно и должно читаться: тема, которой игрок не касался, существует и
  /// обещает объём, но отдельных слов в ней ещё не видно. Звёзды проступают
  /// из пятна по мере усвоения, и пятно слабеет.
  ///
  /// Это не только метафора. Отдельные координаты нужны лишь выученным
  /// звёздам, а невыученная масса рисуется одним градиентом — поэтому карта
  /// растёт вместе с прогрессом, а не вместе с объёмом контента. Иначе
  /// созвездие из трёхсот слов превратилось бы в пятно из трёхсот точек, где
  /// ни одну нельзя различить, и небо перестало бы быть «моим».
  void _paintMilkyWay(
    Canvas canvas,
    Size size,
    ConstellationPlacement constellation,
    bool unlocked,
  ) {
    // Полностью проработанное созвездие свечения не имеет: его роль сыграна,
    // и лишний блюр под яркими звёздами только мутит картинку.
    final unworked = 1 - constellation.worked;
    if (unworked <= 0.01) return;

    final center = _center(constellation, size);
    final radius = _radius(constellation.glowRadius, size);

    // Закрытое созвездие светит слабее: небо больше открытого, и это должно
    // быть видно, но не должно перетягивать внимание.
    final strength = (unlocked ? 0.16 : 0.07) * unworked;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          LumenPalette.starlight.withValues(alpha: strength),
          LumenPalette.starlight.withValues(alpha: 0),
        ])
        // Резкий край у пятна выдал бы окружность и превратил Млечный Путь в
        // круг с заливкой.
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.35),
    );
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
      canvas.drawOval(
        _bounds(constellation, constellation.radius, size),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = LumenPalette.starlight.withValues(alpha: 0.18),
      );
    }
  }

  /// Центр созвездия в пикселях.
  static Offset _center(ConstellationPlacement c, Size size) =>
      Offset(c.center.x * size.width, c.center.y * size.height);

  /// Радиус в пикселях для круга, которому вытянутость не важна (пятно).
  static double _radius(double normalized, Size size) =>
      normalized * size.shortestSide;

  /// Границы созвездия в пикселях.
  ///
  /// Овал, а не круг, и это не придирка. Позиции звёзд нормированы и
  /// умножаются на ширину и высоту по отдельности, а обводка считалась от
  /// `shortestSide` — то есть на вытянутом экране кольцо не совпадало с тем,
  /// что оно обводит: часть звёзд оказывалась снаружи.
  static Rect _bounds(ConstellationPlacement c, double radius, Size size) =>
      Rect.fromCenter(
        center: _center(c, size),
        width: radius * 2 * size.width,
        height: radius * 2 * size.height,
      );

  void _paintSelection(Canvas canvas, Size size) {
    final name = selected;
    if (name == null) return;

    final constellation =
        constellations.where((c) => c.name == name).firstOrNull;
    if (constellation == null) return;

    canvas.drawOval(
      _bounds(constellation, constellation.radius * 1.24, size),
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
