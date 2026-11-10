// Internals shared by PerformanceListView and PerformanceChatView. Not
// exported.
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Remembers the widget built for each slot of one sliver, so a rebuild of
/// the sliver (for example after a page is appended) hands Flutter the
/// identical widget and the item does not rebuild at all.
///
/// An entry is reused only while the slot still shows the identical item.
class ItemWidgetCache {
  final HashMap<int, _Entry> _entries = HashMap<int, _Entry>();

  Widget? lookup(int slot, Object? item) {
    final e = _entries[slot];
    if (e == null || !identical(e.item, item)) return null;
    return e.widget;
  }

  void store(int slot, Object? item, Widget widget) {
    final e = _entries[slot];
    if (e == null) {
      _entries[slot] = _Entry(item, widget);
    } else {
      e
        ..item = item
        ..widget = widget;
    }
  }

  void remove(int slot) => _entries.remove(slot);

  void clear() => _entries.clear();

  /// Forgets slots far outside [first]..[last]. Amortized: runs only when
  /// the cache holds twice as many entries as the laid-out range.
  void prune(int first, int last) {
    final span = last - first + 1;
    if (_entries.length <= span * 2 + 32) return;
    final lo = first - span;
    final hi = last + span;
    _entries.removeWhere((slot, _) => slot < lo || slot > hi);
  }

  int get length => _entries.length;
}

class _Entry {
  _Entry(this.item, this.widget);
  Object? item;
  Widget widget;
}

/// Returned by [CachingItemDelegate.itemOf] for slots that are not items,
/// such as separators. They are never cached.
const Object notAnItem = _NotAnItem();

class _NotAnItem {
  const _NotAnItem();
}

/// A [SliverChildBuilderDelegate] that reuses cached item widgets and
/// reports what it laid out.
class CachingItemDelegate extends SliverChildBuilderDelegate {
  CachingItemDelegate(
    super.builder, {
    required this.cache,
    required this.itemOf,
    required super.childCount,
    super.findChildIndexCallback,
    super.addAutomaticKeepAlives,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
    super.semanticIndexCallback,
    super.semanticIndexOffset,
    this.onLayout,
  });

  final ItemWidgetCache cache;

  /// The item shown in a slot, or [notAnItem].
  final Object? Function(int slot) itemOf;

  /// Called with the first and last laid-out slots after every layout.
  final void Function(int first, int last)? onLayout;

  @override
  Widget? build(BuildContext context, int index) {
    if (index < 0 || (childCount != null && index >= childCount!)) return null;
    final item = itemOf(index);
    final cacheable = !identical(item, notAnItem);
    if (cacheable) {
      final hit = cache.lookup(index, item);
      if (hit != null) return hit;
    }
    final built = super.build(context, index);
    if (built != null && cacheable) cache.store(index, item, built);
    return built;
  }

  @override
  void didFinishLayout(int firstIndex, int lastIndex) {
    cache.prune(firstIndex, lastIndex);
    onLayout?.call(firstIndex, lastIndex);
  }
}

/// Marks the render box of the item at [index], so [findItemRenderBox] can
/// find it for scroll-to-index.
class IndexMarker extends SingleChildRenderObjectWidget {
  const IndexMarker({super.key, required this.index, required super.child});

  final int index;

  @override
  RenderIndexMarker createRenderObject(BuildContext context) =>
      RenderIndexMarker(index);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderIndexMarker renderObject,
  ) {
    renderObject.index = index;
  }
}

class RenderIndexMarker extends RenderProxyBox {
  RenderIndexMarker(this.index);
  int index;
}

/// Visits the laid-out, painted item markers below [root].
void visitMarkers(
  RenderObject root,
  void Function(RenderIndexMarker marker) visit,
) {
  void walk(RenderObject node) {
    if (node is RenderIndexMarker) {
      if (node.hasSize) visit(node);
      return;
    }
    if (node is RenderSliverMultiBoxAdaptor) {
      // Skip kept-alive children: they are not on screen.
      var child = node.firstChild;
      while (child != null) {
        if (node.paintsChild(child)) walk(child);
        child = node.childAfter(child);
      }
      return;
    }
    node.visitChildren(walk);
  }

  walk(root);
}

RenderIndexMarker? findItemRenderBox(RenderObject root, int index) {
  RenderIndexMarker? found;
  visitMarkers(root, (m) {
    if (m.index == index) found = m;
  });
  return found;
}

/// Scrolls [position] until the item at [index] (searched below [root]) is
/// revealed at [alignment]. Unbuilt items are reached by estimating their
/// offset from the items on screen, then correcting.
Future<void> scrollToItem({
  required ScrollPosition Function() position,
  required RenderObject? Function() root,
  required bool Function() isCurrent,
  required int index,
  required double alignment,
  required double offset,
  required Duration duration,
  required Curve curve,
}) async {
  var animated = false;
  for (var attempt = 0; attempt < 16; attempt++) {
    if (!isCurrent()) return;
    final pos = position();
    final r = root();
    if (r == null || !r.attached || !pos.hasContentDimensions) return;
    final marker = findItemRenderBox(r, index);
    if (marker != null) {
      final viewport = RenderAbstractViewport.maybeOf(marker);
      if (viewport == null) return;
      final target =
          (viewport.getOffsetToReveal(marker, alignment).offset - offset).clamp(
            pos.minScrollExtent,
            pos.maxScrollExtent,
          );
      if ((target - pos.pixels).abs() < 0.5) return;
      if (duration == Duration.zero) {
        pos.jumpTo(target);
      } else {
        final far = (target - pos.pixels).abs() > pos.viewportDimension * 1.5;
        await pos.animateTo(
          target,
          duration: animated && far ? duration ~/ 2 : duration,
          curve: curve,
        );
        animated = true;
      }
      await SchedulerBinding.instance.endOfFrame;
      continue;
    }
    final estimate = _estimate(r, index, pos);
    if (estimate == null) return;
    if (duration != Duration.zero && !animated) {
      animated = true;
      await pos.animateTo(estimate, duration: duration, curve: curve);
    } else {
      pos.jumpTo(estimate);
    }
    await SchedulerBinding.instance.endOfFrame;
  }
}

double? _estimate(RenderObject root, int index, ScrollPosition pos) {
  var minIndex = -1;
  var maxIndex = -1;
  double minOffset = 0;
  double maxOffset = 0;
  double extent = 0;
  visitMarkers(root, (m) {
    final viewport = RenderAbstractViewport.maybeOf(m);
    if (viewport == null) return;
    final offset = viewport.getOffsetToReveal(m, 0).offset;
    if (minIndex < 0 || m.index < minIndex) {
      minIndex = m.index;
      minOffset = offset;
      extent = pos.axis == Axis.vertical ? m.size.height : m.size.width;
    }
    if (maxIndex < 0 || m.index > maxIndex) {
      maxIndex = m.index;
      maxOffset = offset;
    }
  });
  if (minIndex < 0) return null;
  final perIndex = maxIndex > minIndex
      ? (maxOffset - minOffset) / (maxIndex - minIndex)
      : math.max(extent, 1.0);
  final anchorIndex = index < minIndex ? minIndex : maxIndex;
  final anchorOffset = index < minIndex ? minOffset : maxOffset;
  // Step at most a few viewports per attempt, so estimates refine as the
  // real extents come into view.
  final raw = anchorOffset + (index - anchorIndex) * perIndex;
  final limit = pos.viewportDimension * 8;
  final step = (raw - pos.pixels).clamp(-limit, limit);
  return (pos.pixels + step).clamp(pos.minScrollExtent, pos.maxScrollExtent);
}

/// Wraps an item for a sliver: marker for scroll-to-index and the item key
/// for state preservation across inserts and removals.
Widget wrapItem(Widget child, int index, Object? key) {
  final keyed = key ?? child.key;
  Widget w = IndexMarker(index: index, child: child);
  if (keyed != null) {
    w = KeyedSubtree(
      key: keyed is Key ? keyed : ValueKey<Object>(keyed),
      child: w,
    );
  }
  return w;
}

/// Maps item keys to indices, for findChildIndexCallback. Rebuilt lazily
/// after changes; appends extend it in place.
class KeyIndex<T> {
  KeyIndex(this.keyOf);

  final Object? Function(T item) keyOf;
  Map<Object, int>? _map;
  int _indexed = 0;

  void invalidate() {
    _map = null;
    _indexed = 0;
  }

  int? indexOf(Object key, List<T> items) {
    var map = _map;
    if (map == null || _indexed > items.length) {
      map = _map = HashMap<Object, int>();
      _indexed = 0;
    }
    for (; _indexed < items.length; _indexed++) {
      final k = keyOf(items[_indexed]);
      if (k != null) map[k is ValueKey ? k.value as Object : k] = _indexed;
    }
    return map[key];
  }
}

/// Re-lays out [sliver] when [childCount] changes.
///
/// Cached items hand Flutter identical widgets, so after an append no child
/// is dirty and the list would keep its old scroll extent until the next
/// scroll. This marks it for layout, which is all an append needs.
class RelayoutOnCount extends SingleChildRenderObjectWidget {
  const RelayoutOnCount({
    super.key,
    required this.childCount,
    required Widget sliver,
  }) : super(child: sliver);

  final int childCount;

  @override
  RenderRelayoutOnCount createRenderObject(BuildContext context) =>
      RenderRelayoutOnCount(childCount);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderRelayoutOnCount renderObject,
  ) {
    if (renderObject.childCount != childCount) {
      renderObject.childCount = childCount;
      renderObject.child?.markNeedsLayout();
    }
  }
}

class RenderRelayoutOnCount extends RenderProxySliver {
  RenderRelayoutOnCount(this.childCount);
  int childCount;
}
