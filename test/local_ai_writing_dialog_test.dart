import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/components/local_ai_writing_dialog.dart';

void main() {
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
