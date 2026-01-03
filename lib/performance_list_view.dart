import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A robust, high-performance list wrapper with built-in pagination,
/// error handling, grid support, and pull-to-refresh.
class PerformanceListView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onEndReached;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;
  final Widget? emptyBuilder;
  final Widget? loadingBuilder;
  final Widget? errorBuilder;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;

  // Grid specific
  final bool isGrid;
  final SliverGridDelegate? gridDelegate;

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
    this.physics,
    this.controller,
    this.padding = EdgeInsets.zero,
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
    this.physics,
    this.controller,
    this.padding = EdgeInsets.zero,
  }) : isGrid = true;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && !isLoading && !hasError) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: Stack(
          children: [
            ListView(
                physics:
                    const AlwaysScrollableScrollPhysics()), // Ensures pull-to-refresh works on empty
            Center(
              child: emptyBuilder ??
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No items found",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: controller,
        physics: physics ?? const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: padding,
            sliver: isGrid
                ? SliverPerformanceGrid<T>(
                    items: items,
                    itemBuilder: itemBuilder,
                    gridDelegate: gridDelegate!,
                    onEndReached: onEndReached,
                    isLoading: isLoading,
                    hasError: hasError,
                    onRetry: onRetry,
                  )
                : SliverPerformanceListView<T>(
                    items: items,
                    itemBuilder: itemBuilder,
                    onEndReached: onEndReached,
                    isLoading: isLoading,
                    hasError: hasError,
                    onRetry: onRetry,
                  ),
          ),
        ],
      ),
    );
  }
}

/// The Sliver implementation for use in CustomScrollViews
class SliverPerformanceListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Future<void> Function()? onEndReached;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;
  final double scrollThreshold;

  const SliverPerformanceListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onEndReached,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
    this.scrollThreshold = 200.0,
  });

  @override
  State<SliverPerformanceListView<T>> createState() =>
      _SliverPerformanceListViewState<T>();
}

class _SliverPerformanceListViewState<T>
    extends State<SliverPerformanceListView<T>> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Pagination Logic
          if (index >= widget.items.length - 1) {
            // Simple debouncing: only trigger if not already loading or error
            if (!widget.isLoading &&
                !widget.hasError &&
                widget.onEndReached != null) {
              // We use a microtask to avoid calling setState during build
              Future.microtask(() => widget.onEndReached!());
            }
          }

          // Loading / Error Indicator at the bottom
          if (index == widget.items.length) {
            return _buildBottomIndicator();
          }

          return RepaintBoundary(
            child: widget.itemBuilder(context, widget.items[index]),
          );
        },
        childCount: widget.items.length + 1, // +1 for the loader/error widget
      ),
    );
  }

  Widget _buildBottomIndicator() {
    if (widget.hasError) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ElevatedButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry loading"),
          ),
        ),
      );
    }
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    return const SizedBox.shrink();
  }
}

/// The Sliver Grid implementation
class SliverPerformanceGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final Future<void> Function()? onEndReached;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  const SliverPerformanceGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.gridDelegate,
    this.onEndReached,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Note: Pagination inside grids is trickier.
    // We append a full-width sliver at the end for the loader.
    // However, for simplicity in this package, we will rely on the parent ScrollView
    // to handle the "bottom" detection or use a specific footer sliver in the main CustomScrollView.
    // *Implementation Note:* For true grid pagination, it's best to check scroll offset
    // in the parent controller. For now, this renders the grid efficiently.

    return SliverGrid(
      gridDelegate: gridDelegate,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= items.length - 2 && !isLoading && !hasError) {
            Future.microtask(() => onEndReached?.call());
          }
          return RepaintBoundary(
            child: itemBuilder(context, items[index]),
          );
        },
        childCount: items.length,
      ),
    );
  }
}

/// A wrapper around CachedNetworkImage optimized for lists.
class PerformanceImage extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final double borderRadius;

  const PerformanceImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
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
        // Memory Optimization: Resize image to display size to save RAM
        memCacheHeight: height != null ? (height! * 2).toInt() : null,
        // Fade in effect
        fadeInDuration: const Duration(milliseconds: 200),
        // Placeholder
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(child: Icon(Icons.image, color: Colors.grey)),
        ),
        // Error
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[100],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }
}
