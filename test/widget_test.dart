// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/l10n/app_localizations.dart';
import 'package:windblog_admin_flutter/main.dart';

void main() {
  test(
    'notification controller updates one persistent task and evicts transient tasks',
    () {
      final controller = AdminNotificationController();

      for (int index = 0; index < 6; index++) {
        controller.showTransient(message: 'message $index');
      }
      expect(controller.transientNotifications, hasLength(5));
      expect(controller.transientNotifications.first.message, 'message 5');

      controller.showPersistent(taskId: 'task-1', title: '上传', message: '准备上传');
      controller.updatePersistent(
        taskId: 'task-1',
        message: '上传 50%',
        progressMode: AdminNotificationProgressMode.determinate,
        progress: 0.5,
      );
      expect(controller.persistentNotifications, hasLength(1));
      expect(controller.persistentNotifications.first.progress, 0.5);
      expect(controller.persistentNotifications.first.message, '上传 50%');

      controller.completePersistent(taskId: 'task-1', message: '完成');
      controller.recordNavigation();
      controller.recordNavigation();
      controller.recordNavigation();
      expect(controller.persistentNotifications, isEmpty);
      expect(
        controller.transientNotifications.any((item) => item.message == '完成'),
        isTrue,
      );
      controller.clear();
    },
  );

  testWidgets('notification host renders right-bottom queue', (
    WidgetTester tester,
  ) async {
    final controller = AdminNotificationController();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminNotificationHost(
          api: AdminApiClient(),
          controller: controller,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    controller.showPersistent(
      taskId: 'render-task',
      title: '上传中',
      message: '文件：50%',
      progressMode: AdminNotificationProgressMode.determinate,
      progress: 0.5,
    );
    await tester.pump();
    expect(find.text('上传中'), findsOneWidget);
    expect(find.text('文件：50%'), findsOneWidget);
    controller.clear();
  });

  testWidgets('show login page', (WidgetTester tester) async {
    final api = AdminApiClient();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', ''), Locale('zh', '')],
        home: LoginPage(api: api, onLogin: (baseUrl, token) async {}),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('WindBlog Admin Panel'), findsOneWidget);
  });

  testWidgets('session expired login keeps authenticated workspace state', (
    WidgetTester tester,
  ) async {
    final GlobalKey<_SessionWorkspaceHarnessState> harnessKey =
        GlobalKey<_SessionWorkspaceHarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: false,
          splashFactory: NoSplash.splashFactory,
        ),
        home: _SessionWorkspaceHarness(key: harnessKey),
      ),
    );

    await tester.tap(find.text('Increase'));
    await tester.pump();
    expect(find.text('Count: 1'), findsOneWidget);

    harnessKey.currentState!.showSessionExpiredLogin();
    await tester.pump();
    expect(find.text('Re-login'), findsOneWidget);
    expect(find.text('Count: 1'), findsOneWidget);

    harnessKey.currentState!.hideSessionExpiredLogin();
    await tester.pump();
    expect(find.text('Re-login'), findsNothing);
    expect(find.text('Count: 1'), findsOneWidget);
  });

  testWidgets('structured form renders synonym rule cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: false,
          splashFactory: NoSplash.splashFactory,
        ),
        home: Scaffold(
          body: SynonymRuleEditor(
            initialValue: const <Map<String, dynamic>>[],
            onChanged: (rules) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('新增规则卡片'));
    await tester.pump();
    expect(find.text('规则卡片 1'), findsOneWidget);
    expect(find.text('等价组'), findsAtLeastNWidgets(1));
    expect(find.text('输入词条后按回车添加'), findsOneWidget);
  });

  testWidgets('links add button opens add link page', (
    WidgetTester tester,
  ) async {
    int? selectedLinkType;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: false,
          splashFactory: NoSplash.splashFactory,
        ),
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: LinksAddButton(
              label: '添加链接',
              onOpen: (defaultLinkType) {
                selectedLinkType = defaultLinkType;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('linksAddButton')));
    await tester.pump();

    expect(selectedLinkType, 0);
  });
}

class _SessionWorkspaceHarness extends StatefulWidget {
  const _SessionWorkspaceHarness({super.key});

  @override
  State<_SessionWorkspaceHarness> createState() {
    return _SessionWorkspaceHarnessState();
  }
}

class _SessionWorkspaceHarnessState extends State<_SessionWorkspaceHarness> {
  bool isSessionExpired = false;

  void showSessionExpiredLogin() {
    setState(() {
      isSessionExpired = true;
    });
  }

  void hideSessionExpiredLogin() {
    setState(() {
      isSessionExpired = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminAuthenticatedWorkspace(
      showSessionExpiredLogin: isSessionExpired,
      workspace: const _WorkspaceStateProbe(),
      sessionExpiredLogin: const Positioned.fill(
        child: ColoredBox(
          color: Colors.black54,
          child: Center(child: Text('Re-login')),
        ),
      ),
    );
  }
}

class _WorkspaceStateProbe extends StatefulWidget {
  const _WorkspaceStateProbe();

  @override
  State<_WorkspaceStateProbe> createState() {
    return _WorkspaceStateProbeState();
  }
}

class _WorkspaceStateProbeState extends State<_WorkspaceStateProbe> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Count: $count'),
          TextButton(
            onPressed: () {
              setState(() {
                count = count + 1;
              });
            },
            child: const Text('Increase'),
          ),
        ],
      ),
    );
  }
}
