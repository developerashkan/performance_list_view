import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Holds text that grows token by token, such as an AI reply being streamed.
///
/// A [StreamingText] listening to it rebuilds only itself per token: the list
/// around it does not rebuild or relayout other items.
class StreamingTextController extends ValueNotifier<String> {
  /// A controller starting with [text].
  StreamingTextController({String text = '', this._done = false}) : super(text);

  bool _done;
  StreamSubscription<String>? _subscription;

  /// Whether the stream has finished.
  bool get isDone => _done;

  /// Appends [token].
  void append(String token) {
    if (token.isEmpty) return;
    value = value + token;
  }

  /// Marks the text as complete. The cursor disappears.
  void complete() {
    if (_done) return;
    _done = true;
    notifyListeners();
  }

  /// Clears the text and starts streaming again.
  void restart([String text = '']) {
    _subscription?.cancel();
    _subscription = null;
    _done = false;
    value = text;
    notifyListeners();
  }

  /// Appends every token of [tokens] and completes when it ends. Cancels a
  /// previous binding. The returned future completes with the stream.
  Future<void> bind(Stream<String> tokens) {
    _subscription?.cancel();
    _done = false;
    final done = Completer<void>();
    _subscription = tokens.listen(
      append,
      onError: (Object e, StackTrace s) {
        complete();
        if (!done.isCompleted) done.completeError(e, s);
      },
      onDone: () {
        complete();
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    return done.future;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Text that follows a [StreamingTextController], with a blinking cursor
/// while it streams.
class StreamingText extends StatelessWidget {
  /// Shows the text of [controller].
  const StreamingText({
    super.key,
    required this.controller,
    this.style,
    this.showCursor = true,
    this.cursorColor,
    this.textAlign,
  });

  /// The streaming text.
  final StreamingTextController controller;

  /// The text style. Defaults to the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// Whether to show a cursor while the text streams.
  final bool showCursor;

  /// The cursor color. Defaults to the text color.
  final Color? cursorColor;

  /// How to align the text.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: controller,
      builder: (context, text, _) {
        final streaming = showCursor && !controller.isDone;
        return Text.rich(
          TextSpan(
            text: text,
            children: [
              if (streaming)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _Cursor(color: cursorColor),
                ),
            ],
          ),
          style: style,
          textAlign: textAlign,
        );
      },
    );
  }
}

class _Cursor extends StatefulWidget {
  const _Cursor({this.color});
  final Color? color;

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (PerformanceListThemeData.of(context).reduceMotion) {
      _blink
        ..stop()
        ..value = 1;
    } else if (!_blink.isAnimating) {
      _blink.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final size = (style.fontSize ?? 14) * 0.9;
    // Its own layer: blinking repaints the cursor, not the paragraph.
    return RepaintBoundary(
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _blink, curve: Curves.easeInOutCubic),
        child: Container(
          margin: const EdgeInsetsDirectional.only(start: 2),
          width: size * 0.5,
          height: size,
          decoration: BoxDecoration(
            color: widget.color ?? style.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Three dots that rise in a wave, shown while the other side is typing or
/// an AI model is thinking.
class TypingIndicator extends StatefulWidget {
  /// Dots of [dotSize] in [color].
  const TypingIndicator({super.key, this.dotSize = 7, this.color});

  /// The diameter of each dot.
  final double dotSize;

  /// Dot color. Defaults to the theme's accent color.
  final Color? color;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (PerformanceListThemeData.of(context).reduceMotion) {
      _wave
        ..stop()
        ..value = 0;
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = PerformanceListThemeData.of(context);
    final d = widget.dotSize;
    return Semantics(
      label: t.texts.typing,
      liveRegion: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(d * 3 + d * 0.9 * 2, d * 2.2),
          painter: _DotsPainter(
            _wave,
            widget.color ?? t.accentColor,
            d,
            animate: !t.reduceMotion,
          ),
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.wave, this.color, this.dot, {required this.animate})
    : _shades = List<Color>.generate(
        17,
        (i) => color.withValues(alpha: 0.4 + 0.6 * i / 16),
        growable: false,
      ),
      super(repaint: wave);

  final Animation<double> wave;
  final Color color;
  final double dot;
  final bool animate;
  final Paint _paint = Paint();
  // Precomputed so a frame allocates no colors.
  final List<Color> _shades;

  @override
  void paint(Canvas canvas, Size size) {
    final r = dot / 2;
    final gap = dot * 0.9;
    for (var i = 0; i < 3; i++) {
      double lift = 0;
      var shade = 4;
      if (animate) {
        final phase = (wave.value - i * 0.16) % 1.0;
        final s = phase < 0.5 ? math.sin(phase * 2 * math.pi) : 0.0;
        lift = s * dot * 0.6;
        shade = (s.clamp(0.0, 1.0) * 16).round();
      }
      _paint.color = _shades[shade];
      canvas.drawCircle(
        Offset(r + i * (dot + gap), size.height - r - dot * 0.3 - lift),
        r,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.color != color ||
      old.dot != dot ||
      old.animate != animate ||
      old.wave != wave;
}

/// A chat bubble with modern defaults: incoming bubbles on the start side,
/// outgoing ([isUser]) on the end side, colors from the theme.
class ChatBubble extends StatelessWidget {
  /// A bubble around [child].
  const ChatBubble({
    super.key,
    required this.child,
    this.isUser = false,
    this.header,
    this.footer,
    this.maxWidthFactor = 0.8,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    this.tail = true,
  });

  /// The content, usually a [Text] or [StreamingText].
  final Widget child;

  /// Whether this is the user's own message.
  final bool isUser;

  /// Shown above the bubble, such as a sender name.
  final Widget? header;

  /// Shown under the bubble, such as a time or actions.
  final Widget? footer;

  /// The bubble's maximum width as a fraction of the available width.
  final double maxWidthFactor;

  /// The background. Defaults to the theme's bubble colors.
  final Color? color;

  /// Space inside the bubble.
  final EdgeInsetsGeometry padding;

  /// Space around the bubble.
  final EdgeInsetsGeometry margin;

  /// Whether the corner nearest the sender is tighter.
  final bool tail;

  @override
  Widget build(BuildContext context) {
    final t = PerformanceListThemeData.of(context);
    final r = Radius.circular(t.bubbleRadius);
    final small = Radius.circular(tail ? 6 : t.bubbleRadius);
    final bg = color ?? (isUser ? t.userBubbleColor : t.bubbleColor);
    final fg = isUser ? t.onUserBubbleColor : t.onBubbleColor;
    final align = isUser
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart;
    return Padding(
      padding: margin,
      child: LayoutBuilder(
        builder: (context, c) {
          final maxW = c.maxWidth.isFinite
              ? c.maxWidth * maxWidthFactor
              : 560.0;
          return Align(
            alignment: align,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: math.min(maxW, 680)),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (header != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 6,
                        right: 6,
                        bottom: 4,
                      ),
                      child: DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                        child: header!,
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadiusDirectional.only(
                        topStart: r,
                        topEnd: r,
                        bottomStart: isUser ? r : small,
                        bottomEnd: isUser ? small : r,
                      ),
                    ),
                    child: Padding(
                      padding: padding,
                      child: DefaultTextStyle.merge(
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: fg, height: 1.4),
                        child: IconTheme.merge(
                          data: IconThemeData(color: fg),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                  if (footer != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 6, right: 6, top: 4),
                      child: DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        child: footer!,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The typing indicator inside an incoming bubble.
class TypingBubble extends StatelessWidget {
  /// A bubble with a [TypingIndicator].
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatBubble(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: TypingIndicator(),
    );
  }
}

/// The floating "jump to latest" pill of [PerformanceChatView].
class JumpToLatestPill extends StatelessWidget {
  /// A pill that calls [onPressed]. Shows [unread] when above zero.
  const JumpToLatestPill({super.key, required this.onPressed, this.unread = 0});

  /// Called on tap.
  final VoidCallback onPressed;

  /// Messages that arrived while scrolled away.
  final int unread;

  @override
  Widget build(BuildContext context) {
    final t = PerformanceListThemeData.of(context);
    final label = unread > 0
        ? t.texts.newMessages(unread)
        : t.texts.jumpToLatest;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: t.pillBackgroundColor,
          elevation: 3,
          shadowColor: Colors.black54,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 9, 18, 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    size: 18,
                    color: t.pillForegroundColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: t.pillForegroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
