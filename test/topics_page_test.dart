import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/main.dart';

void main() {
  testWidgets('话题页使用服务端分页并显示主题内容', (WidgetTester tester) async {
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

    expect(find.text('话题'), findsOneWidget);
    expect(find.text('话题列表'), findsOneWidget);
    expect(find.text('已指派任务'), findsOneWidget);
    expect(find.text('设置与记录'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pump();
    expect(find.text('AI 产业观察'), findsOneWidget);
    expect(find.text('1 个话题'), findsOneWidget);
    expect(find.text('分页测试话题'), findsOneWidget);
    expect(find.byType(PaginationBar), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(api.requestedPages, [1]);

    await tester.tap(find.text('指派并生成草稿'));
    await tester.pumpAndSettle();
    expect(find.text('生成模型'), findsOneWidget);
    expect(find.text('Codex 自动 · high'), findsOneWidget);
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
    expect(find.text('失败测试任务'), findsOneWidget);
    expect(find.text('重试生成'), findsOneWidget);
    expect(api.requestedStatuses.last, 'ASSIGNED');
    expect(find.byType(PaginationBar), findsOneWidget);
  });
}

class _TopicsApiStub extends AdminApiClient {
  final List<int> requestedPages = [];
  final List<String?> requestedStatuses = [];

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
          'occurrenceCount': 1,
          'source': {
            'primarySeed': {'id': 7, 'name': 'AI 产业观察', 'query': 'AI industry'},
            'keywords': ['分页'],
            'sources': [
              {'title': '测试来源', 'url': 'https://example.com/topic'},
            ],
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
              'primarySeed': {'id': 7, 'name': 'AI 产业观察', 'query': 'AI industry'},
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
}
