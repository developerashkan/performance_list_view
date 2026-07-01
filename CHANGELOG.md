## 0.0.5
* **Major Performance Overhaul**: Switched to a fully Sliver-based architecture using `CustomScrollView` for maximum efficiency and flexibility.
* **Extensibility**: Added support for `headerSlivers` and `footerSlivers`, allowing developers to easily add headers, footers, or other sliver widgets.
* **Customization**: Introduced `itemBuilder`, `emptyBuilder`, `loadingBuilder`, `errorBuilder`, and `bottomLoaderBuilder` for full control over the UI in different states.
* **Optimization**: 
    * Integrated `RepaintBoundary` for each list item to minimize unnecessary repaints.
    * Added `itemExtent` and `prototypeItem` support for massive performance gains in long lists.
    * Enhanced `PerformanceImage` with `memCacheHeight` and `memCacheWidth` for better memory management.
* **Maintenance**: Ran `dart fix` and updated project for Flutter 3.44.0 and Dart 3.12.0.
* **Testing**: Added a suite of widget tests to ensure reliability.

## 0.0.4
* Compatible with latest Dart version
## 0.0.3

* fix warnings
## 0.0.2

* add some improvements
## 0.0.1

* Initial release of `PerformanceListView`.
* Core support for automatic pagination and smart image memory caching.
* Integrated Sliver support for `CustomScrollView`.