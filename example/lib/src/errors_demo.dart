import 'package:flutter/material.dart';
import 'package:performance_list_view/performance_list_view.dart';

import 'common.dart';
import 'data.dart';
import 'feed_demo.dart';

/// Error and retry lab: make pages fail and watch the list recover.
class ErrorsDemo extends StatefulWidget {
  const ErrorsDemo({
    super.key,
    required this.latency,
    this.failFirstPage = false,
  });
  final Duration latency;
  final bool failFirstPage;

  @override
  State<ErrorsDemo> createState() => _ErrorsDemoState();
}

class _ErrorsDemoState extends State<ErrorsDemo> {
  late final FakeApi _api = FakeApi(latency: widget.latency, pages: 4)
    ..failFirstPage = widget.failFirstPage
    ..failPage = 2;
  late final PagingController<int, Post> _posts = PagingController.byPage<Post>(
    pageSize: 8,
    fetch: _api.posts,
    fetchTimeout: const Duration(seconds: 8),
  );

  @override
  void dispose() {
    _posts.dispose();
    super.dispose();
  }

  void _restart({bool failFirst = false, int? failPage}) {
    _api
      ..failFirstPage = failFirst
      ..failPage = failPage;
    _posts.reset();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Readable(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _restart(failFirst: true),
                  icon: const Icon(Icons.cloud_off_rounded),
                  label: const Text('Fail first page'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _restart(failPage: 2),
                  icon: const Icon(Icons.wifi_off_rounded),
                  label: const Text('Fail page 2'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _restart(),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Start over'),
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: _posts,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: Row(
                children: [
                  _StatusDot(status: _posts.status),
                  const SizedBox(width: 8),
                  Text(_posts.status.name, style: theme.textTheme.labelLarge),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_posts.length} items · ${_posts.pagesLoaded} ${_posts.pagesLoaded == 1 ? 'page' : 'pages'} · ${_api.requests} requests',
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: PerformanceListView<Post>(
              listController: _posts,
              itemKey: (p) => p.id,
              separatorBuilder: (context, _) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, post, _) => PostTile(post: post),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final PagingStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (status) {
      PagingStatus.firstPageError || PagingStatus.loadMoreError => cs.error,
      PagingStatus.completed => Colors.green,
      PagingStatus.idle => cs.outline,
      _ => cs.primary,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
