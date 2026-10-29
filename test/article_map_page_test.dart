import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/main.dart';

class _ArticleMapApi extends AdminApiClient {
  int mapCalls = 0;

  @override
  Future<PostDetail> postDetail(int id) async => PostDetail.fromMap({
    'id': id,
    'slug': 'root-post',
    'title': {'zh-cn': '起点文章'},
    'summary': {'zh-cn': '摘要'},
    'contentMarkdown': {'zh-cn': '正文'},
    'status': 1,
    'renderType': 0,
    'editorType': 0,
  });

  @override
  Future<Map<String, dynamic>> articleMap(
    int postId, {
    String language = 'zh-cn',
    int depth = 2,
    int maxNodes = 80,
    int relatedPerNode = 4,
  }) async {
    mapCalls++;
    return {
      'enabled': true,
      'rootId': postId,
      'depth': depth,
      'esAvailable': true,
      'truncated': false,
      'relatedQueries': 2,
      'relatedCacheHits': 1,
      'nodes': [
        {
          'id': postId,
          'slug': 'root-post',
          'title': '起点文章',
          'url': 'https://example.com/post/root-post',
          'depth': 0,
          'fuzzy': false,
        },
        {
          'id': 2,
          'slug': 'linked-post',
          'title': '显式链接文章',
          'url': 'https://example.com/post/linked-post',
          'depth': 1,
          'fuzzy': false,
        },
        {
          'id': 3,
          'slug': 'fuzzy-post',
          'title': 'ES 关联文章',
          'url': 'https://example.com/post/fuzzy-post',
          'depth': 1,
          'fuzzy': true,
        },
      ],
      'edges': [
        {'source': postId, 'target': 2, 'type': 'LINK', 'score': 1.0},
        {'source': postId, 'target': 3, 'type': 'FUZZY', 'score': 8.2},
      ],
    };
  }
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Theme(data: AdminTheme.build(), child: child),
  ),
);

void main() {
  testWidgets('文章地图展示显式链接与 ES 模糊关联', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _ArticleMapApi();
    await tester.pumpWidget(
      _wrap(ArticleMapPage(api: api, onAuthError: () {}, postId: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('文章地图'), findsOneWidget);
    expect(find.text('显式链接引用（正文中的文章链接）'), findsOneWidget);
    expect(find.text('ES 模糊关联（more_like_this / fuzzy）'), findsOneWidget);
    expect(find.text('起点文章'), findsWidgets);
    expect(find.text('显式链接文章'), findsOneWidget);
    expect(find.text('ES 关联文章'), findsOneWidget);
    expect(find.text('1 条显式链接'), findsOneWidget);
    expect(find.text('1 条 ES 模糊关联'), findsOneWidget);
    expect(api.mapCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('文章地图在手机宽度下不溢出', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _ArticleMapApi();
    await tester.pumpWidget(
      _wrap(ArticleMapPage(api: api, onAuthError: () {}, postId: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('显式链接引用（正文中的文章链接）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
