import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/main.dart';

class _IpDisplayFakeApi extends AdminApiClient {
  @override
  Future<PageResult<UserListItem>> listUsers({
    int page = 1,
    int pageSize = 20,
    String? keyword,
  }) async {
    return PageResult(
      items: [
        UserListItem.fromMap({
          'id': 1,
          'username': 'alice',
          'email': 'alice@example.com',
          'avatar': 'https://example.com/a.png',
          'roleName': 'USER',
          'status': 1,
          'createdAt': '2026-11-20T08:00:00Z',
          'updatedAt': '2026-11-24T08:00:00Z',
          'lastLoginIp': '223.5.5.5',
          'lastLoginLocation': '中国 浙江省 杭州市 (阿里)',
          'lastLoginAt': '2026-11-24T12:00:00Z',
        }),
      ],
      total: 1,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<PermissionRoleItem>> listRoles() async => [];

  @override
  Future<PostListResult> listPosts({
    required int page,
    required int pageSize,
    String? keyword,
    String sortBy = 'id',
    int? status,
    int? categoryId,
  }) async {
    return PostListResult(
      items: [
        PostItem.fromMap({
          'id': 11,
          'slug': 'ip-test-post',
          'title': {'zh-cn': 'IP 测试文章'},
          'status': 1,
          'visibility': 0,
          'renderType': 0,
          'aiSummaryStatus': 0,
          'version': 1,
          'userName': 'admin',
          'publishedRevisionNumber': 1,
          'hasPublishedRevision': true,
          'updatedAt': '2026-11-24T10:00:00Z',
          'publishIp': '1.1.1.1',
          'publishLocation': 'Australia Queensland Brisbane',
        }),
      ],
      total: 1,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<CategoryItem>> listCategories() async => [];

  @override
  Future<List<TagItem>> listTags() async => [];
}

void main() {
  test('models parse comment, user login, and post publish IP fields', () {
    final comment = CommentItem.fromMap({
      'id': 1,
      'postId': 2,
      'postTitle': 'Hello',
      'userId': 3,
      'userName': 'Bob',
      'content': 'Nice post',
      'status': 1,
      'auditStatus': 2,
      'isReviewing': false,
      'createdAt': '2026-11-24T08:00:00Z',
      'clientIp': '223.5.5.5',
      'ipLocation': '中国 浙江省 杭州市 (阿里)',
    });
    expect(comment.clientIp, '223.5.5.5');
    expect(comment.ipLocation, '中国 浙江省 杭州市 (阿里)');

    final user = UserListItem.fromMap({
      'id': 5,
      'username': 'alice',
      'email': 'alice@example.com',
      'avatar': 'https://example.com/a.png',
      'roleName': 'USER',
      'status': 1,
      'createdAt': '2026-11-20T08:00:00Z',
      'updatedAt': '2026-11-24T08:00:00Z',
      'lastLoginIp': '1.1.1.1',
      'lastLoginLocation': 'Australia Queensland Brisbane',
      'lastLoginAt': '2026-11-24T11:30:00Z',
    });
    expect(user.lastLoginIp, '1.1.1.1');
    expect(user.lastLoginLocation, 'Australia Queensland Brisbane');
    expect(user.lastLoginAt, isNotNull);

    final post = PostItem.fromMap({
      'id': 10,
      'slug': 'post-10',
      'title': {'zh-cn': '文章 10'},
      'status': 1,
      'visibility': 0,
      'renderType': 0,
      'aiSummaryStatus': 0,
      'version': 1,
      'publishedRevisionNumber': 1,
      'hasPublishedRevision': true,
      'publishIp': '8.8.8.8',
      'publishLocation': 'United States',
    });
    expect(post.publishIp, '8.8.8.8');
    expect(post.publishLocation, 'United States');

    final detail = PostDetail.fromMap({
      'id': 10,
      'slug': 'post-10',
      'title': {'zh-cn': '文章 10'},
      'summary': {},
      'aiSummary': {},
      'contentMarkdown': {'zh-cn': '正文'},
      'status': 1,
      'visibility': 0,
      'hasPassword': false,
      'renderType': 0,
      'editorType': 0,
      'aiSummaryStatus': 0,
      'currentRevisionNumber': 1,
      'version': 1,
      'publishedRevisionNumber': 1,
      'hasPublishedRevision': true,
      'publishIp': '8.8.8.8',
      'publishLocation': 'United States',
    });
    expect(detail.publishIp, '8.8.8.8');
    expect(detail.publishLocation, 'United States');
  });

  testWidgets('UserManagementPage displays last login IP and location', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _IpDisplayFakeApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserManagementPage(
            api: api,
            onAuthError: () {},
            isSuperAdmin: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('中国 浙江省 杭州市 (阿里) (223.5.5.5)'),
      findsOneWidget,
    );

    await tester.tap(find.text('alice'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('最后登录 IP：223.5.5.5'), findsOneWidget);
    expect(
      find.textContaining('最后登录地点：中国 浙江省 杭州市 (阿里)'),
      findsOneWidget,
    );
  });

  testWidgets('PostsPage displays publish IP and location', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _IpDisplayFakeApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostsPage(api: api, onAuthError: () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('1.1.1.1 · Australia Queensland Brisbane'),
      findsOneWidget,
    );
  });
}
