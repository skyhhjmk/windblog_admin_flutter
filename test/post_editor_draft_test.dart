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

const String _baseUrl = 'https://blog.example.com';

late AppLocalizations _zh;

/// Test-only delegate that hands out already-loaded strings synchronously.
///
/// `AppLocalizations.delegate` loads its JSON through `rootBundle`; in
/// `flutter_test` that future only resolves for the first widget test in a
/// file, so every later mount would hang on an empty localization tree.
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

class _DraftApi extends AdminApiClient {
  _DraftApi() {
    baseUrl = _baseUrl;
  }

  int updateCalls = 0;

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
  Future<PostDetail> updatePost(int id, PostEditRequest request) async {
    updateCalls++;
    return _postDetail(
      id: id,
      title: request.title['zh-cn'] ?? '',
      content: request.contentMarkdown['zh-cn'] ?? '',
    );
  }
}

PostDetail _postDetail({
  int id = 11,
  String title = '服务器标题',
  String content = '服务器正文',
}) {
  return PostDetail(
    id: id,
    slug: 'server-slug',
    title: {'zh-cn': title},
    summary: const {'zh-cn': '服务器摘要'},
    aiSummary: const {},
    contentMarkdown: {'zh-cn': content},
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

EditorDraft _draft({
  int? postId = 11,
  String title = '恢复的标题',
  String content = '恢复的正文',
}) {
  return EditorDraft(
    baseUrl: _baseUrl,
    postId: postId,
    savedAt: DateTime.now(),
    slug: 'restored-slug',
    title: title,
    summary: '恢复的摘要',
    content: content,
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
    titles: {'zh-cn': title},
    summaries: {'zh-cn': '恢复的摘要'},
    contents: {'zh-cn': content},
  );
}

Future<AdminNotificationController> _pumpEditor(
  WidgetTester tester, {
  required AdminApiClient api,
  PostDetail? detail,
  EditorDraft? draft,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final notifications = AdminNotificationController();
  addTearDown(notifications.clear);
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
        child: PostEditorPage(api: api, detail: detail, initialDraft: draft),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return notifications;
}

void main() {
  setUpAll(() async {
    _zh = AppLocalizations(const Locale('zh'));
    await _zh.load();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('editor reopens with the unsaved draft and marks it dirty', (
    WidgetTester tester,
  ) async {
    final api = _DraftApi();
    final notifications = await _pumpEditor(
      tester,
      api: api,
      detail: _postDetail(),
      draft: _draft(),
    );

    expect(find.text('恢复的标题'), findsOneWidget);
    expect(find.text('恢复的正文'), findsWidgets);
    expect(find.text('未保存'), findsOneWidget);
    expect(find.text('已恢复上次未保存的编辑内容'), findsOneWidget);
    expect(find.text('放弃恢复'), findsOneWidget);
    notifications.clear();
  });

  testWidgets('editor ignores a draft that belongs to another article', (
    WidgetTester tester,
  ) async {
    final api = _DraftApi();
    final notifications = await _pumpEditor(
      tester,
      api: api,
      detail: _postDetail(),
      draft: _draft(postId: 99),
    );

    expect(find.text('服务器标题'), findsOneWidget);
    expect(find.text('恢复的标题'), findsNothing);
    expect(find.text('已恢复上次未保存的编辑内容'), findsNothing);
    notifications.clear();
  });

  testWidgets('editing persists a draft locally', (WidgetTester tester) async {
    final api = _DraftApi();
    final notifications = await _pumpEditor(
      tester,
      api: api,
      detail: _postDetail(),
    );

    await tester.enterText(
      find.byKey(const Key('postTitleField')),
      '本地自动保存的标题',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final draft = await EditorDraftStore.load(baseUrl: _baseUrl, postId: 11);
    expect(draft?.title, '本地自动保存的标题');
    expect(draft?.content, '服务器正文');
    await EditorDraftStore.clear(baseUrl: _baseUrl, postId: 11);
    notifications.clear();
  });

  testWidgets('saving removes the local draft', (WidgetTester tester) async {
    final api = _DraftApi();
    final notifications = await _pumpEditor(
      tester,
      api: api,
      detail: _postDetail(),
      draft: _draft(),
    );

    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.updateCalls, 1);
    expect(await EditorDraftStore.load(baseUrl: _baseUrl, postId: 11), isNull);
    notifications.clear();
  });

  testWidgets('discarding the restored draft reverts to server content', (
    WidgetTester tester,
  ) async {
    final api = _DraftApi();
    final notifications = await _pumpEditor(
      tester,
      api: api,
      detail: _postDetail(),
      draft: _draft(),
    );

    await tester.tap(find.text('放弃恢复'));
    await tester.pump();

    expect(find.text('服务器标题'), findsOneWidget);
    expect(find.text('恢复的标题'), findsNothing);
    expect(await EditorDraftStore.load(baseUrl: _baseUrl, postId: 11), isNull);
    notifications.clear();
  });
}
