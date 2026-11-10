import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance_list_view/performance_list_view.dart';

import 'helpers.dart';

class Msg {
  Msg(this.id, this.text, {this.stream});
  final int id;
  final String text;
  final StreamingTextController? stream;
}

List<Msg> _history(int n, [int from = 0]) => [
  for (var i = from; i < from + n; i++) Msg(i, 'Message $i'),
];

void main() {
  late Map<int, int> builds;

  Widget chat(
    PerformanceListController<Msg> c, {
    ChatScrollController? scroll,
    ValueListenable<bool>? typing,
  }) => host(
    PerformanceChatView<Msg>(
      controller: c,
      scrollController: scroll,
      typing: typing,
      itemKey: (m) => m.id,
      itemBuilder: (context, m, _) {
        builds[m.id] = (builds[m.id] ?? 0) + 1;
        final s = m.stream;
        return SizedBox(
          width: double.infinity,
          child: s == null
              ? SizedBox(height: 60, child: Text(m.text))
              : StreamingText(controller: s),
        );
      },
    ),
  );

  setUp(() => builds = {});

  testWidgets('starts at the newest message, at the bottom', (tester) async {
    useSurface(tester);
    final c = PerformanceListController<Msg>(
      initialItems: _history(30).reversed,
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(chat(c));
    expect(find.text('Message 29'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Message 29')).dy,
      closeTo(800 - 12, 0.5),
    );
    expect(find.text('Message 0'), findsNothing);
  });

  testWidgets(
    'new messages keep the view pinned and rebuild no other message',
    (tester) async {
      useSurface(tester);
      final c = PerformanceListController<Msg>(
        initialItems: _history(30).reversed,
      );
      final scroll = ChatScrollController();
      addTearDown(() {
        c.dispose();
        scroll.dispose();
      });
      await tester.pumpWidget(chat(c, scroll: scroll));
      builds.clear();
      for (var i = 30; i < 35; i++) {
        c.prepend(Msg(i, 'Message $i'));
        await tester.pump();
      }
      expect(builds.keys, [30, 31, 32, 33, 34]);
      expect(builds.values.every((v) => v == 1), isTrue);
      expect(scroll.isAtLatest, isTrue);
      expect(
        tester.getBottomLeft(find.text('Message 34')).dy,
        closeTo(800 - 12, 0.5),
      );
    },
  );

  testWidgets('while scrolled up, new messages do not move what you read', (
    tester,
  ) async {
    useSurface(tester);
    final c = PerformanceListController<Msg>(
      initialItems: _history(60).reversed,
    );
    final scroll = ChatScrollController();
    addTearDown(() {
      c.dispose();
      scroll.dispose();
    });
    await tester.pumpWidget(chat(c, scroll: scroll));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
    await tester.pumpAndSettle();
    final reading = find.text('Message 40');
    final before = tester.getTopLeft(reading);
    c.prepend(Msg(60, 'Message 60'));
    await tester.pump();
    c.prepend(Msg(61, 'Message 61'));
    await tester.pump();
    expect(tester.getTopLeft(reading), before);
    expect(scroll.isAtLatest, isFalse);

    // The pill counts what arrived and jumps back down.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2 new messages'), findsOneWidget);
    await tester.tap(find.text('2 new messages'));
    await tester.pumpAndSettle();
    expect(scroll.isAtLatest, isTrue);
    expect(find.text('Message 61'), findsOneWidget);
    expect(find.text('2 new messages'), findsNothing);
  });

  testWidgets(
    'a streaming reply grows token by token while pinned, rebuilding nothing else',
    (tester) async {
      useSurface(tester);
      final c = PerformanceListController<Msg>(
        initialItems: _history(20).reversed,
      );
      final scroll = ChatScrollController();
      final stream = StreamingTextController();
      addTearDown(() {
        c.dispose();
        scroll.dispose();
        stream.dispose();
      });
      await tester.pumpWidget(chat(c, scroll: scroll));
      c.prepend(Msg(99, '', stream: stream));
      await tester.pump();
      builds.clear();
      for (var i = 0; i < 40; i++) {
        stream.append('token$i ');
        await tester.pump();
      }
      stream.complete();
      await tester.pump();
      expect(builds, isEmpty, reason: 'no item builder ran for any token');
      expect(scroll.isAtLatest, isTrue);
      final reply = tester.getRect(find.byType(StreamingText));
      expect(reply.height, greaterThan(60));
      expect(reply.bottom, closeTo(800 - 12, 0.5));
    },
  );

  testWidgets('the typing indicator shows at the bottom', (tester) async {
    useSurface(tester);
    final c = PerformanceListController<Msg>(
      initialItems: _history(5).reversed,
    );
    final typing = ValueNotifier(false);
    addTearDown(() {
      c.dispose();
      typing.dispose();
    });
    await tester.pumpWidget(chat(c, typing: typing));
    expect(find.byType(TypingIndicator), findsNothing);
    typing.value = true;
    await tester.pump();
    expect(find.byType(TypingIndicator), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(TypingIndicator)).dy,
      greaterThan(tester.getBottomLeft(find.text('Message 4')).dy),
    );
  });

  testWidgets(
    'older history loads when scrolling up, then stops at the start',
    (tester) async {
      useSurface(tester);
      final c = PagingController<int, Msg>(
        firstPageKey: 0,
        // Newest first: page 0 holds messages 99..80.
        fetchPage: (p) => PageResult([
          for (var i = 99 - p * 20; i > 99 - (p + 1) * 20; i--)
            Msg(i, 'Message $i'),
        ], nextPageKey: p < 4 ? p + 1 : null),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(chat(c));
      await frames(tester, 3);
      expect(find.text('Message 99'), findsOneWidget);
      for (var i = 0; i < 15; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
        await frames(tester, 3);
      }
      expect(c.length, 100);
      expect(c.status, PagingStatus.completed);
      expect(find.text('Message 0'), findsOneWidget);
    },
  );

  testWidgets('an empty conversation shows the empty view', (tester) async {
    final c = PerformanceListController<Msg>();
    addTearDown(c.dispose);
    await tester.pumpWidget(chat(c));
    expect(find.byType(PerformanceEmptyView), findsOneWidget);
    c.prepend(Msg(1, 'Hello'));
    await tester.pump();
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('scrollToIndex reaches an old message', (tester) async {
    useSurface(tester);
    final c = PerformanceListController<Msg>(
      initialItems: _history(200).reversed,
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(chat(c));
    c.jumpToIndex(150); // Message 49
    await frames(tester, 30);
    expect(find.text('Message 49'), findsOneWidget);
  });

  test('StreamingTextController.bind appends a stream and completes', () async {
    final s = StreamingTextController();
    final tokens = StreamController<String>();
    final done = s.bind(tokens.stream);
    tokens
      ..add('Hel')
      ..add('lo');
    await tokens.close();
    await done;
    expect(s.value, 'Hello');
    expect(s.isDone, isTrue);
    s.restart('x');
    expect(s.isDone, isFalse);
    expect(s.value, 'x');
    s.dispose();
  });
}
