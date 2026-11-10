import 'package:flutter/material.dart';

/// Builds the placeholder of a [PerformanceImage] while [url] loads.
typedef PlaceholderWidgetBuilder =
    Widget Function(BuildContext context, String url);

/// Builds the error widget of a [PerformanceImage].
typedef LoadingErrorWidgetBuilder =
    Widget Function(BuildContext context, String url, Object error);

/// Builds a [PerformanceImage] from its loaded image provider.
typedef ImageWidgetBuilder =
    Widget Function(BuildContext context, ImageProvider imageProvider);

/// A list-friendly network image: decoded at its display size (not the
/// source size), faded in once, with a placeholder and an error state.
///
/// Decoding at display size is what keeps long image feeds from running out
/// of memory. Pure Flutter, so it works on every platform; for a disk cache
/// pass your own [imageProvider], such as `CachedNetworkImageProvider`.
class PerformanceImage extends StatelessWidget {
  /// An image loaded from [imageUrl].
  const PerformanceImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.memCacheHeight,
    this.memCacheWidth,
    this.httpHeaders,
    this.placeholder,
    this.errorWidget,
    this.imageBuilder,
    this.imageProvider,
    this.fadeInDuration = const Duration(milliseconds: 250),
    this.semanticLabel,
  });

  /// The image URL.
  final String imageUrl;

  /// Display height. Also sets the decode height when finite.
  final double? height;

  /// Display width. Also sets the decode width when finite.
  final double? width;

  /// How the image fills its box.
  final BoxFit fit;

  /// Corner radius.
  final double borderRadius;

  /// Decode height in physical pixels. Defaults to [height] × device pixel
  /// ratio.
  final int? memCacheHeight;

  /// Decode width in physical pixels. Defaults to [width] × device pixel
  /// ratio.
  final int? memCacheWidth;

  /// Headers for the request.
  final Map<String, String>? httpHeaders;

  /// Shown while loading. Defaults to a tinted box.
  final PlaceholderWidgetBuilder? placeholder;

  /// Shown when loading fails. Defaults to a broken-image icon.
  final LoadingErrorWidgetBuilder? errorWidget;

  /// Builds the loaded image yourself.
  final ImageWidgetBuilder? imageBuilder;

  /// Loads the image instead of a [NetworkImage] for [imageUrl], such as a
  /// disk-cached provider. It is still decoded at display size.
  final ImageProvider? imageProvider;

  /// The fade-in time after loading. Zero, or reduced motion, shows the image
  /// at once.
  final Duration fadeInDuration;

  /// Read by screen readers.
  final String? semanticLabel;

  static int? _px(int? explicit, double? logical, double dpr) {
    if (explicit != null) return explicit > 0 ? explicit : null;
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    return (logical * dpr).round();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    var cacheW = _px(memCacheWidth, width, dpr);
    var cacheH = _px(memCacheHeight, height, dpr);
    // Both bounds with a covering fit would shrink one side below the box;
    // keep the larger bound and let the aspect ratio follow.
    if (memCacheWidth == null &&
        memCacheHeight == null &&
        cacheW != null &&
        cacheH != null &&
        fit == BoxFit.cover) {
      if (cacheW >= cacheH) {
        cacheH = null;
      } else {
        cacheW = null;
      }
    }
    final source =
        imageProvider ?? NetworkImage(imageUrl, headers: httpHeaders);
    final provider = ResizeImage.resizeIfNeeded(cacheW, cacheH, source);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final fade = reduce ? Duration.zero : fadeInDuration;
    final cs = Theme.of(context).colorScheme;

    Widget placeholderOf(BuildContext context) =>
        placeholder?.call(context, imageUrl) ??
        ColoredBox(
          color: cs.surfaceContainerHighest,
          child: const SizedBox.expand(),
        );

    final image = Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) {
        final loaded = frame != null;
        final shown = loaded && imageBuilder != null
            ? imageBuilder!(context, provider)
            : child;
        if (sync) return shown;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            if (!loaded) Positioned.fill(child: placeholderOf(context)),
            AnimatedOpacity(
              opacity: loaded ? 1 : 0,
              duration: fade,
              curve: Curves.easeOut,
              child: shown,
            ),
          ],
        );
      },
      errorBuilder: (context, error, _) =>
          errorWidget?.call(context, imageUrl, error) ??
          ColoredBox(
            color: cs.surfaceContainerHigh,
            child: SizedBox(
              width: width?.isFinite == true ? width : null,
              height: height?.isFinite == true ? height : null,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
    );
    if (borderRadius <= 0) return image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: image,
    );
  }
}
