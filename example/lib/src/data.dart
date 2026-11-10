// Deterministic fake data and APIs for the gallery. Nothing touches the
// network, so the demos run anywhere, including tests and screenshots.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

const _first = [
  'Ava',
  'Leo',
  'Mina',
  'Noah',
  'Sara',
  'Omid',
  'Ella',
  'Kai',
  'Zoe',
  'Ravi',
  'Lena',
  'Theo', //
  'Nora',
  'Arash',
  'Ivy',
  'Hugo',
  'Maya',
  'Felix',
  'Yara',
  'Jonas',
  'Aria',
  'Elias',
  'Dina',
  'Bruno',
];
const _last = [
  'Chen',
  'Park',
  'Rahimi',
  'Kim',
  'Lopez',
  'Karimi',
  'Novak',
  'Tanaka',
  'Martin',
  'Shah', //
  'Weber',
  'Costa',
  'Silva',
  'Haddad',
  'Ito',
  'Jansen',
  'Moreau',
  'Rossi',
  'Berg',
  'Duarte',
];
const _bodies = [
  'Shipped infinite scroll today. The first page was shorter than the screen and it still loaded the next one by itself.',
  'Hot take: skeletons beat spinners. Your eyes already know where the content will land.',
  'Pull to refresh while a page is loading used to mix old and new data. Not anymore.',
  'Our chat view keeps you pinned while the reply streams in, and never yanks you down while you read history.',
  'Masonry grid with 10k items, only the visible ones are built. Smooth on a five-year-old phone.',
  'Tip: give every item a key. State follows the item when you insert above it.',
  'Dark mode came for free: every color is read from the ColorScheme.',
  'Turned on reduced motion and every shimmer and pill animation calmed down.',
  'Right-to-left works too: the masonry columns and chat bubbles mirror.',
  'Lazy loading that never gets stuck on "loading": errors stop and wait for retry.',
];
const _palette = [
  (Color(0xFF6D5DF6), Color(0xFF41C7F2)),
  (Color(0xFFFF7A8A), Color(0xFFFFC36B)),
  (Color(0xFF11998E), Color(0xFF38EF7D)),
  (Color(0xFFFC5C7D), Color(0xFF6A82FB)),
  (Color(0xFF8E2DE2), Color(0xFFF000FF)),
  (Color(0xFF00B4DB), Color(0xFF0083B0)),
  (Color(0xFFF7971E), Color(0xFFFFD200)),
  (Color(0xFF4568DC), Color(0xFFB06AB3)),
];
const _titles = [
  'Aurora',
  'Dune',
  'Lagoon',
  'Ember',
  'Nebula',
  'Citrus',
  'Glacier',
  'Orchid',
  'Canyon',
  'Tide', //
  'Meadow', 'Comet', 'Coral', 'Prism', 'Summit', 'Velvet',
];

class Post {
  const Post({
    required this.id,
    required this.author,
    required this.body,
    required this.minutes,
    required this.likes,
    required this.replies,
    required this.colors,
    required this.hasImage,
  });

  final int id;
  final String author;
  final String body;
  final int minutes;
  final int likes;
  final int replies;
  final (Color, Color) colors;
  final bool hasImage;

  String get handle => '@${author.split(' ').first.toLowerCase()}';
  String get initials => author.split(' ').map((p) => p[0]).join();
  String get ago => minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h';
}

Post postAt(int id) {
  final r = Random(id * 7919 + 17);
  return Post(
    id: id,
    author:
        '${_first[r.nextInt(_first.length)]} ${_last[r.nextInt(_last.length)]}',
    body: _bodies[r.nextInt(_bodies.length)],
    minutes: 2 + id * 7 + r.nextInt(6),
    likes: r.nextInt(900) + 12,
    replies: r.nextInt(80),
    colors: _palette[r.nextInt(_palette.length)],
    hasImage: r.nextInt(3) == 0,
  );
}

class Photo {
  const Photo(this.id, this.title, this.colors, this.aspect, this.likes);
  final int id;
  final String title;
  final (Color, Color) colors;
  final double aspect; // width / height
  final int likes;
}

Photo photoAt(int id) {
  final r = Random(id * 104729 + 3);
  const aspects = [0.66, 0.8, 1.0, 1.25, 0.75, 1.5, 0.9];
  return Photo(
    id,
    '${_titles[r.nextInt(_titles.length)]} ${id + 1}',
    _palette[r.nextInt(_palette.length)],
    aspects[r.nextInt(aspects.length)],
    r.nextInt(4000) + 40,
  );
}

class Contact {
  const Contact(this.id, this.name, this.role, this.colors);
  final int id;
  final String name;
  final String role;
  final (Color, Color) colors;
  String get initials => name.split(' ').map((p) => p[0]).join();
}

List<Contact> contacts() {
  const roles = [
    'Design',
    'Engineering',
    'Product',
    'Research',
    'Marketing',
    'Support',
  ];
  final seen = <String>{};
  final out = <Contact>[];
  for (var i = 0; out.length < 180; i++) {
    final r = Random(i * 31 + 7);
    final name =
        '${_first[r.nextInt(_first.length)]} ${_last[r.nextInt(_last.length)]}';
    if (!seen.add(name)) continue;
    out.add(
      Contact(
        out.length,
        name,
        roles[r.nextInt(roles.length)],
        _palette[r.nextInt(_palette.length)],
      ),
    );
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}

/// A paged API with latency and switchable failures.
class FakeApi {
  FakeApi({this.latency = const Duration(milliseconds: 900), this.pages = 8});

  Duration latency;
  final int pages;
  bool failFirstPage = false;
  int? failPage;
  int requests = 0;

  Future<List<Post>> posts(int page, int pageSize) async {
    requests++;
    // Decided when the request starts, like a real server would.
    final failFirst = page == 1 && failFirstPage;
    final failThis = page == failPage;
    if (failFirst) failFirstPage = false;
    if (failThis) failPage = null;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (failFirst) {
      throw const NetworkException('The server took too long to answer.');
    }
    if (failThis) {
      throw const NetworkException('Connection lost while loading page.');
    }
    if (page > pages) return const [];
    return [
      for (var i = 0; i < pageSize; i++) postAt((page - 1) * pageSize + i),
    ];
  }

  Future<List<Photo>> photos(int page, int pageSize) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (page > pages) return const [];
    return [
      for (var i = 0; i < pageSize; i++) photoAt((page - 1) * pageSize + i),
    ];
  }
}

class NetworkException implements Exception {
  const NetworkException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Canned assistant replies, streamed word by word.
const assistantReplies = {
  'Why is it fast?':
      'Three reasons. Items are built lazily by slivers, so only what is on screen exists. '
      'Each built item is cached, so appending a page rebuilds zero visible items. '
      'And while I stream this answer, only this bubble rebuilds, token by token.',
  'Explain pagination':
      'The PagingController loads one page at a time. Calls during a load are ignored, '
      'stale pages after a refresh are dropped, errors wait for a retry, and the next page '
      'loads by itself when the first one does not fill the screen. No more stuck spinners.',
  'Show a chat recipe':
      'Keep messages newest first in a PerformanceListController. Prepend each new message, '
      'give the reply a StreamingTextController, and bind it to your model stream. '
      'The view stays pinned to the bottom while you read along.',
};

const fallbackReply =
    'Good question! This demo streams canned answers, but the list does not care where '
    'tokens come from: bind any Stream<String> from your model and it renders as it arrives.';

/// Splits [text] into word-sized tokens, like an LLM stream.
Stream<String> tokenStream(
  String text, {
  Duration every = const Duration(milliseconds: 35),
}) async* {
  final words = RegExp(r'\S+\s*').allMatches(text).map((m) => m[0]!);
  for (final w in words) {
    await Future<void>.delayed(every);
    yield w;
  }
}
