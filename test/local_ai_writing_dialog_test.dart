import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/components/local_ai_writing_dialog.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';

void main() {
  _registerProviderModeTest();

  testWidgets('写作助手在手机宽度下不溢出', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LocalAiWritingDialog(title: '测试', content: '正文', html: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI 写作助手'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('select custom model and edit/reset full prompt', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LocalAiWritingDialog(title: '测试', content: '正文', html: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('跟随 Codex 默认配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义模型…').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '模型 ID'), findsOneWidget);
    await tester.ensureVisible(find.text('高级选项 · 自定义提示词'));
    await tester.tap(find.text('高级选项 · 自定义提示词'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    final prompt = find.widgetWithText(TextField, '完整提示词模板');
    await tester.ensureVisible(prompt);
    await tester.enterText(prompt, '只输出 {{title}}');
    await tester.ensureVisible(find.text('恢复默认模板'));
    await tester.tap(find.text('恢复默认模板'));
    await tester.pump();
    expect(
      tester.widget<TextField>(prompt).controller!.text,
      contains('{{content}}'),
    );
  });
}

class _WritingApi extends AdminApiClient {
  int calls = 0;
  int? lastProviderId;

  @override
  Future<List<AiProviderConfig>> listAiProviders() async => [
    AiProviderConfig(
      id: 7,
      type: 'POLLING_GROUP',
      name: '主写作轮询组',
      provider: 'POOL',
      enabled: true,
    ),
    AiProviderConfig(
      id: 8,
      type: 'PROVIDER',
      name: '备用 OpenAI',
      provider: 'OPENAI',
      enabled: true,
      model: 'gpt-4.1',
    ),
  ];

  @override
  Future<AiCompletionResult> completeAi({
    int? providerId,
    required String prompt,
    String? systemPrompt,
  }) async {
    calls++;
    lastProviderId = providerId;
    return const AiCompletionResult(
      text: 'API 模式生成的正文',
      provider: 'OPENAI',
      modelId: 'gpt-4.1',
    );
  }
}

void _registerProviderModeTest() {
  testWidgets('切换到 API 提供商模式并生成写作结果', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _WritingApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocalAiWritingDialog(
            title: '测试',
            content: '正文',
            html: false,
            api: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('API 提供商'));
    await tester.pumpAndSettle();
    expect(find.textContaining('主写作轮询组'), findsOneWidget);

    await tester.tap(find.text('生成'));
    await tester.pumpAndSettle();

    expect(api.calls, 1);
    expect(api.lastProviderId, 7);
    expect(find.text('API 模式生成的正文'), findsOneWidget);
  });
}
