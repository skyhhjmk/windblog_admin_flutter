import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/l10n/app_localizations.dart';
import 'package:windblog_admin_flutter/main.dart';

late AppLocalizations _zh;

class _SyncLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncLocalizationsDelegate(this.value);

  final AppLocalizations value;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(value);

  @override
  bool shouldReload(_SyncLocalizationsDelegate old) => false;
}

class _TestConflictApi extends AdminApiClient {
  _TestConflictApi({
    required this.currentDetail,
  });

  PostDetail currentDetail;
  final StreamController<Map<String, dynamic>> eventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  PostEditRequest? lastUpdateRequest;

  @override
  Future<List<CategoryItem>> listCategories() async => const [];

  @override
  Future<List<TagItem>> listTags() async => const [];

  @override
  Future<List<RepostPolicyItem>> listRepostPolicies() async => const [];

  @override
  Future<List<PostRevisionItem>> listPostRevisions(int postId) async => const [];

  @override
  Stream<Map<String, dynamic>> postEvents(int postId) => eventsController.stream;

  @override
  Future<PostDetail> postDetail(int id) async => currentDetail;

  @override
  Future<PostDetail> updatePost(int id, PostEditRequest request) async {
    lastUpdateRequest = request;
    if (!request.force && request.version != currentDetail.version) {
      throw Exception('版本冲突: version mismatch');
    }
    currentDetail = _createPost(
      id: id,
      version: currentDetail.version + 1,
      currentRevisionNumber: currentDetail.currentRevisionNumber,
      title: request.title['zh-cn'] ?? '',
      content: request.contentMarkdown['zh-cn'] ?? '',
      aiSummary: request.aiSummary,
    );
    return currentDetail;
  }
}

PostDetail _createPost({
  int id = 1,
  int version = 1,
  int currentRevisionNumber = 1,
  String title = '初始标题',
  String content = '初始正文第一行\n初始正文第二行',
  Map<String, String>? aiSummary,
}) {
  return PostDetail(
    id: id,
    slug: 'test-slug',
    title: {'zh-cn': title},
    summary: const {'zh-cn': '初始摘要'},
    contentMarkdown: {'zh-cn': content},
    status: 1,
    visibility: 0,
    hasPassword: false,
    renderType: 6,
    editorType: 6,
    aiSummaryStatus: 0,
    aiSummary: aiSummary ?? const {},
    version: version,
    currentRevisionNumber: currentRevisionNumber,
    publishedRevisionNumber: 0,
    hasPublishedRevision: false,
  );
}

Future<AdminNotificationController> _pumpEditor(
  WidgetTester tester,
  _TestConflictApi api,
  PostDetail detail,
) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1400, 2200));
  final notifications = AdminNotificationController();
  addTearDown(notifications.clear);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: [
        _SyncLocalizationsDelegate(_zh),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', ''), Locale('en', '')],
      locale: const Locale('zh', ''),
      theme: AdminTheme.build(),
      home: AdminNotificationHost(
        api: api,
        controller: notifications,
        child: PostEditorPage(
          api: api,
          detail: detail,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return notifications;
}

void main() {
  setUpAll(() async {
    _zh = AppLocalizations(const Locale('zh'));
    await _zh.load();
  });

  testWidgets('seamlessly refreshes version credential on benign SSE post update', (
    WidgetTester tester,
  ) async {
    final initial = _createPost();
    final api = _TestConflictApi(currentDetail: initial);
    final notifications = await _pumpEditor(tester, api, initial);

    // Simulate backend AI task completion bumping version without revision change
    api.currentDetail = _createPost(
      version: 2,
      aiSummary: {'zh-cn': 'AI自动生成摘要'},
    );
    api.eventsController.add({
      'type': 'POST_UPDATED',
      'postId': initial.id,
      'version': 2,
      'currentRevisionNumber': initial.currentRevisionNumber,
      'source': 'AI_SUMMARY',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // No conflict dialog should appear
    expect(find.text('检测到服务端文章已经被更新'), findsNothing);

    // Saving now should succeed with refreshed version 2
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.lastUpdateRequest, isNotNull);
    expect(api.lastUpdateRequest!.version, 2);
    notifications.clear();
    await tester.pump();
  });

  testWidgets('alerts operator when server revision diverged and draft is dirty', (
    WidgetTester tester,
  ) async {
    final initial = _createPost();
    final api = _TestConflictApi(currentDetail: initial);
    final notifications = await _pumpEditor(tester, api, initial);

    // Make local dirty edit by typing into title field
    final titleField = find.byType(TextField).first;
    await tester.enterText(titleField, '本地修改标题');
    await tester.pump();

    // Server update with new content revision
    api.currentDetail = _createPost(
      version: 2,
      currentRevisionNumber: 2,
      title: '服务端新标题',
      content: '服务端新内容',
    );
    api.eventsController.add({
      'type': 'POST_UPDATED',
      'postId': initial.id,
      'version': 2,
      'currentRevisionNumber': 2,
      'source': 'ADMIN_UPDATE',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Conflict banner and dialog should appear with 5 choices
    expect(find.text('检测到服务端文章已经被更新'), findsWidgets);
    expect(find.text('放弃当前内容重载'), findsOneWidget);
    expect(find.text('diff 服务端'), findsOneWidget);
    expect(find.text('自动冲突合并'), findsOneWidget);
    expect(find.text('手动合并'), findsOneWidget);
    expect(find.text('覆盖服务端'), findsOneWidget);

    notifications.clear();
    await tester.pump();
  });

  testWidgets('option 1: discard and reload server content', (
    WidgetTester tester,
  ) async {
    final initial = _createPost();
    final api = _TestConflictApi(currentDetail: initial);
    final notifications = await _pumpEditor(tester, api, initial);

    final titleField = find.byType(TextField).first;
    await tester.enterText(titleField, '本地修改标题');
    await tester.pump();

    api.currentDetail = _createPost(
      version: 2,
      currentRevisionNumber: 2,
      title: '服务端新标题',
      content: '服务端新内容',
    );
    api.eventsController.add({
      'type': 'POST_UPDATED',
      'postId': initial.id,
      'version': 2,
      'currentRevisionNumber': 2,
      'source': 'ADMIN_UPDATE',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap '放弃当前内容重载'
    await tester.tap(find.text('放弃当前内容重载'));
    await tester.pumpAndSettle();

    // Dialog closed, banner dismissed
    expect(find.text('放弃当前内容重载'), findsNothing);
    // Editor text reloaded to server content
    expect(find.text('服务端新标题'), findsOneWidget);

    notifications.clear();
    await tester.pump();
  });

  testWidgets('option 3: auto merges non-overlapping changes cleanly', (
    WidgetTester tester,
  ) async {
    final initial = _createPost(
      content: 'Line 1: Header\nLine 2: Server line\nLine 3: Client line',
    );
    final api = _TestConflictApi(currentDetail: initial);
    final notifications = await _pumpEditor(tester, api, initial);

    // Operator edits line 3 locally and makes it dirty
    final state = tester.state(find.byType(PostEditorPage)) as dynamic;
    state.contentCtrl.text =
        'Line 1: Header\nLine 2: Server line\nLine 3: Client line edited locally';
    final titleField = find.byType(TextField).first;
    await tester.enterText(titleField, '本地修改标题');
    await tester.pump();

    // Server edited line 2
    api.currentDetail = _createPost(
      version: 2,
      currentRevisionNumber: 2,
      content: 'Line 1: Header\nLine 2: Server line edited remotely\nLine 3: Client line',
    );
    api.eventsController.add({
      'type': 'POST_UPDATED',
      'postId': initial.id,
      'version': 2,
      'currentRevisionNumber': 2,
      'source': 'ADMIN_UPDATE',
    });
    await tester.pumpAndSettle();

    // Tap '自动冲突合并'
    await tester.tap(find.text('自动冲突合并'));
    await tester.pumpAndSettle();

    // Dialog closed
    expect(find.text('自动冲突合并'), findsNothing);
    // Merged content includes both changes
    expect(
      state.contentCtrl.text,
      'Line 1: Header\nLine 2: Server line edited remotely\nLine 3: Client line edited locally',
    );

    notifications.clear();
    await tester.pump();
  });

  testWidgets('option 5: force overwrites server version', (
    WidgetTester tester,
  ) async {
    final initial = _createPost();
    final api = _TestConflictApi(currentDetail: initial);
    final notifications = await _pumpEditor(tester, api, initial);

    final titleField = find.byType(TextField).first;
    await tester.enterText(titleField, '我的强制覆盖标题');
    await tester.pump();

    api.currentDetail = _createPost(
      version: 2,
      currentRevisionNumber: 2,
      title: '服务端新标题',
    );
    api.eventsController.add({
      'type': 'POST_UPDATED',
      'postId': initial.id,
      'version': 2,
      'currentRevisionNumber': 2,
      'source': 'ADMIN_UPDATE',
    });
    await tester.pumpAndSettle();

    // Tap '覆盖服务端'
    await tester.tap(find.text('覆盖服务端'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('确认强制覆盖服务端？'), findsOneWidget);
    await tester.tap(find.text('确认覆盖'));
    await tester.pumpAndSettle();

    expect(api.lastUpdateRequest, isNotNull);
    expect(api.lastUpdateRequest!.force, isTrue);

    notifications.clear();
    await tester.pump();
  });
}
