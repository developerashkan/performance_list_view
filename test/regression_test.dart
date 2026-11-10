// Regression tests for bugs in 0.0.5. They use only the 0.x API, so the same
// file runs against the old package: every test here fails on 0.0.5.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance_list_view/performance_list_view.dart';

Widget _host(Widget child) => MaterialApp(
  home: MediaQuery(
    // Still spinners and skeletons, so frames settle.
    data: const MediaQueryData(size: Size(400, 800), disableAnimations: true),
    child: Scaffold(body: child),
  ),
);

Widget _tile(BuildContext context, String item, int index) =>
    SizedBox(height: 60, child: Text(item));

/// A parent that pages like a typical 0.x app: onEndReached flips isLoading,
/// waits, then appends [pageSize] items (or none).
class _Pager extends StatefulWidget {
  const _Pager({
    required this.initial,
    required this.pageSize,
    required this.onCall,
  });

  final int initial;
  final int pageSize;
  final VoidCallback onCall;

  @override
  State<_Pager> createState() => _PagerState();
}

class _PagerState extends State<_Pager> {
  late final List<String> items = [
    for (var i = 0; i < widget.initial; i++) 'Item $i',
  ];
  bool loading = false;

  Future<void> _load() async {
    widget.onCall();
    if (loading) return;
    setState(() => loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() {
      final n = items.length;
      items.addAll([for (var i = 0; i < widget.pageSize; i++) 'Item ${n + i}']);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => PerformanceListView<String>(
    items: items,
    isLoading: loading,
    onEndReached: _load,
    onRefresh: () async {},
    itemBuilder: _tile,
  );
}

/// An item with state that only a tap creates, so a recreated state shows.
class _Tapper extends StatefulWidget {
  const _Tapper({super.key, required this.label, this.keepAlive = false});
  final String label;
  final bool keepAlive;

  @override
  State<_Tapper> createState() => _TapperState();
}

class _TapperState extends State<_Tapper> with AutomaticKeepAliveClientMixin {
  int taps = 0;

  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: () => setState(() => taps++),
      child: SizedBox(height: 60, child: Text('${widget.label} taps $taps')),
    );
  }
}

void main() {
  testWidgets(
    'onEndReached fires once when the first page does not fill the viewport',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          PerformanceListView<String>(
            items: const ['a', 'b', 'c'],
            onEndReached: () => calls++,
            onRefresh: () async {},
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // 0.0.5 called it once per item built within the threshold, from
      // microtasks during build: two concurrent loads here.
      expect(calls, 1);
    },
  );

  testWidgets('an unrelated parent rebuild does not fire onEndReached again', (
    tester,
  ) async {
    var calls = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return PerformanceListView<String>(
              items: const ['a', 'b', 'c'],
              onEndReached: () => calls++,
              onRefresh: () async {},
              itemBuilder: _tile,
            );
          },
        ),
      ),
    );
    await tester.pump();
    final first = calls;
    for (var i = 0; i < 3; i++) {
      rebuild(() {});
      await tester.pump();
    }
    expect(first, 1);
    expect(calls, 1);
  });

  testWidgets('a page that returns no items does not loop onEndReached', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(_Pager(initial: 3, pageSize: 0, onCall: () => calls++)),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    // 0.0.5 re-fired after every rebuild that ended a load: about 10 calls.
    expect(calls, 1);
  });

  testWidgets('pages keep loading until the viewport is filled', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(_Pager(initial: 2, pageSize: 2, onCall: () => calls++)),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    final state = tester.state<_PagerState>(find.byType(_Pager));
    // 800 px viewport, 60 px items: at least 14 items are needed.
    expect(state.items.length, greaterThanOrEqualTo(14));
    // Each onEndReached started exactly one load.
    expect(calls, (state.items.length - 2) ~/ 2 + (state.loading ? 1 : 0));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('an empty list with onEndReached loads the first page', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        PerformanceListView<String>(
          items: const [],
          onEndReached: () => calls++,
          onRefresh: () async {},
          itemBuilder: _tile,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    // 0.0.5 showed "No data found" and never asked for data.
    expect(calls, 1);
  });

  testWidgets(
    'an item builder returning null hides one item, not the rest of the list',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          PerformanceListView<String>(
            items: [for (var i = 0; i < 6; i++) 'Item $i'],
            onEndReached: () => calls++,
            onRefresh: () async {},
            itemBuilder: (context, item, index) =>
                index == 2 ? null : _tile(context, item, index),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 5'), findsOneWidget);
      // 0.0.5 stopped the list at the null: the end was never reached, so the
      // next page never loaded.
      expect(calls, 1);
    },
  );

  testWidgets('an item that asks to be kept alive keeps its state off screen', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _host(
        PerformanceListView<String>(
          items: [for (var i = 0; i < 200; i++) 'Item $i'],
          controller: scroll,
          onRefresh: () async {},
          itemBuilder: (context, item, index) =>
              _Tapper(label: item, keepAlive: index == 0),
        ),
      ),
    );
    await tester.tap(find.text('Item 0 taps 0'));
    await tester.pump();
    scroll.jumpTo(6000);
    await tester.pump();
    scroll.jumpTo(0);
    await tester.pump();
    // 0.0.5 built the list without AutomaticKeepAlive, so keep-alive
    // requests (its own wrapper included) did nothing.
    expect(find.text('Item 0 taps 1'), findsOneWidget);
  });

  testWidgets(
    'a builder-provided key keeps item state when items are inserted before it',
    (tester) async {
      final items = ['Item a', 'Item b', 'Item c'];
      late StateSetter rebuild;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return PerformanceListView<String>(
                items: items,
                onRefresh: () async {},
                itemBuilder: (context, item, index) =>
                    _Tapper(key: ValueKey(item), label: item),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Item b taps 0'));
      await tester.pump();
      rebuild(() => items.insert(0, 'Item z'));
      await tester.pump();
      // 0.0.5 had no findChildIndexCallback: "b" got a fresh state.
      expect(find.text('Item b taps 1'), findsOneWidget);
      expect(find.text('Item z taps 0'), findsOneWidget);
    },
  );

  testWidgets(
    'a load-more error shows a footer, not the full-screen errorBuilder',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          PerformanceListView<String>(
            items: [for (var i = 0; i < 3; i++) 'Item $i'],
            hasError: true,
            onRetry: () => retries++,
            onEndReached: () {},
            onRefresh: () async {},
            errorBuilder: (context) => const Text('FULL SCREEN ERROR'),
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('FULL SCREEN ERROR'), findsNothing);
      await tester.tap(find.byType(TextButton));
      expect(retries, 1);
    },
  );

  testWidgets('PerformanceImage accepts an unbounded size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: PerformanceImage(
              imageUrl: 'https://example.com/a.png',
              height: double.infinity,
            ),
          ),
        ),
      ),
    );
    // 0.0.5 threw "Infinity or NaN toInt" while computing the cache size.
    expect(tester.takeException(), isNull);
  });
}
