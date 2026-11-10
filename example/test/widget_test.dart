import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance_list_view/performance_list_view.dart';
import 'package:performance_list_view_example/main.dart';

void main() {
  setUp(() {
    // Still spinners and skeletons, so frames settle.
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });

  Future<void> open(
    WidgetTester tester,
    Demo demo, {
    Size size = const Size(400, 860),
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GalleryApp(
        initialDemo: demo,
        latency: const Duration(milliseconds: 50),
        tokenInterval: const Duration(milliseconds: 5),
      ),
    );
  }

  testWidgets('feed loads pages and shows skeletons first', (tester) async {
    await open(tester, Demo.feed);
    await tester.pump();
    expect(find.byType(SkeletonListTile), findsWidgets);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(SkeletonListTile), findsNothing);
    expect(find.textContaining('@'), findsWidgets);
  });

  testWidgets('masonry gallery renders photos', (tester) async {
    await open(tester, Demo.gallery);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('1'), findsWidgets);
  });

  testWidgets('contacts index bar jumps to a letter', (tester) async {
    await open(tester, Demo.contacts);
    await tester.pump();
    await tester.tap(find.text('M').last);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final header = find.widgetWithText(PerformanceSectionHeader, 'M');
    expect(header, findsOneWidget);
    // Pinned right under the app bar, with the first "M" contact below it.
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    expect(tester.getTopLeft(header).dy, closeTo(appBarBottom, 1));
  });

  testWidgets('AI chat streams a reply', (tester) async {
    await open(tester, Demo.chat);
    await tester.pump();
    await tester.tap(find.text('Why is it fast?'));
    await tester.pump();
    expect(find.text('Why is it fast?'), findsNWidgets(2)); // chip and bubble
    await tester.pump(const Duration(milliseconds: 800));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(
      find.textContaining('Three reasons', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('errors demo recovers with retry', (tester) async {
    await open(tester, Demo.errors);
    await tester.tap(find.text('Fail first page'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PerformanceErrorView), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PerformanceErrorView), findsNothing);
    expect(find.textContaining('@'), findsWidgets);
  });

  testWidgets(
    'desktop width uses a navigation rail, and every destination opens',
    (tester) async {
      await open(tester, Demo.feed, size: const Size(1280, 800));
      await tester.pump();
      expect(find.byType(NavigationRail), findsOneWidget);
      for (final d in Demo.values) {
        await tester.tap(find.text(d.label).last);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
