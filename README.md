# ⚡ PerformanceListView

[![Pub Version](https://img.shields.io/pub/v/performance_list_view)](https://pub.dev/packages/performance_list_view)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)](https://flutter.dev)

**Stop reinventing the wheel.** `PerformanceListView` is a production-ready, drop-in replacement for Flutter's standard ListView/GridView. It eliminates boilerplate by handling **Pagination**, **Pull-to-Refresh**, **Error States**, and **Memory-Optimized Caching** right out of the box.

<p align="center">
  <img src="https://github.com/user-attachments/assets/df5cf389-9890-4f31-bd10-1888a7bb84a4"
       alt="Ollama Local Chat Flutter UI"
       width="360" />
</p>

## 🚀 Why PerformanceListView?

Standard Flutter lists become complex quickly when you add infinite scrolling and remote images. `PerformanceListView` solves:
* **Jank-Free Scrolling:** Uses `RepaintBoundary` to isolate item paints.
* **Memory Bloat:** `PerformanceImage` automatically resizes images to their display size in memory.
* **Boilerplate:** No more manual `ScrollController` listeners for pagination.
* **Robust UX:** Built-in "Retry" buttons for errors and "Empty" states for no data.

## ✨ Key Features
*  **Auto-Pagination:** Simple `onEndReached` callback.
*  **Grid Support:** Easy switch to `PerformanceListView.grid`.
*  **Sliver Ready:** Exported as `SliverPerformanceListView` for complex `CustomScrollView` layouts.
*  **Smart Caching:** Built-in wrapper for `CachedNetworkImage` with optimized memory usage.
*  **Refreshable:** Seamless integration with `RefreshIndicator`.

## 📦 Installation

Add this to your `pubspec.yaml`:
```yaml
dependencies:
  performance_list_view: ^0.0.3
