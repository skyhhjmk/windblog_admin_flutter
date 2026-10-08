import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/l10n/app_localizations.dart';
import 'package:windblog_admin_flutter/main.dart';

void main() {
  testWidgets('媒体库支持滚动加载、页码同步、跳页和失败重试', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = _MediaApiStub(totalPages: 3)..failingPages.add(2);
    final notifications = AdminNotificationController();
    addTearDown(notifications.clear);

    await tester.pumpWidget(_buildMediaLibrary(api, notifications));
    await tester.pumpAndSettle();

    expect(api.requestedPages, [1]);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2400));
    await tester.pumpAndSettle();
    expect(api.requestedPages, [1, 2]);
    expect(find.text('重试'), findsOneWidget);

    api.failingPages.clear();
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(api.requestedPages, [1, 2, 2]);
    expect(find.text('重试'), findsNothing);

    await tester.enterText(find.byType(TextField), '2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();
    Finder mediaCard(int id) => find
        .ancestor(of: find.text('媒体 $id'), matching: find.byType(Card))
        .first;
    final previousPageCard = tester.getRect(mediaCard(23));
    final previousRowCard = tester.getRect(mediaCard(19));
    final nextPageCard = tester.getRect(mediaCard(24));
    final regularRowGap = previousPageCard.top - previousRowCard.bottom;
    final pageBoundaryGap = nextPageCard.top - previousPageCard.bottom;
    expect(pageBoundaryGap, closeTo(regularRowGap, 0.5));

    await tester.enterText(find.byType(TextField), '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(api.requestedPages, [1, 2, 2, 3]);
    expect(find.text('3 / 3'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2400));
    await tester.pumpAndSettle();
    expect(api.requestedPages, [1, 2, 2, 3]);
    expect(find.text('3 / 3'), findsOneWidget);

    // The failed request creates a five second transient notification timer.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}

Widget _buildMediaLibrary(
  _MediaApiStub api,
  AdminNotificationController notifications,
) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('zh', ''), Locale('en', '')],
    locale: const Locale('zh', ''),
    home: AdminNotificationHost(
      api: api,
      controller: notifications,
      child: Theme(
        data: AdminTheme.build(),
        child: Scaffold(
          body: MediaLibraryPage(api: api, onAuthError: () {}),
        ),
      ),
    ),
  );
}

class _MediaApiStub extends AdminApiClient {
  _MediaApiStub({required this.totalPages});

  final int totalPages;
  final List<int> requestedPages = <int>[];
  final Set<int> failingPages = <int>{};

  @override
  Future<MediaListResult> listMedia({
    int page = 1,
    int pageSize = 20,
    bool unreferenced = false,
    bool failedOnly = false,
  }) async {
    requestedPages.add(page);
    if (failingPages.contains(page)) {
      throw StateError('temporary media page failure');
    }
    final items = List<MediaItem>.generate(pageSize, (index) {
      final id = (page - 1) * pageSize + index;
      return MediaItem(
        id: id,
        storageKey: 'media-$id',
        url: 'https://example.com/media-$id',
        requiresManualOriginal: false,
        fileName: '媒体 $id',
        mimeType: 'application/octet-stream',
        size: 128,
        mediaType: 0,
        createdAt: DateTime.utc(2026),
        referenced: false,
        references: const <MediaReference>[],
      );
    });
    return MediaListResult(
      items: items,
      total: totalPages * pageSize,
      page: page,
      pageSize: pageSize,
    );
  }
}
