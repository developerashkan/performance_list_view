import 'package:flutter/material.dart';
import 'package:performance_list_view/performance_list_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      home: const AdvancedPage(),
    );
  }
}

class AdvancedPage extends StatefulWidget {
  const AdvancedPage({super.key});

  @override
  State<AdvancedPage> createState() => _AdvancedPageState();
}

class _AdvancedPageState extends State<AdvancedPage> {
  final List<String> _items = List.generate(20, (index) => 'Item $index');
  bool _isLoading = false;
  bool _hasError = false;

  Future<void> _refresh() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _items.clear();
      _items.addAll(List.generate(20, (index) => 'Refreshed $index'));
      _hasError = false;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    // FIX: Removed _hasError from the guard block.
    // If we have an error, we WANT this function to run when the user taps Retry.
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false; // Clear previous errors when attempting a new fetch
    });

    await Future.delayed(const Duration(seconds: 2));

    // Randomly fail about 20% of the time to demonstrate error handling
    if (DateTime.now().second % 5 == 0) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _items.addAll(
          List.generate(15, (index) => 'New Item ${_items.length + index}'));
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: PerformanceListView<String>(
        items: _items,
        isLoading: _isLoading,
        hasError: _hasError,
        onRefresh: _refresh,
        onEndReached: _loadMore,
        onRetry: _loadMore,
        itemExtent: 90.0, // Fixed height for O(1) performance
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        headerSlivers: [
          SliverAppBar.large(
            expandedHeight: 150.0,
            floating: true,
            pinned: true,
            snap: true,
            stretch: true,
            title: const Text("Modern List", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
          ),
        ],
        itemBuilder: (context, item, index) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: PerformanceImage(
                imageUrl: 'https://picsum.photos/seed/${item.hashCode}/200/200',
                width: 54,
                height: 54,
                borderRadius: 10,
              ),
              title: Text(
                item,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                "High performance list item #$index",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
            ),
          );
        },
      ),
    );
  }
}