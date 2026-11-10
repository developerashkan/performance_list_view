import 'package:flutter/material.dart';

/// A gradient circle with initials.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initials,
    required this.colors,
    this.size = 44,
  });
  final String initials;
  final (Color, Color) colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.$1, colors.$2],
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// Generated artwork: a gradient with soft shapes. Stands in for photos.
class Art extends StatelessWidget {
  const Art({
    super.key,
    required this.colors,
    required this.seed,
    this.radius = 18,
  });
  final (Color, Color) colors;
  final int seed;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1 + (seed % 3) * 0.5, -1),
            end: const Alignment(1, 1),
            colors: [colors.$1, colors.$2],
          ),
        ),
        child: CustomPaint(painter: _Shapes(seed)),
      ),
    );
  }
}

class _Shapes extends CustomPainter {
  _Shapes(this.seed);
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.18);
    final s = seed * 37;
    canvas.drawCircle(
      Offset(
        size.width * (0.2 + (s % 50) / 100),
        size.height * (0.25 + (s % 30) / 100),
      ),
      size.shortestSide * 0.32,
      p,
    );
    p.color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(
      Offset(size.width * (0.85 - (s % 20) / 100), size.height * 0.85),
      size.shortestSide * 0.45,
      p,
    );
    p.color = Colors.black.withValues(alpha: 0.08);
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.95),
      size.shortestSide * 0.25,
      p,
    );
  }

  @override
  bool shouldRepaint(_Shapes old) => old.seed != seed;
}

/// Centers [child] at a readable width on large screens.
class Readable extends StatelessWidget {
  const Readable({super.key, required this.child, this.maxWidth = 720});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
