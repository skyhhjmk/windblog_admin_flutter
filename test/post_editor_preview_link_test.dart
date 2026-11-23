import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/l10n/app_localizations.dart';
import 'package:windblog_admin_flutter/main.dart';

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

class _PreviewLinkApi extends AdminApiClient {
  int previewLinkCalls = 0;
  int? lastPostId;
  String? lastTitleZh;
  String? lastContentZh;
  int? lastTtlMinutes;

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
  Future<PostPreviewLink> createPostPreviewLink({
    int? postId,
    required String slug,
    required Map<String, String> title,
    required Map<String, String> summary,
    required Map<String, String> aiSummary,
    required Map<String, String> contentMarkdown,
    required int visibility,
    String? seoTitle,
    String? seoDescription,
    String? seoKeywords,
    required int renderType,
    required int aiSummaryStatus,
    int? pointsPrice,
    int? categoryId,
    List<int> categoryIds = const [],
    List<int> tagIds = const [],
    List<String> contentDeclarations = const [],
    String? repostPolicyCode,
    int articleMode = 0,
    Map<String, dynamic>? tutorialMeta,
    Map<String, dynamic>? resourceMeta,
    String? authorName,
    int? userId,
    String? language,
    int ttlMinutes = 60,
  }) async {
    previewLinkCalls++;
    lastPostId = postId;
    lastTitleZh = title['zh-cn'];
    lastContentZh = contentMarkdown['zh-cn'];
    lastTtlMinutes = ttlMinutes;
    return PostPreviewLink(
      token: 'tok-$previewLinkCalls',
      previewPath: '/preview/post/tok-$previewLinkCalls',
      previewUrl: 'https://blog.example.com/preview/post/tok-$previewLinkCalls',
      expiresAt: DateTime.utc(2026, 11, 24, 12, 0).add(
        Duration(minutes: ttlMinutes),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _zh = AppLocalizations(const Locale('zh'));
    await _zh.load();
  });

  testWidgets('editor generates preview link dialog and supports TTL change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _PreviewLinkApi();
    final detail = PostDetail(
      id: 42,
      slug: 'preview-demo',
      title: const {'zh-cn': '预览测试标题'},
      summary: const {'zh-cn': '摘要'},
      aiSummary: const {},
      contentMarkdown: const {'zh-cn': '# Hello Preview'},
      status: 0,
      visibility: 0,
      hasPassword: false,
      renderType: 0,
      editorType: 0,
      aiSummaryStatus: 0,
      currentRevisionNumber: 1,
      version: 1,
      publishedRevisionNumber: 0,
      hasPublishedRevision: false,
      repostPolicyCode: RepostPolicyItem.defaultCode,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: [
          _SyncLocalizationsDelegate(_zh),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: PostEditorPage(api: api, detail: detail),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('预览链接'), findsOneWidget);
    await tester.tap(find.text('预览链接'));
    await tester.pumpAndSettle();

    expect(api.previewLinkCalls, 1);
    expect(api.lastPostId, 42);
    expect(api.lastTitleZh, '预览测试标题');
    expect(api.lastContentZh, '# Hello Preview');
    expect(api.lastTtlMinutes, 60);

    expect(
      find.text('https://blog.example.com/preview/post/tok-1'),
      findsOneWidget,
    );
    expect(find.text('在浏览器中打开'), findsOneWidget);
    expect(find.text('复制链接'), findsOneWidget);

    await tester.tap(find.text('6h'));
    await tester.pumpAndSettle();

    expect(api.previewLinkCalls, 2);
    expect(api.lastTtlMinutes, 360);
    expect(
      find.text('https://blog.example.com/preview/post/tok-2'),
      findsOneWidget,
    );
  });
}
