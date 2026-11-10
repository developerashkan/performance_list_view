import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance_list_view/performance_list_view.dart';

import 'helpers.dart';

void main() {
  group('pagination', () {
    testWidgets(
      'shows skeletons, loads the first page, then fills the viewport',
      (tester) async {
        useSurface(tester);
        final api = FakeApi(auto: false);
        final c = api.controller();
        addTearDown(c.dispose);
        await tester.pumpWidget(
          host(
            PerformanceListView<String>(
              listController: c,
              itemBuilder: (_, s, _) => Tile(s),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(SkeletonListTile), findsWidgets);
        expect(api.requested, [1]);
        api.completeNext();
        await frames(tester, 3);
        expect(find.text('Item 0'), findsOneWidget);
        // 10 × 60 px does not fill 800 px: page 2 is requested by itself.
        expect(api.requested, [1, 2]);
        expect(find.byType(PerformanceLoadingFooter), findsOneWidget);
        api.completeNext();
        await frames(tester, 3);
        // 20 items fill the viewport but sit inside the prefetch distance.
        expect(api.requested, [1, 2, 3]);
        api.completeNext();
        await frames(tester, 3);
        expect(api.requested, [1, 2, 3], reason: 'far enough from the end now');
      },
    );

    testWidgets(
      'scrolling to the end loads every page, then shows the end footer',
      (tester) async {
        useSurface(tester);
        final api = FakeApi(pages: 4);
        final c = api.controller();
        addTearDown(c.dispose);
        await tester.pumpWidget(
          host(
            PerformanceListView<String>(
              listController: c,
              itemBuilder: (_, s, _) => Tile(s),
            ),
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -900),
          );
          await frames(tester, 4);
        }
        expect(c.length, 40);
        expect(c.status, PagingStatus.completed);
        expect(api.requested, [1, 2, 3, 4]);
        expect(find.byType(PerformanceEndFooter), findsOneWidget);
      },
    );

    testWidgets('appending a page rebuilds none of the items on screen', (
      tester,
    ) async {
      useSurface(tester);
      final builds = <String, int>{};
      final c = PerformanceListController<String>(
        initialItems: [for (var i = 0; i < 30; i++) 'Item $i'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<String>(
            listController: c,
            itemBuilder: (_, s, _) => Tile(s, builds: builds),
          ),
        ),
      );
      final before = Map.of(builds);
      c.addAll([for (var i = 30; i < 50; i++) 'Item $i']);
      await tester.pump();
      expect(builds, before);
      expect(find.text('Item 0'), findsOneWidget);
      // The new items are reachable: the scroll extent was updated.
      final pos = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(pos.maxScrollExtent, greaterThan(49 * 60 - 800));
    });

    testWidgets('updating one item rebuilds only that item', (tester) async {
      useSurface(tester);
      final builds = <String, int>{};
      final c = PerformanceListController<String>(
        initialItems: [for (var i = 0; i < 10; i++) 'Item $i'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<String>(
            listController: c,
            itemBuilder: (_, s, _) => Tile(s, builds: builds),
          ),
        ),
      );
      builds.clear();
      c.updateAt(3, 'Item 3 edited');
      await tester.pump();
      expect(builds, {'Item 3 edited': 1});
    });

    testWidgets('a failed page shows a retry footer that loads it again', (
      tester,
    ) async {
      useSurface(tester);
      final api = FakeApi(auto: false);
      final c = api.controller();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<String>(
            listController: c,
            itemBuilder: (_, s, _) => Tile(s),
          ),
        ),
      );
      await tester.pump();
      api.completeNext();
      await frames(tester, 3);
      api.failNext();
      await frames(tester, 3);
      expect(c.status, PagingStatus.loadMoreError);
      expect(find.byType(PerformanceErrorFooter), findsOneWidget);
      await frames(tester, 5);
      expect(api.requested, [1, 2], reason: 'no automatic retry loop');
      await tester.tap(find.widgetWithText(TextButton, 'Try again'));
      await tester.pump();
      expect(api.requested, [1, 2, 2]);
      api.completeNext();
      await frames(tester, 3);
      expect(c.length, 20);
    });

    testWidgets('a failed first page shows the error view and retries', (
      tester,
    ) async {
      useSurface(tester);
      final api = FakeApi()..fail = true;
      final c = api.controller();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<String>(
            listController: c,
            itemBuilder: (_, s, _) => Tile(s),
          ),
        ),
      );
      await frames(tester, 3);
      expect(find.byType(PerformanceErrorView), findsOneWidget);
      api.fail = false;
      await tester.tap(find.text('Try again'));
      await frames(tester, 3);
      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('an empty first page shows the empty view', (tester) async {
      useSurface(tester);
      final c = PagingController<int, String>(
        firstPageKey: 1,
        fetchPage: (_) => const PageResult.last([]),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<String>(
            listController: c,
            itemBuilder: (_, s, _) => Tile(s),
            emptyBuilder: (_) => const Text('No posts'),
          ),
        ),
      );
      await frames(tester, 3);
      expect(find.text('No posts'), findsOneWidget);
    });

    testWidgets('disposing the view during a load is safe', (tester) async {
      useSurface(tester);
      final api = FakeApi(auto: false);
      final c = api.controller();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<String>(
            listController: c,
            itemBuilder: (_, s, _) => Tile(s),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(host(const SizedBox()));
      api.completeNext();
      await frames(tester, 3);
      expect(tester.takeException(), isNull);
      expect(c.length, 10);
    });

    testWidgets('pull-to-refresh replaces the items and drops a stale page', (
      tester,
    ) async {
      useSurface(tester);
      final api = FakeApi(auto: false);
      final c = api.controller();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<String>(
            listController: c,
            itemBuilder: (_, s, _) => Tile(s),
          ),
        ),
      );
      await tester.pump();
      api.completeNext(); // page 1
      await frames(tester, 3);
      expect(api.requested, [1, 2]); // page 2 in flight
      await tester.fling(find.text('Item 0'), const Offset(0, 400), 1000);
      await frames(tester, 30);
      expect(api.requested, [1, 2, 1]); // refresh asked for page 1
      api.pending.last.$2.complete(
        const PageResult(['Fresh'], nextPageKey: null),
      );
      await frames(tester, 3);
      api.completeNext(); // the stale page 2 arrives
      await tester.pumpAndSettle();
      expect(c.items, ['Fresh']);
      expect(find.text('Item 0'), findsNothing);
    });

    testWidgets('loadMoreDebounce spaces automatic loads', (tester) async {
      useSurface(tester);
      final api = FakeApi(pageSize: 2);
      final c = api.controller();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<String>(
            listController: c,
            loadMoreDebounce: const Duration(milliseconds: 300),
            itemBuilder: (_, s, _) => Tile(s),
          ),
        ),
      );
      await frames(tester, 5);
      expect(api.requested, [1]);
      await tester.pump(const Duration(milliseconds: 320));
      await frames(tester, 2);
      expect(api.requested, [1, 2]);
    });

    testWidgets('horizontal lists load more too', (tester) async {
      useSurface(tester);
      final api = FakeApi(pageSize: 3);
      final c = api.controller();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<String>(
            listController: c,
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, s, _) => SizedBox(width: 120, child: Text(s)),
          ),
        ),
      );
      await frames(tester, 10);
      expect(api.requested.length, greaterThanOrEqualTo(2));
    });
  });

  group('controllers', () {
    testWidgets('swapping scroll and list controllers keeps working', (
      tester,
    ) async {
      useSurface(tester);
      final a = ScrollController();
      final b = ScrollController();
      final c1 = PerformanceListController<String>(initialItems: ['one']);
      final c2 = PerformanceListController<String>(initialItems: ['two']);
      addTearDown(() {
        a.dispose();
        b.dispose();
        c1.dispose();
        c2.dispose();
      });
      Widget build(ScrollController? s, PerformanceListController<String> c) =>
          host(
            PerformanceListView<String>(
              controller: s,
              listController: c,
              itemBuilder: (_, x, _) => Tile(x),
            ),
          );
      await tester.pumpWidget(build(null, c1));
      await tester.pumpWidget(build(a, c1));
      expect(a.hasClients, isTrue);
      await tester.pumpWidget(build(b, c2));
      expect(a.hasClients, isFalse);
      expect(b.hasClients, isTrue);
      expect(find.text('two'), findsOneWidget);
      await tester.pumpWidget(build(null, c2));
      c1.add('late'); // the old controller no longer drives the view
      await tester.pump();
      expect(find.text('late'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('itemKey keeps state when items are prepended', (tester) async {
      useSurface(tester);
      final c = PerformanceListController<String>(initialItems: ['a', 'b']);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<String>(
            listController: c,
            itemKey: (s) => s,
            itemBuilder: (_, s, _) => _Toggle(label: s),
          ),
        ),
      );
      await tester.tap(find.text('b off'));
      await tester.pump();
      c.prepend('z');
      await tester.pump();
      expect(find.text('b on'), findsOneWidget);
      expect(find.text('z off'), findsOneWidget);
    });

    testWidgets('scrollToIndex reaches an unbuilt item of varying height', (
      tester,
    ) async {
      useSurface(tester);
      final c = PerformanceListController<int>(
        initialItems: List.generate(1000, (i) => i),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            listController: c,
            itemBuilder: (_, i, _) =>
                Tile('Row $i', height: 40.0 + (i * 37) % 90),
          ),
        ),
      );
      c.scrollToIndex(700, duration: const Duration(milliseconds: 200));
      await frames(tester, 80);
      final rect = tester.getRect(find.text('Row 700'));
      expect(rect.top, closeTo(0, 1.5));
      c.jumpToIndex(20, alignment: 0.5);
      await frames(tester, 20);
      final mid = tester.getRect(
        find
            .ancestor(of: find.text('Row 20'), matching: find.byType(SizedBox))
            .first,
      );
      expect(mid.center.dy, closeTo(400, 2));
    });

    testWidgets('scrollToIndex in a grid', (tester) async {
      useSurface(tester);
      final c = PerformanceListController<int>(
        initialItems: List.generate(600, (i) => i),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<int>.grid(
            listController: c,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),
            itemBuilder: (_, i, _) => Text('Cell $i'),
          ),
        ),
      );
      c.jumpToIndex(451);
      await frames(tester, 30);
      expect(find.text('Cell 451'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Cell 451')).dy, closeTo(0, 1.5));
    });
  });

  group('rendering', () {
    testWidgets('fixed extents use SliverFixedExtentList', (tester) async {
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            items: const [1, 2],
            itemExtent: 50,
            itemBuilder: (_, i, _) => Text('$i'),
          ),
        ),
      );
      expect(find.byType(SliverFixedExtentList), findsOneWidget);
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            items: const [1, 2],
            prototypeItem: const SizedBox(height: 40),
            itemBuilder: (_, i, _) => Text('$i'),
          ),
        ),
      );
      expect(find.byType(SliverPrototypeExtentList), findsOneWidget);
    });

    testWidgets('off-screen items are disposed', (tester) async {
      useSurface(tester);
      _Live.count = 0;
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            items: List.generate(500, (i) => i),
            controller: scroll,
            itemBuilder: (_, i, _) => _Live(i),
          ),
        ),
      );
      for (var y = 0.0; y < 20000; y += 400) {
        scroll.jumpTo(y);
        await tester.pump();
      }
      expect(_Live.count, lessThan(40));
    });

    testWidgets('reverse lists start at the bottom', (tester) async {
      useSurface(tester);
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            items: const [0, 1, 2],
            reverse: true,
            itemBuilder: (_, i, _) => Tile('R$i'),
          ),
        ),
      );
      expect(
        tester.getBottomLeft(find.text('R0')).dy,
        greaterThan(tester.getBottomLeft(find.text('R1')).dy),
      );
      expect(tester.getRect(find.byType(Tile).first).bottom, 800);
    });

    testWidgets(
      'separators sit between items and are not counted by semantics',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          host(
            PerformanceListView<int>(
              items: const [0, 1, 2, 3],
              separatorBuilder: (_, i) => Divider(key: ValueKey('sep$i')),
              itemBuilder: (_, i, _) => Tile('S$i'),
            ),
          ),
        );
        expect(find.byType(Divider), findsNWidgets(3));
        final indexes = tester
            .widgetList<IndexedSemantics>(find.byType(IndexedSemantics))
            .map((e) => e.index);
        expect(indexes, [0, 1, 2, 3]);
        final scroll = tester.widget<CustomScrollView>(
          find.byType(CustomScrollView),
        );
        expect(scroll.semanticChildCount, 4);
        handle.dispose();
      },
    );

    testWidgets('header and footer slivers stay in every state', (
      tester,
    ) async {
      Widget build(List<int> items, {bool error = false}) => host(
        PerformanceListView<int>(
          items: items,
          hasError: error,
          headerSlivers: const [SliverToBoxAdapter(child: Text('HEADER'))],
          footerSlivers: const [SliverToBoxAdapter(child: Text('FOOTER'))],
          itemBuilder: (_, i, _) => Text('$i'),
        ),
      );
      for (final w in [
        build(const []),
        build(const [1]),
        build(const [], error: true),
      ]) {
        await tester.pumpWidget(w);
        expect(find.text('HEADER'), findsOneWidget);
        expect(find.text('FOOTER', skipOffstage: false), findsOneWidget);
      }
    });

    testWidgets('0.x builders still work', (tester) async {
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            items: const [],
            isLoading: true,
            loadingBuilder: (_) => const Text('LOADING'),
            itemBuilder: (_, i, _) => Text('$i'),
          ),
        ),
      );
      expect(find.text('LOADING'), findsOneWidget);
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            items: const [],
            hasError: true,
            errorBuilder: (_) => const Text('ERROR'),
            itemBuilder: (_, i, _) => Text('$i'),
          ),
        ),
      );
      expect(find.text('ERROR'), findsOneWidget);
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            items: const [1],
            isLoading: true,
            bottomLoaderBuilder: (_) => const Text('MORE'),
            itemBuilder: (_, i, _) => Text('$i'),
          ),
        ),
      );
      expect(find.text('MORE'), findsOneWidget);
    });

    testWidgets('no refresh indicator without a refresh handler', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            items: const [1],
            itemBuilder: (_, i, _) => Text('$i'),
          ),
        ),
      );
      expect(find.byType(RefreshIndicator), findsNothing);
      await tester.pumpWidget(
        host(
          PerformanceListView<int>(
            items: const [1],
            onRefresh: () async {},
            itemBuilder: (_, i, _) => Text('$i'),
          ),
        ),
      );
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('reduced motion leaves nothing animating', (tester) async {
      final c = PagingController<int, String>(
        firstPageKey: 1,
        fetchPage: (_) => Future<PageResult<int, String>>.delayed(
          const Duration(seconds: 1),
          () => const PageResult.last(['x']),
        ),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<String>(
            listController: c,
            itemBuilder: (_, s, _) => Text(s),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SkeletonListTile), findsWidgets);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('x'), findsOneWidget);
    });
  });

  group('animated changes', () {
    testWidgets('inserts and removals animate', (tester) async {
      useSurface(tester);
      final c = PerformanceListController<String>(initialItems: ['a', 'b']);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          PerformanceListView<String>(
            listController: c,
            animateChanges: true,
            itemBuilder: (_, s, _) => Tile(s),
          ),
          reduceMotion: false,
        ),
      );
      c.insert(1, 'new');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getSize(
        find.ancestor(
          of: find.text('new'),
          matching: find.byType(SizeTransition),
        ),
      );
      expect(mid.height, inExclusiveRange(0, 60));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Tile).at(1)).height, 60);
      c.removeAt(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('a'), findsOneWidget); // still animating out
      await tester.pumpAndSettle();
      expect(find.text('a'), findsNothing);
      expect(find.text('new'), findsOneWidget);
    });
  });
}

class _Toggle extends StatefulWidget {
  const _Toggle({required this.label});
  final String label;

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  bool on = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => on = !on),
    child: SizedBox(
      height: 60,
      child: Text('${widget.label} ${on ? 'on' : 'off'}'),
    ),
  );
}

class _Live extends StatefulWidget {
  const _Live(this.i);
  final int i;
  static int count = 0;

  @override
  State<_Live> createState() => _LiveState();
}

class _LiveState extends State<_Live> {
  @override
  void initState() {
    super.initState();
    _Live.count++;
  }

  @override
  void dispose() {
    _Live.count--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 60, child: Text('L${widget.i}'));
}
