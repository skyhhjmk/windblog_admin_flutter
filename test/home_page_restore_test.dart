import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/l10n/app_localizations.dart';
import 'package:windblog_admin_flutter/main.dart';
import 'package:windblog_admin_flutter/utils/editor_draft_store.dart';
import 'package:windblog_admin_flutter/utils/storage_service.dart';

const String _baseUrl = 'https://blog.example.com';

late AppLocalizations _zh;

class _SyncLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncLocalizationsDelegate(this.value);

  final AppLocalizations value;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(value);

  @override
  bool shouldReload(_SyncLocalizationsDelegate old) => false;
}

class _WorkspaceApi extends AdminApiClient {
  _WorkspaceApi() {
    baseUrl = _baseUrl;
    token = 'test-token';
  }

  int postDetailCalls = 0;

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
      items: const [],
      total: 0,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<CategoryItem>> listCategories() async => const [];

  @override
  Future<List<TagItem>> listTags() async => const [];

  @override
  Future<List<RepostPolicyItem>> listRepostPolicies() async => const [];

  @override
  Future<List<PostRevisionItem>> listPostRevisions(int postId) async =>
      const [];

  @override
  Future<PostDetail> postDetail(int id) async {
    postDetailCalls++;
    return PostDetail(
      id: id,
      slug: 'restored-post',
      title: const {'zh-cn': '服务器标题'},
      summary: const {'zh-cn': '服务器摘要'},
      aiSummary: const {},
      contentMarkdown: const {'zh-cn': '服务器正文'},
      status: 0,
      visibility: 0,
      hasPassword: false,
      renderType: 6,
      editorType: 6,
      aiSummaryStatus: 0,
      currentRevisionNumber: 1,
      version: 1,
      publishedRevisionNumber: 0,
      hasPublishedRevision: false,
    );
  }
}

EditorDraft _draftForPost(int postId) {
  return EditorDraft(
    baseUrl: _baseUrl,
    postId: postId,
    savedAt: DateTime.now(),
    slug: 'restored-post',
    title: '恢复的标题',
    summary: '恢复的摘要',
    content: '恢复的正文',
    seoTitle: '',
    seoDescription: '',
    seoKeywords: '',
    status: 0,
    visibility: 0,
    renderType: 6,
    editorType: 6,
    aiSummaryStatus: 0,
    categoryId: null,
    categoryIds: const [],
    tagIds: const [],
    visibilityRegions: const [],
    contentDeclarations: const [],
    repostPolicyCode: RepostPolicyItem.defaultCode,
    pointsPrice: '',
    freeLines: '',
    titles: const {'zh-cn': '恢复的标题'},
    summaries: const {'zh-cn': '恢复的摘要'},
    contents: const {'zh-cn': '恢复的正文'},
  );
}

void main() {
  setUpAll(() async {
    _zh = AppLocalizations(const Locale('zh'));
    await _zh.load();
  });

  testWidgets('cold start restores the last section and reopens the draft', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.saveWorkspaceTab(1);
    await EditorDraftStore.save(_draftForPost(9));

    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifications = AdminNotificationController();
    addTearDown(notifications.clear);

    final api = _WorkspaceApi();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          _SyncLocalizationsDelegate(_zh),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', ''), Locale('en', '')],
        locale: const Locale('zh', ''),
        theme: AdminTheme.build(),
        home: AdminNotificationHost(
          api: api,
          controller: notifications,
          child: HomePage(
            api: api,
            user: AdminUser(
              id: 1,
              username: 'admin',
              email: 'admin@example.com',
              roleName: 'ADMIN',
            ),
            onLogout: () {},
            onAuthError: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    // The navigation rail has a pre-existing 8px brand overflow at this
    // width; it is unrelated to state restoration.
    while (tester.takeException() != null) {}

    expect(api.postDetailCalls, 1);
    expect(find.byType(PostEditorPage), findsOneWidget);
    expect(find.text('恢复的标题'), findsOneWidget);
    expect(find.text('已恢复上次未保存的编辑内容'), findsOneWidget);
    notifications.clear();
  });
}
