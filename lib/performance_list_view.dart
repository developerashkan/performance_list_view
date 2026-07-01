import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Function signature for building list items.
typedef ItemBuilder<T> = Widget? Function(BuildContext context, T item, int index);

/// Function signature for building state-based widgets (Loading, Error, Empty).
typedef StateBuilder = Widget Function(BuildContext context);

/// A highly optimized, production-ready list/grid wrapper for Flutter.
/// Designed for high performance with large datasets and smooth scrolling.
class PerformanceListView<T> extends StatelessWidget {
  /// The list of items to display.
  final List<T> items;

  /// Builder function to create a widget for each item.
  final ItemBuilder<T> itemBuilder;

  /// Callback triggered when the user pulls to refresh.
  final RefreshCallback onRefresh;

  /// Callback triggered when the list reaches the end (for pagination).
  final VoidCallback? onEndReached;

  /// Indicates if more items are currently being loaded.
  final bool isLoading;

  /// Indicates if an error occurred during the last fetch.
  final bool hasError;

  /// Callback for the "Retry" action in case of an error.
  final VoidCallback? onRetry;

  /// Custom widget to show when the list is empty.
  final StateBuilder? emptyBuilder;

  /// Custom widget to show while the initial list is loading.
  final StateBuilder? loadingBuilder;

  /// Custom widget to show when an error occurs and the list is empty.
  final StateBuilder? errorBuilder;

  /// Custom widget to show at the bottom while loading more items.
  final StateBuilder? bottomLoaderBuilder;

  /// Scroll physics for the list.
  final ScrollPhysics? physics;

  /// Controller for the scroll view.
  final ScrollController? controller;

  /// Padding around the list content.
  final EdgeInsetsGeometry padding;

  /// Slivers to display before the main list/grid.
  final List<Widget>? headerSlivers;

  /// Slivers to display after the main list/grid.
  final List<Widget>? footerSlivers;

  /// If true, renders a grid instead of a list.
  final bool isGrid;

  /// Delegate that controls the layout of children within the grid.
  final SliverGridDelegate? gridDelegate;

  /// Optional: A fixed height/width for all items to significantly improve performance.
  final double? itemExtent;

  /// Optional: A widget that has the same dimensions as the items, used for performance.
  final Widget? prototypeItem;

  /// How much content should be cached outside the visible area.
  final double? cacheExtent;

  /// Whether to wrap each child in a [RepaintBoundary].
  /// Defaults to true. Useful for complex items to avoid unnecessary repaints.
  final bool addRepaintBoundaries;

  /// Whether to wrap each child in an [AutomaticKeepAlive] widget.
  final bool addAutomaticKeepAlives;

  /// The number of items from the end to trigger [onEndReached].
  final int scrollThreshold;

  /// See [ScrollView.keyboardDismissBehavior]
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// See [ScrollView.clipBehavior]
  final Clip clipBehavior;

  const PerformanceListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onRefresh,
    this.onEndReached,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.bottomLoaderBuilder,
    this.physics,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.headerSlivers,
    this.footerSlivers,
    this.itemExtent,
    this.prototypeItem,
    this.cacheExtent,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.scrollThreshold = 2,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
  })  : isGrid = false,
        gridDelegate = null;

  const PerformanceListView.grid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onRefresh,
    required SliverGridDelegate this.gridDelegate,
    this.onEndReached,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.bottomLoaderBuilder,
    this.physics,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.headerSlivers,
    this.footerSlivers,
    this.cacheExtent,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.scrollThreshold = 2,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
  })  : isGrid = true,
        itemExtent = null,
        prototypeItem = null;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: controller,
        physics: physics ?? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        scrollCacheExtent: cacheExtent != null ? ScrollCacheExtent.pixels(cacheExtent!) : null,
        keyboardDismissBehavior: keyboardDismissBehavior,
        clipBehavior: clipBehavior,
        slivers: [
          if (headerSlivers != null) ...headerSlivers!,
          ..._buildMainContent(context),
          if (footerSlivers != null) ...footerSlivers!,
        ],
      ),
    );
  }

  List<Widget> _buildMainContent(BuildContext context) {
    if (items.isEmpty) {
      if (isLoading) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: loadingBuilder?.call(context) ??
                const Center(child: CircularProgressIndicator.adaptive()),
          )
        ];
      }
      if (hasError) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: errorBuilder?.call(context) ?? _DefaultErrorView(onRetry: onRetry, isFullScreen: true),
          )
        ];
      }
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: emptyBuilder?.call(context) ?? const _DefaultEmptyView(),
        )
      ];
    }

    return [
      SliverPadding(
        padding: padding,
        sliver: isGrid ? _buildGrid() : _buildList(),
      ),
      SliverToBoxAdapter(
        child: _buildBottomIndicator(context),
      ),
    ];
  }

  Widget _buildList() {
    if (itemExtent != null) {
      return SliverFixedExtentList(
        itemExtent: itemExtent!,
        delegate: _createDelegate(),
      );
    } else if (prototypeItem != null) {
      return SliverPrototypeExtentList(
        prototypeItem: prototypeItem!,
        delegate: _createDelegate(),
      );
    } else {
      return SliverList(delegate: _createDelegate());
    }
  }

  Widget _buildGrid() {
    return SliverGrid(
      gridDelegate: gridDelegate!,
      delegate: _createDelegate(),
    );
  }

  SliverChildBuilderDelegate _createDelegate() {
    return SliverChildBuilderDelegate(
      (context, index) {
        if (index >= items.length - scrollThreshold && !isLoading && !hasError && onEndReached != null) {
          Future.microtask(() => onEndReached!());
        }
        final item = items[index];
        final child = itemBuilder(context, item, index);
        if (child == null) return null;

        Widget wrappedChild = child;
        if (addRepaintBoundaries) {
          wrappedChild = RepaintBoundary(child: wrappedChild);
        }
        if (addAutomaticKeepAlives) {
          wrappedChild = _KeepAliveWrapper(child: wrappedChild);
        }
        return wrappedChild;
      },
      childCount: items.length,
      addRepaintBoundaries: false,
      addAutomaticKeepAlives: false,
    );
  }

  Widget _buildBottomIndicator(BuildContext context) {
    if (hasError) {
      return errorBuilder?.call(context) ?? _DefaultErrorView(onRetry: onRetry);
    }
    if (isLoading) {
      return bottomLoaderBuilder?.call(context) ??
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
    }
    return const SizedBox.shrink();
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class _DefaultEmptyView extends StatelessWidget {
  const _DefaultEmptyView();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "No data found",
            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _DefaultErrorView extends StatelessWidget {
  final VoidCallback? onRetry;
  final bool isFullScreen;

  const _DefaultErrorView({this.onRetry, this.isFullScreen = false});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        const SizedBox(height: 16),
        const Text("Something went wrong"),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text("Try Again"),
          ),
        ]
      ],
    );

    if (isFullScreen) {
      return Center(child: content);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: content,
    );
  }
}

/// A highly optimized image loader for lists.
class PerformanceImage extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final double borderRadius;
  final int? memCacheHeight;
  final int? memCacheWidth;
  final Map<String, String>? httpHeaders;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final ImageWidgetBuilder? imageBuilder;

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
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        height: height,
        width: width,
        fit: fit,
        httpHeaders: httpHeaders,
        memCacheHeight: memCacheHeight ?? (height != null ? (height! * 2).toInt() : null),
        memCacheWidth: memCacheWidth ?? (width != null ? (width! * 2).toInt() : null),
        fadeInDuration: const Duration(milliseconds: 250),
        fadeOutDuration: const Duration(milliseconds: 250),
        imageBuilder: imageBuilder,
        placeholder: placeholder ?? (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: errorWidget ?? (context, url, error) => Container(
          color: Colors.grey[100],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }
}
