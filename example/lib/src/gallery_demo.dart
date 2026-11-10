import 'package:flutter/material.dart';
import 'package:performance_list_view/performance_list_view.dart';

import 'common.dart';
import 'data.dart';

/// Masonry grid: columns adapt to the width, pages load as you scroll.
class GalleryDemo extends StatefulWidget {
  const GalleryDemo({super.key, required this.api});
  final FakeApi api;

  @override
  State<GalleryDemo> createState() => _GalleryDemoState();
}

class _GalleryDemoState extends State<GalleryDemo> {
  late final PagingController<int, Photo> _photos =
      PagingController.byPage<Photo>(pageSize: 18, fetch: widget.api.photos);

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PerformanceListView<Photo>.masonry(
      listController: _photos,
      maxCrossAxisExtent: 230,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemKey: (p) => p.id,
      itemBuilder: (context, photo, _) => PhotoCard(photo: photo),
    );
  }
}

class PhotoCard extends StatelessWidget {
  const PhotoCard({super.key, required this.photo});
  final Photo photo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: photo.aspect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Art(colors: photo.colors, seed: photo.id),
              PositionedDirectional(
                top: 8,
                end: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${photo.likes}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 0),
          child: Text(
            photo.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
