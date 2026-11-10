// The 0.0.5 test suite, kept to show that 0.x call sites still compile and
// behave the same.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance_list_view/performance_list_view.dart';

void main() {
  group('PerformanceListView (0.x API)', () {
    testWidgets('renders list items correctly', (WidgetTester tester) async {
      final items = List.generate(10, (index) => 'Item $index');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceListView<String>(
              items: items,
              itemBuilder: (context, item, index) =>
                  ListTile(title: Text(item)),
              onRefresh: () async {},
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 9'), findsOneWidget);
    });

    testWidgets('renders empty builder when no items', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceListView<String>(
              items: const [],
              itemBuilder: (context, item, index) =>
                  ListTile(title: Text(item)),
              onRefresh: () async {},
              emptyBuilder: (context) => const Text('Empty List'),
            ),
          ),
        ),
      );

      expect(find.text('Empty List'), findsOneWidget);
    });

    testWidgets('triggers onRefresh when pulled down', (
      WidgetTester tester,
    ) async {
      bool refreshed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceListView<String>(
              items: List.generate(20, (index) => 'Item $index'),
              itemBuilder: (context, item, index) =>
                  ListTile(title: Text(item)),
              onRefresh: () async {
                refreshed = true;
              },
            ),
          ),
        ),
      );

      await tester.drag(find.text('Item 0'), const Offset(0.0, 500.0));
      await tester.pumpAndSettle();

      expect(refreshed, isTrue);
    });

    testWidgets('grid constructor and every 0.x parameter', (
      WidgetTester tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceListView<int>.grid(
              items: List.generate(6, (i) => i),
              itemBuilder: (context, item, index) => Text('Cell $item'),
              onRefresh: () async {},
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              onEndReached: () {},
              isLoading: false,
              hasError: false,
              onRetry: () {},
              emptyBuilder: (_) => const SizedBox(),
              loadingBuilder: (_) => const SizedBox(),
              errorBuilder: (_) => const SizedBox(),
              bottomLoaderBuilder: (_) => const SizedBox(),
              physics: const BouncingScrollPhysics(),
              controller: scroll,
              padding: const EdgeInsets.all(8),
              headerSlivers: const [SliverToBoxAdapter(child: Text('Top'))],
              footerSlivers: const [],
              cacheExtent: 500,
              addRepaintBoundaries: true,
              addAutomaticKeepAlives: false,
              scrollThreshold: 2,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              clipBehavior: Clip.none,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Top'), findsOneWidget);
      expect(find.text('Cell 1'), findsOneWidget);
      expect(
        tester
            .widget<PerformanceListView<int>>(
              find.byType(PerformanceListView<int>),
            )
            .isGrid,
        isTrue,
      );
    });
  });

  group('PerformanceImage', () {
    testWidgets('renders with a placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PerformanceImage(
            imageUrl: 'https://example.com/image.png',
            width: 100,
            height: 100,
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(ColoredBox), findsWidgets);
    });
  });
}
