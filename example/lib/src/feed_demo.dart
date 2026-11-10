import 'package:flutter/material.dart';
import 'package:performance_list_view/performance_list_view.dart';

import 'common.dart';
import 'data.dart';

/// Infinite feed: page loading, skeletons, pull-to-refresh, scroll-to-top.
class FeedDemo extends StatefulWidget {
  const FeedDemo({super.key, required this.api});
  final FakeApi api;

  @override
  State<FeedDemo> createState() => _FeedDemoState();
}

class _FeedDemoState extends State<FeedDemo> {
  late final PagingController<int, Post> _posts = PagingController.byPage<Post>(
    pageSize: 12,
    fetch: widget.api.posts,
  );
  final _scroll = ScrollController();
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 1200;
      if (show != _showTop) setState(() => _showTop = show);
    });
  }

  @override
  void dispose() {
    _posts.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Readable(
          child: PerformanceListView<Post>(
            listController: _posts,
            controller: _scroll,
            itemKey: (p) => p.id,
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            separatorBuilder: (context, _) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, post, _) => PostTile(post: post),
          ),
        ),
        PositionedDirectional(
          end: 20,
          bottom: 20,
          child: AnimatedScale(
            scale: _showTop ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton.small(
              tooltip: 'Back to top',
              onPressed: () => _posts.scrollToIndex(0),
              child: const Icon(Icons.vertical_align_top_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(initials: post.initials, colors: post.colors),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        post.author,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${post.handle} · ${post.ago}', style: muted),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  post.body,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
                if (post.hasImage) ...[
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Art(colors: post.colors, seed: post.id),
                  ),
                ],
                const SizedBox(height: 8),
                DefaultTextStyle.merge(
                  style: muted,
                  child: IconTheme.merge(
                    data: IconThemeData(size: 17, color: cs.onSurfaceVariant),
                    child: Row(
                      children: [
                        const Icon(Icons.mode_comment_outlined),
                        const SizedBox(width: 5),
                        Text('${post.replies}'),
                        const SizedBox(width: 22),
                        const Icon(Icons.favorite_border_rounded),
                        const SizedBox(width: 5),
                        Text('${post.likes}'),
                        const SizedBox(width: 22),
                        const Icon(Icons.ios_share_rounded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
