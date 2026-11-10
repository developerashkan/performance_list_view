import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:performance_list_view/performance_list_view.dart';

/// A fetcher whose pages complete when the test says so.
class _Fetcher {
  final List<int> keys = [];
  final List<Completer<PageResult<int, String>>> pending = [];

  Future<PageResult<int, String>> call(int key) {
    keys.add(key);
    final c = Completer<PageResult<int, String>>();
    pending.add(c);
    return c.future;
  }

  void complete(int i, List<String> items, {int? next}) =>
      pending[i].complete(PageResult(items, nextPageKey: next));
}

List<String> _page(int key, [int n = 3]) => [
  for (var i = 0; i < n; i++) 'p$key-$i',
];

void main() {
  group('PagingController', () {
    test('only one load runs at a time', () async {
      final f = _Fetcher();
      final c = PagingController<int, String>(
        firstPageKey: 1,
        fetchPage: f.call,
      );
      final a = c.loadMore();
      final b = c.loadMore();
      c.loadMore();
      expect(f.keys, [1]);
      expect(c.status, PagingStatus.loadingFirstPage);
      f.complete(0, _page(1), next: 2);
      await a;
      await b;
      expect(c.items, _page(1));
      expect(c.status, PagingStatus.idle);
      expect(c.nextPageKey, 2);
    });

    test(
      'pages append in order and the last page completes the list',
      () async {
        final c = PagingController<int, String>(
          firstPageKey: 1,
          fetchPage: (k) =>
              PageResult(_page(k), nextPageKey: k < 3 ? k + 1 : null),
        );
        await c.loadMore();
        await c.loadMore();
        await c.loadMore();
        expect(c.length, 9);
        expect(c.status, PagingStatus.completed);
        expect(c.hasMore, isFalse);
        expect(c.pagesLoaded, 3);
        await c.loadMore(); // no-op after the end
        expect(c.length, 9);
      },
    );

    test('a response that arrives after refresh is dropped', () async {
      final f = _Fetcher();
      final c = PagingController<int, String>(
        firstPageKey: 1,
        fetchPage: f.call,
      );
      final first = c.loadMore();
      f.complete(0, _page(1), next: 2);
      await first;
      final more = c.loadMore(); // page 2 in flight
      final refresh = c.refresh(); // supersedes it
      f.complete(2, ['fresh'], next: 2);
      await refresh;
      f.complete(1, _page(2), next: 3); // the stale page 2 arrives late
      await more;
      expect(c.items, ['fresh']);
      expect(c.status, PagingStatus.idle);
    });

    test(
      'a response that arrives after dispose is dropped without errors',
      () async {
        final f = _Fetcher();
        final c = PagingController<int, String>(
          firstPageKey: 1,
          fetchPage: f.call,
        );
        var notified = 0;
        c.addListener(() => notified++);
        final load = c.loadMore();
        final before = notified;
        c.dispose();
        f.complete(0, _page(1), next: 2);
        await load;
        expect(notified, before);
      },
    );

    test('reset drops the running load and starts over', () async {
      final f = _Fetcher();
      final c = PagingController<int, String>(
        firstPageKey: 1,
        fetchPage: f.call,
      );
      final first = c.loadMore();
      f.complete(0, _page(1), next: 2);
      await first;
      final more = c.loadMore();
      c.reset();
      f.complete(1, _page(2), next: 3);
      await more;
      expect(c.items, isEmpty);
      expect(c.status, PagingStatus.idle);
      c.loadMore();
      expect(f.keys.last, 1);
    });

    test('an error stops auto-loading until retry', () async {
      var fail = true;
      var calls = 0;
      final c = PagingController<int, String>(
        firstPageKey: 1,
        fetchPage: (k) async {
          calls++;
          if (fail) throw StateError('offline');
          return PageResult(_page(k), nextPageKey: k + 1);
        },
      );
      await c.loadMore();
      expect(c.status, PagingStatus.firstPageError);
      expect(c.error, isA<StateError>());
      expect(c.stackTrace, isNotNull);
      await c.loadMore();
      await c.loadMore();
      expect(calls, 1);
      fail = false;
      await c.retry();
      expect(c.status, PagingStatus.idle);
      expect(c.error, isNull);
      expect(c.length, 3);
      fail = true;
      await c.loadMore();
      expect(c.status, PagingStatus.loadMoreError);
      expect(c.length, 3);
    });

    test('a fetch that never completes times out into an error', () async {
      final c = PagingController<int, String>(
        firstPageKey: 1,
        fetchTimeout: const Duration(milliseconds: 20),
        fetchPage: (k) => Completer<PageResult<int, String>>().future,
      );
      await c.loadMore();
      expect(c.status, PagingStatus.firstPageError);
      expect(c.error, isA<TimeoutException>());
    });

    test('an empty page that points at the same key ends the list', () async {
      var calls = 0;
      final c = PagingController<int, String>(
        firstPageKey: 1,
        fetchPage: (k) {
          calls++;
          return PageResult(const [], nextPageKey: k);
        },
      );
      await c.loadMore();
      await c.loadMore();
      expect(calls, 1);
      expect(c.status, PagingStatus.completed);
    });

    test('concurrent refreshes share one load', () async {
      final f = _Fetcher();
      final c = PagingController<int, String>(
        firstPageKey: 1,
        fetchPage: f.call,
      );
      final a = c.refresh();
      final b = c.refresh();
      expect(f.keys, [1]);
      f.complete(0, _page(1), next: 2);
      await Future.wait([a, b]);
      expect(c.items, _page(1));
    });

    test(
      'a failed refresh keeps the old items and reports refreshError',
      () async {
        var fail = false;
        final c = PagingController<int, String>(
          firstPageKey: 1,
          fetchPage: (k) async {
            if (fail) throw StateError('down');
            return PageResult(_page(k), nextPageKey: k + 1);
          },
        );
        await c.loadMore();
        fail = true;
        await c.refresh();
        expect(c.items, _page(1));
        expect(c.status, PagingStatus.idle);
        expect(c.refreshError, isA<StateError>());
        fail = false;
        await c.refresh();
        expect(c.refreshError, isNull);
      },
    );

    test('refresh(keepItems: false) clears first', () async {
      final f = _Fetcher();
      final c = PagingController<int, String>(
        firstPageKey: 1,
        fetchPage: f.call,
      );
      final first = c.loadMore();
      f.complete(0, _page(1), next: 2);
      await first;
      final r = c.refresh(keepItems: false);
      expect(c.items, isEmpty);
      expect(c.status, PagingStatus.loadingFirstPage);
      f.complete(1, ['new'], next: 2);
      await r;
      expect(c.items, ['new']);
    });

    test('byPage ends on a short page', () async {
      final requests = <(int, int)>[];
      final c = PagingController.byPage<int>(
        pageSize: 4,
        fetch: (page, size) {
          requests.add((page, size));
          return [
            for (var i = 0; i < (page < 3 ? size : 2); i++) page * 10 + i,
          ];
        },
      );
      await c.loadMore();
      await c.loadMore();
      await c.loadMore();
      expect(requests, [(1, 4), (2, 4), (3, 4)]);
      expect(c.length, 10);
      expect(c.status, PagingStatus.completed);
    });

    test('byCursor passes the cursor along', () async {
      final cursors = <String?>[];
      final c = PagingController.byCursor<String>(
        fetch: (cursor) {
          cursors.add(cursor);
          return (
            ['x${cursors.length}'],
            cursors.length < 2 ? 'c${cursors.length}' : null,
          );
        },
      );
      await c.loadMore();
      await c.loadMore();
      expect(cursors, [null, 'c1']);
      expect(c.items, ['x1', 'x2']);
      expect(c.status, PagingStatus.completed);
    });

    test('status and item listeners are separate', () async {
      final c = PagingController<int, String>(
        firstPageKey: 1,
        fetchPage: (k) => PageResult(_page(k), nextPageKey: k + 1),
      );
      var status = 0;
      var items = 0;
      c.statusListenable.addListener(() => status++);
      c.itemsListenable.addListener(() => items++);
      await c.loadMore();
      expect(items, 1);
      expect(status, greaterThanOrEqualTo(2)); // loading, then idle
      status = 0;
      c.updateAt(0, 'edited');
      expect(status, 0);
      expect(items, 2);
    });
  });

  group('PerformanceListController', () {
    test('mutations emit structural changes', () {
      final c = PerformanceListController<String>(initialItems: ['a', 'b']);
      final changes = <ListChange<String>>[];
      c.addChangeListener(changes.add);
      c.add('c');
      c.prepend('z');
      c.insert(2, 'm');
      c.removeAt(0);
      c.updateAt(0, 'A');
      c.remove('m');
      c.replaceAll(['q']);
      expect(c.items, ['q']);
      expect(changes.map((e) => e.kind), [
        ListChangeKind.insert,
        ListChangeKind.insert,
        ListChangeKind.insert,
        ListChangeKind.remove,
        ListChangeKind.update,
        ListChangeKind.remove,
        ListChangeKind.reset,
      ]);
      expect(changes[3].removed, ['z']);
      expect(changes[4].removed, ['a']);
    });

    test('removeWhere and updateWhere', () {
      final c = PerformanceListController<int>(initialItems: [1, 2, 3, 4]);
      c.removeWhere((v) => v.isEven);
      expect(c.items, [1, 3]);
      expect(c.updateWhere((v) => v == 3, (v) => v * 10), isTrue);
      expect(c.items, [1, 30]);
      expect(c.updateWhere((v) => v == 99, (v) => v), isFalse);
    });

    test('items are read-only', () {
      final c = PerformanceListController<int>(initialItems: [1]);
      expect(() => c.items.add(2), throwsUnsupportedError);
    });

    test('a plain controller is never loading', () async {
      final c = PerformanceListController<int>();
      expect(c.status, PagingStatus.completed);
      expect(c.isPaginated, isFalse);
      await c.loadMore();
      await c.refresh();
      expect(c.isLoading, isFalse);
    });

    test('scrollToIndex without a view completes', () async {
      final c = PerformanceListController<int>(initialItems: [1, 2]);
      await c.scrollToIndex(1);
    });
  });

  group('PageResult', () {
    test('last and next', () {
      expect(const PageResult<int, int>.last([1]).isLastPage, isTrue);
      expect(const PageResult<int, int>.next([1], 2).isLastPage, isFalse);
      expect(const PageResult<int, int>([1]).isLastPage, isTrue);
      expect(
        const PageResult<String?, int>([1], isLastPage: false).isLastPage,
        isFalse,
      );
    });
  });
}
