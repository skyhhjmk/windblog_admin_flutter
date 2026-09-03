import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/main.dart';

void main() {
  testWidgets(
    'edits the Codex Creator connection without exposing its secret',
    (WidgetTester tester) async {
      AdminStepUpAuthorization.clear();
      final api = _CodexCreatorApiStub();
      addTearDown(AdminStepUpAuthorization.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AdminTheme.build(),
            child: Scaffold(
              body: CodexCreatorPage(api: api, onAuthError: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('连接配置'), findsOneWidget);
      expect(find.textContaining('已配置（已隐藏）'), findsOneWidget);
      expect(find.text('stored-secret'), findsNothing);

      await tester.enterText(
        find.byType(TextField).at(0),
        'https://creator.example.com/',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'replacement-secret',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.ensureVisible(find.text('保存连接配置'));
      await tester.tap(find.text('保存连接配置'));
      await tester.pump();

      expect(find.text('确认 Codex Creator 连接配置'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'admin-password');
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(api.updateCalls, 1);
      expect(api.updatedEndpoint, 'https://creator.example.com/');
      expect(api.updatedSecret, 'replacement-secret');
      expect(api.updatedStepUpToken, 'step-up-token');
      expect(find.text('replacement-secret'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _CodexCreatorApiStub extends AdminApiClient {
  _CodexCreatorApiStub() {
    token = 'bearer-token';
  }

  int updateCalls = 0;
  String? updatedEndpoint;
  String? updatedSecret;
  String? updatedStepUpToken;

  Map<String, dynamic> get config => {
    'providerId': 7,
    'providerName': 'Codex Creator (内部)',
    'endpoint': 'http://codex-creator:8681',
    'enabled': true,
    'sharedSecretConfigured': true,
    'hasDatabaseConfig': true,
    'source': 'database',
    'model': 'codex-default',
  };

  @override
  Future<Map<String, dynamic>> codexCreatorConfig() async => config;

  @override
  Future<Map<String, dynamic>> codexCreatorStatus() async => {
    'connected': true,
    'status': {'ready': true},
  };

  @override
  Future<Map<String, dynamic>> codexCreatorTopicAutomation() async => {
    'settings': {
      'enabled': false,
      'intervalMinutes': 360,
      'maxSeedsPerRun': 5,
      'maxTopicsPerRun': 20,
    },
    'seeds': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> codexCreatorTopics({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async => {
    'items': <Map<String, dynamic>>[],
    'total': 0,
    'page': page,
    'pageSize': pageSize,
  };

  @override
  Future<Map<String, dynamic>> codexCreatorTopicRuns({
    int page = 1,
    int pageSize = 20,
  }) async => {
    'items': <Map<String, dynamic>>[],
    'total': 0,
    'page': page,
    'pageSize': pageSize,
  };

  @override
  Future<List<CategoryItem>> listCategories() async => <CategoryItem>[];

  @override
  Future<String> issueAdminStepUp(String password) async => 'step-up-token';

  @override
  Future<Map<String, dynamic>> updateCodexCreatorConfig({
    required String endpoint,
    required bool enabled,
    String? sharedSecret,
    String? model,
    String? stepUpToken,
  }) async {
    updateCalls++;
    updatedEndpoint = endpoint;
    updatedSecret = sharedSecret;
    updatedStepUpToken = stepUpToken;
    return config;
  }
}
