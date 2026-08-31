import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/l10n/app_localizations.dart';
import 'package:windblog_admin_flutter/main.dart';

void main() {
  test('parses policy catalog and serializes the selected policy', () {
    final policy = RepostPolicyItem.fromMap(const {
      'code': 'CC_BY_NC_4_0',
      'name': 'CC BY-NC 4.0',
      'nameEn': 'CC BY-NC 4.0',
      'licenseUrl': 'https://creativecommons.org/licenses/by-nc/4.0/',
      'requiresApplication': false,
      'summary': '免申请转载',
      'summaryEn': 'No application required',
      'conditions': ['仅限非商业转载'],
      'conditionsEn': ['Non-commercial sharing only'],
    });
    final request = PostEditRequest(
      slug: 'demo',
      title: const {'zh-cn': '示例'},
      summary: const {},
      aiSummary: const {},
      contentMarkdown: const {'zh-cn': '# 示例'},
      status: 0,
      visibility: 0,
      renderType: 6,
      editorType: 6,
      aiSummaryStatus: 0,
      version: 0,
      repostPolicyCode: policy.code,
    );

    expect(policy.requiresApplication, isFalse);
    expect(policy.conditions, contains('仅限非商业转载'));
    expect(request.toCreateBody()['repostPolicyCode'], 'CC_BY_NC_4_0');
    expect(request.toUpdateBody()['repostPolicyCode'], 'CC_BY_NC_4_0');
    expect(request.copyWith(version: 2).repostPolicyCode, 'CC_BY_NC_4_0');

    final oldDetail = PostDetail.fromMap(const {
      'id': 1,
      'slug': 'legacy',
      'title': {'zh-cn': '旧文章'},
      'summary': {},
      'aiSummary': {},
      'contentMarkdown': {'zh-cn': '内容'},
      'status': 0,
      'visibility': 0,
      'hasPassword': false,
      'renderType': 6,
      'editorType': 6,
      'aiSummaryStatus': 0,
      'currentRevisionNumber': 1,
      'version': 1,
      'tagIds': [],
      'visibilityRegions': [],
      'contentDeclarations': [],
      'publishedRevisionNumber': 0,
      'hasPublishedRevision': false,
    });
    expect(oldDetail.repostPolicyCode, RepostPolicyItem.defaultCode);

    final legacyDetail = PostDetail.fromMap({
      'id': 2,
      'slug': 'legacy-cc',
      'title': const {'zh-cn': '旧 CC 文章'},
      'summary': const {},
      'aiSummary': const {},
      'contentMarkdown': const {'zh-cn': '内容'},
      'status': 0,
      'visibility': 0,
      'hasPassword': false,
      'renderType': 6,
      'editorType': 6,
      'aiSummaryStatus': 0,
      'currentRevisionNumber': 1,
      'version': 1,
      'tagIds': const [],
      'visibilityRegions': const [],
      'contentDeclarations': const ['CC_BY_NC_4_0'],
      'publishedRevisionNumber': 0,
      'hasPublishedRevision': false,
    });
    expect(legacyDetail.repostPolicyCode, 'CC_BY_NC_4_0');
  });

  testWidgets('editor marks policy changes as unsaved', (
    WidgetTester tester,
  ) async {
    final api = _RepostPolicyApiStub();
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        theme: AdminTheme.build(),
        home: PostEditorPage(api: api),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('文章转载协议'), findsOneWidget);
    final policyDropdown = find.descendant(
      of: find.byKey(const Key('repostPolicyDropdown')),
      matching: find.byType(DropdownButton<String>),
    );
    await tester.tap(policyDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CC BY-NC 4.0').last);
    await tester.pump();

    expect(find.text('未保存'), findsOneWidget);
    expect(find.text('免申请转载'), findsOneWidget);
    expect(find.text('• 仅限非商业转载'), findsOneWidget);
  });
}

class _RepostPolicyApiStub extends AdminApiClient {
  @override
  Future<List<CategoryItem>> listCategories() async => const [];

  @override
  Future<List<TagItem>> listTags() async => const [];

  @override
  Future<List<RepostPolicyItem>> listRepostPolicies() async => const [
    RepostPolicyItem(
      code: RepostPolicyItem.defaultCode,
      name: '转载需申请授权',
      nameEn: 'Repost requires authorization',
      requiresApplication: true,
      summary: '转载需先申请授权',
      summaryEn: 'Request authorization before reposting',
      conditions: ['转载前需要申请授权'],
      conditionsEn: ['Authorization is required before reposting'],
    ),
    RepostPolicyItem(
      code: 'CC_BY_NC_4_0',
      name: 'CC BY-NC 4.0',
      nameEn: 'CC BY-NC 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by-nc/4.0/',
      requiresApplication: false,
      summary: '无须申请转载；仅限非商业转载。',
      summaryEn: 'No application required; non-commercial sharing only.',
      conditions: ['仅限非商业转载'],
      conditionsEn: ['Non-commercial sharing only'],
    ),
  ];
}
