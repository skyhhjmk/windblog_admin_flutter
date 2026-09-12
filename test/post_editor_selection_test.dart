import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/main.dart';

class _LinkTrackingApi extends AdminApiClient {
  int findArticleLinkCalls = 0;

  @override
  Future<AdminLinkItem?> findArticleLink(String url) async {
    findArticleLinkCalls++;
    return null;
  }
}

void main() {
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
    expect(editable.selectionColor, isNotNull);
    expect(state.renderEditable.selection, controller.selection);
    expect(state.renderEditable.selectionColor, editable.selectionColor);
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

    await tester.tap(find.byType(EditableText));
    await tester.pump();
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(state.renderEditable.selectionColor, isNotNull);
  });
}
