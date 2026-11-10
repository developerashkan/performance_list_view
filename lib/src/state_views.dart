import 'package:flutter/material.dart';

import 'theme.dart';

/// Signature of builders for error states, with a [retry] callback.
typedef ErrorStateBuilder =
    Widget Function(BuildContext context, Object? error, VoidCallback retry);

/// The default view for an empty list.
class PerformanceEmptyView extends StatelessWidget {
  /// An empty view with an [icon], [title] and [message].
  const PerformanceEmptyView({
    super.key,
    this.icon = Icons.inbox_outlined,
    this.title,
    this.message,
    this.action,
  });

  /// The icon above the title.
  final IconData icon;

  /// The title. Defaults to [PerformanceListTexts.emptyTitle].
  final String? title;

  /// The message. Defaults to [PerformanceListTexts.emptyMessage].
  final String? message;

  /// An optional button under the message.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = PerformanceListThemeData.of(context);
    return _CenteredState(
      icon: icon,
      iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      iconBackground: Theme.of(context).colorScheme.surfaceContainerHigh,
      title: title ?? t.texts.emptyTitle,
      message: message ?? t.texts.emptyMessage,
      action: action,
    );
  }
}

/// The default view for a failed first page.
class PerformanceErrorView extends StatelessWidget {
  /// An error view with a retry button when [onRetry] is set.
  const PerformanceErrorView({
    super.key,
    this.error,
    this.onRetry,
    this.title,
    this.message,
  });

  /// The error. Not shown; available to subclasses and tests.
  final Object? error;

  /// Called by the retry button. Null hides it.
  final VoidCallback? onRetry;

  /// The title. Defaults to [PerformanceListTexts.errorTitle].
  final String? title;

  /// The message. Defaults to [PerformanceListTexts.errorMessage].
  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = PerformanceListThemeData.of(context);
    final cs = Theme.of(context).colorScheme;
    return _CenteredState(
      icon: Icons.cloud_off_rounded,
      iconColor: cs.onErrorContainer,
      iconBackground: cs.errorContainer,
      title: title ?? t.texts.errorTitle,
      message: message ?? t.texts.errorMessage,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t.texts.retry),
            ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Icon(icon, size: 34, color: iconColor),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// The default footer while the next page loads.
class PerformanceLoadingFooter extends StatelessWidget {
  /// A spinner and a label.
  const PerformanceLoadingFooter({super.key, this.label});

  /// The label. Defaults to [PerformanceListTexts.loadingMore].
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = PerformanceListThemeData.of(context);
    final text = label ?? t.texts.loadingMore;
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  strokeCap: StrokeCap.round,
                  color: t.accentColor,
                  // A spinning indicator never settles; reduced motion and
                  // tests get a still arc.
                  value: t.reduceMotion ? 0.72 : null,
                ),
              ),
              const SizedBox(width: 12),
              Text(text, style: t.footerTextStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// The default footer when loading the next page failed.
class PerformanceErrorFooter extends StatelessWidget {
  /// A message with a retry button.
  const PerformanceErrorFooter({super.key, this.error, required this.onRetry});

  /// The error.
  final Object? error;

  /// Called by the retry button.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = PerformanceListThemeData.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Center(
        child: Material(
          color: cs.errorContainer.withValues(alpha: 0.55),
          shape: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: cs.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    t.texts.loadMoreError,
                    style: t.footerTextStyle.copyWith(
                      color: cs.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onErrorContainer,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(t.texts.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The default footer after the last page.
class PerformanceEndFooter extends StatelessWidget {
  /// A quiet "all caught up" line.
  const PerformanceEndFooter({super.key, this.label});

  /// The label. Defaults to [PerformanceListTexts.endOfList].
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = PerformanceListThemeData.of(context);
    final cs = Theme.of(context).colorScheme;
    final line = Expanded(
      child: Divider(
        color: cs.outlineVariant.withValues(alpha: 0.6),
        height: 1,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: t.accentColor,
                ),
                const SizedBox(width: 6),
                Text(label ?? t.texts.endOfList, style: t.footerTextStyle),
              ],
            ),
          ),
          line,
        ],
      ),
    );
  }
}
