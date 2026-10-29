import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/main.dart';

PostItem article(
  String slug, {
  int status = 1,
  int visibility = 0,
  String? title,
}) => PostItem.fromMap({
  'id': 42,
  'slug': slug,
  'title': {'zh-cn': title ?? slug},
  'status': status,
  'visibility': visibility,
  'hasPublishedRevision': status == 1,
});
PostListResult result(List<PostItem> items, {int page = 1, int total = 1}) =>
    PostListResult(items: items, total: total, page: page, pageSize: 20);

class _Api extends AdminApiClient {
  Future<PostListResult> Function(int, String?)? handler;
  @override
  Future<PostListResult> listPosts({
    required int page,
    required int pageSize,
    String? keyword,
    String sortBy = 'id',
    int? status,
    int? categoryId,
  }) async => handler!(page, keyword);
}

void main() {
  test('generated reference escapes titles and URL path segments', () {
    final block = articleReferenceMarkdown(
      article('a) [bad]/中文', title: '标题] *粗体*\n::: /article'),
    );
    expect(block, contains(r'标题\] \*粗体\* ::: /article'));
    expect(block, contains('/post/a%29%20%5Bbad%5D%2F'));
    expect(block.split('\n').where((line) => line == '::: /article').length, 1);
    expect(analyzeMarkdownOutline(block)['blocks'], isEmpty);
  });

  testWidgets(
    'toolbar inserts a reference at the selection and marks editor changed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      final target = article('target', title: '目标文章');
      final api = _Api()
        ..handler = (_, _) async => result([
          target,
          article('draft', status: 0),
          article('private', visibility: 1),
        ], total: 3);
      final controller = MarkdownSyntaxController(text: 'before replace after');
      controller.selection = const TextSelection(
        baseOffset: 7,
        extentOffset: 14,
      );
      var changed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownPlusEditor(
              controller: controller,
              api: api,
              onChanged: () => changed++,
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('引用文章'));
      await tester.pumpAndSettle();
      final draft = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'draft'),
      );
      final private = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'private'),
      );
      expect(draft.onTap, isNull);
      expect(private.onTap, isNull);
      await tester.tap(find.text('目标文章'));
      await tester.pump();
      expect(
        controller.text,
        'before ${articleReferenceMarkdown(target)} after',
      );
      expect(changed, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 230));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ArticleReferenceCard), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('reference card retains native link action in both themes', (
    tester,
  ) async {
    final links = <String>[];
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: ArticlePreviewMarkdown(
              data: articleReferenceMarkdown(article('linked', title: '引用的标题')),
              onLinkTap: links.add,
            ),
          ),
        ),
      );
      expect(find.byType(ArticleReferenceCard), findsOneWidget);
      await tester.tap(find.text('引用的标题', findRichText: true));
    }
    expect(links, ['/post/linked', '/post/linked']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker retries failed requests and paginates', (tester) async {
    var calls = 0;
    final pages = <int>[];
    final api = _Api()
      ..handler = (page, keyword) async {
        pages.add(page);
        if (calls++ == 0) throw StateError('offline');
        return result([article('page-$page')], page: page, total: 21);
      };
    await tester.pumpWidget(
      MaterialApp(home: ArticleReferencePicker(api: api)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('加载文章失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('page-1'), findsOneWidget);
    await tester.tap(find.byTooltip('下一页'));
    await tester.pumpAndSettle();
    expect(find.text('page-2'), findsOneWidget);
    expect(pages, [1, 1, 2]);
  });

  testWidgets('a late search response cannot overwrite newer results', (
    tester,
  ) async {
    final oldRequest = Completer<PostListResult>();
    final api = _Api()
      ..handler = (_, keyword) async {
        if (keyword == 'old') return oldRequest.future;
        return result([
          article(keyword?.isNotEmpty == true ? keyword! : 'initial'),
        ]);
      };
    await tester.pumpWidget(
      MaterialApp(home: ArticleReferencePicker(api: api)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'new'), findsOneWidget);
    oldRequest.complete(result([article('stale')]));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'new'), findsOneWidget);
    expect(find.text('stale'), findsNothing);
  });
}
