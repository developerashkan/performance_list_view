import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The strings the default widgets show. Override them for localization
/// through [PerformanceListThemeData.texts].
@immutable
class PerformanceListTexts {
  /// English defaults.
  const PerformanceListTexts({
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage = 'Pull down to refresh, or check back later.',
    this.errorTitle = 'Something went wrong',
    this.errorMessage = 'Check your connection and try again.',
    this.retry = 'Try again',
    this.loadingMore = 'Loading more',
    this.loadMoreError = "Couldn't load more",
    this.endOfList = "You're all caught up",
    this.jumpToLatest = 'Jump to latest',
    this.newMessages = _newMessages,
    this.typing = 'Typing',
    this.loading = 'Loading',
  });

  /// Title of the default empty view.
  final String emptyTitle;

  /// Message of the default empty view.
  final String emptyMessage;

  /// Title of the default first-page error view.
  final String errorTitle;

  /// Message of the default first-page error view.
  final String errorMessage;

  /// Label of the retry buttons.
  final String retry;

  /// Label of the loading footer.
  final String loadingMore;

  /// Label of the load-more error footer.
  final String loadMoreError;

  /// Label of the end-of-list footer.
  final String endOfList;

  /// Label of the jump-to-latest pill.
  final String jumpToLatest;

  /// Label of the jump-to-latest pill with unread messages.
  final String Function(int count) newMessages;

  /// Semantics label of the typing indicator.
  final String typing;

  /// Semantics label of skeleton placeholders.
  final String loading;

  static String _newMessages(int count) =>
      count == 1 ? '1 new message' : '$count new messages';

  @override
  bool operator ==(Object other) =>
      other is PerformanceListTexts &&
      other.emptyTitle == emptyTitle &&
      other.emptyMessage == emptyMessage &&
      other.errorTitle == errorTitle &&
      other.errorMessage == errorMessage &&
      other.retry == retry &&
      other.loadingMore == loadingMore &&
      other.loadMoreError == loadMoreError &&
      other.endOfList == endOfList &&
      other.jumpToLatest == jumpToLatest &&
      other.newMessages == newMessages &&
      other.typing == typing &&
      other.loading == loading;

  @override
  int get hashCode => Object.hash(
    emptyTitle,
    emptyMessage,
    errorTitle,
    errorMessage,
    retry,
    loadingMore,
    loadMoreError,
    endOfList,
    jumpToLatest,
    newMessages,
    typing,
    loading,
  );
}

/// Colors, shapes and motion for the default widgets of this package.
///
/// Add it to [ThemeData.extensions] to change them app-wide. Every null
/// field is derived from the [ColorScheme], so the defaults follow light and
/// dark themes.
@immutable
class PerformanceListThemeData
    extends ThemeExtension<PerformanceListThemeData> {
  /// Creates a theme. Null fields fall back to the [ColorScheme].
  const PerformanceListThemeData({
    this.skeletonBaseColor,
    this.skeletonHighlightColor,
    this.skeletonRadius,
    this.shimmerPeriod,
    this.accentColor,
    this.footerTextStyle,
    this.pillBackgroundColor,
    this.pillForegroundColor,
    this.bubbleColor,
    this.userBubbleColor,
    this.onBubbleColor,
    this.onUserBubbleColor,
    this.bubbleRadius,
    this.reduceMotion,
    this.texts,
  });

  /// Base color of skeleton shapes.
  final Color? skeletonBaseColor;

  /// Color of the shimmer sweep over skeleton shapes.
  final Color? skeletonHighlightColor;

  /// Corner radius of skeleton lines and cards.
  final double? skeletonRadius;

  /// Time of one shimmer sweep.
  final Duration? shimmerPeriod;

  /// Color of spinners, retry buttons and the typing indicator.
  final Color? accentColor;

  /// Text style of the loading, error and end footers.
  final TextStyle? footerTextStyle;

  /// Background of the jump-to-latest pill.
  final Color? pillBackgroundColor;

  /// Text and icon color of the jump-to-latest pill.
  final Color? pillForegroundColor;

  /// Background of incoming [ChatBubble]s and the typing bubble.
  final Color? bubbleColor;

  /// Background of outgoing [ChatBubble]s.
  final Color? userBubbleColor;

  /// Text color on [bubbleColor].
  final Color? onBubbleColor;

  /// Text color on [userBubbleColor].
  final Color? onUserBubbleColor;

  /// Corner radius of chat bubbles.
  final double? bubbleRadius;

  /// Forces reduced motion on or off. Null follows
  /// [MediaQueryData.disableAnimations].
  final bool? reduceMotion;

  /// The strings of the default widgets.
  final PerformanceListTexts? texts;

  @override
  bool operator ==(Object other) =>
      other is PerformanceListThemeData &&
      other.skeletonBaseColor == skeletonBaseColor &&
      other.skeletonHighlightColor == skeletonHighlightColor &&
      other.skeletonRadius == skeletonRadius &&
      other.shimmerPeriod == shimmerPeriod &&
      other.accentColor == accentColor &&
      other.footerTextStyle == footerTextStyle &&
      other.pillBackgroundColor == pillBackgroundColor &&
      other.pillForegroundColor == pillForegroundColor &&
      other.bubbleColor == bubbleColor &&
      other.userBubbleColor == userBubbleColor &&
      other.onBubbleColor == onBubbleColor &&
      other.onUserBubbleColor == onUserBubbleColor &&
      other.bubbleRadius == bubbleRadius &&
      other.reduceMotion == reduceMotion &&
      other.texts == texts;

  @override
  int get hashCode => Object.hash(
    skeletonBaseColor,
    skeletonHighlightColor,
    skeletonRadius,
    shimmerPeriod,
    accentColor,
    footerTextStyle,
    pillBackgroundColor,
    pillForegroundColor,
    bubbleColor,
    userBubbleColor,
    onBubbleColor,
    onUserBubbleColor,
    bubbleRadius,
    reduceMotion,
    texts,
  );

  /// The theme for [context] with every field resolved.
  static ResolvedPerformanceListTheme of(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<PerformanceListThemeData>();
    final cs = theme.colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final reduce =
        ext?.reduceMotion ??
        MediaQuery.maybeDisableAnimationsOf(context) ??
        false;
    return ResolvedPerformanceListTheme(
      skeletonBaseColor: ext?.skeletonBaseColor ?? cs.surfaceContainerHighest,
      skeletonHighlightColor:
          ext?.skeletonHighlightColor ??
          Color.lerp(
            cs.surfaceContainerHighest,
            dark ? cs.onSurface : cs.surface,
            dark ? 0.12 : 0.75,
          )!,
      skeletonRadius: ext?.skeletonRadius ?? 10,
      shimmerPeriod: ext?.shimmerPeriod ?? const Duration(milliseconds: 1400),
      accentColor: ext?.accentColor ?? cs.primary,
      footerTextStyle:
          ext?.footerTextStyle ??
          theme.textTheme.labelLarge!.copyWith(color: cs.onSurfaceVariant),
      pillBackgroundColor: ext?.pillBackgroundColor ?? cs.inverseSurface,
      pillForegroundColor: ext?.pillForegroundColor ?? cs.onInverseSurface,
      bubbleColor: ext?.bubbleColor ?? cs.surfaceContainerHigh,
      userBubbleColor: ext?.userBubbleColor ?? cs.primary,
      onBubbleColor: ext?.onBubbleColor ?? cs.onSurface,
      onUserBubbleColor: ext?.onUserBubbleColor ?? cs.onPrimary,
      bubbleRadius: ext?.bubbleRadius ?? 20,
      reduceMotion: reduce,
      texts: ext?.texts ?? const PerformanceListTexts(),
    );
  }

  @override
  PerformanceListThemeData copyWith({
    Color? skeletonBaseColor,
    Color? skeletonHighlightColor,
    double? skeletonRadius,
    Duration? shimmerPeriod,
    Color? accentColor,
    TextStyle? footerTextStyle,
    Color? pillBackgroundColor,
    Color? pillForegroundColor,
    Color? bubbleColor,
    Color? userBubbleColor,
    Color? onBubbleColor,
    Color? onUserBubbleColor,
    double? bubbleRadius,
    bool? reduceMotion,
    PerformanceListTexts? texts,
  }) {
    return PerformanceListThemeData(
      skeletonBaseColor: skeletonBaseColor ?? this.skeletonBaseColor,
      skeletonHighlightColor:
          skeletonHighlightColor ?? this.skeletonHighlightColor,
      skeletonRadius: skeletonRadius ?? this.skeletonRadius,
      shimmerPeriod: shimmerPeriod ?? this.shimmerPeriod,
      accentColor: accentColor ?? this.accentColor,
      footerTextStyle: footerTextStyle ?? this.footerTextStyle,
      pillBackgroundColor: pillBackgroundColor ?? this.pillBackgroundColor,
      pillForegroundColor: pillForegroundColor ?? this.pillForegroundColor,
      bubbleColor: bubbleColor ?? this.bubbleColor,
      userBubbleColor: userBubbleColor ?? this.userBubbleColor,
      onBubbleColor: onBubbleColor ?? this.onBubbleColor,
      onUserBubbleColor: onUserBubbleColor ?? this.onUserBubbleColor,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      texts: texts ?? this.texts,
    );
  }

  @override
  PerformanceListThemeData lerp(PerformanceListThemeData? other, double t) {
    if (other == null) return this;
    return PerformanceListThemeData(
      skeletonBaseColor: Color.lerp(
        skeletonBaseColor,
        other.skeletonBaseColor,
        t,
      ),
      skeletonHighlightColor: Color.lerp(
        skeletonHighlightColor,
        other.skeletonHighlightColor,
        t,
      ),
      skeletonRadius: lerpDouble(skeletonRadius, other.skeletonRadius, t),
      shimmerPeriod: t < 0.5 ? shimmerPeriod : other.shimmerPeriod,
      accentColor: Color.lerp(accentColor, other.accentColor, t),
      footerTextStyle: TextStyle.lerp(
        footerTextStyle,
        other.footerTextStyle,
        t,
      ),
      pillBackgroundColor: Color.lerp(
        pillBackgroundColor,
        other.pillBackgroundColor,
        t,
      ),
      pillForegroundColor: Color.lerp(
        pillForegroundColor,
        other.pillForegroundColor,
        t,
      ),
      bubbleColor: Color.lerp(bubbleColor, other.bubbleColor, t),
      userBubbleColor: Color.lerp(userBubbleColor, other.userBubbleColor, t),
      onBubbleColor: Color.lerp(onBubbleColor, other.onBubbleColor, t),
      onUserBubbleColor: Color.lerp(
        onUserBubbleColor,
        other.onUserBubbleColor,
        t,
      ),
      bubbleRadius: lerpDouble(bubbleRadius, other.bubbleRadius, t),
      reduceMotion: t < 0.5 ? reduceMotion : other.reduceMotion,
      texts: t < 0.5 ? texts : other.texts,
    );
  }
}

/// [PerformanceListThemeData] with every value resolved for a context.
@immutable
class ResolvedPerformanceListTheme {
  /// Creates a resolved theme. Use [PerformanceListThemeData.of].
  const ResolvedPerformanceListTheme({
    required this.skeletonBaseColor,
    required this.skeletonHighlightColor,
    required this.skeletonRadius,
    required this.shimmerPeriod,
    required this.accentColor,
    required this.footerTextStyle,
    required this.pillBackgroundColor,
    required this.pillForegroundColor,
    required this.bubbleColor,
    required this.userBubbleColor,
    required this.onBubbleColor,
    required this.onUserBubbleColor,
    required this.bubbleRadius,
    required this.reduceMotion,
    required this.texts,
  });

  /// See [PerformanceListThemeData.skeletonBaseColor].
  final Color skeletonBaseColor;

  /// See [PerformanceListThemeData.skeletonHighlightColor].
  final Color skeletonHighlightColor;

  /// See [PerformanceListThemeData.skeletonRadius].
  final double skeletonRadius;

  /// See [PerformanceListThemeData.shimmerPeriod].
  final Duration shimmerPeriod;

  /// See [PerformanceListThemeData.accentColor].
  final Color accentColor;

  /// See [PerformanceListThemeData.footerTextStyle].
  final TextStyle footerTextStyle;

  /// See [PerformanceListThemeData.pillBackgroundColor].
  final Color pillBackgroundColor;

  /// See [PerformanceListThemeData.pillForegroundColor].
  final Color pillForegroundColor;

  /// See [PerformanceListThemeData.bubbleColor].
  final Color bubbleColor;

  /// See [PerformanceListThemeData.userBubbleColor].
  final Color userBubbleColor;

  /// See [PerformanceListThemeData.onBubbleColor].
  final Color onBubbleColor;

  /// See [PerformanceListThemeData.onUserBubbleColor].
  final Color onUserBubbleColor;

  /// See [PerformanceListThemeData.bubbleRadius].
  final double bubbleRadius;

  /// Whether motion is reduced: animations jump to their end.
  final bool reduceMotion;

  /// See [PerformanceListThemeData.texts].
  final PerformanceListTexts texts;
}
