import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

/// Where a list is in its loading lifecycle.
enum PagingStatus {
  /// Nothing is loading and more pages may exist.
  idle,

  /// The first page is loading and there are no items yet.
  loadingFirstPage,

  /// A further page is loading. Items are on screen.
  loadingMore,

  /// A refresh is loading the first page again. Old items stay on screen.
  refreshing,

  /// Loading the first page failed. Call [PagingController.retry].
  firstPageError,

  /// Loading a further page failed. Call [PagingController.retry].
  loadMoreError,

  /// The last page has been loaded.
  completed,
}

/// The kind of a [ListChange].
enum ListChangeKind {
  /// Items were inserted at [ListChange.index].
  insert,

  /// Items were removed at [ListChange.index].
  remove,

  /// The item at [ListChange.index] was replaced.
  update,

  /// The whole list was replaced.
  reset,
}

/// A structural change to a [PerformanceListController]'s items.
///
/// Animated lists and chat views use these to animate inserts and removals
/// and to keep their scroll anchor.
@immutable
class ListChange<T> {
  const ListChange._(this.kind, this.index, this.count, this.removed);

  /// What happened.
  final ListChangeKind kind;

  /// The first affected index.
  final int index;

  /// How many items were inserted, removed or updated.
  final int count;

  /// The removed items, for [ListChangeKind.remove] and the replaced item for
  /// [ListChangeKind.update]. Empty otherwise.
  final List<T> removed;

  @override
  String toString() => 'ListChange(${kind.name}, index: $index, count: $count)';
}

/// Signature for listeners of [PerformanceListController.addChangeListener].
typedef ListChangeListener<T> = void Function(ListChange<T> change);

/// One page returned by a [PageFetcher].
@immutable
class PageResult<K, T> {
  /// A page of [items]. Pass [nextPageKey] when another page exists.
  ///
  /// The page is the last one when [_isLastPage] is true, or when it is
  /// omitted and [nextPageKey] is null.
  const PageResult(this.items, {this.nextPageKey, this._isLastPage});

  /// A page followed by the page at [nextPageKey].
  const PageResult.next(this.items, K this.nextPageKey) : _isLastPage = false;

  /// The final page.
  const PageResult.last(this.items) : nextPageKey = null, _isLastPage = true;

  /// The items of this page, in display order.
  final List<T> items;

  /// The key of the following page.
  final K? nextPageKey;

  final bool? _isLastPage;

  /// Whether no page follows this one.
  bool get isLastPage => _isLastPage ?? nextPageKey == null;
}

/// Loads the page at [pageKey].
typedef PageFetcher<K, T> = FutureOr<PageResult<K, T>> Function(K pageKey);

/// Owns the items of a [PerformanceListView] or [PerformanceChatView].
///
/// Mutations notify only the views that show the items, and each one
/// rebuilds only the item that changed: appending a page never rebuilds the
/// items already on screen. A view attached to the controller also gives it
/// [scrollToIndex].
///
/// Use [PagingController] to load the items page by page.
class PerformanceListController<T> extends ChangeNotifier {
  /// A controller holding [initialItems].
  PerformanceListController({Iterable<T> initialItems = const []})
    : _items = List<T>.of(initialItems);

  List<T> _items;
  UnmodifiableListView<T>? _view;
  bool _disposed = false;
  int _revision = 0;
  final _ChangeNotifier _itemsNotifier = _ChangeNotifier();
  final _ChangeNotifier _statusNotifier = _ChangeNotifier();
  final List<ListChangeListener<T>> _changeListeners =
      <ListChangeListener<T>>[];
  ListViewAttachment? _attachment;

  /// The items, read-only. Mutate them with the methods of this controller.
  List<T> get items => _view ??= UnmodifiableListView<T>(_items);

  /// The number of items.
  int get length => _items.length;

  /// Whether there are no items.
  bool get isEmpty => _items.isEmpty;

  /// Whether there is at least one item.
  bool get isNotEmpty => _items.isNotEmpty;

  /// The item at [index].
  T operator [](int index) => _items[index];

  /// Increases on every change to the items. Views use it to tell whether a
  /// cached item widget is still current.
  int get revision => _revision;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  /// Notifies when the items change, but not when only the status changes.
  Listenable get itemsListenable => _itemsNotifier;

  /// Notifies when the loading status changes, but not when only the items
  /// change.
  Listenable get statusListenable => _statusNotifier;

  /// The loading status. A plain controller is always [PagingStatus.completed].
  PagingStatus get status => PagingStatus.completed;

  /// Whether the items are loaded page by page.
  bool get isPaginated => false;

  /// Whether more pages may exist.
  bool get hasMore => false;

  /// The error of the last failed load, if the status is an error.
  Object? get error => null;

  /// Whether a page is loading.
  bool get isLoading =>
      status == PagingStatus.loadingFirstPage ||
      status == PagingStatus.loadingMore ||
      status == PagingStatus.refreshing;

  /// Loads the next page. Does nothing on a plain controller.
  Future<void> loadMore() => Future<void>.value();

  /// Retries the failed load. Does nothing on a plain controller.
  Future<void> retry() => Future<void>.value();

  /// Reloads from the first page. Does nothing on a plain controller.
  Future<void> refresh() => Future<void>.value();

  /// Adds [items] after the last item.
  void addAll(Iterable<T> items) => insertAll(_items.length, items);

  /// Adds [item] after the last item.
  void add(T item) => insertAll(_items.length, <T>[item]);

  /// Adds [items] before the first item. In a [PerformanceChatView] index 0 is
  /// the newest message, so this adds new messages.
  void prependAll(Iterable<T> items) => insertAll(0, items);

  /// Adds [item] before the first item.
  void prepend(T item) => insertAll(0, <T>[item]);

  /// Inserts [item] at [index].
  void insert(int index, T item) => insertAll(index, <T>[item]);

  /// Inserts [items] at [index].
  void insertAll(int index, Iterable<T> items) {
    _checkNotDisposed();
    final list = items is List<T> ? items : List<T>.of(items);
    if (list.isEmpty) return;
    RangeError.checkValueInInterval(index, 0, _items.length, 'index');
    _items.insertAll(index, list);
    _emit(ListChange<T>._(ListChangeKind.insert, index, list.length, const []));
  }

  /// Removes the item at [index] and returns it.
  T removeAt(int index) {
    _checkNotDisposed();
    final removed = _items.removeAt(index);
    _emit(ListChange<T>._(ListChangeKind.remove, index, 1, <T>[removed]));
    return removed;
  }

  /// Removes the first occurrence of [item]. Returns whether it was found.
  bool remove(T item) {
    final index = _items.indexOf(item);
    if (index < 0) return false;
    removeAt(index);
    return true;
  }

  /// Removes every item that satisfies [test], from the last to the first.
  void removeWhere(bool Function(T item) test) {
    _checkNotDisposed();
    for (var i = _items.length - 1; i >= 0; i--) {
      if (test(_items[i])) removeAt(i);
    }
  }

  /// Replaces the item at [index] with [item]. Only that item rebuilds.
  void updateAt(int index, T item) {
    _checkNotDisposed();
    final old = _items[index];
    _items[index] = item;
    _emit(ListChange<T>._(ListChangeKind.update, index, 1, <T>[old]));
  }

  /// Replaces the first item that satisfies [test] with `update(item)`.
  /// Returns whether an item matched.
  bool updateWhere(bool Function(T item) test, T Function(T item) update) {
    for (var i = 0; i < _items.length; i++) {
      if (test(_items[i])) {
        updateAt(i, update(_items[i]));
        return true;
      }
    }
    return false;
  }

  /// Rebuilds the item at [index], for items that were mutated in place.
  void markItemChanged(int index) => updateAt(index, _items[index]);

  /// Replaces every item.
  void replaceAll(Iterable<T> items) {
    _checkNotDisposed();
    _items = List<T>.of(items);
    _view = null;
    _emit(ListChange<T>._(ListChangeKind.reset, 0, _items.length, const []));
  }

  /// Removes every item.
  void clear() => replaceAll(const []);

  /// Calls [listener] for every structural change, before listeners are
  /// notified.
  void addChangeListener(ListChangeListener<T> listener) =>
      _changeListeners.add(listener);

  /// Stops calling [listener].
  void removeChangeListener(ListChangeListener<T> listener) =>
      _changeListeners.remove(listener);

  /// Scrolls the attached view until the item at [index] is visible, at
  /// [alignment] (0 = leading edge, 1 = trailing edge), [offset] pixels
  /// further from the leading edge (for example below a pinned header).
  ///
  /// Works for items that are not built yet: the view jumps to an estimate,
  /// measures and corrects. Animates unless [duration] is zero or the
  /// platform asks for reduced motion. Completes when the item is on screen,
  /// or right away if no view is attached.
  Future<void> scrollToIndex(
    int index, {
    double alignment = 0,
    double offset = 0,
    Duration duration = const Duration(milliseconds: 350),
    Curve curve = Curves.easeOutCubic,
  }) {
    final attachment = _attachment;
    if (attachment == null || index < 0 || index >= _items.length) {
      return Future<void>.value();
    }
    return attachment.scrollToIndex(index, alignment, offset, duration, curve);
  }

  /// Like [scrollToIndex] without animation.
  Future<void> jumpToIndex(
    int index, {
    double alignment = 0,
    double offset = 0,
  }) => scrollToIndex(
    index,
    alignment: alignment,
    offset: offset,
    duration: Duration.zero,
  );

  /// Connects a view, for [scrollToIndex]. The views of this package call
  /// it; apps do not need to.
  void attachView(ListViewAttachment attachment) => _attachment = attachment;

  /// Disconnects [attachment] if it is the attached view.
  void detachView(ListViewAttachment attachment) {
    if (identical(_attachment, attachment)) _attachment = null;
  }

  /// Replaces the items without emitting a change. For subclasses.
  @protected
  void setItemsSilently(List<T> items) {
    _items = items;
    _view = null;
    _revision++;
  }

  void _emit(ListChange<T> change) {
    _revision++;
    for (final listener in List<ListChangeListener<T>>.of(_changeListeners)) {
      listener(change);
    }
    _itemsNotifier.notify();
    notifyListeners();
  }

  /// Notifies status listeners. For subclasses.
  @protected
  void notifyStatusChanged() {
    if (_disposed) return;
    _statusNotifier.notify();
    notifyListeners();
  }

  void _checkNotDisposed() {
    assert(!_disposed, 'A $runtimeType was used after being disposed.');
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _changeListeners.clear();
    _attachment = null;
    _itemsNotifier.dispose();
    _statusNotifier.dispose();
    super.dispose();
  }
}

/// What a view gives its [PerformanceListController]. Implemented by the
/// views of this package.
abstract interface class ListViewAttachment {
  /// See [PerformanceListController.scrollToIndex].
  Future<void> scrollToIndex(
    int index,
    double alignment,
    double offset,
    Duration duration,
    Curve curve,
  );
}

/// Loads a list page by page, for infinite scrolling.
///
/// ```dart
/// final controller = PagingController<int, Post>(
///   firstPageKey: 1,
///   fetchPage: (page) async {
///     final posts = await api.posts(page: page, limit: 20);
///     return PageResult(posts, nextPageKey: posts.length < 20 ? null : page + 1);
///   },
/// );
/// ```
///
/// The controller guarantees that:
/// * only one load runs at a time, and [loadMore] calls during a load are
///   ignored;
/// * a response that arrives after [refresh], [reset] or [dispose] is
///   dropped, so stale pages never mix into fresh data;
/// * a thrown error, or a [fetchTimeout], ends the load with an error
///   status instead of leaving the list loading forever;
/// * after an error nothing loads until [retry] is called, so a failing
///   endpoint is not hammered;
/// * an empty page that points at the same key again ends the list instead
///   of looping.
class PagingController<K, T> extends PerformanceListController<T> {
  /// A controller that loads pages from [_fetchPage], starting at
  /// [firstPageKey].
  PagingController({
    required this.firstPageKey,
    required this._fetchPage,
    this.fetchTimeout,
    super.initialItems,
  }) : _nextPageKey = firstPageKey;

  /// A controller for numbered pages of [pageSize] items. A page shorter than
  /// [pageSize] is the last one.
  static PagingController<int, T> byPage<T>({
    required FutureOr<List<T>> Function(int page, int pageSize) fetch,
    int pageSize = 20,
    int firstPage = 1,
    Duration? fetchTimeout,
  }) {
    return PagingController<int, T>(
      firstPageKey: firstPage,
      fetchTimeout: fetchTimeout,
      fetchPage: (page) async {
        final items = await fetch(page, pageSize);
        return PageResult<int, T>(
          items,
          nextPageKey: items.length < pageSize ? null : page + 1,
        );
      },
    );
  }

  /// A controller for cursor-based pages. [fetch] gets null for the first
  /// page and returns the next cursor, or null after the last page.
  static PagingController<String?, T> byCursor<T>({
    required FutureOr<(List<T> items, String? nextCursor)> Function(
      String? cursor,
    )
    fetch,
    Duration? fetchTimeout,
  }) {
    return PagingController<String?, T>(
      firstPageKey: null,
      fetchTimeout: fetchTimeout,
      fetchPage: (cursor) async {
        final (items, next) = await fetch(cursor);
        return PageResult<String?, T>(
          items,
          nextPageKey: next,
          isLastPage: next == null,
        );
      },
    );
  }

  /// The key of the first page, used by [refresh] and [reset].
  final K firstPageKey;

  /// Fails a load that takes longer than this. Null waits forever.
  final Duration? fetchTimeout;

  final PageFetcher<K, T> _fetchPage;
  PagingStatus _status = PagingStatus.idle;
  K? _nextPageKey;
  bool _hasMore = true;
  Object? _error;
  StackTrace? _stackTrace;
  Object? _refreshError;
  int _generation = 0;
  Future<void>? _inFlight;
  Future<void>? _refreshInFlight;
  int _pagesLoaded = 0;

  @override
  PagingStatus get status => _status;

  @override
  bool get isPaginated => true;

  @override
  bool get hasMore => _hasMore;

  @override
  Object? get error => _error;

  /// The stack trace of [error].
  StackTrace? get stackTrace => _stackTrace;

  /// The error of the last failed [refresh] that kept the old items, if the
  /// items have not been refreshed since.
  Object? get refreshError => _refreshError;

  /// The key the next [loadMore] will fetch, or null after the last page.
  K? get nextPageKey => _hasMore ? _nextPageKey : null;

  /// How many pages have loaded since the first page.
  int get pagesLoaded => _pagesLoaded;

  /// Whether [loadMore] would start a load now.
  bool get canLoadMore =>
      !isDisposed && _hasMore && _status == PagingStatus.idle;

  /// Loads the next page, unless a load is running, the last page has
  /// loaded or the previous load failed. Returns the running load, if any.
  @override
  Future<void> loadMore() {
    if (_inFlight != null) return _inFlight!;
    if (!canLoadMore) return Future<void>.value();
    return _start(refresh: false);
  }

  /// Retries after [PagingStatus.firstPageError] or
  /// [PagingStatus.loadMoreError].
  @override
  Future<void> retry() {
    if (_status != PagingStatus.firstPageError &&
        _status != PagingStatus.loadMoreError) {
      return loadMore();
    }
    _setStatus(PagingStatus.idle);
    return loadMore();
  }

  /// Loads the first page again, superseding any running load.
  ///
  /// With [keepItems] the old items stay on screen until the new first page
  /// replaces them. If that fails they stay, with [refreshError] set.
  /// Concurrent calls share one load.
  @override
  Future<void> refresh({bool keepItems = true}) {
    if (_refreshInFlight != null) return _refreshInFlight!;
    if (isDisposed) return Future<void>.value();
    if (!keepItems && isNotEmpty) {
      setItemsSilently(<T>[]);
      _emitReset();
    }
    final future = _start(refresh: true);
    _refreshInFlight = future;
    return future;
  }

  /// Clears the items and errors and starts over from [firstPageKey]. The
  /// first page loads when a view asks for it, or on [loadMore].
  void reset() {
    if (isDisposed) return;
    _generation++;
    _inFlight = null;
    _refreshInFlight = null;
    _nextPageKey = firstPageKey;
    _hasMore = true;
    _error = null;
    _stackTrace = null;
    _refreshError = null;
    _pagesLoaded = 0;
    _status = PagingStatus.idle;
    if (isNotEmpty) {
      setItemsSilently(<T>[]);
      _emitReset();
    }
    notifyStatusChanged();
  }

  Future<void> _start({required bool refresh}) {
    final generation = ++_generation;
    final key = refresh ? firstPageKey : _nextPageKey as K;
    _error = null;
    _stackTrace = null;
    _setStatus(
      isEmpty
          ? PagingStatus.loadingFirstPage
          : refresh
          ? PagingStatus.refreshing
          : PagingStatus.loadingMore,
    );
    final completer = Completer<void>();
    _inFlight = completer.future;
    _run(generation, key, refresh).whenComplete(() {
      if (generation == _generation) {
        _inFlight = null;
        if (refresh) _refreshInFlight = null;
      }
      completer.complete();
    });
    return completer.future;
  }

  Future<void> _run(int generation, K key, bool refresh) async {
    PageResult<K, T> page;
    try {
      var result = _fetchPage(key);
      if (result is Future<PageResult<K, T>> && fetchTimeout != null) {
        result = result.timeout(fetchTimeout!);
      }
      page = await result;
    } catch (error, stackTrace) {
      if (_isStale(generation)) return;
      if (refresh && isNotEmpty) {
        _refreshError = error;
        _setStatus(_hasMore ? PagingStatus.idle : PagingStatus.completed);
        return;
      }
      _error = error;
      _stackTrace = stackTrace;
      _setStatus(
        isEmpty ? PagingStatus.firstPageError : PagingStatus.loadMoreError,
      );
      return;
    }
    if (_isStale(generation)) return;

    final repeatsKey =
        page.items.isEmpty && !page.isLastPage && page.nextPageKey == key;
    _hasMore = !page.isLastPage && !repeatsKey;
    _nextPageKey = page.isLastPage ? null : page.nextPageKey;
    _refreshError = null;
    if (refresh) {
      _pagesLoaded = 1;
      setItemsSilently(List<T>.of(page.items));
      _status = _hasMore ? PagingStatus.idle : PagingStatus.completed;
      _emitReset();
      notifyStatusChanged();
    } else {
      _pagesLoaded++;
      _status = _hasMore ? PagingStatus.idle : PagingStatus.completed;
      if (page.items.isNotEmpty) addAll(page.items);
      notifyStatusChanged();
    }
  }

  bool _isStale(int generation) => isDisposed || generation != _generation;

  void _emitReset() =>
      _emit(ListChange<T>._(ListChangeKind.reset, 0, length, const []));

  void _setStatus(PagingStatus status) {
    if (_status == status) return;
    _status = status;
    notifyStatusChanged();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}

class _ChangeNotifier extends ChangeNotifier {
  bool _disposed = false;

  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
