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

  testWidgets(
    'blockquote maintains spacing and does not squeeze with following content or paragraphs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final controller = MarkdownSyntaxController(
        text: '''> 引用第一段
>
> 引用第二段

正文内容''',
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
      await tester.pumpAndSettle();

      final quote1Finder = find.text('引用第一段', findRichText: true);
      final quote2Finder = find.text('引用第二段', findRichText: true);
      final textFinder = find.text('正文内容', findRichText: true);

      expect(quote1Finder, findsOneWidget);
      expect(quote2Finder, findsOneWidget);
      expect(textFinder, findsOneWidget);

      // Verify quote1 and quote2 have vertical spacing between them (not squeezed)
      final quote1Bottom = tester.getBottomLeft(quote1Finder).dy;
      final quote2Top = tester.getTopLeft(quote2Finder).dy;
      expect(quote2Top - quote1Bottom, greaterThanOrEqualTo(16.0));

      // Verify quote box and regular text have vertical spacing between them
      final quote2Bottom = tester.getBottomLeft(quote2Finder).dy;
      final textTop = tester.getTopLeft(textFinder).dy;
      expect(textTop - quote2Bottom, greaterThanOrEqualTo(32.0));

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('blockquote preserves extra blank lines spacing in preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final singleBlankController = MarkdownSyntaxController(
      text: '''> 引用内容\n\n正文内容''',
    );
    final doubleBlankController = MarkdownSyntaxController(
      text: '''> 引用内容\n\n\n正文内容''',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(),
        home: Scaffold(
          body: MarkdownPlusEditor(
            controller: singleBlankController,
            api: AdminApiClient(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final singleQuote = tester
        .getBottomLeft(find.text('引用内容', findRichText: true))
        .dy;
    final singleText = tester
        .getTopLeft(find.text('正文内容', findRichText: true))
        .dy;
    final singleGap = singleText - singleQuote;

    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(),
        home: Scaffold(
          body: MarkdownPlusEditor(
            controller: doubleBlankController,
            api: AdminApiClient(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final doubleQuote = tester
        .getBottomLeft(find.text('引用内容', findRichText: true))
        .dy;
    final doubleText = tester
        .getTopLeft(find.text('正文内容', findRichText: true))
        .dy;
    final doubleGap = doubleText - doubleQuote;

    expect(doubleGap, greaterThan(singleGap));

    await tester.pumpWidget(const SizedBox.shrink());
    singleBlankController.dispose();
    doubleBlankController.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'cursor movement within preview viewport does not scroll preview or trigger highlight flash',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final controller = MarkdownSyntaxController(
        text: '''段落一

段落二

段落三''',
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
      await tester.pumpAndSettle();

      expect(find.text('段落一', findRichText: true), findsWidgets);
      expect(find.text('段落二', findRichText: true), findsWidgets);
      expect(find.text('段落三', findRichText: true), findsWidgets);

      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(MarkdownPlusEditor),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      final initialOffset = scrollable.position.pixels;

      // Move cursor to "段落二" in the editor
      controller.selection = const TextSelection.collapsed(offset: 6);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(scrollable.position.pixels, equals(initialOffset));

      final wrappers = tester
          .widgetList<MarkdownBlockWrapper>(find.byType(MarkdownBlockWrapper))
          .toList();
      for (final wrapper in wrappers) {
        expect(wrapper.isHighlighted, isFalse);
      }

      // Move cursor to "段落三" in the editor
      controller.selection = const TextSelection.collapsed(offset: 12);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(scrollable.position.pixels, equals(initialOffset));
      for (final wrapper in tester.widgetList<MarkdownBlockWrapper>(
        find.byType(MarkdownBlockWrapper),
      )) {
        expect(wrapper.isHighlighted, isFalse);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );
}
