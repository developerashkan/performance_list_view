import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance_list_view/performance_list_view.dart';

import 'helpers.dart';

double _h(int i) => 80.0 + (i * 53) % 120;

Widget _masonry({
  required List<int> items,
  int? columns = 2,
  double? maxExtent,
  ScrollController? scroll,
  PerformanceListController<int>? controller,
}) {
  return PerformanceListView<int>.masonry(
    items: items,
    listController: controller,
    controller: scroll,
    crossAxisCount: maxExtent == null ? columns : null,
    maxCrossAxisExtent: maxExtent,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    itemBuilder: (_, i, _) => SizedBox(height: _h(i), child: Text('M$i')),
  );
}

/// Replays the masonry rule: each item goes into the shortest column.
List<Offset> _expected(int n, int columns, double width) {
  final colW = (width - 8 * (columns - 1)) / columns;
  final ends = List<double>.filled(columns, 0);
  final used = List<bool>.filled(columns, false);
  final out = <Offset>[];
  for (var i = 0; i < n; i++) {
    var best = 0;
    var bestEnd = double.infinity;
    for (var c = 0; c < columns; c++) {
      final start = used[c] ? ends[c] + 8 : 0.0;
      if (start < bestEnd - 1e-10) {
        best = c;
        bestEnd = start;
      }
    }
    out.add(Offset(best * (colW + 8), bestEnd));
    ends[best] = bestEnd + _h(i);
    used[best] = true;
  }
  return out;
}

void main() {
  group('grid', () {
    testWidgets(
      'lays out by the grid delegate and shows card skeletons while loading',
      (tester) async {
        useSurface(tester);
        await tester.pumpWidget(
          host(
            PerformanceListView<int>.grid(
              items: List.generate(9, (i) => i),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemBuilder: (_, i, _) => Text('G$i'),
            ),
          ),
        );
        expect(tester.getTopLeft(find.text('G1')).dx, closeTo(400 / 3, 0.01));
        expect(tester.getTopLeft(find.text('G3')).dy, closeTo(400 / 3, 0.01));

        final c = PagingController<int, int>(
          firstPageKey: 1,
          fetchPage: (_) => Future.delayed(
            const Duration(seconds: 1),
            () => const PageResult.last([1]),
          ),
        );
        addTearDown(c.dispose);
        await tester.pumpWidget(
          host(
            PerformanceListView<int>.grid(
              listController: c,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              itemBuilder: (_, i, _) => Text('G$i'),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(SkeletonCard), findsWidgets);
        await tester.pump(const Duration(seconds: 2));
      },
    );
  });

  group('masonry', () {
    testWidgets('puts each item in the shortest column', (tester) async {
      useSurface(tester);
      await tester.pumpWidget(
        host(_masonry(items: List.generate(12, (i) => i))),
      );
      final expected = _expected(12, 2, 400);
      for (var i = 0; i < 12; i++) {
        final f = find.text('M$i');
        if (f.evaluate().isEmpty) continue; // below the viewport
        expect(
          tester.getTopLeft(f),
          offsetMoreOrLessEquals(expected[i], epsilon: 0.01),
          reason: 'M$i',
        );
      }
    });

    testWidgets('keeps placements when scrolling far down and back', (
      tester,
    ) async {
      useSurface(tester);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        host(
          _masonry(
            items: List.generate(300, (i) => i),
            columns: 3,
            scroll: scroll,
          ),
        ),
      );
      final expected = _expected(300, 3, 400);
      scroll.jumpTo(9000);
      await tester.pump();
      final visible = tester
          .widgetList<Text>(find.textContaining('M'))
          .map((t) => int.parse(t.data!.substring(1)));
      expect(visible, isNotEmpty);
      for (final i in visible.take(6)) {
        final top = tester.getTopLeft(find.text('M$i'));
        expect(top.dx, closeTo(expected[i].dx, 0.01));
        expect(top.dy, closeTo(expected[i].dy - 9000, 0.01), reason: 'M$i');
      }
      scroll.jumpTo(0);
      await tester.pump();
      expect(tester.getTopLeft(find.text('M0')), Offset.zero);
      // The scroll extent is exact once the end has been reached.
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      final ends = List<double>.filled(3, 0);
      for (var i = 0; i < 300; i++) {
        final c = (expected[i].dx / ((400 - 16) / 3 + 8)).round();
        ends[c] = expected[i].dy + _h(i);
      }
      final content = ends.reduce((a, b) => a > b ? a : b);
      expect(scroll.position.maxScrollExtent, closeTo(content - 800, 1));
    });

    testWidgets('maxCrossAxisExtent adapts the column count to the width', (
      tester,
    ) async {
      useSurface(tester, const Size(1000, 800));
      await tester.pumpWidget(
        host(_masonry(items: List.generate(10, (i) => i), maxExtent: 220)),
      );
      // ceil((1000 + 8) / (220 + 8)) = 5 columns.
      final xs = {
        for (var i = 0; i < 5; i++)
          tester.getTopLeft(find.text('M$i')).dx.round(),
      };
      expect(xs.length, 5);
    });

    testWidgets('mirrors columns in right-to-left layouts', (tester) async {
      useSurface(tester);
      await tester.pumpWidget(
        host(
          _masonry(items: List.generate(4, (i) => i)),
          direction: TextDirection.rtl,
        ),
      );
      final first = tester.getRect(
        find
            .ancestor(of: find.text('M0'), matching: find.byType(SizedBox))
            .first,
      );
      expect(first.right, closeTo(400, 0.01));
    });

    testWidgets('paginates', (tester) async {
      useSurface(tester);
      final c = PagingController<int, int>(
        firstPageKey: 0,
        fetchPage: (p) => PageResult(
          List.generate(6, (i) => p * 6 + i),
          nextPageKey: p < 3 ? p + 1 : null,
        ),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(host(_masonry(items: const [], controller: c)));
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
        await frames(tester, 3);
      }
      expect(c.length, 24);
      expect(c.status, PagingStatus.completed);
    });

    testWidgets('items whose height changes move the items after them', (
      tester,
    ) async {
      useSurface(tester);
      final heights = ValueNotifier<double>(100);
      addTearDown(heights.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<int>.masonry(
            items: const [0, 1, 2],
            crossAxisCount: 1,
            itemBuilder: (_, i, _) => i == 0
                ? ValueListenableBuilder<double>(
                    valueListenable: heights,
                    builder: (_, h, _) =>
                        SizedBox(height: h, child: const Text('M0')),
                  )
                : SizedBox(height: 50, child: Text('M$i')),
          ),
        ),
      );
      expect(tester.getTopLeft(find.text('M1')).dy, 100);
      heights.value = 160;
      await tester.pump();
      expect(tester.getTopLeft(find.text('M1')).dy, 160);
      expect(tester.getTopLeft(find.text('M2')).dy, 210);
    });
  });

  group('sections', () {
    final sections = PerformanceSections<int, int>(
      sectionOf: (i) => i ~/ 10,
      headerBuilder: (_, s, first) => SizedBox(
        height: 40,
        child: ColoredBox(
          color: Colors.white,
          child: Text('Section $s from $first'),
        ),
      ),
    );

    testWidgets('groups consecutive items and pins the current header', (
      tester,
    ) async {
      useSurface(tester);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            items: List.generate(50, (i) => i),
            controller: scroll,
            sections: sections,
            itemBuilder: (_, i, _) => Tile('Row $i', height: 50),
          ),
        ),
      );
      expect(find.text('Section 0 from 0'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Row 0')).dy, 40);
      // Into section 1 (starts at 40 + 500): its header is pinned at the top.
      scroll.jumpTo(40 + 500 + 40 + 120);
      await tester.pump();
      expect(tester.getTopLeft(find.text('Section 1 from 10')).dy, 0);
      expect(find.text('Section 0 from 0'), findsNothing);
      // Section 2's header pushes section 1's header up as it arrives.
      scroll.jumpTo(2 * 540 - 20);
      await tester.pump();
      expect(tester.getTopLeft(find.text('Section 1 from 10')).dy, lessThan(0));
    });

    testWidgets('non-sticky headers scroll away', (tester) async {
      useSurface(tester);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            items: List.generate(30, (i) => i),
            controller: scroll,
            sections: PerformanceSections<int, int>(
              sectionOf: (i) => i ~/ 10,
              sticky: false,
              headerBuilder: (_, s, _) =>
                  SizedBox(height: 40, child: Text('H$s')),
            ),
            itemBuilder: (_, i, _) => Tile('Row $i', height: 50),
          ),
        ),
      );
      scroll.jumpTo(200);
      await tester.pump();
      expect(find.text('H0'), findsNothing);
    });

    testWidgets('sections update as pages arrive and use a default header', (
      tester,
    ) async {
      useSurface(tester);
      final c = PerformanceListController<int>(
        initialItems: List.generate(5, (i) => i),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            listController: c,
            sections: PerformanceSections<int, int>(
              sectionOf: (i) => i ~/ 5,
              headerBuilder: (_, s, _) =>
                  PerformanceSectionHeader(title: 'Week $s'),
            ),
            itemBuilder: (_, i, _) => Tile('Row $i', height: 40),
          ),
        ),
      );
      expect(find.text('Week 1'), findsNothing);
      c.addAll(List.generate(5, (i) => i + 5));
      await tester.pump();
      expect(find.text('Week 1'), findsOneWidget);
      expect(find.byType(PerformanceSectionHeader), findsNWidgets(2));
    });
  });
}
