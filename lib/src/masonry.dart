import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A lazy masonry (staggered) grid sliver: children keep their own main-axis
/// extent and each one goes into the currently shortest column.
///
/// Only the children inside the viewport and its cache extent are built.
/// Placements are remembered, so scrolling back up does not re-measure. Bump
/// [layoutRevision] when items before the end are replaced, so the
/// remembered placements are dropped.
class SliverMasonryGrid extends SliverMultiBoxAdaptorWidget {
  /// A masonry grid with [crossAxisCount] columns, or as many columns of at
  /// most [maxCrossAxisExtent] as fit.
  const SliverMasonryGrid({
    super.key,
    required super.delegate,
    this.crossAxisCount,
    this.maxCrossAxisExtent,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.layoutRevision = 0,
  }) : assert(
         (crossAxisCount == null) != (maxCrossAxisExtent == null),
         'Pass exactly one of crossAxisCount and maxCrossAxisExtent.',
       );

  /// The number of columns.
  final int? crossAxisCount;

  /// The widest a column may be; the column count follows the width.
  final double? maxCrossAxisExtent;

  /// Space between children of a column.
  final double mainAxisSpacing;

  /// Space between columns.
  final double crossAxisSpacing;

  /// Changing it forgets every remembered placement.
  final int layoutRevision;

  @override
  RenderSliverMasonryGrid createRenderObject(BuildContext context) {
    return RenderSliverMasonryGrid(
      childManager: context as SliverMultiBoxAdaptorElement,
      crossAxisCount: crossAxisCount,
      maxCrossAxisExtent: maxCrossAxisExtent,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      layoutRevision: layoutRevision,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverMasonryGrid renderObject,
  ) {
    renderObject
      ..crossAxisCount = crossAxisCount
      ..maxCrossAxisExtent = maxCrossAxisExtent
      ..mainAxisSpacing = mainAxisSpacing
      ..crossAxisSpacing = crossAxisSpacing
      ..layoutRevision = layoutRevision;
  }
}

const double _epsilon = 1e-10;

class _Slot {
  _Slot(this.column, this.offset, this.extent);
  final int column;
  final double offset;
  double extent;
  double get end => offset + extent;
}

/// The render object of [SliverMasonryGrid].
class RenderSliverMasonryGrid extends RenderSliverMultiBoxAdaptor {
  /// Creates the render object. See [SliverMasonryGrid].
  RenderSliverMasonryGrid({
    required super.childManager,
    this._crossAxisCount,
    this._maxCrossAxisExtent,
    this._mainAxisSpacing = 0,
    this._crossAxisSpacing = 0,
    this._layoutRevision = 0,
  });

  int? _crossAxisCount;
  set crossAxisCount(int? v) {
    if (v == _crossAxisCount) return;
    _crossAxisCount = v;
    _reset();
  }

  double? _maxCrossAxisExtent;
  set maxCrossAxisExtent(double? v) {
    if (v == _maxCrossAxisExtent) return;
    _maxCrossAxisExtent = v;
    _reset();
  }

  double _mainAxisSpacing;
  set mainAxisSpacing(double v) {
    if (v == _mainAxisSpacing) return;
    _mainAxisSpacing = v;
    _reset();
  }

  double _crossAxisSpacing;
  set crossAxisSpacing(double v) {
    if (v == _crossAxisSpacing) return;
    _crossAxisSpacing = v;
    _reset();
  }

  int _layoutRevision;
  set layoutRevision(int v) {
    if (v == _layoutRevision) return;
    _layoutRevision = v;
    _reset();
  }

  // Placements of children 0 .. _slots.length - 1, in index order, and the
  // indices of each column (ascending, so their ends ascend too).
  final List<_Slot> _slots = <_Slot>[];
  List<List<int>> _columns = <List<int>>[];
  int _columnCount = 0;
  double _columnExtent = 0;

  void _reset() {
    _slots.clear();
    for (final c in _columns) {
      c.clear();
    }
    markNeedsLayout();
  }

  void _truncate(int from) {
    if (from >= _slots.length) return;
    _slots.removeRange(from, _slots.length);
    for (final c in _columns) {
      while (c.isNotEmpty && c.last >= from) {
        c.removeLast();
      }
    }
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverGridParentData) {
      child.parentData = SliverGridParentData();
    }
  }

  @override
  double childCrossAxisPosition(RenderBox child) =>
      (child.parentData! as SliverGridParentData).crossAxisOffset ?? 0;

  double _extentOf(RenderBox child) => switch (constraints.axis) {
    Axis.vertical => child.size.height,
    Axis.horizontal => child.size.width,
  };

  /// Where the next child of column [c] would start, counting only children
  /// up to [index].
  double _nextStartAfter(int c, int index) {
    final col = _columns[c];
    var lo = 0;
    var hi = col.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (col[mid] <= index) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo == 0 ? 0 : _slots[col[lo - 1]].end + _mainAxisSpacing;
  }

  /// Whether every child after [index] starts at or after [end]: each one
  /// goes into the shortest column, so none can start before the lowest
  /// column end.
  bool _restStartsAfter(int index, double end) {
    for (var c = 0; c < _columnCount; c++) {
      if (_nextStartAfter(c, index) < end) return false;
    }
    return true;
  }

  /// The smallest known index whose child ends after [offset], or the number
  /// of known placements.
  int _leadIndex(double offset) {
    var lead = _slots.length;
    for (final col in _columns) {
      var lo = 0;
      var hi = col.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (_slots[col[mid]].end <= offset) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      if (lo < col.length) lead = math.min(lead, col[lo]);
    }
    return lead;
  }

  void _place(RenderBox child, int index) {
    final extent = _extentOf(child);
    if (index < _slots.length) {
      final slot = _slots[index];
      if ((slot.extent - extent).abs() < _epsilon) {
        _applyParentData(child, slot);
        return;
      }
      // The child changed size: everything after it moves.
      _truncate(index + 1);
      slot.extent = extent;
      _applyParentData(child, slot);
      return;
    }
    assert(index == _slots.length, 'Masonry children are placed in order.');
    var best = 0;
    var bestEnd = double.infinity;
    for (var c = 0; c < _columnCount; c++) {
      final col = _columns[c];
      final end = col.isEmpty ? 0.0 : _slots[col.last].end + _mainAxisSpacing;
      if (end < bestEnd - _epsilon) {
        best = c;
        bestEnd = end;
      }
    }
    final slot = _Slot(best, bestEnd, extent);
    _slots.add(slot);
    _columns[best].add(index);
    _applyParentData(child, slot);
  }

  void _applyParentData(RenderBox child, _Slot slot) {
    final data = child.parentData! as SliverGridParentData;
    data.layoutOffset = slot.offset;
    final start = slot.column * (_columnExtent + _crossAxisSpacing);
    data.crossAxisOffset =
        axisDirectionIsReversed(constraints.crossAxisDirection)
        ? constraints.crossAxisExtent - start - _columnExtent
        : start;
  }

  double get _knownExtent {
    var end = 0.0;
    for (final col in _columns) {
      if (col.isNotEmpty) end = math.max(end, _slots[col.last].end);
    }
    return end;
  }

  @override
  void performLayout() {
    final c = constraints;
    childManager
      ..didStartLayout()
      ..setDidUnderflow(false);

    final cross = c.crossAxisExtent;
    final count =
        _crossAxisCount ??
        math.max(
          1,
          ((cross + _crossAxisSpacing) /
                  (_maxCrossAxisExtent! + _crossAxisSpacing))
              .ceil(),
        );
    final columnExtent = math.max(
      0.0,
      (cross - _crossAxisSpacing * (count - 1)) / count,
    );
    if (count != _columnCount ||
        (columnExtent - _columnExtent).abs() > _epsilon) {
      _columnCount = count;
      _columnExtent = columnExtent;
      _slots.clear();
      _columns = List<List<int>>.generate(count, (_) => <int>[]);
    }

    final childCount = childManager.childCount;
    if (_slots.length > childCount) _truncate(childCount);
    final scrollOffset = c.scrollOffset + c.cacheOrigin;
    final targetEnd = scrollOffset + c.remainingCacheExtent;
    final childConstraints = switch (c.axis) {
      Axis.vertical => BoxConstraints.tightFor(width: columnExtent),
      Axis.horizontal => BoxConstraints.tightFor(height: columnExtent),
    };

    if (childCount == 0) {
      collectGarbage(childCount, 0);
      geometry = SliverGeometry.zero;
      childManager.didFinishLayout();
      return;
    }

    final lead = math.min(_leadIndex(scrollOffset), childCount - 1);

    // Drop children before the lead, and every child when the first one is
    // past the known placements (they were forgotten).
    if (firstChild != null) {
      var leading = 0;
      var total = 0;
      RenderBox? child = firstChild;
      while (child != null) {
        if (indexOf(child) < lead) leading++;
        total++;
        child = childAfter(child);
      }
      if (leading > 0) collectGarbage(leading, 0);
      if (firstChild != null && indexOf(firstChild!) > _slots.length) {
        collectGarbage(total - leading, 0);
      }
    }

    if (firstChild == null) {
      final start = math.min(lead, _slots.length);
      if (!addInitialChild(
        index: start,
        layoutOffset: start < _slots.length ? _slots[start].offset : 0,
      )) {
        geometry = SliverGeometry.zero;
        childManager.didFinishLayout();
        return;
      }
      firstChild!.layout(childConstraints, parentUsesSize: true);
      _place(firstChild!, start);
    } else {
      firstChild!.layout(childConstraints, parentUsesSize: true);
      _place(firstChild!, indexOf(firstChild!));
    }

    // Fill backwards to the lead; those placements are known.
    while (indexOf(firstChild!) > lead) {
      final child = insertAndLayoutLeadingChild(
        childConstraints,
        parentUsesSize: true,
      );
      if (child == null) break;
      _place(child, indexOf(child));
    }

    // Walk forward until every later child would start past the cache area.
    var child = firstChild!;
    var index = indexOf(child);
    var reachedEnd = false;
    while (true) {
      if (index >= childCount - 1) {
        reachedEnd = true;
        break;
      }
      if (_restStartsAfter(index, targetEnd)) break;
      var next = childAfter(child);
      if (next == null || indexOf(next) != index + 1) {
        next = insertAndLayoutChild(
          childConstraints,
          after: child,
          parentUsesSize: true,
        );
        if (next == null) {
          reachedEnd = true;
          break;
        }
      } else {
        next.layout(childConstraints, parentUsesSize: true);
      }
      index++;
      _place(next, index);
      child = next;
      // While catching up through unmeasured children, keep only those that
      // reach the cache area.
      while (!identical(firstChild, child) &&
          _slots[indexOf(firstChild!)].end <= scrollOffset) {
        collectGarbage(1, 0);
      }
    }

    // Children after the walk are stale.
    var trailing = 0;
    var after = childAfter(child);
    while (after != null) {
      trailing++;
      after = childAfter(after);
    }
    collectGarbage(0, trailing);

    final known = _knownExtent;
    final double scrollExtent;
    if (reachedEnd && _slots.length >= childCount) {
      scrollExtent = known;
    } else {
      final average = _slots.isEmpty
          ? 0.0
          : (known * _columnCount) / _slots.length;
      scrollExtent =
          known + (childCount - _slots.length) * average / _columnCount;
    }
    final paintExtent = calculatePaintOffset(c, from: 0, to: scrollExtent);
    final cacheExtent = calculateCacheOffset(c, from: 0, to: scrollExtent);
    geometry = SliverGeometry(
      scrollExtent: scrollExtent,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: scrollExtent,
      hasVisualOverflow:
          scrollExtent > c.scrollOffset + c.remainingPaintExtent ||
          c.scrollOffset > 0,
    );
    if (reachedEnd && known < targetEnd) childManager.setDidUnderflow(true);
    childManager.didFinishLayout();
  }
}
