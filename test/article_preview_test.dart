import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/main.dart';

void main() {
  testWidgets(
    'default preview is inline and theme changes reach nested blocks',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final controller = MarkdownSyntaxController(
        text: '''正文

::: quick
嵌套正文
::: /quick''',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.build(),
          home: Scaffold(
            body: MarkdownPlusEditor(
              controller: controller,
              api: AdminApiClient(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('正文预览'), findsOneWidget);
      expect(find.text('嵌套正文', findRichText: true), findsOneWidget);
      expect(find.byIcon(Icons.open_in_browser), findsNothing);
      final sheets = tester
          .widgetList<MarkdownBody>(find.byType(MarkdownBody))
          .map((widget) => widget.styleSheet!)
          .toList();
      expect(sheets.length, greaterThanOrEqualTo(3));
      for (final sheet in sheets) {
        expect(sheet.p!.fontSize, 15);
        expect(sheet.p!.height, 1.6);
        expect(sheet.p!.color, const Color(0xff374151));
      }
      await tester.tap(find.byTooltip('切换深色预览'));
      await tester.pump();
      for (final widget in tester.widgetList<MarkdownBody>(
        find.byType(MarkdownBody),
      )) {
        expect(widget.styleSheet!.p!.color, const Color(0xff94a3b8));
      }
      expect(find.text('嵌套正文', findRichText: true), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('nested container links retain editor actions', (tester) async {
    final links = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArticlePreviewMarkdown(
            data: '::: quick\n[引用链接](/post/example)\n::: /quick',
            onLinkTap: links.add,
          ),
        ),
      ),
    );
    await tester.tap(find.text('引用链接', findRichText: true));
    expect(links, ['/post/example']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing updates the inline preview without saving', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    final controller = MarkdownSyntaxController(text: '初始正文');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownPlusEditor(
            controller: controller,
            api: AdminApiClient(),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      controller.text = '实时修改的正文';
      await Future<void>.delayed(const Duration(milliseconds: 350));
    });
    await tester.pumpAndSettle();
    expect(find.text('实时修改的正文', findRichText: true), findsWidgets);
    expect(
      tester
          .widgetList<MarkdownBody>(find.byType(MarkdownBody))
          .any((widget) => widget.data == '实时修改的正文'),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
