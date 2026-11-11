import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/components/visibility_regions_selector.dart';
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

class _MockApi extends AdminApiClient {
  PostQuickEditRequest? lastQuickEditRequest;
  Completer<PostDetail>? postDetailCompleter;

  @override
  String normalizeBaseUrl(String url) => 'http://localhost:8080';

  @override
  String get baseUrl => 'http://localhost:8080';

  @override
  Future<List<RegionRule>> listRegionRules() async {
    return [
      RegionRule(
        id: 1,
        name: '中国大陆',
        ruleType: 'ip',
        pattern: '1.0.0.0/8',
        region: 'cn',
        isEnabled: true,
      ),
      RegionRule(
        id: 2,
        name: '北美',
        ruleType: 'ip',
        pattern: '2.0.0.0/8',
        region: 'us',
        isEnabled: true,
      ),
    ];
  }

  @override
  Future<List<TagItem>> listTags() async => [];

  @override
  Future<List<CategoryItem>> listCategories() async => [];

  @override
  Future<List<RepostPolicyItem>> listRepostPolicies() async => [];

  @override
  Future<PageResult<UserListItem>> listUsers({
    int page = 1,
    int pageSize = 20,
    String? keyword,
  }) async {
    return PageResult<UserListItem>(
      items: [],
      total: 0,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<PostItem> quickEditPost(int id, PostQuickEditRequest req) async {
    lastQuickEditRequest = req;
    return PostItem.fromMap({
      'id': id,
      'slug': req.slug ?? 'test-post',
      'title': {'zh-cn': req.title?['zh-cn'] ?? '测试标题'},
      'status': req.status ?? 0,
      'visibility': req.visibility ?? 0,
      'visibilityRegions': req.visibilityRegions ?? [],
      'renderType': 6,
      'editorType': 6,
      'aiSummaryStatus': 0,
      'version': req.version + 1,
      'publishedRevisionNumber': 0,
      'hasPublishedRevision': false,
    });
  }

  @override
  Future<PostDetail> postDetail(int id) async {
    if (postDetailCompleter != null) {
      return postDetailCompleter!.future;
    }
    return PostDetail.fromMap({
      'id': id,
      'slug': 'test-post',
      'title': {'zh-cn': '测试文章'},
      'summary': {'zh-cn': '摘要'},
      'contentMarkdown': {'zh-cn': '# 标题\n内容'},
      'status': 0,
      'visibility': 0,
      'visibilityRegions': ['cn'],
      'renderType': 6,
      'editorType': 6,
      'aiSummaryStatus': 0,
      'version': 1,
      'currentRevisionNumber': 1,
      'publishedRevisionNumber': 0,
      'hasPublishedRevision': false,
    });
  }
}

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: [
    _SyncLocalizationsDelegate(_zh),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('zh'), Locale('en')],
  home: Scaffold(
    body: Theme(data: AdminTheme.build(), child: child),
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _zh = AppLocalizations(const Locale('zh'));
    await _zh.load();
  });

  group('VisibilityRegionsSelector tests', () {
    testWidgets('renders all available chips and handles toggling', (
      tester,
    ) async {
      List<String> selected = ['cn'];
      late StateSetter stateSetter;

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              stateSetter = setState;
              return VisibilityRegionsSelector(
                selectedRegions: selected,
                regionRules: [
                  RegionRule(
                    id: 1,
                    name: '中国大陆',
                    ruleType: 'ip',
                    pattern: '1.0.0.0/8',
                    region: 'cn',
                    isEnabled: true,
                  ),
                ],
                onChanged: (next) {
                  stateSetter(() {
                    selected = next;
                  });
                },
              );
            },
          ),
        ),
      );

      expect(find.text('可见区域'), findsOneWidget);
      expect(find.text('已选择 1 个可见区域'), findsOneWidget);
      expect(find.text('清除限制'), findsOneWidget);

      // Tap US chip to add US
      final usChip = find.widgetWithText(FilterChip, 'US (United States)');
      expect(usChip, findsOneWidget);
      await tester.tap(usChip);
      await tester.pumpAndSettle();

      expect(selected, containsAll(['cn', 'us']));
      expect(find.text('已选择 2 个可见区域'), findsOneWidget);

      // Tap '清除限制'
      await tester.tap(find.text('清除限制'));
      await tester.pumpAndSettle();

      expect(selected, isEmpty);
      expect(find.text('全部区域可见'), findsOneWidget);
      expect(find.text('清除限制'), findsNothing);
    });
  });

  group('EditorLoadingDialog and cancel button tests', () {
    testWidgets('EditorLoadingDialog shows cancel button and calls onCancel', (
      tester,
    ) async {
      bool cancelled = false;

      await tester.pumpWidget(
        _wrap(
          EditorLoadingDialog(
            onCancel: () {
              cancelled = true;
            },
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final cancelBtn = find.text('取消');
      expect(cancelBtn, findsOneWidget);

      await tester.tap(cancelBtn);
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('openPostEditor can be cancelled and does not push editor', (
      tester,
    ) async {
      final api = _MockApi();
      final completer = Completer<PostDetail>();
      api.postDetailCompleter = completer;

      late BuildContext testContext;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              testContext = context;
              return ElevatedButton(
                onPressed: () {
                  openPostEditor(context: testContext, api: api, postId: 123);
                },
                child: const Text('打开'),
              );
            },
          ),
        ),
      );

      // Tap button to initiate openPostEditor
      await tester.tap(find.text('打开'));
      await tester.pump(); // Show loading dialog

      expect(find.byType(EditorLoadingDialog), findsOneWidget);
      expect(find.text('正在打开文章编辑器...'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      // Tap Cancel button
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Loading dialog should be dismissed
      expect(find.byType(EditorLoadingDialog), findsNothing);

      // Now complete the future after cancellation
      completer.complete(
        PostDetail.fromMap({
          'id': 123,
          'slug': 'slug',
          'title': {'zh-cn': '已取消的文章'},
          'summary': {},
          'contentMarkdown': {},
          'status': 0,
          'visibility': 0,
          'renderType': 6,
          'editorType': 6,
          'aiSummaryStatus': 0,
          'version': 1,
          'currentRevisionNumber': 1,
          'publishedRevisionNumber': 0,
          'hasPublishedRevision': false,
        }),
      );
      await tester.pumpAndSettle();

      // PostEditorPage should NOT be pushed
      expect(find.byType(PostEditorPage), findsNothing);
    });
  });

  group('QuickEditPostDialog visibility regions tests', () {
    testWidgets('QuickEditPostDialog displays and modifies visibilityRegions', (
      tester,
    ) async {
      final api = _MockApi();
      final post = PostItem.fromMap({
        'id': 42,
        'slug': 'test-post',
        'title': {'zh-cn': '测试文章'},
        'status': 0,
        'visibility': 0,
        'visibilityRegions': ['cn'],
        'renderType': 6,
        'editorType': 6,
        'aiSummaryStatus': 0,
        'version': 1,
        'publishedRevisionNumber': 0,
        'hasPublishedRevision': false,
      });

      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrap(QuickEditPostDialog(item: post, api: api, categories: const [])),
      );
      await tester.pumpAndSettle();

      // Find visibility regions selector in quick edit dialog
      expect(find.text('可见区域'), findsOneWidget);
      expect(find.text('已选择 1 个可见区域'), findsOneWidget);

      // Add US region
      final usChip = find.widgetWithText(FilterChip, '北美 (us)');
      expect(usChip, findsOneWidget);
      await tester.ensureVisible(usChip);
      await tester.tap(usChip);
      await tester.pumpAndSettle();

      expect(find.text('已选择 2 个可见区域'), findsOneWidget);

      // Save
      final saveBtn = find.widgetWithText(ElevatedButton, '保存');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(api.lastQuickEditRequest, isNotNull);
      expect(
        api.lastQuickEditRequest!.visibilityRegions,
        containsAll(['cn', 'us']),
      );
    });
  });

  group('PostEditorPage visibility regions UI tests', () {
    testWidgets('PostEditorPage displays and edits visibilityRegions', (
      tester,
    ) async {
      final api = _MockApi();
      final detail = PostDetail.fromMap({
        'id': 100,
        'slug': 'post-100',
        'title': {'zh-cn': '文章100'},
        'summary': {'zh-cn': '摘要'},
        'contentMarkdown': {'zh-cn': '# 标题\n内容'},
        'status': 0,
        'visibility': 0,
        'visibilityRegions': ['jp'],
        'renderType': 6,
        'editorType': 6,
        'aiSummaryStatus': 0,
        'version': 1,
        'currentRevisionNumber': 1,
        'publishedRevisionNumber': 0,
        'hasPublishedRevision': false,
      });

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(PostEditorPage(detail: detail, api: api)));
      await tester.pumpAndSettle();

      // Ensure visibility regions section exists
      expect(find.text('可见区域'), findsOneWidget);
      expect(find.text('已选择 1 个可见区域'), findsOneWidget);

      // Toggle HK region
      final hkChip = find.widgetWithText(FilterChip, 'HK (Hong Kong)');
      expect(hkChip, findsOneWidget);
      await tester.ensureVisible(hkChip);
      await tester.tap(hkChip);
      await tester.pumpAndSettle();

      expect(find.text('已选择 2 个可见区域'), findsOneWidget);
    });
  });
}
