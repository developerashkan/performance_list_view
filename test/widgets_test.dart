import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance_list_view/performance_list_view.dart';

import 'helpers.dart';

void main() {
  group('skeletons', () {
    testWidgets(
      'shimmer animates without rebuilding, and stops for reduced motion',
      (tester) async {
        var builds = 0;
        await tester.pumpWidget(
          host(
            Column(
              children: [
                Builder(
                  builder: (context) {
                    builds++;
                    return const SkeletonListTile();
                  },
                ),
                const SizedBox(width: 120, child: SkeletonCard()),
                const SkeletonBubble(alignEnd: true),
                const SkeletonBox(width: 40, height: 40, circle: true),
              ],
            ),
            reduceMotion: false,
          ),
        );
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(builds, 1);
        await tester.pumpWidget(host(const SkeletonListTile()));
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets('PerformanceShimmer shares one ticker', (tester) async {
      await tester.pumpWidget(
        host(
          const PerformanceShimmer(
            child: Column(
              children: [
                SkeletonListTile(),
                SkeletonListTile(seed: 1),
                SkeletonListTile(seed: 2),
              ],
            ),
          ),
          reduceMotion: false,
        ),
      );
      expect(tester.binding.transientCallbackCount, 1);
      await tester.pumpWidget(
        host(
          const PerformanceShimmer(enabled: false, child: SkeletonListTile()),
          reduceMotion: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a skeleton announces a loading label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const SkeletonListTile()));
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      handle.dispose();
    });
  });

  group('theme', () {
    testWidgets('defaults come from the color scheme, light and dark', (
      tester,
    ) async {
      ResolvedPerformanceListTheme? resolved;
      ColorScheme? scheme;
      Widget probe() => Builder(
        builder: (c) {
          resolved = PerformanceListThemeData.of(c);
          scheme = Theme.of(c).colorScheme;
          return const SizedBox();
        },
      );
      await tester.pumpWidget(host(probe()));
      final light = resolved!;
      final lightScheme = scheme!;
      await tester.pumpWidget(host(probe(), brightness: Brightness.dark));
      await tester.pumpAndSettle();
      final dark = resolved!;
      final darkScheme = scheme!;
      expect(light.skeletonBaseColor, lightScheme.surfaceContainerHighest);
      expect(dark.skeletonBaseColor, darkScheme.surfaceContainerHighest);
      expect(light.userBubbleColor, lightScheme.primary);
      expect(dark.pillBackgroundColor, darkScheme.inverseSurface);
      expect(light.skeletonBaseColor, isNot(dark.skeletonBaseColor));
    });

    testWidgets('extension values and texts override the defaults', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [
              PerformanceListThemeData(
                accentColor: Color(0xFFFF0000),
                reduceMotion: true,
                texts: PerformanceListTexts(
                  endOfList: 'Fin',
                  loadingMore: 'Chargement',
                ),
              ),
            ],
          ),
          home: const Scaffold(
            body: Column(
              children: [PerformanceEndFooter(), PerformanceLoadingFooter()],
            ),
          ),
        ),
      );
      expect(find.text('Fin'), findsOneWidget);
      expect(find.text('Chargement'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
      expect(icon.color, const Color(0xFFFF0000));
    });

    test('lerp and copyWith', () {
      const a = PerformanceListThemeData(
        skeletonRadius: 0,
        accentColor: Color(0xFF000000),
      );
      const b = PerformanceListThemeData(
        skeletonRadius: 10,
        accentColor: Color(0xFFFFFFFF),
      );
      expect(a.lerp(b, 0.5).skeletonRadius, 5);
      expect(a.copyWith(bubbleRadius: 3).bubbleRadius, 3);
      expect(a.copyWith(bubbleRadius: 3).skeletonRadius, 0);
    });
  });

  group('PerformanceImage', () {
    testWidgets('decodes at display size times the pixel ratio', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: PerformanceImage(
            imageUrl: 'https://example.com/a.png',
            width: 100,
            height: 50,
          ),
        ),
      );
      final resize =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      // Cover keeps one bound so the aspect ratio is not squashed.
      expect(resize.width, 300);
      expect(resize.height, isNull);
      await tester.pumpWidget(
        const MaterialApp(
          home: PerformanceImage(
            imageUrl: 'https://example.com/a.png',
            memCacheWidth: 64,
            memCacheHeight: 32,
          ),
        ),
      );
      final explicit =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect((explicit.width, explicit.height), (64, 32));
    });

    testWidgets('takes a custom provider and shows the error widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceImage(
            imageUrl: 'unused',
            width: 80,
            height: 80,
            borderRadius: 12,
            imageProvider: const _FailingImage(),
            errorWidget: (_, url, e) => Text('failed $url'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('failed unused'), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });

  group('AI widgets', () {
    testWidgets('chat bubbles align by sender', (tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            children: [
              ChatBubble(isUser: true, child: Text('me')),
              ChatBubble(
                header: Text('AI'),
                footer: Text('now'),
                child: Text('bot'),
              ),
            ],
          ),
        ),
      );
      expect(tester.getTopRight(find.text('me')).dx, greaterThan(300));
      expect(tester.getTopLeft(find.text('bot')).dx, lessThan(100));
      expect(find.text('AI'), findsOneWidget);
    });

    testWidgets('chat bubbles mirror in right-to-left layouts', (tester) async {
      await tester.pumpWidget(
        host(
          const ChatBubble(isUser: true, child: Text('me')),
          direction: TextDirection.rtl,
        ),
      );
      expect(tester.getTopLeft(find.text('me')).dx, lessThan(100));
    });

    testWidgets('typing indicator and pill labels', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        host(
          Column(
            children: [
              const TypingBubble(),
              JumpToLatestPill(onPressed: () => taps++, unread: 1),
              JumpToLatestPill(onPressed: () => taps++),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Typing'), findsOneWidget);
      expect(find.text('1 new message'), findsOneWidget);
      await tester.tap(find.text('Jump to latest'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('streaming text shows a cursor until complete', (tester) async {
      final s = StreamingTextController(text: 'Hi');
      addTearDown(s.dispose);
      await tester.pumpWidget(host(StreamingText(controller: s)));
      final cursor = find.descendant(
        of: find.byType(StreamingText),
        matching: find.byType(FadeTransition),
      );
      expect(cursor, findsOneWidget);
      s.append(' there');
      s.complete();
      await tester.pump();
      expect(find.text('Hi there', findRichText: true), findsOneWidget);
      expect(cursor, findsNothing);
    });

    testWidgets('default state views', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        host(
          ListView(
            children: [
              const SizedBox(
                height: 300,
                child: PerformanceEmptyView(title: 'Empty', message: 'Nothing'),
              ),
              SizedBox(
                height: 300,
                child: PerformanceErrorView(onRetry: () => retried++),
              ),
              PerformanceErrorFooter(onRetry: () => retried++),
            ],
          ),
        ),
      );
      expect(find.text('Empty'), findsOneWidget);
      await tester.tap(find.text('Try again').first);
      await tester.tap(find.text('Try again').last);
      expect(retried, 2);
    });
  });
}

class _FailingImage extends ImageProvider<_FailingImage> {
  const _FailingImage();

  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_FailingImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingImage key,
    ImageDecoderCallback decode,
  ) =>
      OneFrameImageStreamCompleter(Future<ImageInfo>.error(StateError('nope')));
}
