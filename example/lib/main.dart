import 'package:flutter/material.dart';
import 'package:performance_list_view/performance_list_view.dart';

void main() {
  runApp(const MaterialApp(
    home: AdvancedPage(),
    debugShowCheckedModeBanner: false,
  ));
}

class AdvancedPage extends StatefulWidget {
  const AdvancedPage({super.key});

  @override
  State<AdvancedPage> createState() => _AdvancedPageState();
}

class _AdvancedPageState extends State<AdvancedPage> {
  final List<String> _items = List.generate(15, (index) => 'Item $index');
  bool _isLoading = false;
  bool _hasError = false;

  Future<void> _refresh() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _items.clear();
      _items.addAll(List.generate(15, (index) => 'Refreshed $index'));
      _hasError = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading || _hasError) return;

    setState(() => _isLoading = true);

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Simulate random error
    if (DateTime.now().second % 5 == 0) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _items.addAll(List.generate(10, (index) => 'New Item ${_items.length + index}'));
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Performance listview")),
      body: PerformanceListView<String>(
        items: _items,
        isLoading: _isLoading,
        hasError: _hasError,
        onRefresh: _refresh,
        onEndReached: _loadMore,
        onRetry: _loadMore,
        // The retry button calls the load function again
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, item) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade100, width: 1), // Soft border
            ),
            child: ListTile(
              leading: PerformanceImage(
                // Use the item string or index to ensure each image is unique
                imageUrl: 'https://picsum.photos/seed/${item.hashCode}/200/200',
                width: 50,
                height: 50,
                borderRadius: 8,
              ),
              title: Text(item),
              subtitle: const Text("Optimized list item"),
            ),
          );
        },
      ),
    );
  }
}
