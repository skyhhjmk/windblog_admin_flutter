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
        'userId': 1,
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

  PostQuickEditRequest? lastQuickEditRequest;
  int? lastQuickEditId;

  @override
  Future<PostItem> quickEditPost(int id, PostQuickEditRequest req) async {
    lastQuickEditId = id;
    lastQuickEditRequest = req;
    return PostItem.fromMap({
      'id': id,
      'slug': req.slug,
      'title': {'zh-cn': req.title},
      'status': req.status,
      'visibility': req.visibility,
      'renderType': req.articleMode,
      'aiSummaryStatus': 0,
      'version': 1,
      'categoryId': (req.categoryIds != null && req.categoryIds!.isNotEmpty)
          ? req.categoryIds!.first
          : null,
      'categoryIds': req.categoryIds,
      'authorName': req.authorName,
      'allowComment': req.allowComment,
      'userName': 'BiliWind',
      'publishedRevisionNumber': 2,
      'hasPublishedRevision': true,
      'updatedAt': '2026-10-01T08:00:00Z',
    });
  }

  @override
  Future<List<TagItem>> listTags() async => [];

  @override
  Future<PageResult<UserListItem>> listUsers({
    int page = 1,
    int pageSize = 20,
    String? keyword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 20));
    return PageResult<UserListItem>(
      items: [
        UserListItem.fromMap({
          'id': 1,
          'username': 'admin',
          'displayName': 'Admin User',
          'role': 'ADMIN',
          'status': 1,
          'createdAt': '2026-01-01T00:00:00Z',
        }),
      ],
      total: 1,
      page: page,
      pageSize: pageSize,
    );
  }
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

  testWidgets('点击快捷编辑打开对话框并提交修改', (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _PostsApi();
    await tester.pumpWidget(_wrap(PostsPage(api: api, onAuthError: () {})));
    await tester.pumpAndSettle();

    final quickEditBtn = find.byIcon(Icons.bolt).first;
    expect(quickEditBtn, findsOneWidget);
    await tester.tap(quickEditBtn);
    await tester.pumpAndSettle();

    expect(find.byType(QuickEditPostDialog), findsOneWidget);

    final saveBtn = find.widgetWithText(ElevatedButton, 'save');
    expect(saveBtn, findsOneWidget);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(api.lastQuickEditId, 1);
    expect(api.lastQuickEditRequest?.title?['zh-cn'], 'Quarkus 原生镜像实践');
    expect(tester.takeException(), isNull);
  });
}
