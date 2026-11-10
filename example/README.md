# performance_list_view example

A gallery of every feature, adaptive from phone to desktop:

- **Feed**: infinite scroll with `PagingController.byPage`, skeletons, pull-to-refresh, separators and back-to-top with `scrollToIndex`.
- **Masonry**: `PerformanceListView.masonry` with columns that follow the window width.
- **Contacts**: sticky section headers and an A–Z index bar driven by `scrollToIndex`.
- **AI chat**: `PerformanceChatView` with replies streamed token by token, a typing indicator and a jump-to-latest pill.
- **Errors**: make the first page or page 2 fail and watch the list recover with retry.

```bash
flutter run -d chrome
```
