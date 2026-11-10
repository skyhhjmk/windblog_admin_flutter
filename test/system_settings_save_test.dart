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

void main() {
  setUpAll(() async {
    _zh = AppLocalizations(const Locale('zh'));
    await _zh.load();
  });

  testWidgets(
    'saving site info SEO settings is a daily operation without step-up',
    (WidgetTester tester) async {
      AdminStepUpAuthorization.clear();
      final api = _SystemSettingsApiStub();
      final notifications = AdminNotificationController();
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        AdminStepUpAuthorization.clear();
        notifications.clear();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            _SyncLocalizationsDelegate(_zh),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh')],
          locale: const Locale('zh'),
          home: AdminNotificationHost(
            api: api,
            controller: notifications,
            child: AdminShortcutHost(
              child: Theme(
                data: AdminTheme.build(),
                child: Scaffold(
                  body: SystemSettingsPage(api: api, onAuthError: () {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('保存配置'), findsWidgets);
      expect(find.text('简单设置 · 即时生效'), findsOneWidget);
      expect(find.text('关键设置 · 需验证期'), findsOneWidget);
      expect(find.textContaining('此设置可能影响站点运行'), findsOneWidget);
      expect(find.text('SEO描述'), findsOneWidget);
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText?.startsWith('添加标签') == true,
        ),
        'new-keyword',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '更新后的 SEO 描述');
      await tester.tap(find.text('保存配置').first);
      await tester.pump();

      await tester.pump();
      expect(find.text('确认系统设置操作'), findsNothing);

      api.reloadCompleter.complete([api.setting, api.criticalSetting]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.updateCalls, 1);
      expect(api.updatedKey, 'site_info');
      expect(find.text('保存成功'), findsOneWidget);
      expect(api.updatedValue?['keywords'], ['blog', 'tech', 'new-keyword']);
      expect(api.updatedValue?['description'], '更新后的 SEO 描述');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'SidebarLayoutSettingsEditor supports multi-area switching, custom HTML widgets, and saving',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, dynamic>? savedPayload;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SidebarLayoutSettingsEditor(
                initialValues: const <String, dynamic>{},
                isFrozen: false,
                onSave: (values) {
                  savedPayload = values;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('首页侧边栏'), findsWidgets);
      expect(find.text('新增自定义 HTML'), findsOneWidget);

      await tester.tap(find.text('新增自定义 HTML'));
      await tester.pumpAndSettle();

      expect(find.text('HTML 或公告内容'), findsOneWidget);

      await tester.tap(find.textContaining('文章详情页侧边栏'));
      await tester.pumpAndSettle();

      expect(find.text('文章目录 (TOC)'), findsWidgets);

      final saveButton = find.text('保存侧边栏配置');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(savedPayload, isNotNull);
      final areas = savedPayload!['areas'] as Map<String, dynamic>;
      expect((areas['home'] as List).length, 5);
      expect((areas['post'] as List).length, 8);
    },
  );

  testWidgets(
    'adapts layout for mobile with horizontal scrollable chips and responsive cards',
    (WidgetTester tester) async {
      AdminStepUpAuthorization.clear();
      final api = _SystemSettingsApiStub();
      final notifications = AdminNotificationController();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        AdminStepUpAuthorization.clear();
        notifications.clear();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            _SyncLocalizationsDelegate(_zh),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh')],
          locale: const Locale('zh'),
          home: AdminNotificationHost(
            api: api,
            controller: notifications,
            child: AdminShortcutHost(
              child: Theme(
                data: AdminTheme.build(),
                child: Scaffold(
                  body: SystemSettingsPage(api: api, onAuthError: () {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsWidgets);
      expect(find.text('基础设置'), findsOneWidget);
    },
  );
}

class _SystemSettingsApiStub extends AdminApiClient {
  _SystemSettingsApiStub() {
    token = 'bearer-token';
  }

  int listCalls = 0;
  int updateCalls = 0;
  String? updatedKey;
  Map<String, dynamic>? updatedValue;

  final reloadCompleter = Completer<List<SystemSetting>>();

  SystemSetting get setting => SystemSetting(
    id: 1,
    configKey: 'site_info',
    configValue: const <String, dynamic>{
      'title': 'WindBlog',
      'subtitle': '技术博客',
      'keywords': ['blog', 'tech'],
      'description': '原 SEO 描述',
      'author': 'BiliWind',
      'site_url': 'https://example.com',
    },
    configType: 'object',
    groupName: '基础设置',
    uiSchema: UISchema(
      type: 'object',
      fields: [
        UISchemaField(key: 'title', label: '站点标题', widget: 'input'),
        UISchemaField(key: 'subtitle', label: '站点副标题', widget: 'input'),
        UISchemaField(key: 'keywords', label: 'SEO关键词', widget: 'tag_input'),
        UISchemaField(key: 'description', label: 'SEO描述', widget: 'textarea'),
        UISchemaField(key: 'author', label: '站点作者', widget: 'input'),
        UISchemaField(
          key: 'site_url',
          label: '本站链接',
          widget: 'input',
          required: true,
        ),
      ],
    ),
    description: '网站基础信息设置',
    version: 1,
    isFrozen: false,
    settingLevel: 'NORMAL',
    requiresVerification: false,
  );

  SystemSetting get criticalSetting => SystemSetting(
    id: 2,
    configKey: 'security_network',
    configValue: const <String, dynamic>{'client_ip_header': 'X-Forwarded-For'},
    configType: 'object',
    groupName: '基础设置',
    uiSchema: UISchema(
      type: 'object',
      fields: [
        UISchemaField(key: 'client_ip_header', label: '客户端 IP 请求头', widget: 'input'),
      ],
    ),
    description: '可信代理与客户端 IP 解析设置',
    version: 1,
    isFrozen: false,
    settingLevel: 'CRITICAL',
    requiresVerification: true,
  );

  @override
  Future<List<SystemSetting>> listSystemSettings({String? group}) async {
    listCalls++;
    if (listCalls == 2) return reloadCompleter.future;
    return [setting, criticalSetting];
  }

  @override
  Future<String> issueAdminStepUp(String password) async => 'step-up-token';

  @override
  Future<SystemSetting> updateSystemSetting(
    String key,
    dynamic value, {
    String? reason,
    String? stepUpToken,
  }) async {
    updateCalls++;
    updatedKey = key;
    updatedValue = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    return setting;
  }
}
