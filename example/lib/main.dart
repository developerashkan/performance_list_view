import 'package:flutter/material.dart';
import 'src/chat_demo.dart';
import 'src/contacts_demo.dart';
import 'src/data.dart';
import 'src/errors_demo.dart';
import 'src/feed_demo.dart';
import 'src/gallery_demo.dart';

void main() => runApp(const GalleryApp());

enum Demo {
  feed('Feed', Icons.dynamic_feed_outlined, Icons.dynamic_feed_rounded),
  gallery('Masonry', Icons.dashboard_outlined, Icons.dashboard_rounded),
  contacts('Contacts', Icons.contacts_outlined, Icons.contacts_rounded),
  chat('AI chat', Icons.auto_awesome_outlined, Icons.auto_awesome_rounded),
  errors('Errors', Icons.wifi_off_outlined, Icons.wifi_off_rounded);

  const Demo(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const seed = Color(0xFF5B5BF7);

ThemeData buildTheme(Brightness brightness) => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
);

/// The example gallery. The parameters exist for tests and screenshots.
class GalleryApp extends StatefulWidget {
  const GalleryApp({
    super.key,
    this.initialDemo = Demo.feed,
    this.themeMode = ThemeMode.light,
    this.rtl = false,
    this.latency = const Duration(milliseconds: 900),
    this.tokenInterval = const Duration(milliseconds: 35),
    this.chatPrompt,
    this.failFirstPage = false,
  });

  final Demo initialDemo;
  final ThemeMode themeMode;
  final bool rtl;
  final Duration latency;
  final Duration tokenInterval;
  final String? chatPrompt;
  final bool failFirstPage;

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  late ThemeMode _mode = widget.themeMode;
  late bool _rtl = widget.rtl;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PerformanceListView',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: _mode,
      builder: (context, child) => Directionality(
        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      home: Shell(
        initialDemo: widget.initialDemo,
        latency: widget.latency,
        tokenInterval: widget.tokenInterval,
        chatPrompt: widget.chatPrompt,
        failFirstPage: widget.failFirstPage,
        dark: _mode == ThemeMode.dark,
        rtl: _rtl,
        onToggleTheme: () => setState(
          () => _mode = _mode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark,
        ),
        onToggleRtl: () => setState(() => _rtl = !_rtl),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.initialDemo,
    required this.latency,
    required this.tokenInterval,
    required this.chatPrompt,
    required this.failFirstPage,
    required this.dark,
    required this.rtl,
    required this.onToggleTheme,
    required this.onToggleRtl,
  });

  final Demo initialDemo;
  final Duration latency;
  final Duration tokenInterval;
  final String? chatPrompt;
  final bool failFirstPage;
  final bool dark;
  final bool rtl;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleRtl;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late Demo _demo = widget.initialDemo;
  late final FakeApi _api = FakeApi(latency: widget.latency);
  // Built on first visit, then kept, so each demo keeps its scroll position.
  final Map<Demo, Widget> _built = {};

  Widget _page(Demo d) => switch (d) {
    Demo.feed => FeedDemo(api: _api),
    Demo.gallery => GalleryDemo(api: _api),
    Demo.contacts => const ContactsDemo(),
    Demo.chat => ChatDemo(
      tokenInterval: widget.tokenInterval,
      autoPrompt: widget.chatPrompt,
    ),
    Demo.errors => ErrorsDemo(
      latency: widget.latency,
      failFirstPage: widget.failFirstPage,
    ),
  };

  @override
  Widget build(BuildContext context) {
    _built.putIfAbsent(_demo, () => _page(_demo));
    final body = IndexedStack(
      index: Demo.values.indexOf(_demo),
      children: [
        for (final d in Demo.values) _built[d] ?? const SizedBox.shrink(),
      ],
    );
    final appBar = AppBar(
      title: Text(_demo == Demo.feed ? 'PerformanceListView' : _demo.label),
      actions: [
        IconButton(
          tooltip: widget.rtl ? 'Left to right' : 'Right to left',
          onPressed: widget.onToggleRtl,
          icon: Icon(
            widget.rtl
                ? Icons.format_textdirection_l_to_r
                : Icons.format_textdirection_r_to_l,
          ),
        ),
        IconButton(
          tooltip: widget.dark ? 'Light theme' : 'Dark theme',
          onPressed: widget.onToggleTheme,
          icon: Icon(
            widget.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 840) {
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                NavigationRail(
                  extended: c.maxWidth >= 1200,
                  selectedIndex: Demo.values.indexOf(_demo),
                  labelType: c.maxWidth >= 1200
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  onDestinationSelected: (i) =>
                      setState(() => _demo = Demo.values[i]),
                  destinations: [
                    for (final d in Demo.values)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: appBar,
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: Demo.values.indexOf(_demo),
            onDestinationSelected: (i) =>
                setState(() => _demo = Demo.values[i]),
            destinations: [
              for (final d in Demo.values)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
