import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'controller.dart';
import 'core.dart';
import 'masonry.dart';
import 'skeleton.dart';
import 'state_views.dart';
import 'theme.dart';

/// Builds the widget for [item] at [index]. Returning null shows nothing for
/// that item; the items after it still show.
typedef ItemBuilder<T> =
    Widget? Function(BuildContext context, T item, int index);

/// Builds a widget for a list state such as empty or loading.
typedef StateBuilder = Widget Function(BuildContext context);

/// Wraps an inserted or removed item in a transition.
typedef ItemTransitionBuilder =
    Widget Function(
      BuildContext context,
      Widget child,
      Animation<double> animation,
    );

/// Groups consecutive items into sections with (sticky) headers.
///
/// ```dart
/// sections: PerformanceSections<Contact, String>(
///   sectionOf: (c) => c.name[0],
///   headerBuilder: (context, letter, _) => PerformanceSectionHeader(title: letter),
/// ),
/// ```
@immutable
class PerformanceSections<T, S> {
  /// Sections keyed by [sectionOf]; a new section starts whenever the key
  /// changes from one item to the next.
  const PerformanceSections({
    required this.sectionOf,
    required this.headerBuilder,
    this.sticky = true,
  });

  /// The section of an item.
  final S Function(T item) sectionOf;

  /// Builds a section header. [firstIndex] is the section's first item.
  final Widget Function(BuildContext context, S section, int firstIndex)
  headerBuilder;

  /// Whether headers stay pinned while their section scrolls by.
  final bool sticky;

  Object? _keyOf(T item) => sectionOf(item);

  Widget _header(BuildContext context, Object? section, int firstIndex) =>
      headerBuilder(context, section as S, firstIndex);
}

/// A default section header: an opaque bar with a title.
class PerformanceSectionHeader extends StatelessWidget {
  /// A header showing [title], and [trailing] on the end side.
  const PerformanceSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  /// The title.
  final String title;

  /// Shown on the end side, such as a count.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Material(
        color: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (trailing != null)
                DefaultTextStyle.merge(
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: trailing!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Layout { list, grid, masonry }

enum _Phase { content, firstLoading, firstError, empty }

/// A fast, lazily built list, grid or masonry grid with pagination,
/// pull-to-refresh, sticky sections and complete empty, loading, error and
/// end states.
///
/// Give it items in one of two ways:
/// * a [listController] — a [PagingController] for infinite scrolling, or a
///   [PerformanceListController] for a local list. Appending a page, or
///   updating one item, rebuilds only what changed;
/// * a plain [items] list with [onEndReached], [isLoading], [hasError] and
///   [hasMore], as in 0.x.
///
/// Loading more is triggered from scroll metrics after layout, never from
/// the item builder. It fires once per load, also when the first page does
/// not fill the viewport, and never while loading, after an error (until
/// retry) or after the last page.
class PerformanceListView<T> extends StatefulWidget {
  /// A vertical (or [scrollDirection]) list.
  ///
  /// Give [itemExtent] or [prototypeItem] when all items have the same
  /// extent: layout then skips measuring. [separatorBuilder] adds separators
  /// between items.
  const PerformanceListView({
    super.key,
    this.items = const [],
    this.listController,
    required this.itemBuilder,
    this.itemKey,
    this.onRefresh,
    this.onEndReached,
    this.isLoading = false,
    this.hasError = false,
    this.hasMore = true,
    this.error,
    this.onRetry,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.bottomLoaderBuilder,
    this.endOfListBuilder,
    this.firstPageErrorBuilder,
    this.loadMoreErrorBuilder,
    this.skeletonBuilder,
    this.skeletonCount = 8,
    this.separatorBuilder,
    this.sections,
    this.physics,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.headerSlivers,
    this.footerSlivers,
    this.itemExtent,
    this.prototypeItem,
    this.cacheExtent,
    this.scrollCacheExtent,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.addSemanticIndexes = true,
    this.scrollThreshold = 3,
    this.loadMoreExtent,
    this.loadMoreDebounce = Duration.zero,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.pullToRefresh = true,
    this.animateChanges = false,
    this.animationDuration = const Duration(milliseconds: 280),
    this.itemTransitionBuilder,
    this.dragStartBehavior = DragStartBehavior.start,
    this.restorationId,
  }) : _layout = _Layout.list,
       gridDelegate = null,
       crossAxisCount = null,
       maxCrossAxisExtent = null,
       mainAxisSpacing = 0,
       crossAxisSpacing = 0,
       assert(
         itemExtent == null || prototypeItem == null,
         'Pass itemExtent or prototypeItem, not both.',
       ),
       assert(
         separatorBuilder == null ||
             (itemExtent == null && prototypeItem == null),
         'Separators need items to be measured: drop itemExtent and prototypeItem.',
       ),
       assert(
         !animateChanges || (sections == null && separatorBuilder == null),
         'animateChanges supports plain lists only.',
       );

  /// A grid laid out by [gridDelegate].
  const PerformanceListView.grid({
    super.key,
    this.items = const [],
    this.listController,
    required this.itemBuilder,
    required SliverGridDelegate this.gridDelegate,
    this.itemKey,
    this.onRefresh,
    this.onEndReached,
    this.isLoading = false,
    this.hasError = false,
    this.hasMore = true,
    this.error,
    this.onRetry,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.bottomLoaderBuilder,
    this.endOfListBuilder,
    this.firstPageErrorBuilder,
    this.loadMoreErrorBuilder,
    this.skeletonBuilder,
    this.skeletonCount = 8,
    this.sections,
    this.physics,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.headerSlivers,
    this.footerSlivers,
    this.cacheExtent,
    this.scrollCacheExtent,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.addSemanticIndexes = true,
    this.scrollThreshold = 6,
    this.loadMoreExtent,
    this.loadMoreDebounce = Duration.zero,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.pullToRefresh = true,
    this.dragStartBehavior = DragStartBehavior.start,
    this.restorationId,
  }) : _layout = _Layout.grid,
       itemExtent = null,
       prototypeItem = null,
       separatorBuilder = null,
       crossAxisCount = null,
       maxCrossAxisExtent = null,
       mainAxisSpacing = 0,
       crossAxisSpacing = 0,
       animateChanges = false,
       animationDuration = Duration.zero,
       itemTransitionBuilder = null;

  /// A masonry (staggered) grid: items keep their own height and fill the
  /// shortest column. Give [crossAxisCount], or [maxCrossAxisExtent] for a
  /// column count that adapts to the width.
  const PerformanceListView.masonry({
    super.key,
    this.items = const [],
    this.listController,
    required this.itemBuilder,
    this.crossAxisCount,
    this.maxCrossAxisExtent,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.itemKey,
    this.onRefresh,
    this.onEndReached,
    this.isLoading = false,
    this.hasError = false,
    this.hasMore = true,
    this.error,
    this.onRetry,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.bottomLoaderBuilder,
    this.endOfListBuilder,
    this.firstPageErrorBuilder,
    this.loadMoreErrorBuilder,
    this.skeletonBuilder,
    this.skeletonCount = 8,
    this.sections,
    this.physics,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.headerSlivers,
    this.footerSlivers,
    this.cacheExtent,
    this.scrollCacheExtent,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.addSemanticIndexes = true,
    this.scrollThreshold = 6,
    this.loadMoreExtent,
    this.loadMoreDebounce = Duration.zero,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.pullToRefresh = true,
    this.dragStartBehavior = DragStartBehavior.start,
    this.restorationId,
  }) : _layout = _Layout.masonry,
       gridDelegate = null,
       itemExtent = null,
       prototypeItem = null,
       separatorBuilder = null,
       animateChanges = false,
       animationDuration = Duration.zero,
       itemTransitionBuilder = null,
       assert(
         (crossAxisCount == null) != (maxCrossAxisExtent == null),
         'Pass exactly one of crossAxisCount and maxCrossAxisExtent.',
       );

  final _Layout _layout;

  /// The items, when there is no [listController]. Rebuild the widget after
  /// changing them.
  final List<T> items;

  /// Owns the items and, for a [PagingController], loads them. Takes
  /// precedence over [items].
  final PerformanceListController<T>? listController;

  /// Builds each item.
  final ItemBuilder<T> itemBuilder;

  /// A stable identity for an item, such as its id. With it, item state
  /// (text fields, animations, keep-alives) follows the item when items are
  /// inserted or removed before it.
  final Object? Function(T item)? itemKey;

  /// Called by pull-to-refresh. Defaults to [PagingController.refresh] with
  /// a [listController].
  final RefreshCallback? onRefresh;

  /// Called to load the next page when [items] is used. If it returns a
  /// future, no further call happens until it completes.
  final FutureOr<void> Function()? onEndReached;

  /// With [items]: whether a page is loading.
  final bool isLoading;

  /// With [items]: whether the last load failed.
  final bool hasError;

  /// With [items]: whether more pages exist. False stops [onEndReached] and
  /// shows the end footer.
  final bool hasMore;

  /// With [items]: the error of the last load, passed to the error builders.
  final Object? error;

  /// With [items]: called by the retry buttons. Defaults to [onEndReached].
  final VoidCallback? onRetry;

  /// Shown when there are no items.
  final StateBuilder? emptyBuilder;

  /// Shown while the first page loads, instead of skeletons.
  final StateBuilder? loadingBuilder;

  /// Shown when the first page failed, instead of [firstPageErrorBuilder].
  final StateBuilder? errorBuilder;

  /// The footer while a further page loads.
  final StateBuilder? bottomLoaderBuilder;

  /// The footer after the last page. Defaults to [PerformanceEndFooter] for
  /// paginated lists.
  final StateBuilder? endOfListBuilder;

  /// Shown when the first page failed, with the error and a retry callback.
  final ErrorStateBuilder? firstPageErrorBuilder;

  /// The footer when a further page failed, with the error and a retry
  /// callback.
  final ErrorStateBuilder? loadMoreErrorBuilder;

  /// Builds the placeholders shown while the first page loads. Defaults to
  /// shimmering [SkeletonListTile]s, or [SkeletonCard]s in grids.
  final IndexedWidgetBuilder? skeletonBuilder;

  /// How many placeholders to show while the first page loads.
  final int skeletonCount;

  /// Builds the separator after the item at the index. List layout only.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Groups items into sections with sticky headers.
  final PerformanceSections<T, Object?>? sections;

  /// Scroll physics. Always scrollable, so pull-to-refresh works on short
  /// lists; the platform's default feel otherwise.
  final ScrollPhysics? physics;

  /// The scroll controller. One is created (and disposed) when null.
  final ScrollController? controller;

  /// Padding around the items.
  final EdgeInsetsGeometry padding;

  /// Slivers before the items, such as a [SliverAppBar].
  final List<Widget>? headerSlivers;

  /// Slivers after the items and the footer.
  final List<Widget>? footerSlivers;

  /// The extent of every item, for the fastest layout.
  final double? itemExtent;

  /// A widget with the extent of every item, for fast layout.
  final Widget? prototypeItem;

  /// How many pixels outside the viewport to build ahead.
  final double? cacheExtent;

  /// How much to build ahead, in pixels or viewports. Overrides
  /// [cacheExtent].
  final ScrollCacheExtent? scrollCacheExtent;

  /// Whether each item gets a [RepaintBoundary].
  final bool addRepaintBoundaries;

  /// Whether items may keep themselves alive off screen with
  /// [AutomaticKeepAliveClientMixin]. Items that do not ask are disposed off
  /// screen, so long lists use constant memory.
  final bool addAutomaticKeepAlives;

  /// Whether items get semantic indexes, so screen readers announce
  /// "item 3 of 20".
  final bool addSemanticIndexes;

  /// Loads the next page once an item this close to the last one is laid
  /// out (the cache extent counts).
  final int scrollThreshold;

  /// Loads the next page once the content after the viewport is shorter than
  /// this. Defaults to 60% of the viewport.
  final double? loadMoreExtent;

  /// The least time between two automatic loads.
  final Duration loadMoreDebounce;

  /// See [ScrollView.keyboardDismissBehavior].
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// See [ScrollView.clipBehavior].
  final Clip clipBehavior;

  /// The scroll axis.
  final Axis scrollDirection;

  /// Whether the list starts at the bottom (or end). For chat, prefer
  /// [PerformanceChatView].
  final bool reverse;

  /// See [ScrollView.shrinkWrap]. Slower: lays out every item.
  final bool shrinkWrap;

  /// Whether pull-to-refresh is on when there is a refresh handler.
  final bool pullToRefresh;

  /// Animates inserts and removals made through [listController].
  final bool animateChanges;

  /// The duration of insert and remove animations.
  final Duration animationDuration;

  /// The insert and remove transition. Defaults to size and fade.
  final ItemTransitionBuilder? itemTransitionBuilder;

  /// See [ScrollView.dragStartBehavior].
  final DragStartBehavior dragStartBehavior;

  /// See [ScrollView.restorationId].
  final String? restorationId;

  /// The grid layout, for [PerformanceListView.grid].
  final SliverGridDelegate? gridDelegate;

  /// Masonry columns, for [PerformanceListView.masonry].
  final int? crossAxisCount;

  /// Widest masonry column, for [PerformanceListView.masonry].
  final double? maxCrossAxisExtent;

  /// Space between masonry items of a column.
  final double mainAxisSpacing;

  /// Space between masonry columns.
  final double crossAxisSpacing;

  /// Whether this is a grid or masonry grid.
  bool get isGrid => _layout != _Layout.list;

  @override
  State<PerformanceListView<T>> createState() => _PerformanceListViewState<T>();
}

/// Adapts the 0.x props (items, isLoading, hasError, hasMore,
/// onEndReached) to the controller interface the view reads, and guards
/// [PerformanceListView.onEndReached]:
/// * it is called once, then not again until the parent reacts (items,
///   hasError or hasMore change), its future completes, or the user drags;
/// * a load that ends without new items stalls auto-loading, so an endpoint
///   that returns nothing is not called in a loop;
/// * while its future is pending the list counts as loading, even if the
///   parent never sets isLoading.
class _PropsController<T> extends PerformanceListController<T> {
  _PropsController(this._state);

  final _PerformanceListViewState<T> _state;
  bool _pending = false;
  bool _waiting = false;
  bool _stalled = false;
  int _lengthAtCall = -1;
  int _calls = 0;

  PerformanceListView<T> get _w => _state.widget;

  bool get stalled => _stalled;

  void sync(List<T> items) => setItemsSilently(items);

  @override
  bool get isPaginated => _w.onEndReached != null;

  @override
  bool get hasMore => _w.hasMore && _w.onEndReached != null;

  @override
  Object? get error => _w.hasError ? _w.error : null;

  @override
  PagingStatus get status {
    final empty = _w.items.isEmpty;
    if (_w.isLoading || _pending) {
      return empty ? PagingStatus.loadingFirstPage : PagingStatus.loadingMore;
    }
    if (_w.hasError) {
      return empty ? PagingStatus.firstPageError : PagingStatus.loadMoreError;
    }
    if (!hasMore) return PagingStatus.completed;
    return PagingStatus.idle;
  }

  bool get canAutoLoad => status == PagingStatus.idle && !_waiting && !_stalled;

  void didUpdate(PerformanceListView<T> old) {
    final w = _w;
    if (old.items.length != w.items.length ||
        old.hasError != w.hasError ||
        old.hasMore != w.hasMore) {
      _waiting = false;
      _stalled = false;
    } else if (old.isLoading && !w.isLoading && !_pending) {
      // A load the parent tracked finished without new items.
      _waiting = false;
      _stalled = w.items.length == _lengthAtCall;
    }
  }

  void userScrolled() {
    if (_pending) return;
    _waiting = false;
    _stalled = false;
  }

  Future<void> _invoke(FutureOr<void> Function() fn) {
    _waiting = true;
    _lengthAtCall = _w.items.length;
    final call = ++_calls;
    final result = fn();
    if (result is! Future<void>) return Future<void>.value();
    _pending = true;
    _state._propsChanged();
    return result.whenComplete(() {
      if (call != _calls || !_state.mounted) return;
      _pending = false;
      _waiting = false;
      _stalled = _w.items.length == _lengthAtCall && !_w.hasError;
      _state._propsChanged();
    });
  }

  @override
  Future<void> loadMore() {
    final onEnd = _w.onEndReached;
    if (onEnd == null || !canAutoLoad) return Future<void>.value();
    return _invoke(onEnd);
  }

  @override
  Future<void> retry() {
    _stalled = false;
    _waiting = false;
    final onRetry = _w.onRetry;
    if (onRetry != null) {
      onRetry();
      return Future<void>.value();
    }
    final onEnd = _w.onEndReached;
    return onEnd == null ? Future<void>.value() : _invoke(onEnd);
  }

  @override
  Future<void> refresh() {
    _stalled = false;
    _waiting = false;
    return _w.onRefresh?.call() ?? Future<void>.value();
  }
}

class _PerformanceListViewState<T> extends State<PerformanceListView<T>>
    implements ListViewAttachment {
  late _PropsController<T> _props = _PropsController<T>(this);
  ScrollController? _ownScroll;
  final Map<int, ItemWidgetCache> _caches = <int, ItemWidgetCache>{};
  KeyIndex<T>? _keyIndex;
  final Map<Key, (Object?, int)> _seenKeys = <Key, (Object?, int)>{};
  _Phase _phase = _Phase.empty;
  int _layoutRevision = 0;
  int _lastLaidOut = -1;
  bool _checkScheduled = false;
  Duration? _lastLoadAt;
  Timer? _debounce;
  int _scrollEpoch = 0;
  List<_Section>? _sectionsCache;
  GlobalKey<SliverAnimatedListState> _animatedKey =
      GlobalKey<SliverAnimatedListState>();
  final GlobalKey _scrollKey = GlobalKey();
  late final FrameCallback _postFrame = _onPostFrame;

  PerformanceListController<T> get _src => widget.listController ?? _props;
  ScrollController get _scroll =>
      widget.controller ?? (_ownScroll ??= ScrollController());
  List<T> get _items => _src.items;

  @override
  void initState() {
    super.initState();
    if (widget.listController == null) _props.sync(widget.items);
    _subscribe(_src);
    _phase = _computePhase();
    _scheduleLoadCheck();
  }

  @override
  void didUpdateWidget(PerformanceListView<T> old) {
    super.didUpdateWidget(old);
    if (old.listController != widget.listController) {
      _unsubscribe(old.listController ?? _props);
      if (widget.listController == null) _props = _PropsController<T>(this);
      _subscribe(_src);
      _invalidateAll();
    }
    if (old.controller != widget.controller) {
      if (widget.controller != null) {
        _ownScroll?.dispose();
        _ownScroll = null;
      }
    }
    if (widget.listController == null) {
      // Props: the items may have changed in place, and the builder closure
      // may capture new state. Rebuild what is on screen, like ListView.
      _props
        ..didUpdate(old)
        ..sync(widget.items);
      _invalidateAll();
    } else if (old.itemBuilder != widget.itemBuilder ||
        old.itemKey != widget.itemKey ||
        old.separatorBuilder != widget.separatorBuilder ||
        old.sections != widget.sections) {
      // A new builder closure may render differently.
      _invalidateAll();
    }
    if (old.itemKey != widget.itemKey) _keyIndex = null;
    _phase = _computePhase();
    _scheduleLoadCheck();
  }

  @override
  void dispose() {
    _scrollEpoch++;
    _debounce?.cancel();
    _unsubscribe(_src);
    _props.dispose();
    _ownScroll?.dispose();
    super.dispose();
  }

  void _subscribe(PerformanceListController<T> c) {
    c.itemsListenable.addListener(_onItems);
    c.statusListenable.addListener(_onStatus);
    c.addChangeListener(_onChange);
    if (c != _props) c.attachView(this);
  }

  void _unsubscribe(PerformanceListController<T> c) {
    if (c.isDisposed) return;
    c.itemsListenable.removeListener(_onItems);
    c.statusListenable.removeListener(_onStatus);
    c.removeChangeListener(_onChange);
    c.detachView(this);
  }

  void _invalidateAll() {
    for (final cache in _caches.values) {
      cache.clear();
    }
    _keyIndex?.invalidate();
    _sectionsCache = null;
  }

  void _onChange(ListChange<T> change) {
    final appended =
        change.kind == ListChangeKind.insert &&
        change.index + change.count == _items.length;
    if (!appended) {
      _keyIndex?.invalidate();
      _layoutRevision++;
    }
    _sectionsCache = null;
    switch (change.kind) {
      case ListChangeKind.update:
        final separated =
            widget.separatorBuilder != null && widget._layout == _Layout.list;
        for (final entry in _caches.entries) {
          final local = change.index - entry.key;
          if (local >= 0) entry.value.remove(separated ? local * 2 : local);
        }
      case ListChangeKind.reset:
        _invalidateAll();
        _lastLaidOut = -1;
        _animatedKey = GlobalKey<SliverAnimatedListState>();
      case ListChangeKind.insert:
        _animated?.insertAllItems(
          change.index,
          change.count,
          duration: _motion(widget.animationDuration),
        );
      case ListChangeKind.remove:
        final state = _animated;
        if (state != null) {
          for (var i = 0; i < change.removed.length; i++) {
            final item = change.removed[i];
            final index = change.index;
            state.removeItem(
              index,
              (context, animation) => _transition(
                context,
                widget.itemBuilder(context, item, index) ??
                    const SizedBox.shrink(),
                animation,
              ),
              duration: _motion(widget.animationDuration),
            );
          }
        }
    }
  }

  SliverAnimatedListState? get _animated =>
      widget.animateChanges ? _animatedKey.currentState : null;

  void _onItems() {
    if (!mounted) return;
    setState(() => _phase = _computePhase());
    _scheduleLoadCheck();
  }

  void _onStatus() {
    if (!mounted) return;
    final phase = _computePhase();
    // The footer listens on its own; rebuild the view only for a new phase.
    if (phase != _phase) setState(() => _phase = phase);
    _scheduleLoadCheck();
  }

  void _propsChanged() {
    if (!mounted) return;
    setState(() => _phase = _computePhase());
    _scheduleLoadCheck();
  }

  _Phase _computePhase() {
    final s = _src;
    if (s.items.isNotEmpty) return _Phase.content;
    if (s is _PropsController<T> && s.stalled && !s.isLoading) {
      return _Phase.empty;
    }
    return switch (s.status) {
      PagingStatus.loadingFirstPage ||
      PagingStatus.refreshing => _Phase.firstLoading,
      PagingStatus.firstPageError ||
      PagingStatus.loadMoreError => _Phase.firstError,
      PagingStatus.loadingMore => _Phase.firstLoading,
      PagingStatus.idle =>
        s.isPaginated && s.hasMore ? _Phase.firstLoading : _Phase.empty,
      PagingStatus.completed => _Phase.empty,
    };
  }

  Duration _motion(Duration d) =>
      PerformanceListThemeData.of(context).reduceMotion ? Duration.zero : d;

  // ---------------------------------------------------------------- loading

  void _scheduleLoadCheck() {
    if (_checkScheduled || !mounted) return;
    _checkScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback(_postFrame)
      ..ensureVisualUpdate();
  }

  void _onPostFrame(Duration timeStamp) {
    _checkScheduled = false;
    _maybeLoadMore(timeStamp);
  }

  bool get _canAutoLoad {
    final s = _src;
    if (s is _PropsController<T>) return s.isPaginated && s.canAutoLoad;
    return s.isPaginated && s.hasMore && s.status == PagingStatus.idle;
  }

  void _maybeLoadMore(Duration now) {
    if (!mounted || !_canAutoLoad) return;
    if (_items.isNotEmpty) {
      final scroll = _scroll;
      if (!scroll.hasClients) return;
      final pos = scroll.position;
      if (!pos.hasContentDimensions || !pos.hasViewportDimension) return;
      final extent = widget.loadMoreExtent ?? pos.viewportDimension * 0.6;
      final nearEnd =
          pos.extentAfter <= extent ||
          (_lastLaidOut >= 0 &&
              _lastLaidOut >= _items.length - 1 - widget.scrollThreshold);
      if (!nearEnd) return;
    }
    final debounce = widget.loadMoreDebounce;
    final last = _lastLoadAt;
    if (debounce > Duration.zero && last != null && now - last < debounce) {
      _debounce?.cancel();
      _debounce = Timer(debounce - (now - last), _scheduleLoadCheck);
      return;
    }
    _lastLoadAt = now;
    _src.loadMore();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      // A new drag after an onEndReached that changed nothing: allow again.
      _props.userScrolled();
    }
    if (n is ScrollUpdateNotification ||
        n is ScrollEndNotification ||
        n is OverscrollNotification) {
      _scheduleLoadCheck();
    }
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification n) {
    if (n.depth == 0) _scheduleLoadCheck();
    return false;
  }

  void _onLayout(int base, int first, int last, bool separated) {
    final lastItem = base + (separated ? last ~/ 2 : last);
    if (lastItem > _lastLaidOut || base == 0) _lastLaidOut = lastItem;
  }

  Future<void> _refresh() {
    if (widget.onRefresh != null) return widget.onRefresh!();
    return _src.refresh();
  }

  void _retry() => _src.retry();

  // ---------------------------------------------------------- scroll-to-index

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
    return scrollToItem(
      position: () => _scroll.position,
      root: () => _scrollKey.currentContext?.findRenderObject(),
      isCurrent: () => mounted && epoch == _scrollEpoch && _scroll.hasClients,
      index: index,
      alignment: alignment,
      offset: offset,
      duration: _motion(duration),
      curve: curve,
    );
  }

  // ----------------------------------------------------------------- building

  Widget _buildItem(BuildContext context, int index) {
    final item = _items[index];
    final child =
        widget.itemBuilder(context, item, index) ?? const SizedBox.shrink();
    final key = child.key;
    if (widget.itemKey == null && key != null) {
      // Remember which item a builder-provided key belongs to, so the item's
      // state can follow it when items are inserted before it.
      if (_seenKeys.length > 4096) _seenKeys.clear();
      _seenKeys[key] = (item, index);
    }
    return wrapItem(child, index, widget.itemKey?.call(item));
  }

  int? _indexOfSeen(Key key) {
    final seen = _seenKeys[key];
    if (seen == null) return null;
    final (item, last) = seen;
    final items = _items;
    // Items usually move by a few places; look near the last index first.
    for (var d = 0; d <= 64; d++) {
      final a = last + d;
      if (a < items.length && identical(items[a], item)) return a;
      final b = last - d;
      if (d > 0 && b >= 0 && b < items.length && identical(items[b], item)) {
        return b;
      }
    }
    for (var i = 0; i < items.length; i++) {
      if (identical(items[i], item)) return i;
    }
    return null;
  }

  Widget _transition(
    BuildContext context,
    Widget child,
    Animation<double> animation,
  ) {
    final custom = widget.itemTransitionBuilder;
    if (custom != null) return custom(context, child, animation);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return SizeTransition(
      sizeFactor: curved,
      axis: widget.scrollDirection,
      child: FadeTransition(opacity: curved, child: child),
    );
  }

  int? _findChildIndex(Key key, int base, int count, bool separated) {
    final keyOf = widget.itemKey;
    final index = keyOf == null
        ? _indexOfSeen(key)
        : (_keyIndex ??= KeyIndex<T>(
            keyOf,
          )).indexOf(key is ValueKey ? key.value as Object : key, _items);
    if (index == null || index < base || index >= base + count) return null;
    final local = index - base;
    return separated ? local * 2 : local;
  }

  Widget _itemsSliver(int base, int count) =>
      RelayoutOnCount(childCount: count, sliver: _rawItemsSliver(base, count));

  Widget _rawItemsSliver(int base, int count) {
    final cache = _caches.putIfAbsent(base, ItemWidgetCache.new);
    final separated =
        widget.separatorBuilder != null && widget._layout == _Layout.list;
    final delegate = CachingItemDelegate(
      separated
          ? (context, slot) {
              final i = base + slot ~/ 2;
              if (slot.isOdd) return widget.separatorBuilder!(context, i);
              return _buildItem(context, i);
            }
          : (context, slot) => _buildItem(context, base + slot),
      cache: cache,
      itemOf: separated
          ? (slot) => slot.isOdd ? notAnItem : _items[base + slot ~/ 2]
          : (slot) => _items[base + slot],
      childCount: separated ? (count == 0 ? 0 : count * 2 - 1) : count,
      findChildIndexCallback: (key) =>
          _findChildIndex(key, base, count, separated),
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
      addSemanticIndexes: widget.addSemanticIndexes,
      semanticIndexCallback: separated
          ? (_, slot) => slot.isEven ? slot ~/ 2 : null
          : (_, slot) => slot,
      semanticIndexOffset: base,
      onLayout: (first, last) => _onLayout(base, first, last, separated),
    );
    switch (widget._layout) {
      case _Layout.list:
        if (widget.itemExtent != null) {
          return SliverFixedExtentList(
            itemExtent: widget.itemExtent!,
            delegate: delegate,
          );
        }
        if (widget.prototypeItem != null) {
          return SliverPrototypeExtentList(
            prototypeItem: widget.prototypeItem!,
            delegate: delegate,
          );
        }
        return SliverList(delegate: delegate);
      case _Layout.grid:
        return SliverGrid(
          gridDelegate: widget.gridDelegate!,
          delegate: delegate,
        );
      case _Layout.masonry:
        return SliverMasonryGrid(
          delegate: delegate,
          crossAxisCount: widget.crossAxisCount,
          maxCrossAxisExtent: widget.maxCrossAxisExtent,
          mainAxisSpacing: widget.mainAxisSpacing,
          crossAxisSpacing: widget.crossAxisSpacing,
          layoutRevision: _layoutRevision,
        );
    }
  }

  Widget _animatedSliver() {
    return RelayoutOnCount(
      childCount: _items.length,
      sliver: _rawAnimatedSliver(),
    );
  }

  Widget _rawAnimatedSliver() {
    return SliverAnimatedList(
      key: _animatedKey,
      initialItemCount: _items.length,
      findChildIndexCallback: (key) =>
          _findChildIndex(key, 0, _items.length, false),
      itemBuilder: (context, index, animation) {
        Widget child = _buildItem(context, index);
        if (widget.addRepaintBoundaries) child = RepaintBoundary(child: child);
        return _transition(context, child, animation);
      },
    );
  }

  List<_Section> _sections() {
    final cached = _sectionsCache;
    if (cached != null) return cached;
    final spec = widget.sections!;
    final items = _items;
    final out = <_Section>[];
    Object? key;
    for (var i = 0; i < items.length; i++) {
      final k = spec._keyOf(items[i]);
      if (out.isEmpty || k != key) {
        out.add(_Section(k, i));
        key = k;
      }
      out.last.count++;
    }
    return _sectionsCache = out;
  }

  List<Widget> _contentSlivers(BuildContext context) {
    final spec = widget.sections;
    if (spec == null) {
      return [
        widget.animateChanges
            ? _animatedSliver()
            : _itemsSliver(0, _items.length),
      ];
    }
    final sections = _sections();
    final live = <int>{};
    final slivers = <Widget>[];
    for (final s in sections) {
      live.add(s.start);
      final header = Builder(
        builder: (context) => spec._header(context, s.key, s.start),
      );
      slivers.add(
        SliverMainAxisGroup(
          slivers: [
            if (spec.sticky)
              PinnedHeaderSliver(child: header)
            else
              SliverToBoxAdapter(child: header),
            _itemsSliver(s.start, s.count),
          ],
        ),
      );
    }
    _caches.removeWhere((start, _) => !live.contains(start));
    return slivers;
  }

  Widget _skeletonSliver(BuildContext context) {
    Widget skeleton(BuildContext context, int i) {
      final custom = widget.skeletonBuilder;
      final Widget w = custom != null
          ? custom(context, i)
          : switch (widget._layout) {
              _Layout.list =>
                widget.itemExtent != null
                    ? SkeletonListTile(height: widget.itemExtent!, seed: i)
                    : SkeletonListTile(seed: i),
              _Layout.grid => SkeletonCard(seed: i),
              _Layout.masonry => SkeletonCard(
                seed: i,
                imageAspectRatio: const [0.75, 1.2, 0.9, 1.4, 0.8, 1.05][i % 6],
              ),
            };
      // One announcement for the whole placeholder list.
      return i == 0 ? w : ExcludeSemantics(child: w);
    }

    final delegate = SliverChildBuilderDelegate(
      skeleton,
      childCount: widget.skeletonCount,
      addAutomaticKeepAlives: false,
      addSemanticIndexes: false,
    );
    final sliver = switch (widget._layout) {
      _Layout.list =>
        widget.itemExtent != null
            ? SliverFixedExtentList(
                itemExtent: widget.itemExtent!,
                delegate: delegate,
              )
            : SliverList(delegate: delegate),
      _Layout.grid => SliverGrid(
        gridDelegate: widget.gridDelegate!,
        delegate: delegate,
      ),
      _Layout.masonry => SliverMasonryGrid(
        delegate: delegate,
        crossAxisCount: widget.crossAxisCount,
        maxCrossAxisExtent: widget.maxCrossAxisExtent,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
      ),
    };
    return SliverIgnorePointer(
      sliver: SliverPadding(padding: widget.padding, sliver: sliver),
    );
  }

  List<Widget> _bodySlivers(BuildContext context) {
    switch (_phase) {
      case _Phase.firstLoading:
        if (widget.loadingBuilder != null) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: widget.loadingBuilder!(context),
            ),
          ];
        }
        return [_skeletonSliver(context)];
      case _Phase.firstError:
        final Widget child;
        if (widget.errorBuilder != null) {
          child = widget.errorBuilder!(context);
        } else if (widget.firstPageErrorBuilder != null) {
          child = widget.firstPageErrorBuilder!(context, _src.error, _retry);
        } else {
          child = PerformanceErrorView(error: _src.error, onRetry: _retry);
        }
        return [SliverFillRemaining(hasScrollBody: false, child: child)];
      case _Phase.empty:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child:
                widget.emptyBuilder?.call(context) ??
                const PerformanceEmptyView(),
          ),
        ];
      case _Phase.content:
        final content = widget.sections == null
            ? _contentSlivers(context).single
            : SliverMainAxisGroup(slivers: _contentSlivers(context));
        return [
          // One sliver fewer to lay out per frame when there is no padding.
          if (widget.padding == EdgeInsets.zero)
            content
          else
            SliverPadding(padding: widget.padding, sliver: content),
          SliverToBoxAdapter(
            child: _Footer<T>(
              controller: _src,
              loader: widget.bottomLoaderBuilder,
              end: widget.endOfListBuilder,
              loadMoreError: widget.loadMoreErrorBuilder,
              onRetry: _retry,
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final cacheExtent =
        widget.scrollCacheExtent ??
        (widget.cacheExtent != null
            ? ScrollCacheExtent.pixels(widget.cacheExtent!)
            : null);
    Widget view = CustomScrollView(
      key: _scrollKey,
      controller: _scroll,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      scrollCacheExtent: cacheExtent,
      semanticChildCount: _phase == _Phase.content ? _items.length : 0,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      clipBehavior: widget.clipBehavior,
      dragStartBehavior: widget.dragStartBehavior,
      restorationId: widget.restorationId,
      slivers: [
        ...?widget.headerSlivers,
        ..._bodySlivers(context),
        ...?widget.footerSlivers,
      ],
    );
    view = NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: view,
      ),
    );
    final canRefresh =
        widget.onRefresh != null ||
        (widget.listController?.isPaginated ?? false);
    if (widget.pullToRefresh &&
        canRefresh &&
        !widget.reverse &&
        widget.scrollDirection == Axis.vertical) {
      view = RefreshIndicator.adaptive(onRefresh: _refresh, child: view);
    }
    return view;
  }
}

class _Section {
  _Section(this.key, this.start);
  final Object? key;
  final int start;
  int count = 0;
}

class _Footer<T> extends StatelessWidget {
  const _Footer({
    required this.controller,
    required this.loader,
    required this.end,
    required this.loadMoreError,
    required this.onRetry,
  });

  final PerformanceListController<T> controller;
  final StateBuilder? loader;
  final StateBuilder? end;
  final ErrorStateBuilder? loadMoreError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.statusListenable,
      builder: (context, _) {
        switch (controller.status) {
          case PagingStatus.loadingMore:
          case PagingStatus.loadingFirstPage:
            return loader?.call(context) ?? const PerformanceLoadingFooter();
          case PagingStatus.loadMoreError:
          case PagingStatus.firstPageError:
            return loadMoreError?.call(context, controller.error, onRetry) ??
                PerformanceErrorFooter(
                  error: controller.error,
                  onRetry: onRetry,
                );
          case PagingStatus.completed:
            if (end != null) return end!(context);
            return controller.isPaginated
                ? const PerformanceEndFooter()
                : const SizedBox.shrink();
          case PagingStatus.idle:
          case PagingStatus.refreshing:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
