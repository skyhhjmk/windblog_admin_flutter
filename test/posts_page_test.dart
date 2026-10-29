import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/main.dart';

class _PostsApi extends AdminApiClient {
  int? lastStatus;

  @override
  Future<PostListResult> listPosts({
    required int page,
    required int pageSize,
    String? keyword,
    String sortBy = 'id',
    int? status,
    int? categoryId,
  }) async {
    lastStatus = status;
    final items = [
      PostItem.fromMap({
        'id': 1,
        'slug': 'quarkus-native',
        'title': {'zh-cn': 'Quarkus 原生镜像实践'},
        'status': 1,
        'visibility': 0,
        'renderType': 0,
        'aiSummaryStatus': 0,
        'version': 1,
        'categoryId': 3,
        'categoryIds': [3],
        'userName': 'BiliWind',
        'publishedRevisionNumber': 2,
        'hasPublishedRevision': true,
        'updatedAt': '2026-10-01T08:00:00Z',
      }),
      PostItem.fromMap({
        'id': 2,
        'slug': 'draft-post',
        'title': {'zh-cn': '尚未发布的草稿'},
        'status': 0,
        'visibility': 1,
        'renderType': 0,
        'aiSummaryStatus': 1,
        'version': 1,
        'categoryId': 3,
        'categoryIds': [3, 4],
        'userName': 'BiliWind',
        'publishedRevisionNumber': 0,
        'hasPublishedRevision': false,
        'updatedAt': '2026-10-02T08:00:00Z',
      }),
    ];
    return PostListResult(
      items: items,
      total: 2,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<CategoryItem>> listCategories() async => [
    CategoryItem.fromMap({
      'id': 3,
      'slug': 'backend',
      'name': {'zh-cn': '后端'},
      'path': 'backend',
      'createdAt': '2026-01-01T00:00:00Z',
      'postCount': 2,
    }),
    CategoryItem.fromMap({
      'id': 4,
      'slug': 'quarkus',
      'name': {'zh-cn': 'Quarkus'},
      'path': 'backend.quarkus',
      'createdAt': '2026-01-01T00:00:00Z',
      'postCount': 1,
    }),
  ];
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Theme(data: AdminTheme.build(), child: child),
  ),
);

void main() {
  testWidgets('文章列表在桌面端使用紧凑表格并支持状态筛选', (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _PostsApi();
    await tester.pumpWidget(_wrap(PostsPage(api: api, onAuthError: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Quarkus 原生镜像实践'), findsOneWidget);
    expect(find.text('尚未发布的草稿'), findsOneWidget);
    expect(find.text('已发布'), findsWidgets);
    expect(find.text('草稿'), findsWidgets);
    expect(find.text('后端 / Quarkus'), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);

    await tester.tap(find.text('已发布').first);
    await tester.pumpAndSettle();
    expect(api.lastStatus, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('文章列表在平板宽度下隐藏作者列且不溢出', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _PostsApi();
    await tester.pumpWidget(_wrap(PostsPage(api: api, onAuthError: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Quarkus 原生镜像实践'), findsOneWidget);
    expect(find.text('作者'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('文章列表在手机宽度下使用卡片且不溢出', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _PostsApi();
    await tester.pumpWidget(_wrap(PostsPage(api: api, onAuthError: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Quarkus 原生镜像实践'), findsOneWidget);
    expect(find.text('已发布'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
