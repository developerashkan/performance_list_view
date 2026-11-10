## 1.0.0

A rewrite focused on correctness and speed. 0.x call sites keep compiling; see
**Migrating from 0.x** in the README for the few behavior changes.

### Fixed
* **Lazy loading no longer gets stuck or loops.** Loading more was a side
  effect of the item builder (`Future.microtask` per built item), which:
  * fired `onEndReached` several times per frame (2 concurrent loads when the
    first page was short);
  * fired again on every unrelated parent rebuild;
  * re-fired after every load that returned no items (about 10 calls a second);
  * never fired for an empty list, so a list waiting for its first page showed
    "No data found" forever;
  * never fired when an item builder returned null, because the list stopped
    at the null.

  Loading is now triggered from scroll metrics after layout: once per load,
  also when the first page does not fill the viewport, never while loading,
  after an error (until retry) or after the last page.
* Items that ask to be kept alive (`AutomaticKeepAliveClientMixin`) now stay
  alive. 0.0.5 built the list without `AutomaticKeepAlive`, so these requests,
  and its own keep-alive wrapper, did nothing.
* Item state follows its item when items are inserted before it
  (`findChildIndexCallback`, from `itemKey` or from keys your builder returns).
* A load-more error shows a footer with retry instead of the full-screen
  `errorBuilder`.
* `PerformanceImage` no longer throws for an unbounded width or height, and
  decodes at display size × device pixel ratio (it used a fixed × 2).
* The SDK constraint matches the APIs used (`ScrollCacheExtent` needs
  Flutter 3.44); 0.0.5 claimed Flutter 3.10.

### Added
* `PagingController`: page-number (`byPage`) or cursor (`byCursor`) loading
  with one load at a time, stale responses dropped after refresh, reset or
  dispose, error states with `retry()`, `refresh()` that keeps items on screen,
  `fetchTimeout`, and protection against empty pages that repeat a key.
* `PerformanceListController`: append, prepend, insert, remove, update and
  `scrollToIndex` / `jumpToIndex` (also for unbuilt items of varying height).
* Appending a page rebuilds **zero** items already on screen; updating one item
  rebuilds only that item.
* `PerformanceListView.masonry` (lazy staggered grid), sticky section headers
  (`PerformanceSections`), `separatorBuilder`, animated inserts and removals
  (`animateChanges`), reverse lists, horizontal lists, `loadMoreDebounce`.
* `PerformanceChatView` for chat and AI streaming: pinned to the newest
  message while replies stream in, stable while you read history, a
  jump-to-latest pill with an unread count, typing indicator and older history
  loading.
* `StreamingTextController` / `StreamingText` (rebuild one bubble per token),
  `TypingIndicator`, `ChatBubble`, `JumpToLatestPill`.
* Shimmer skeletons (`SkeletonListTile`, `SkeletonCard`, `SkeletonBubble`,
  `SkeletonBox`, `PerformanceShimmer`) that repaint without rebuilding.
* Default empty, error, loading and end views; `PerformanceListThemeData`
  theme extension with every color derived from the `ColorScheme` (light and
  dark) and replaceable texts for localization.
* Accessibility: semantic child counts, separators excluded from indexes,
  live-region loading footers, labeled buttons. Right-to-left layouts.
  Reduced motion stops shimmer, typing, cursor and scroll animations.
* A gallery example (feed, masonry, contacts, AI chat, error lab) and a
  benchmark against `ListView.builder` in `test/benchmark_test.dart`.

### Changed
* No more dependency on `cached_network_image`: the package is pure Flutter
  and runs on Android, iOS, web, macOS, Windows and Linux. Pass
  `imageProvider:` to `PerformanceImage` for a disk cache.
* `onRefresh` is optional; there is no refresh indicator without a handler.
* The default physics follow the platform (always scrollable) instead of
  bouncing everywhere.

## 0.0.5
* Switched to a sliver-based architecture using `CustomScrollView`.
* Added `headerSlivers` and `footerSlivers`.
* Added `itemBuilder`, `emptyBuilder`, `loadingBuilder`, `errorBuilder` and `bottomLoaderBuilder`.
* Added `RepaintBoundary` per item, `itemExtent` and `prototypeItem`.
* `PerformanceImage` gained `memCacheHeight` and `memCacheWidth`.

## 0.0.4
* Compatible with latest Dart version

## 0.0.3
* fix warnings

## 0.0.2
* add some improvements

## 0.0.1
* Initial release of `PerformanceListView`.
