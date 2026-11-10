import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance_list_view/performance_list_view.dart';

/// Hosts [child] in a 400 × 800 app. Reduced motion by default, so spinners
/// and skeletons are still and frames settle.
Widget host(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  Brightness brightness = Brightness.light,
  bool reduceMotion = true,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5B5BF7),
        brightness: brightness,
      ),
      extensions: [PerformanceListThemeData(reduceMotion: reduceMotion)],
    ),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: child),
    ),
  );
}

void useSurface(WidgetTester tester, [Size size = const Size(400, 800)]) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
}

/// A fixed-height tile that counts its builds.
class Tile extends StatelessWidget {
  const Tile(this.label, {super.key, this.height = 60, this.builds});
  final String label;
  final double height;
  final Map<String, int>? builds;

  @override
  Widget build(BuildContext context) {
    if (builds != null) builds![label] = (builds![label] ?? 0) + 1;
    return SizedBox(height: height, child: Text(label));
  }
}

/// A paging source whose pages complete on demand, or right away with
/// [auto].
class FakeApi {
  FakeApi({
    this.pageSize = 10,
    this.pages = 5,
    this.auto = true,
    this.delay = Duration.zero,
  });

  final int pageSize;
  final int pages;
  final bool auto;
  final Duration delay;
  final List<int> requested = [];
  final List<(int, Completer<PageResult<int, String>>)> pending = [];
  bool fail = false;

  Future<PageResult<int, String>> fetch(int page) async {
    requested.add(page);
    if (!auto) {
      final c = Completer<PageResult<int, String>>();
      pending.add((page, c));
      return c.future;
    }
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (fail) throw StateError('offline');
    return result(page);
  }

  PageResult<int, String> result(int page) => PageResult([
    for (var i = 0; i < pageSize; i++) 'Item ${(page - 1) * pageSize + i}',
  ], nextPageKey: page < pages ? page + 1 : null);

  void completeNext() {
    final (page, c) = pending.removeAt(0);
    c.complete(result(page));
  }

  void failNext() {
    final (_, c) = pending.removeAt(0);
    c.completeError(StateError('offline'));
  }

  PagingController<int, String> controller() =>
      PagingController<int, String>(firstPageKey: 1, fetchPage: fetch);
}

/// Pumps [n] frames of 16 ms.
Future<void> frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
