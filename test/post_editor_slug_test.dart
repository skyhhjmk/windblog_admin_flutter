import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/l10n/app_localizations.dart';
import 'package:windblog_admin_flutter/main.dart';

late AppLocalizations _zh;

/// `AppLocalizations.delegate` only resolves its bundle for the first widget
/// test in a file, so later mounts get an empty localization tree.
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

class _SlugApi extends AdminApiClient {
  final String transliterated = 'kuai-su-ru-men';
  int previewCalls = 0;
  PostEditRequest? lastUpdate;

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
  Future<String> previewPostSlug(String title) async {
    previewCalls++;
    return transliterated;
  }

  @override
  Future<PostDetail> updatePost(int id, PostEditRequest request) async {
    lastUpdate = request;
    return PostDetail(
      id: id,
      slug: request.slug,
      title: request.title,
      summary: request.summary,
      aiSummary: request.aiSummary,
      contentMarkdown: request.contentMarkdown,
      status: request.status,
      visibility: request.visibility,
      hasPassword: false,
      renderType: request.renderType,
      editorType: request.editorType,
      aiSummaryStatus: request.aiSummaryStatus,
      currentRevisionNumber: 1,
      version: request.version + 1,
      publishedRevisionNumber: 0,
      hasPublishedRevision: false,
      repostPolicyCode: request.repostPolicyCode,
    );
  }
}

PostDetail _post({String slug = 'save-test'}) {
  return PostDetail(
    id: 11,
    slug: slug,
    title: const {'zh-cn': '保存测试文章'},
    summary: const {'zh-cn': '摘要'},
    aiSummary: const {},
    contentMarkdown: const {'zh-cn': '正文'},
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

Future<AdminNotificationController> _pumpEditor(
  WidgetTester tester,
  AdminApiClient api, {
  PostDetail? detail,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1400, 2200));
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
        child: PostEditorPage(api: api, detail: detail),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return notifications;
}

String _slugText(WidgetTester tester) {
  final field = tester.widget<TextField>(
    find.byKey(const Key('postSlugField')),
  );
  return field.controller?.text ?? '';
}

void main() {
  setUpAll(() async {
    _zh = AppLocalizations(const Locale('zh'));
    await _zh.load();
  });

  testWidgets('the editor shows and saves an edited slug', (
    WidgetTester tester,
  ) async {
    final api = _SlugApi();
    final notifications = await _pumpEditor(tester, api, detail: _post());

    expect(_slugText(tester), 'save-test');

    await tester.enterText(
      find.byKey(const Key('postSlugField')),
      'custom-slug',
    );
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.lastUpdate?.slug, 'custom-slug');
    expect(_slugText(tester), 'custom-slug');
    notifications.clear();
    await tester.pump();
  });

  testWidgets('a new post derives a URL-safe slug from a Chinese title', (
    WidgetTester tester,
  ) async {
    final api = _SlugApi();
    await _pumpEditor(tester, api);

    await tester.enterText(find.byKey(const Key('postTitleField')), '快速入门');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(api.previewCalls, 1);
    expect(_slugText(tester), 'kuai-su-ru-men');
  });

  testWidgets('a hand-edited slug stops following the title', (
    WidgetTester tester,
  ) async {
    final api = _SlugApi();
    await _pumpEditor(tester, api);

    await tester.enterText(find.byKey(const Key('postTitleField')), '快速入门');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(_slugText(tester), 'kuai-su-ru-men');

    await tester.enterText(
      find.byKey(const Key('postSlugField')),
      'my-custom-slug',
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('postTitleField')), '另一个标题');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(_slugText(tester), 'my-custom-slug');
    expect(api.previewCalls, 1);
  });

  testWidgets('editing the title does not rename an existing slug', (
    WidgetTester tester,
  ) async {
    final api = _SlugApi();
    await _pumpEditor(tester, api, detail: _post());

    await tester.enterText(find.byKey(const Key('postTitleField')), '新的标题');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(_slugText(tester), 'save-test');
    expect(api.previewCalls, 0);
  });
}
