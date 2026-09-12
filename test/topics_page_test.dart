import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/l10n/app_localizations.dart';
import 'package:windblog_admin_flutter/main.dart';

void main() {
  testWidgets('话题页使用服务端分页并显示主题内容', (WidgetTester tester) async {
    final api = _TopicsApiStub();
    final notifications = AdminNotificationController();
    addTearDown(notifications.clear);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', ''), Locale('en', '')],
        locale: const Locale('zh', ''),
        home: AdminNotificationHost(
          api: api,
          controller: notifications,
          child: Theme(
            data: AdminTheme.build(),
            child: Scaffold(
              body: TopicsPage(api: api, onAuthError: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('话题'), findsOneWidget);
    expect(find.text('话题列表'), findsOneWidget);
    expect(find.text('已指派任务'), findsOneWidget);
    expect(find.text('设置与记录'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pump();
    // The active seed is intentionally shown in both its tab and section header.
    expect(find.text('AI 产业观察'), findsNWidgets(2));
    expect(find.text('分页测试话题'), findsOneWidget);
    expect(find.byType(PaginationBar), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(api.requestedPages, [1]);

    await tester.tap(find.text('指派并生成草稿'));
    await tester.pumpAndSettle();
    expect(find.text('生成模型'), findsOneWidget);
    expect(find.text('Codex 自动'), findsOneWidget);
    expect(find.text('high'), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(PaginationBar),
        matching: find.byIcon(Icons.chevron_right),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.requestedPages, [1, 2]);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.text('已指派任务'));
    await tester.pumpAndSettle();

    expect(find.text('已指派测试任务'), findsOneWidget);
    expect(find.text('重新生成'), findsOneWidget);
    expect(find.text('查看文章'), findsOneWidget);
    expect(find.text('失败测试任务'), findsOneWidget);
    expect(find.text('重试生成'), findsOneWidget);
    expect(api.requestedStatuses.last, 'ASSIGNED');
    expect(find.byType(PaginationBar), findsOneWidget);
    expect(find.byType(AdminNotificationScope), findsOneWidget);

    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    await tester.tap(find.text('查看文章'));
    await tester.pumpAndSettle();
    expect(find.byType(PostEditorPage), findsOneWidget);
    expect(find.byType(AdminNotificationHost), findsOneWidget);
    expect(api.requestedPostId, 9);
    notifications.clear();
    tester.view.reset();
  });

  testWidgets('刷新种子分组时可替换话题标签控制器', (WidgetTester tester) async {
    final api = _TopicsApiStub();
    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: AdminTheme.build(),
          child: Scaffold(
            body: TopicsPage(api: api, onAuthError: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    api.seedCount = 2;
    await tester.tap(find.byTooltip('刷新话题'));
    await tester.pumpAndSettle();

    expect(find.text('AI 工程实践'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('话题列表中的生成失败任务显示重新生成按钮', (WidgetTester tester) async {
    final api = _TopicsApiStub()..showFailedTopic = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: AdminTheme.build(),
          child: Scaffold(
            body: TopicsPage(api: api, onAuthError: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('生成失败测试话题'), findsOneWidget);
    expect(find.text('重新生成'), findsOneWidget);
  });
}

class _TopicsApiStub extends AdminApiClient {
  final List<int> requestedPages = [];
  final List<String?> requestedStatuses = [];
  int seedCount = 1;
  bool showFailedTopic = false;
  int? requestedPostId;

  @override
  Future<Map<String, dynamic>> codexCreatorModels() async => {
    'topic': [
      {
        'profileId': 'codex-default',
        'modelId': 'auto',
        'displayName': 'Codex 自动',
        'reasoningEffort': 'high',
        'isDefault': true,
      },
    ],
    'article': [
      {
        'profileId': 'codex-default',
        'modelId': 'auto',
        'displayName': 'Codex 自动',
        'reasoningEffort': 'high',
        'isDefault': true,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> codexCreatorTopicAutomation() async => {
    'settings': {
      'enabled': false,
      'intervalMinutes': 360,
      'maxSeedsPerRun': 5,
      'maxTopicsPerRun': 20,
    },
    'seeds': <Map<String, dynamic>>[
      {
        'id': 7,
        'name': 'AI 产业观察',
        'query': 'AI industry',
        'language': 'zh-CN',
        'enabled': true,
      },
      if (seedCount > 1)
        {
          'id': 8,
          'name': 'AI 工程实践',
          'query': 'AI engineering',
          'language': 'zh-CN',
          'enabled': true,
        },
    ],
  };

  @override
  Future<Map<String, dynamic>> codexCreatorTopics({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    requestedPages.add(page);
    requestedStatuses.add(status);
    return {
      'items': [
        {
          'id': page,
          'title': status == 'ASSIGNED' ? '已指派测试任务' : '分页测试话题',
          'rationale': '用于验证分页组件。',
          'recommendation': 'WRITE',
          'status': status == 'ASSIGNED' ? 'DRAFT_CREATED' : 'SUGGESTED',
          if (status == 'ASSIGNED') 'postId': 9,
          'occurrenceCount': 1,
          'source': {
            'primarySeed': {'id': 7, 'name': 'AI 产业观察', 'query': 'AI industry'},
            'keywords': ['分页'],
            'sources': [
              {'title': '测试来源', 'url': 'https://example.com/topic'},
            ],
          },
        },
        if (showFailedTopic && status != 'ASSIGNED')
          {
            'id': 88,
            'title': '生成失败测试话题',
            'rationale': '用于验证失败任务可以重新生成。',
            'recommendation': 'WRITE',
            'status': 'SUGGESTED',
            'articleJobStatus': 'FAILED',
            'articleJobId': 123,
            'articleError': '测试失败原因',
            'occurrenceCount': 1,
            'source': {
              'primarySeed': {
                'id': 7,
                'name': 'AI 产业观察',
                'query': 'AI industry',
              },
              'sources': <Map<String, String>>[],
            },
          },
        if (status == 'ASSIGNED')
          {
            'id': 99,
            'title': '失败测试任务',
            'rationale': '用于验证失败任务仍可见。',
            'recommendation': 'WRITE',
            'status': 'FAILED',
            'articleError': 'Codex usage limit',
            'occurrenceCount': 1,
            'source': {
              'primarySeed': {
                'id': 7,
                'name': 'AI 产业观察',
                'query': 'AI industry',
              },
              'sources': <Map<String, String>>[],
            },
          },
      ],
      'total': 21,
      'page': page,
      'pageSize': pageSize,
    };
  }

  @override
  Future<Map<String, dynamic>> codexCreatorTopicRuns({
    int page = 1,
    int pageSize = 20,
  }) async => {
    'items': <Map<String, dynamic>>[],
    'total': 0,
    'page': page,
    'pageSize': pageSize,
  };

  @override
  Future<List<CategoryItem>> listCategories() async => <CategoryItem>[];

  @override
  Future<PostDetail> postDetail(int id) async {
    requestedPostId = id;
    return PostDetail.fromMap({
      'id': id,
      'slug': 'generated-draft',
      'title': {'zh-cn': '已生成文章'},
      'summary': {'zh-cn': '测试摘要'},
      'contentMarkdown': {'zh-cn': '测试正文'},
      'status': 0,
      'renderType': 0,
      'editorType': 0,
    });
  }
}
