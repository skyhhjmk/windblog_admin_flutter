import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/l10n/app_localizations.dart';
import 'package:windblog_admin_flutter/main.dart';

class _LinkTrackingApi extends AdminApiClient {
  int findArticleLinkCalls = 0;

  @override
  Future<AdminLinkItem?> findArticleLink(String url) async {
    findArticleLinkCalls++;
    return null;
  }
}

class _PostSaveApi extends AdminApiClient {
  int updateCalls = 0;

  @override
  Future<List<CategoryItem>> listCategories() async => const [];

  @override
  Future<List<TagItem>> listTags() async => const [];

  @override
  Future<List<RepostPolicyItem>> listRepostPolicies() async => const [];

  @override
  Future<List<PostRevisionItem>> listPostRevisions(int postId) async =>
      const [];

  @override
  Future<PostDetail> updatePost(int id, PostEditRequest request) async {
    updateCalls++;
    return PostDetail(
      id: id,
      slug: request.slug,
      title: request.title,
      summary: request.summary,
      aiSummary: request.aiSummary,
      contentMarkdown: request.contentMarkdown,
      status: request.status,
      visibility: request.visibility,
      hasPassword: false,
      renderType: request.renderType,
      editorType: request.editorType,
      aiSummaryStatus: request.aiSummaryStatus,
      currentRevisionNumber: 1,
      version: request.version + 1,
      publishedRevisionNumber: 0,
      hasPublishedRevision: false,
      repostPolicyCode: request.repostPolicyCode,
    );
  }
}

PostDetail _postForSaveTest() {
  return PostDetail(
    id: 11,
    slug: 'save-test',
    title: const {'zh-cn': '保存测试文章'},
    summary: const {'zh-cn': '摘要'},
    aiSummary: const {},
    contentMarkdown: const {'zh-cn': '正文'},
    status: 0,
    visibility: 0,
    hasPassword: false,
    renderType: 6,
    editorType: 6,
    aiSummaryStatus: 0,
    currentRevisionNumber: 1,
    version: 1,
    publishedRevisionNumber: 0,
    hasPublishedRevision: false,
  );
}

PostDetail _legacyPostForDirtyTest() {
  return PostDetail(
    id: 12,
    slug: 'legacy-post',
    title: const {'zh-cn': '旧版文章'},
    summary: const {'zh-cn': '摘要'},
    aiSummary: const {},
    contentMarkdown: const {'zh-cn': '正文'},
    status: 0,
    visibility: 0,
    hasPassword: false,
    renderType: 0,
    editorType: 0,
    aiSummaryStatus: 0,
    currentRevisionNumber: 1,
    version: 1,
    publishedRevisionNumber: 0,
    hasPublishedRevision: false,
  );
}

void main() {
  test('Markdown outline analysis is a pure serializable computation', () {
    final result = analyzeMarkdownOutline('''# 标题
::: quick {group=security, title="检查项", exclude=cn,us}
内容
::: /quick''');

    expect(result['outline'], ['# 标题']);
    expect(result['stats'], {'quick': 1});
    final blocks = result['blocks']! as List<Object?>;
    expect(blocks, hasLength(1));
    final block = blocks.single as Map<Object?, Object?>;
    expect(block['level'], 'quick');
    expect(block['group'], 'security');
    expect(block['exclude'], ['cn']);
  });

  testWidgets('saving stays in the editor and uses a transient notification', (
    WidgetTester tester,
  ) async {
    final api = _PostSaveApi();
    final notifications = AdminNotificationController();
    addTearDown(notifications.clear);
    addTearDown(() async => tester.binding.setSurfaceSize(null));
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
        home: AdminNotificationHost(
          api: api,
          controller: notifications,
          child: PostEditorPage(api: api, detail: _postForSaveTest()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.updateCalls, 1);
    expect(find.byType(PostEditorPage), findsOneWidget);
    expect(notifications.persistentNotifications, isEmpty);
    expect(
      notifications.transientNotifications.any(
        (item) => item.message == '草稿保存成功',
      ),
      isTrue,
    );
    expect(find.text('未保存'), findsNothing);
    notifications.clear();
  });

  testWidgets('legacy editor defaults do not create an unsaved state', (
    WidgetTester tester,
  ) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));
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
        home: PostEditorPage(
          api: _PostSaveApi(),
          detail: _legacyPostForDirtyTest(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('未保存'), findsNothing);
  });

  testWidgets('mouse-wheel scrolling animates toward the target offset', (
    WidgetTester tester,
  ) async {
    final controller = SmoothScrollController();
    addTearDown(controller.dispose);
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 300));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: const SizedBox(height: 2000),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.position.pointerScroll(120);
    expect(controller.offset, lessThan(120));
    expect(controller.offset, greaterThanOrEqualTo(0));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(controller.offset, greaterThan(0));
    expect(controller.offset, lessThan(120));

    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.offset, closeTo(120, 0.1));
  });

  test('mouse dragging remains available for text selection', () {
    const behavior = SmoothScrollBehavior();

    expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
    expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
    expect(behavior.dragDevices, isNot(contains(PointerDeviceKind.mouse)));
  });

  testWidgets('mouse drag selects text in the Markdown source area', (
    WidgetTester tester,
  ) async {
    final controller = MarkdownSyntaxController(text: '这是可以用鼠标拖拽选中的源码内容');
    addTearDown(controller.dispose);
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1000, 700));

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(),
        scrollBehavior: const SmoothScrollBehavior(),
        home: Scaffold(
          body: MarkdownPlusEditor(
            controller: controller,
            api: AdminApiClient(),
          ),
        ),
      ),
    );
    await tester.pump();

    final editable = find.byType(EditableText);
    final start = tester.getTopLeft(editable) + const Offset(8, 18);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(180, 0));
    await gesture.up();
    await tester.pump();

    expect(controller.selection.isCollapsed, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Markdown editor paints an explicit selection color', (
    WidgetTester tester,
  ) async {
    final controller = MarkdownSyntaxController(text: '可被选中的文章内容');
    addTearDown(controller.dispose);
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1000, 700));

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

    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    await tester.pump();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.cursorOpacityAnimates, isTrue);
    expect(editable.selectionColor, isNotNull);
    expect(state.renderEditable.selection, controller.selection);
    expect(state.renderEditable.selectionColor, editable.selectionColor);
  });

  testWidgets('Markdown preview keeps GFM table rows in one block', (
    WidgetTester tester,
  ) async {
    final controller = MarkdownSyntaxController(
      text: '''| 控制层 | 应回答的问题 | 常见遗漏 |
| --- | --- | --- |
| 云安全组 | 哪些 IP 或网段能到达面板端口？ | 排障后遗留全网放行 |
| 主机防火墙 | 云侧规则变化后，实例仍拒绝什么？ | 未核对服务监听地址与端口 |
| 面板账户 | 谁能登录、权限多大、能否追溯？ | 共用管理员账号或只靠密码 |''',
    );
    addTearDown(controller.dispose);
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1000, 700));

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

    expect(find.byType(Table), findsOneWidget);
  });

  testWidgets('Markdown preview keeps compound blocks intact', (
    WidgetTester tester,
  ) async {
    final controller = MarkdownSyntaxController(
      text: '''- 第一项
  - 嵌套项
- 第二项

> **粗体引用**
> [引用链接](https://example.com)

~~~dart
# 不是标题
- 不是列表

~~~

::: quick {group=security, title="检查项"}
- [x] 容器内任务
::: /quick

尾段''',
    );
    addTearDown(controller.dispose);
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1000, 700));

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

    // List, quote, ~~~ code fence, custom container, and trailing prose.
    expect(find.byType(MarkdownBlockWrapper), findsNWidgets(5));
    expect(find.text('尾段'), findsOneWidget);
  });

  testWidgets('clicking a Markdown link in the source does not open a dialog', (
    WidgetTester tester,
  ) async {
    final controller = MarkdownSyntaxController(
      text: '[文章引用](https://example.com/article)',
    );
    final api = _LinkTrackingApi();
    addTearDown(controller.dispose);
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1000, 700));

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(),
        home: Scaffold(
          body: MarkdownPlusEditor(controller: controller, api: api),
        ),
      ),
    );
    await tester.pump();

    final editable = find.byType(EditableText);
    await tester.tapAt(tester.getTopLeft(editable) + const Offset(12, 18));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.findArticleLinkCalls, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('HTML editor receives the shared selection color', (
    WidgetTester tester,
  ) async {
    final controller = HtmlSyntaxController(text: '<p>可被选中的 HTML 内容</p>');
    addTearDown(controller.dispose);
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1000, 700));

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(),
        home: Scaffold(
          body: HtmlSyntaxEditor(controller: controller, onChanged: () {}),
        ),
      ),
    );
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.cursorOpacityAnimates, isTrue);
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(state.renderEditable.selectionColor, isNotNull);
  });
}
