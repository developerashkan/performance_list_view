// Renders the README / pub.dev screenshots and GIF frames with real fonts.
//
//   cd example
//   flutter test test/screenshots_test.dart --dart-define=CAPTURE=true
//   python tool/make_media.py
//
// Writes ../assets/screenshots/*.png and build/frames/*.png.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance_list_view_example/main.dart';

import 'support/capture.dart';

const _capture = bool.fromEnvironment('CAPTURE');
const _out = '../assets/screenshots';
const _phone = Size(393, 852);

void main() {
  Future<GlobalKey> mount(
    WidgetTester tester,
    Widget app, {
    Size size = _phone,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: app));
    return key;
  }

  Future<void> wait(
    WidgetTester tester,
    Duration total, {
    Duration step = const Duration(milliseconds: 16),
  }) async {
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('screenshots', (tester) async {
    if (!_capture) return;
    await loadRealFonts(tester);
    addTearDown(tester.view.reset);
    const latency = Duration(milliseconds: 400);

    // Feed, first load: shimmering skeletons, caught mid-sweep.
    var key = await mount(
      tester,
      GalleryApp(key: UniqueKey(), latency: const Duration(seconds: 5)),
    );
    await wait(tester, const Duration(milliseconds: 620));
    await capturePng(tester, key, '$_out/phone_loading_light.png');
    await done(tester);

    // Feed, loaded.
    key = await mount(tester, GalleryApp(key: UniqueKey(), latency: latency));
    await wait(tester, const Duration(milliseconds: 1500));
    await capturePng(tester, key, '$_out/phone_feed_light.png');
    await done(tester);

    // Masonry, dark.
    key = await mount(
      tester,
      GalleryApp(
        key: UniqueKey(),
        initialDemo: Demo.gallery,
        themeMode: ThemeMode.dark,
        latency: latency,
      ),
    );
    await wait(tester, const Duration(milliseconds: 1500));
    await capturePng(tester, key, '$_out/phone_masonry_dark.png');
    await done(tester);

    // Contacts, scrolled so a header is pinned.
    key = await mount(
      tester,
      GalleryApp(
        key: UniqueKey(),
        initialDemo: Demo.contacts,
        latency: latency,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('E').last);
    await wait(tester, const Duration(milliseconds: 700));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
    await wait(tester, const Duration(milliseconds: 600));
    await capturePng(tester, key, '$_out/phone_contacts_light.png');
    await done(tester);

    // AI chat, dark, mid-stream.
    key = await mount(
      tester,
      GalleryApp(
        key: UniqueKey(),
        initialDemo: Demo.chat,
        themeMode: ThemeMode.dark,
        chatPrompt: 'Why is it fast?',
      ),
    );
    await wait(tester, const Duration(milliseconds: 1900));
    await capturePng(tester, key, '$_out/phone_chat_dark.png');
    await done(tester);

    // AI chat, scrolled up while a reply arrives: the pill counts it.
    key = await mount(
      tester,
      GalleryApp(
        key: UniqueKey(),
        initialDemo: Demo.chat,
        rtl: false,
        tokenInterval: const Duration(milliseconds: 5),
      ),
    );
    await tester.pump();
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 420),
    );
    await wait(tester, const Duration(milliseconds: 900));
    await tester.tap(find.text('Explain pagination'));
    await wait(tester, const Duration(milliseconds: 1800));
    await capturePng(tester, key, '$_out/phone_chat_pill_light.png');
    await done(tester);

    // Errors: page 2 failed, the footer offers a retry.
    key = await mount(
      tester,
      GalleryApp(key: UniqueKey(), initialDemo: Demo.errors, latency: latency),
    );
    await wait(tester, const Duration(milliseconds: 1400));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await wait(tester, const Duration(milliseconds: 1400));
    await capturePng(tester, key, '$_out/phone_errors_light.png');
    await done(tester);

    // Right-to-left masonry.
    key = await mount(
      tester,
      GalleryApp(
        key: UniqueKey(),
        initialDemo: Demo.gallery,
        rtl: true,
        latency: latency,
      ),
    );
    await wait(tester, const Duration(milliseconds: 1500));
    await capturePng(tester, key, '$_out/phone_masonry_rtl_light.png');
    await done(tester);

    // Desktop: rail + masonry.
    key = await mount(
      tester,
      GalleryApp(key: UniqueKey(), initialDemo: Demo.gallery, latency: latency),
      size: const Size(1280, 800),
    );
    await wait(tester, const Duration(milliseconds: 1500));
    await capturePng(
      tester,
      key,
      '$_out/desktop_masonry_light.png',
      pixelRatio: 1.5,
    );
    await done(tester);

    // Desktop: AI chat, dark.
    key = await mount(
      tester,
      GalleryApp(
        key: UniqueKey(),
        initialDemo: Demo.chat,
        themeMode: ThemeMode.dark,
        chatPrompt: 'Show a chat recipe',
      ),
      size: const Size(1280, 800),
    );
    await wait(tester, const Duration(milliseconds: 2600));
    await capturePng(
      tester,
      key,
      '$_out/desktop_chat_dark.png',
      pixelRatio: 1.5,
    );
    await done(tester);
  });

  testWidgets('hero GIF frames', (tester) async {
    if (!_capture) return;
    await loadRealFonts(tester);
    addTearDown(tester.view.reset);
    final key = await mount(
      tester,
      const GalleryApp(
        initialDemo: Demo.chat,
        tokenInterval: Duration(milliseconds: 60),
      ),
    );
    var frame = 0;
    Future<void> shot() => capturePng(
      tester,
      key,
      'build/frames/f${(frame++).toString().padLeft(3, '0')}.png',
      pixelRatio: 2,
    );
    const step = Duration(milliseconds: 83);
    for (var i = 0; i < 6; i++) {
      await tester.pump(step);
      await shot();
    }
    await tester.tap(find.text('Why is it fast?'));
    // Typing indicator, then the reply streams in.
    for (var i = 0; i < 62; i++) {
      await tester.pump(step);
      await shot();
    }
    // Hold the finished answer.
    for (var i = 0; i < 10; i++) {
      await tester.pump(step);
      await shot();
    }
    await done(tester);
  });
}
