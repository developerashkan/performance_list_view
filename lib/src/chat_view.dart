import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'ai_widgets.dart';
import 'controller.dart';
import 'core.dart';
import 'list_view.dart' show ItemBuilder, StateBuilder;
import 'skeleton.dart';
import 'state_views.dart';
import 'theme.dart';

/// A [ScrollController] for [PerformanceChatView] that stays pinned to the
/// latest message while the list grows, for example while an AI reply
/// streams in.
class ChatScrollController extends ScrollController {
  /// A controller that sticks to the latest message when [stickToLatest].
  ChatScrollController({
    this.stickToLatest = true,
    this.pinTolerance = 2,
    super.debugLabel,
    super.keepScrollOffset,
  });

  /// Whether to follow new content while pinned at the latest message.
  bool stickToLatest;

  /// How close to the latest message counts as pinned, in pixels.
  double pinTolerance;

  /// Whether the view shows the latest message.
  bool get isAtLatest {
    if (!hasClients) return true;
    final p = position;
    if (!p.hasContentDimensions || !p.hasPixels) return true;
    return (p.pixels - p.minScrollExtent).abs() <= pinTolerance;
  }

  /// How far the view is scrolled from the latest message.
  double get distanceFromLatest {
    if (!hasClients) return 0;
    final p = position;
    if (!p.hasContentDimensions || !p.hasPixels) return 0;
    return p.pixels - p.minScrollExtent;
  }

  /// Scrolls to the latest message. Animates unless [duration] is zero.
  Future<void> scrollToLatest({
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeOutCubic,
  }) async {
    if (!hasClients) return;
    final p = position;
    if (duration == Duration.zero) {
      p.jumpTo(p.minScrollExtent);
      return;
    }
    await p.animateTo(p.minScrollExtent, duration: duration, curve: curve);
    // The latest message may have grown during the animation.
    if (hasClients && !isAtLatest) position.jumpTo(position.minScrollExtent);
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _ChatScrollPosition(
      controller: this,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _ChatScrollPosition extends ScrollPositionWithSingleContext {
  _ChatScrollPosition({
    required this.controller,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final ChatScrollController controller;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final first = !hasContentDimensions;
    final pinned =
        controller.stickToLatest &&
        hasPixels &&
        (first ||
            ((pixels - this.minScrollExtent).abs() <= controller.pinTolerance &&
                !(activity?.isScrolling ?? false)));
    final settled = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    if (pinned && (pixels - minScrollExtent).abs() > _epsilon) {
      // Content grew below the anchor (or this is the first layout): follow
      // it in the same frame.
      correctPixels(minScrollExtent);
      return false;
    }
    return settled;
  }
}

const double _epsilon = 1e-10;

/// A chat or AI conversation list.
///
/// Index 0 of [controller] is the newest message, at the bottom: add new
/// messages with [PerformanceListController.prepend]. With a
/// [PagingController], older history loads page by page as the user scrolls
/// up.
///
/// * New messages, a growing streaming reply and the typing indicator keep
///   the view pinned to the bottom, in the same frame.
/// * When the user has scrolled up, nothing they read moves: new content
///   grows below a fixed anchor, and a "jump to latest" pill counts the
///   unread messages.
/// * A streaming reply ([StreamingText]) rebuilds only its own text per
///   token; no other message rebuilds when messages are added.
class PerformanceChatView<T> extends StatefulWidget {
  /// A chat list of the messages in [controller], newest first.
  const PerformanceChatView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.itemKey,
    this.scrollController,
    this.typing,
    this.typingBuilder,
    this.showJumpToLatest = true,
    this.jumpToLatestBuilder,
    this.jumpToLatestThreshold = 240,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
    this.emptyBuilder,
    this.historyLoaderBuilder,
    this.historyErrorBuilder,
    this.historyStartBuilder,
    this.skeletonCount = 6,
    this.physics,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.scrollCacheExtent,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.scrollThreshold = 5,
    this.loadMoreExtent,
    this.clipBehavior = Clip.hardEdge,
  });

  /// The messages, newest first.
  final PerformanceListController<T> controller;

  /// Builds a message. The index is the newest-first index when it was
  /// built; a message is not rebuilt when newer messages arrive.
  final ItemBuilder<T> itemBuilder;

  /// A stable identity for a message, so its state survives removals.
  final Object? Function(T item)? itemKey;

  /// Created and disposed by the view when null.
  final ChatScrollController? scrollController;

  /// Shows the typing indicator while true.
  final ValueListenable<bool>? typing;

  /// The typing indicator. Defaults to [TypingBubble].
  final WidgetBuilder? typingBuilder;

  /// Whether to show the jump-to-latest pill when scrolled up.
  final bool showJumpToLatest;

  /// Builds the pill. Defaults to [JumpToLatestPill].
  final Widget Function(
    BuildContext context,
    int unread,
    VoidCallback onPressed,
  )?
  jumpToLatestBuilder;

  /// How far from the latest message the pill appears, in pixels.
  final double jumpToLatestThreshold;

  /// Padding around the messages.
  final EdgeInsets padding;

  /// Shown when there are no messages.
  final StateBuilder? emptyBuilder;

  /// Shown at the top while older history loads.
  final StateBuilder? historyLoaderBuilder;

  /// Shown at the top when older history failed, with a retry callback.
  final ErrorStateBuilder? historyErrorBuilder;

  /// Shown at the top once all history has loaded.
  final StateBuilder? historyStartBuilder;

  /// Placeholder bubbles while the first page loads.
  final int skeletonCount;

  /// Scroll physics.
  final ScrollPhysics? physics;

  /// Defaults to dismissing the keyboard when the user drags.
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// How much to build outside the viewport.
  final ScrollCacheExtent? scrollCacheExtent;

  /// Whether each message gets a [RepaintBoundary].
  final bool addRepaintBoundaries;

  /// Whether messages may keep themselves alive off screen.
  final bool addAutomaticKeepAlives;

  /// Loads older history once a message this close to the oldest is laid out.
  final int scrollThreshold;

  /// Loads older history once the content above the viewport is shorter
  /// than this. Defaults to 60% of the viewport.
  final double? loadMoreExtent;

  /// See [ScrollView.clipBehavior].
  final Clip clipBehavior;

  @override
  State<PerformanceChatView<T>> createState() => _PerformanceChatViewState<T>();
}

class _PerformanceChatViewState<T> extends State<PerformanceChatView<T>>
    implements ListViewAttachment {
  ChatScrollController? _own;
  final Key _center = UniqueKey();
  final GlobalKey _scrollKey = GlobalKey();
  final ItemWidgetCache _newCache = ItemWidgetCache();
  final ItemWidgetCache _historyCache = ItemWidgetCache();
  KeyIndex<T>? _keyIndex;
  final ValueNotifier<int> _unread = ValueNotifier<int>(0);
  final ValueNotifier<bool> _away = ValueNotifier<bool>(false);
  int _newCount = 0; // messages below the anchor: items[0 .. _newCount)
  int _lastHistoryLaidOut = -1;
  bool _checkScheduled = false;
  int _scrollEpoch = 0;
  late final FrameCallback _postFrame = _onPostFrame;
  ChatScrollController? _listening;

  ChatScrollController get _scroll =>
      widget.scrollController ?? (_own ??= ChatScrollController());
  PerformanceListController<T> get _c => widget.controller;
  List<T> get _items => _c.items;

  @override
  void initState() {
    super.initState();
    _subscribe(_c);
    _listen();
    _scheduleLoadCheck();
  }

  @override
  void didUpdateWidget(PerformanceChatView<T> old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _unsubscribe(old.controller);
      _subscribe(widget.controller);
      _newCount = 0;
      _clearCaches();
    } else if (old.itemBuilder != widget.itemBuilder ||
        old.itemKey != widget.itemKey) {
      _clearCaches();
    }
    if (old.scrollController != widget.scrollController &&
        widget.scrollController != null) {
      _own?.dispose();
      _own = null;
    }
    _listen();
    _scheduleLoadCheck();
  }

  @override
  void dispose() {
    _scrollEpoch++;
    _unsubscribe(_c);
    _listening?.removeListener(_onScrolled);
    _own?.dispose();
    _unread.dispose();
    _away.dispose();
    super.dispose();
  }

  void _listen() {
    final scroll = _scroll;
    if (identical(scroll, _listening)) return;
    _listening?.removeListener(_onScrolled);
    _listening = scroll..addListener(_onScrolled);
  }

  void _subscribe(PerformanceListController<T> c) {
    c.itemsListenable.addListener(_onItems);
    c.statusListenable.addListener(_onStatus);
    c.addChangeListener(_onChange);
    c.attachView(this);
  }

  void _unsubscribe(PerformanceListController<T> c) {
    if (c.isDisposed) return;
    c.itemsListenable.removeListener(_onItems);
    c.statusListenable.removeListener(_onStatus);
    c.removeChangeListener(_onChange);
    c.detachView(this);
  }

  void _clearCaches() {
    _newCache.clear();
    _historyCache.clear();
    _keyIndex?.invalidate();
  }

  void _onChange(ListChange<T> change) {
    final appended =
        change.kind == ListChangeKind.insert &&
        change.index + change.count == _items.length;
    if (!appended) _keyIndex?.invalidate();
    switch (change.kind) {
      case ListChangeKind.insert:
        // Pages of older history append at the end; new messages go in at
        // the front, below the anchor.
        if (change.index < _newCount || (change.index == 0 && !appended)) {
          _newCount += change.count;
          if (change.index == 0 && !_scroll.isAtLatest) {
            _unread.value += change.count;
          }
        }
      case ListChangeKind.remove:
        if (change.index < _newCount) {
          _newCount -= change.count.clamp(0, _newCount - change.index);
        }
      case ListChangeKind.update:
        if (change.index < _newCount) {
          _newCache.remove(_newCount - 1 - change.index);
        } else {
          _historyCache.remove(change.index - _newCount);
        }
      case ListChangeKind.reset:
        _newCount = 0;
        _unread.value = 0;
        _lastHistoryLaidOut = -1;
        _clearCaches();
    }
  }

  void _onItems() {
    if (!mounted) return;
    setState(() {});
    _scheduleLoadCheck();
  }

  void _onStatus() {
    if (!mounted) return;
    setState(() {});
    _scheduleLoadCheck();
  }

  void _onScrolled() {
    final distance = _scroll.distanceFromLatest;
    _away.value = distance > widget.jumpToLatestThreshold;
    if (distance <= _scroll.pinTolerance && _unread.value != 0) {
      _unread.value = 0;
    }
    _scheduleLoadCheck();
  }

  void _jumpToLatest() {
    _unread.value = 0;
    final reduce = PerformanceListThemeData.of(context).reduceMotion;
    _scroll.scrollToLatest(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 360),
    );
  }

  // ---------------------------------------------------------------- history

  void _scheduleLoadCheck() {
    if (_checkScheduled || !mounted) return;
    _checkScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback(_postFrame)
      ..ensureVisualUpdate();
  }

  void _onPostFrame(Duration _) {
    _checkScheduled = false;
    if (!mounted) return;
    final c = _c;
    if (!c.isPaginated || !c.hasMore || c.status != PagingStatus.idle) return;
    if (_items.isNotEmpty) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (!pos.hasContentDimensions || !pos.hasViewportDimension) return;
      final extent = widget.loadMoreExtent ?? pos.viewportDimension * 0.6;
      final historyCount = _items.length - _newCount;
      final near =
          pos.extentAfter <= extent ||
          (_lastHistoryLaidOut >= 0 &&
              _lastHistoryLaidOut >= historyCount - 1 - widget.scrollThreshold);
      if (!near) return;
    }
    c.loadMore();
  }

  @override
  Future<void> scrollToIndex(
    int index,
    double alignment,
    double offset,
    Duration duration,
    Curve curve,
  ) {
    if (!mounted || !_scroll.hasClients) return Future<void>.value();
    final epoch = ++_scrollEpoch;
    final reduce = PerformanceListThemeData.of(context).reduceMotion;
    return scrollToItem(
      position: () => _scroll.position,
      root: () => _scrollKey.currentContext?.findRenderObject(),
      isCurrent: () => mounted && epoch == _scrollEpoch && _scroll.hasClients,
      index: index,
      alignment: alignment,
      offset: offset,
      duration: reduce ? Duration.zero : duration,
      curve: curve,
    );
  }

  // ---------------------------------------------------------------- building

  Widget _build(BuildContext context, int index) {
    final item = _items[index];
    final child =
        widget.itemBuilder(context, item, index) ?? const SizedBox.shrink();
    return wrapItem(child, index, widget.itemKey?.call(item));
  }

  int? _findIndex(Key key, bool below) {
    final keyOf = widget.itemKey;
    if (keyOf == null) return null;
    final g = (_keyIndex ??= KeyIndex<T>(
      keyOf,
    )).indexOf(key is ValueKey ? key.value as Object : key, _items);
    if (g == null) return null;
    if (below) return g < _newCount ? _newCount - 1 - g : null;
    return g >= _newCount ? g - _newCount : null;
  }

  Widget _topSliver(BuildContext context) {
    final c = _c;
    switch (c.status) {
      case PagingStatus.loadingFirstPage:
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => i == 0
                ? SkeletonBubble(alignEnd: i.isOdd, seed: i)
                : ExcludeSemantics(
                    child: SkeletonBubble(
                      alignEnd: i.isOdd,
                      seed: i,
                      lines: 1 + i % 3,
                    ),
                  ),
            childCount: widget.skeletonCount,
          ),
        );
      case PagingStatus.loadingMore:
      case PagingStatus.refreshing:
        return SliverToBoxAdapter(
          child:
              widget.historyLoaderBuilder?.call(context) ??
              const PerformanceLoadingFooter(),
        );
      case PagingStatus.firstPageError:
        return SliverFillRemaining(
          hasScrollBody: false,
          child:
              widget.historyErrorBuilder?.call(context, c.error, c.retry) ??
              PerformanceErrorView(error: c.error, onRetry: c.retry),
        );
      case PagingStatus.loadMoreError:
        return SliverToBoxAdapter(
          child:
              widget.historyErrorBuilder?.call(context, c.error, c.retry) ??
              PerformanceErrorFooter(error: c.error, onRetry: c.retry),
        );
      case PagingStatus.idle:
      case PagingStatus.completed:
        if (_items.isEmpty && !(c.isPaginated && c.hasMore)) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child:
                widget.emptyBuilder?.call(context) ??
                const PerformanceEmptyView(icon: Icons.forum_outlined),
          );
        }
        if (c.status == PagingStatus.completed &&
            c.isPaginated &&
            _items.isNotEmpty) {
          return SliverToBoxAdapter(
            child:
                widget.historyStartBuilder?.call(context) ??
                const SizedBox(height: 8),
          );
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
  }

  @override
  Widget build(BuildContext context) {
    final newCount = _newCount;
    final historyCount = _items.length - newCount;
    final belowAnchor = RelayoutOnCount(
      childCount: newCount,
      sliver: SliverList(
        delegate: CachingItemDelegate(
          (context, slot) => _build(context, newCount - 1 - slot),
          cache: _newCache,
          itemOf: (slot) => _items[newCount - 1 - slot],
          childCount: newCount,
          findChildIndexCallback: widget.itemKey == null
              ? null
              : (key) => _findIndex(key, true),
          addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
          addRepaintBoundaries: widget.addRepaintBoundaries,
          semanticIndexCallback: (_, slot) => newCount - 1 - slot,
        ),
      ),
    );

    final history = RelayoutOnCount(
      key: _center,
      childCount: historyCount,
      sliver: SliverList(
        delegate: CachingItemDelegate(
          (context, slot) => _build(context, newCount + slot),
          cache: _historyCache,
          itemOf: (slot) => _items[newCount + slot],
          childCount: historyCount,
          findChildIndexCallback: widget.itemKey == null
              ? null
              : (key) => _findIndex(key, false),
          addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
          addRepaintBoundaries: widget.addRepaintBoundaries,
          semanticIndexOffset: newCount,
          onLayout: (first, last) => _lastHistoryLaidOut = last,
        ),
      ),
    );

    final typing = widget.typing;
    final view = CustomScrollView(
      key: _scrollKey,
      controller: _scroll,
      reverse: true,
      center: _center,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      scrollCacheExtent: widget.scrollCacheExtent,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      clipBehavior: widget.clipBehavior,
      semanticChildCount: _items.length,
      // Before the center sliver, outward from it: these grow downward.
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: widget.padding.bottom)),
        if (typing != null)
          SliverToBoxAdapter(
            child: ValueListenableBuilder<bool>(
              valueListenable: typing,
              builder: (context, on, _) => on
                  ? (widget.typingBuilder?.call(context) ??
                        const TypingBubble())
                  : const SizedBox.shrink(),
            ),
          ),
        belowAnchor,
        history,
        // After the center sliver: these grow upward.
        _topSliver(context),
        SliverToBoxAdapter(child: SizedBox(height: widget.padding.top)),
      ],
    );
    if (!widget.showJumpToLatest) return view;
    final reduce = PerformanceListThemeData.of(context).reduceMotion;
    return Stack(
      children: [
        Positioned.fill(child: view),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 16,
          child: Center(
            child: ListenableBuilder(
              listenable: Listenable.merge([_away, _unread]),
              builder: (context, _) {
                final show =
                    _away.value || _unread.value > 0 && !_scroll.isAtLatest;
                final pill =
                    widget.jumpToLatestBuilder?.call(
                      context,
                      _unread.value,
                      _jumpToLatest,
                    ) ??
                    JumpToLatestPill(
                      onPressed: _jumpToLatest,
                      unread: _unread.value,
                    );
                return IgnorePointer(
                  ignoring: !show,
                  child: AnimatedSlide(
                    offset: show ? Offset.zero : const Offset(0, 0.6),
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: show ? 1 : 0,
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: pill,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
