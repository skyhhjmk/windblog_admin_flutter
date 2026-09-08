import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/l10n/app_localizations.dart';
import 'package:windblog_admin_flutter/main.dart';

void main() {
  testWidgets(
    'saving site info SEO settings is a daily operation without step-up',
    (WidgetTester tester) async {
      AdminStepUpAuthorization.clear();
      final api = _SystemSettingsApiStub();
      final notifications = AdminNotificationController();
      addTearDown(() async {
        AdminStepUpAuthorization.clear();
        notifications.clear();
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
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

      expect(find.text('保存配置'), findsOneWidget);
      expect(find.text('SEO描述'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(2), '更新后的 SEO 描述');
      await tester.tap(find.text('保存配置'));
      await tester.pump();

      await tester.pump();
      expect(find.text('确认系统设置操作'), findsNothing);

      api.reloadCompleter.complete([api.setting]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.updateCalls, 1);
      expect(api.updatedKey, 'site_info');
      expect(api.updatedValue?['description'], '更新后的 SEO 描述');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
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
  );

  @override
  Future<List<SystemSetting>> listSystemSettings({String? group}) async {
    listCalls++;
    if (listCalls == 2) return reloadCompleter.future;
    return [setting];
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
