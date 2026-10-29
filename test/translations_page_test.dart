import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/main.dart';

class _TranslationApi extends AdminApiClient {
  int translateCalls = 0;
  int batchCalls = 0;
  String? lastTarget;

  @override
  Future<TranslationPageResult> listTranslations({
    required int page,
    required int pageSize,
    String targetLanguage = 'en-US',
    String? translationStatus,
    String? keyword,
    int? status,
  }) async {
    lastTarget = targetLanguage;
    return TranslationPageResult(
      items: [
        TranslationItem.fromMap({
          'id': 1,
          'slug': 'twelve-factor',
          'title': {'zh-cn': '十二要素应用实践'},
          'status': 1,
          'hasPublishedRevision': true,
          'revisionNumber': 3,
          'languages': ['zh-cn'],
          'sourceLanguage': 'zh-cn',
          'translated': false,
          'updatedAt': '2026-10-01T08:00:00Z',
        }),
        TranslationItem.fromMap({
          'id': 2,
          'slug': 'quarkus-native',
          'title': {'zh-cn': 'Quarkus 原生镜像'},
          'status': 1,
          'hasPublishedRevision': true,
          'currentRevisionPublished': true,
          'revisionNumber': 2,
          'languages': ['zh-cn', 'en-US'],
          'sourceLanguage': 'zh-cn',
          'translated': true,
          'updatedAt': '2026-10-02T08:00:00Z',
        }),
      ],
      total: 2,
      page: page,
      pageSize: pageSize,
      targetLanguage: targetLanguage,
    );
  }

  @override
  Future<TranslatePostOutcome> translatePostToTarget(
    int postId, {
    String targetLanguage = 'en-US',
    String? sourceLanguage,
    bool overwrite = false,
  }) async {
    translateCalls++;
    return TranslatePostOutcome(
      postId: postId,
      slug: 'twelve-factor',
      sourceLanguage: 'zh-cn',
      targetLanguage: targetLanguage,
      translated: true,
      skipped: false,
      published: true,
      revisionNumber: 4,
    );
  }

  @override
  Future<BatchTranslateOutcome> batchTranslatePosts(
    List<int> postIds, {
    String targetLanguage = 'en-US',
    String? sourceLanguage,
    bool overwrite = false,
  }) async {
    batchCalls++;
    return const BatchTranslateOutcome(
      requested: 1,
      translated: 1,
      skipped: 0,
      failed: 0,
      results: [],
      errors: [],
    );
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Theme(data: AdminTheme.build(), child: child),
    ),
  );
}

void main() {
  testWidgets('翻译管理展示条目并支持单篇翻译', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _TranslationApi();
    await tester.pumpWidget(
      _wrap(TranslationsPage(api: api, onAuthError: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('翻译管理'), findsOneWidget);
    expect(find.text('十二要素应用实践'), findsOneWidget);
    expect(find.text('待翻译'), findsWidgets);
    expect(find.text('已翻译'), findsWidgets);
    expect(find.text('译为英语'), findsOneWidget);

    await tester.tap(find.text('译为英语'));
    await tester.pumpAndSettle();
    expect(api.translateCalls, 1);
    expect(api.lastTarget, 'en-US');
  });

  testWidgets('翻译管理在手机宽度下使用卡片布局并显示批量按钮', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _TranslationApi();
    await tester.pumpWidget(
      _wrap(TranslationsPage(api: api, onAuthError: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('十二要素应用实践'), findsOneWidget);
    expect(find.text('待翻译'), findsWidgets);
    expect(find.text('批量翻译'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
