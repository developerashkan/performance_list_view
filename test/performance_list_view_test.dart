import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance_list_view/performance_list_view.dart';

void main() {
  group('PerformanceListView', () {
    testWidgets('renders list items correctly', (WidgetTester tester) async {
      final items = List.generate(10, (index) => 'Item $index');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceListView<String>(
              items: items,
              itemBuilder: (context, item, index) => ListTile(title: Text(item)),
              onRefresh: () async {},
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 9'), findsOneWidget);
    });

    testWidgets('renders empty builder when no items', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceListView<String>(
              items: const [],
              itemBuilder: (context, item, index) => ListTile(title: Text(item)),
              onRefresh: () async {},
              emptyBuilder: (context) => const Text('Empty List'),
            ),
          ),
        ),
      );

      expect(find.text('Empty List'), findsOneWidget);
    });

    testWidgets('triggers onRefresh when pulled down', (WidgetTester tester) async {
      bool refreshed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceListView<String>(
              items: List.generate(20, (index) => 'Item $index'),
              itemBuilder: (context, item, index) => ListTile(title: Text(item)),
              onRefresh: () async {
                refreshed = true;
              },
            ),
          ),
        ),
      );

      // Scroll a bit then pull
      await tester.drag(find.text('Item 0'), const Offset(0.0, 500.0));
      await tester.pumpAndSettle();

      expect(refreshed, isTrue);
    });
  });

  group('PerformanceImage', () {
    testWidgets('renders with placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PerformanceImage(
            imageUrl: 'https://example.com/image.png',
            width: 100,
            height: 100,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
