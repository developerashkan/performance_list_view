// Frame-time benchmark against a plain ListView.builder.
//
//   flutter test test/benchmark_test.dart --dart-define=BENCH=true
//
// Times every frame (build + layout + paint) with a stopwatch around
// tester.pump(), and counts item builds. Widget tests run in debug (JIT)
// mode, so absolute times are higher than on a release build; compare the
// columns, not the numbers with a device. Without BENCH the same scenarios
// run briefly as a smoke test.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance_list_view/performance_list_view.dart';

const _bench = bool.fromEnvironment('BENCH');
final int _rounds = _bench ? 7 : 1;
final int _scrollFrames = _bench ? 600 : 40;
final int _appends = _bench ? 60 : 4;
final int _tokens = _bench ? 400 : 20;

int _builds = 0;

class _Tile extends StatelessWidget {
  const _Tile(this.i);
  final int i;

  @override
  Widget build(BuildContext context) {
    _builds++;
    final theme = Theme.of(context);
    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(radius: 20, child: Text('${i % 10}')),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Item number $i', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Subtitle with some more text for item $i',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _Stats {
  final List<int> micros = [];
  int builds = 0;

  void add(Stopwatch s) => micros.add(s.elapsedMicroseconds);

  double pct(double p) {
    final sorted = [...micros]..sort();
    return sorted[((sorted.length - 1) * p).round()] / 1000;
  }

  double get mean => micros.reduce((a, b) => a + b) / micros.length / 1000;
}

Future<void> _timedPump(WidgetTester tester, _Stats stats) async {
  final s = Stopwatch()..start();
  await tester.pump(const Duration(milliseconds: 16));
  s.stop();
  stats.add(s);
}

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(
    extensions: const [PerformanceListThemeData(reduceMotion: true)],
  ),
  home: Scaffold(body: child),
);

/// Scrolls 30 px per frame through a 10,000-item list.
Future<_Stats> _scroll(
  WidgetTester tester,
  Widget Function(ScrollController) build,
) async {
  final scroll = ScrollController();
  await tester.pumpWidget(_app(build(scroll)));
  await tester.pump();
  for (var i = 0; i < 30; i++) {
    scroll.jumpTo(scroll.offset + 30); // warm-up
    await tester.pump(const Duration(milliseconds: 16));
  }
  final stats = _Stats();
  _builds = 0;
  for (var i = 0; i < _scrollFrames; i++) {
    scroll.jumpTo(scroll.offset + 30);
    await _timedPump(tester, stats);
  }
  stats.builds = _builds;
  await tester.pumpWidget(const SizedBox());
  scroll.dispose();
  return stats;
}

/// Appends 20 items at a time while the first screen is visible.
Future<_Stats> _appendPlain(WidgetTester tester) async {
  final items = List.generate(40, (i) => i);
  late StateSetter set;
  await tester.pumpWidget(
    _app(
      StatefulBuilder(
        builder: (context, s) {
          set = s;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => _Tile(items[i]),
          );
        },
      ),
    ),
  );
  final stats = _Stats();
  _builds = 0;
  for (var k = 0; k < _appends; k++) {
    set(() => items.addAll(List.generate(20, (i) => items.length + i)));
    await _timedPump(tester, stats);
  }
  stats.builds = _builds;
  await tester.pumpWidget(const SizedBox());
  return stats;
}

Future<_Stats> _appendOurs(WidgetTester tester) async {
  final c = PerformanceListController<int>(
    initialItems: List.generate(40, (i) => i),
  );
  await tester.pumpWidget(
    _app(
      PerformanceListView<int>(
        listController: c,
        itemExtent: null,
        itemBuilder: (_, i, _) => _Tile(i),
      ),
    ),
  );
  final stats = _Stats();
  _builds = 0;
  for (var k = 0; k < _appends; k++) {
    c.addAll(List.generate(20, (i) => c.length + i));
    await _timedPump(tester, stats);
  }
  stats.builds = _builds;
  await tester.pumpWidget(const SizedBox());
  c.dispose();
  return stats;
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    _builds++;
    return ChatBubble(child: Text(text));
  }
}

/// Streams tokens into the newest message of a 200-message chat.
Future<_Stats> _streamPlain(WidgetTester tester) async {
  final messages = List.generate(
    200,
    (i) => 'Message $i with a few words in it',
  );
  late StateSetter set;
  await tester.pumpWidget(
    _app(
      StatefulBuilder(
        builder: (context, s) {
          set = s;
          return ListView.builder(
            reverse: true,
            itemCount: messages.length,
            itemBuilder: (_, i) => _Bubble(messages[i]),
          );
        },
      ),
    ),
  );
  set(() => messages.insert(0, ''));
  await tester.pump();
  final stats = _Stats();
  _builds = 0;
  for (var t = 0; t < _tokens; t++) {
    set(() => messages[0] = '${messages[0]}tok$t ');
    await _timedPump(tester, stats);
  }
  stats.builds = _builds;
  await tester.pumpWidget(const SizedBox());
  return stats;
}

Future<_Stats> _streamOurs(WidgetTester tester) async {
  final c = PerformanceListController<Object>(
    initialItems: List.generate(
      200,
      (i) => 'Message $i with a few words in it',
    ),
  );
  final stream = StreamingTextController();
  await tester.pumpWidget(
    _app(
      PerformanceChatView<Object>(
        controller: c,
        showJumpToLatest: false,
        itemBuilder: (_, m, _) => m is StreamingTextController
            ? ChatBubble(child: StreamingText(controller: m, showCursor: false))
            : _Bubble(m as String),
      ),
    ),
  );
  c.prepend(stream);
  await tester.pump();
  final stats = _Stats();
  _builds = 0;
  for (var t = 0; t < _tokens; t++) {
    stream.append('tok$t ');
    await _timedPump(tester, stats);
  }
  stats.builds = _builds;
  await tester.pumpWidget(const SizedBox());
  c.dispose();
  stream.dispose();
  return stats;
}

/// The round with the median mean, so one noisy round does not decide.
_Stats _median(List<_Stats> rounds) {
  final sorted = [...rounds]..sort((a, b) => a.mean.compareTo(b.mean));
  return sorted[sorted.length ~/ 2];
}

void main() {
  testWidgets('benchmark vs ListView.builder', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final results = <String, List<_Stats>>{};
    void record(String name, _Stats s) => (results[name] ??= []).add(s);

    for (var r = 0; r < _rounds; r++) {
      record(
        'scroll  ListView.builder',
        await _scroll(
          tester,
          (s) => ListView.builder(
            controller: s,
            itemCount: 10000,
            itemBuilder: (_, i) => _Tile(i),
          ),
        ),
      );
      record(
        'scroll  PerformanceListView',
        await _scroll(
          tester,
          (s) => PerformanceListView<int>(
            items: List.generate(10000, (i) => i),
            controller: s,
            itemBuilder: (_, i, _) => _Tile(i),
          ),
        ),
      );
      record(
        'scroll  ListView.builder itemExtent',
        await _scroll(
          tester,
          (s) => ListView.builder(
            controller: s,
            itemExtent: 72,
            itemCount: 10000,
            itemBuilder: (_, i) => _Tile(i),
          ),
        ),
      );
      record(
        'scroll  PerformanceListView itemExtent',
        await _scroll(
          tester,
          (s) => PerformanceListView<int>(
            items: List.generate(10000, (i) => i),
            controller: s,
            itemExtent: 72,
            itemBuilder: (_, i, _) => _Tile(i),
          ),
        ),
      );
      record('append  ListView.builder + setState', await _appendPlain(tester));
      record(
        'append  PerformanceListView controller',
        await _appendOurs(tester),
      );
      record('stream  ListView.builder + setState', await _streamPlain(tester));
      record(
        'stream  PerformanceChatView + StreamingText',
        await _streamOurs(tester),
      );
    }

    final lines = <String>[
      'scenario                                      mean ms  p50 ms  p90 ms  item builds',
    ];
    for (final e in results.entries) {
      final s = _median(e.value);
      lines.add(
        '${e.key.padRight(44)}${s.mean.toStringAsFixed(3).padLeft(8)}'
        '${s.pct(0.5).toStringAsFixed(3).padLeft(8)}${s.pct(0.9).toStringAsFixed(3).padLeft(8)}'
        '${s.builds.toString().padLeft(13)}',
      );
    }
    final report = lines.join('\n');
    // ignore: avoid_print
    print(report);
    if (_bench) {
      Directory('build').createSync(recursive: true);
      File('build/benchmark.txt').writeAsStringSync('$report\n');
    }

    // What the design guarantees, independent of timing noise.
    expect(
      _median(results['append  PerformanceListView controller']!).builds,
      0,
    );
    expect(
      _median(results['stream  PerformanceChatView + StreamingText']!).builds,
      0,
    );
    expect(
      _median(results['append  ListView.builder + setState']!).builds,
      greaterThan(0),
    );
  });
}
