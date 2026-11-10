import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Lays out the bones of a skeleton for [size], into [out].
typedef SkeletonLayout =
    void Function(Size size, TextDirection direction, List<RRect> out);

/// Shares one shimmer animation with every skeleton below it, so their sweeps
/// stay in step and only one ticker runs.
///
/// The default loading views of [PerformanceListView] add one. Without it,
/// each skeleton runs its own ticker.
class PerformanceShimmer extends StatefulWidget {
  /// Shimmers the skeletons in [child].
  const PerformanceShimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  /// The subtree with skeletons.
  final Widget child;

  /// Whether the sweep runs. Off, skeletons are drawn in their base color.
  final bool enabled;

  /// The shared animation above [context], if any. Null when there is no
  /// [PerformanceShimmer] or motion is reduced.
  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.animation;

  static bool _hasScope(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ShimmerScope>() != null;

  @override
  State<PerformanceShimmer> createState() => _PerformanceShimmerState();
}

class _PerformanceShimmerState extends State<PerformanceShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PerformanceShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final theme = PerformanceListThemeData.of(context);
    final run = widget.enabled && !theme.reduceMotion;
    _controller.duration = theme.shimmerPeriod;
    if (run && !_running) {
      _controller.repeat();
    } else if (!run && _running) {
      _controller.stop();
    }
    _running = run;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ShimmerScope(
    animation: _running ? _controller : null,
    child: widget.child,
  );
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.animation, required super.child});

  final Animation<double>? animation;

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) =>
      animation != oldWidget.animation;
}

/// A placeholder drawn as rounded "bones" with a shimmer sweep.
///
/// Prefer the ready-made shapes: [SkeletonBox], [SkeletonListTile],
/// [SkeletonCard] and [SkeletonBubble]. The bones are painted by one
/// [CustomPainter] behind a [RepaintBoundary]: the sweep repaints only the
/// skeleton, never rebuilds it, and allocates nothing per frame.
class Skeleton extends StatefulWidget {
  /// A skeleton whose bones [layout] places.
  const Skeleton({
    super.key,
    required this.layout,
    this.width,
    this.height,
    this.semanticLabel,
  });

  /// Places the bones.
  final SkeletonLayout layout;

  /// Width. Null fills the available width.
  final double? width;

  /// Height. Null needs a bounded height from the parent.
  final double? height;

  /// Read by screen readers. Defaults to [PerformanceListTexts.loading].
  final String? semanticLabel;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _own;

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  Animation<double>? _animation(ResolvedPerformanceListTheme theme) {
    final shared = PerformanceShimmer.maybeOf(context);
    if (shared != null || PerformanceShimmer._hasScope(context)) {
      _own?.dispose();
      _own = null;
      return shared;
    }
    if (theme.reduceMotion) {
      _own?.stop();
      return null;
    }
    final own = _own ??= AnimationController(vsync: this);
    own.duration = theme.shimmerPeriod;
    if (!own.isAnimating) own.repeat();
    return own;
  }

  @override
  Widget build(BuildContext context) {
    final theme = PerformanceListThemeData.of(context);
    return Semantics(
      label: widget.semanticLabel ?? theme.texts.loading,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _BonesPainter(
                layout: widget.layout,
                animation: _animation(theme),
                base: theme.skeletonBaseColor,
                highlight: theme.skeletonHighlightColor,
                direction: Directionality.of(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BonesPainter extends CustomPainter {
  _BonesPainter({
    required this.layout,
    required this.animation,
    required this.base,
    required this.highlight,
    required this.direction,
  }) : super(repaint: animation);

  final SkeletonLayout layout;
  final Animation<double>? animation;
  final Color base;
  final Color highlight;
  final TextDirection direction;

  // Rebuilt only when the size changes, so a shimmer frame allocates nothing.
  Size? _size;
  final Path _path = Path();
  final List<RRect> _bones = <RRect>[];
  final Paint _basePaint = Paint();
  final Paint _bandPaint = Paint();
  Rect _band = Rect.zero;

  void _prepare(Size size) {
    if (_size == size) return;
    _size = size;
    _bones.clear();
    layout(size, direction, _bones);
    _path.reset();
    for (final bone in _bones) {
      _path.addRRect(bone);
    }
    _basePaint.color = base;
    final w = math.min(size.width * 0.7, 420.0);
    _band = Rect.fromLTWH(0, 0, w, size.height);
    // Opaque paint color: its alpha would scale the shader.
    _bandPaint
      ..color = const Color(0xFF000000)
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(w, 0),
        <Color>[base, highlight, base],
        const <double>[0.1, 0.5, 0.9],
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _prepare(size);
    canvas.drawPath(_path, _basePaint);
    final a = animation;
    if (a == null) return;
    final t = Curves.easeInOutSine.transform(a.value);
    final travel = size.width + _band.width;
    final dx = direction == TextDirection.ltr
        ? -_band.width + travel * t
        : size.width - travel * t;
    canvas
      ..save()
      ..clipPath(_path)
      ..translate(dx, 0)
      ..drawRect(_band, _bandPaint)
      ..restore();
  }

  @override
  bool shouldRepaint(_BonesPainter old) =>
      old.layout != layout ||
      old.animation != animation ||
      old.base != base ||
      old.highlight != highlight ||
      old.direction != direction;
}

double _start(TextDirection d, double width, double x, double w) =>
    d == TextDirection.ltr ? x : width - x - w;

/// A single rounded skeleton bone, or a circle.
class SkeletonBox extends StatelessWidget {
  /// A bone of [width] × [height].
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius,
    this.circle = false,
  });

  /// Width. Null fills the available width.
  final double? width;

  /// Height.
  final double? height;

  /// Corner radius. Defaults to the theme's skeleton radius.
  final double? radius;

  /// Draws a circle instead of a rounded rectangle.
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? PerformanceListThemeData.of(context).skeletonRadius;
    return Skeleton(
      width: width,
      height: height,
      layout: circle ? _circle : _RoundedLayout(r).call,
    );
  }

  static void _circle(Size s, TextDirection d, List<RRect> out) {
    final side = math.min(s.width, s.height);
    out.add(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_start(d, s.width, 0, side), 0, side, side),
        Radius.circular(side / 2),
      ),
    );
  }
}

class _RoundedLayout {
  const _RoundedLayout(this.radius);
  final double radius;

  void call(Size s, TextDirection d, List<RRect> out) => out.add(
    RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(radius)),
  );

  @override
  bool operator ==(Object other) =>
      other is _RoundedLayout && other.radius == radius;

  @override
  int get hashCode => radius.hashCode;
}

/// A list-tile placeholder: an avatar and a few lines of text.
class SkeletonListTile extends StatelessWidget {
  /// A tile of [height] with [lines] text lines.
  const SkeletonListTile({
    super.key,
    this.leading = true,
    this.lines = 2,
    this.trailing = false,
    this.height = 76,
    this.seed = 0,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: 16),
  });

  /// Whether to draw a leading avatar circle.
  final bool leading;

  /// The number of text lines, 1 to 4.
  final int lines;

  /// Whether to draw a short trailing bone.
  final bool trailing;

  /// The tile's height.
  final double height;

  /// Varies the line widths, so a column of tiles does not look cloned.
  final int seed;

  /// Space around the bones.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final r = PerformanceListThemeData.of(context).skeletonRadius;
    return Padding(
      padding: padding,
      child: Skeleton(
        height: height,
        layout: _TileLayout(leading, lines.clamp(1, 4), trailing, seed, r).call,
      ),
    );
  }
}

class _TileLayout {
  const _TileLayout(this.leading, this.lines, this.trailing, this.seed, this.r);
  final bool leading;
  final int lines;
  final bool trailing;
  final int seed;
  final double r;

  void call(Size s, TextDirection d, List<RRect> out) {
    final avatar = leading ? math.min(44.0, s.height - 16) : 0.0;
    var x = 0.0;
    if (leading) {
      out.add(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            _start(d, s.width, 0, avatar),
            (s.height - avatar) / 2,
            avatar,
            avatar,
          ),
          Radius.circular(avatar / 2),
        ),
      );
      x = avatar + 16;
    }
    final trailingW = trailing ? 40.0 : 0.0;
    final avail = s.width - x - (trailing ? trailingW + 16 : 0);
    const lineH = 11.0;
    const gap = 9.0;
    final total = lines * lineH + (lines - 1) * gap;
    var y = (s.height - total) / 2;
    for (var i = 0; i < lines; i++) {
      final f = i == 0
          ? 0.55 + 0.3 * _frac(seed, 1)
          : 0.75 + 0.25 * _frac(seed, i + 2);
      final w = avail * (i == lines - 1 && i > 0 ? f * 0.6 : f);
      out.add(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            _start(d, s.width, x, w),
            y,
            w,
            i == 0 ? lineH + 2 : lineH,
          ),
          Radius.circular(math.min(r, lineH / 2)),
        ),
      );
      y += lineH + gap;
    }
    if (trailing) {
      out.add(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            _start(d, s.width, s.width - trailingW, trailingW),
            s.height / 2 - 6,
            trailingW,
            12,
          ),
          const Radius.circular(6),
        ),
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _TileLayout &&
      other.leading == leading &&
      other.lines == lines &&
      other.trailing == trailing &&
      other.seed == seed &&
      other.r == r;

  @override
  int get hashCode => Object.hash(leading, lines, trailing, seed, r);
}

double _frac(int seed, int salt) {
  var h = (seed * 0x9E3779B1 + salt * 0x85EBCA77) & 0x7fffffff;
  h = (h ^ (h >> 15)) * 0x2C1B3C6D & 0x7fffffff;
  return (h % 1000) / 1000;
}

/// A card placeholder for grids: an image block and caption lines.
class SkeletonCard extends StatelessWidget {
  /// A card whose image block has [imageAspectRatio] (width / height).
  const SkeletonCard({
    super.key,
    this.imageAspectRatio = 1,
    this.lines = 2,
    this.seed = 0,
  });

  /// Width / height of the image block.
  final double imageAspectRatio;

  /// Caption lines under the image, 0 to 3.
  final int lines;

  /// Varies the caption widths.
  final int seed;

  @override
  Widget build(BuildContext context) {
    final r = PerformanceListThemeData.of(context).skeletonRadius;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 160.0;
        final h = w / imageAspectRatio + (lines > 0 ? 12 + lines * 20 : 0);
        return Skeleton(
          height: c.maxHeight.isFinite && c.hasBoundedHeight ? null : h,
          layout: _CardLayout(
            imageAspectRatio,
            lines.clamp(0, 3),
            seed,
            r,
          ).call,
        );
      },
    );
  }
}

class _CardLayout {
  const _CardLayout(this.aspect, this.lines, this.seed, this.r);
  final double aspect;
  final int lines;
  final int seed;
  final double r;

  void call(Size s, TextDirection d, List<RRect> out) {
    final captions = lines > 0 ? 12 + lines * 20.0 : 0.0;
    final imageH = math.max(
      0.0,
      math.min(s.width / aspect, s.height - captions),
    );
    out.add(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s.width, imageH),
        Radius.circular(r * 1.6),
      ),
    );
    var y = imageH + 12;
    for (var i = 0; i < lines; i++) {
      final w =
          s.width *
          (i == 0
              ? 0.7 + 0.25 * _frac(seed, 7)
              : 0.4 + 0.2 * _frac(seed, 9 + i));
      out.add(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(_start(d, s.width, 0, w), y, w, 11),
          const Radius.circular(5.5),
        ),
      );
      y += 20;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _CardLayout &&
      other.aspect == aspect &&
      other.lines == lines &&
      other.seed == seed &&
      other.r == r;

  @override
  int get hashCode => Object.hash(aspect, lines, seed, r);
}

/// A chat-bubble placeholder.
class SkeletonBubble extends StatelessWidget {
  /// A bubble aligned to the end side when [alignEnd].
  const SkeletonBubble({
    super.key,
    this.alignEnd = false,
    this.lines = 2,
    this.seed = 0,
  });

  /// Aligns the bubble to the end (outgoing side).
  final bool alignEnd;

  /// Text lines in the bubble, 1 to 4.
  final int lines;

  /// Varies the bubble width.
  final int seed;

  @override
  Widget build(BuildContext context) {
    final r = PerformanceListThemeData.of(context).bubbleRadius;
    final n = lines.clamp(1, 4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Skeleton(
        height: 24.0 + n * 18,
        layout: _BubbleLayout(alignEnd, seed, r).call,
      ),
    );
  }
}

class _BubbleLayout {
  const _BubbleLayout(this.end, this.seed, this.r);
  final bool end;
  final int seed;
  final double r;

  void call(Size s, TextDirection d, List<RRect> out) {
    final w = s.width * (0.45 + 0.3 * _frac(seed, 3));
    final ltrStart = end ? s.width - w : 0.0;
    out.add(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_start(d, s.width, ltrStart, w), 0, w, s.height),
        Radius.circular(r),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _BubbleLayout &&
      other.end == end &&
      other.seed == seed &&
      other.r == r;

  @override
  int get hashCode => Object.hash(end, seed, r);
}
