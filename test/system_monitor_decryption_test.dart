import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/main.dart';

void main() {
  testWidgets(
    'requests step-up authorization before decrypting tracking text',
    (WidgetTester tester) async {
      AdminStepUpAuthorization.clear();
      final api = _SystemMonitorApiStub();
      addTearDown(AdminStepUpAuthorization.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AdminTheme.build(),
            child: Scaffold(
              body: SystemMonitorPage(api: api, onAuthError: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'encrypted-tracking-text');
      await tester.ensureVisible(find.text('解密追踪文本'));
      await tester.tap(find.text('解密追踪文本'));
      await tester.pump();

      expect(find.text('确认解密错误追踪文本'), findsOneWidget);
      expect(api.decryptCalls, 0);

      await tester.enterText(find.byType(TextField).last, 'admin-password');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.issuedPassword, 'admin-password');
      expect(api.decryptCalls, 1);
      expect(api.decryptedStepUpToken, 'step-up-token');
      expect(find.text('decrypted-tracking-text'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _SystemMonitorApiStub extends AdminApiClient {
  _SystemMonitorApiStub() {
    token = 'bearer-token';
  }

  String? issuedPassword;
  String? decryptedStepUpToken;
  int decryptCalls = 0;

  @override
  Future<SystemMonitorInfo> getSystemMonitor() async => SystemMonitorInfo(
    jvm: JvmInfo(
      memoryUsed: 1,
      memoryMax: 2,
      memoryCommitted: 2,
      threadCount: 1,
      peakThreadCount: 1,
      uptime: 1000,
    ),
    system: SystemInfo(
      cpuCount: 1,
      systemLoadAverage: 0,
      osName: 'Linux',
      osVersion: 'test',
      osArch: 'x86_64',
    ),
    application: ApplicationInfo(
      name: 'WindBlog',
      version: 'test',
      startTime: 'now',
      uptime: 1000,
    ),
    health: HealthInfo(status: 'UP', components: {}),
  );

  @override
  Future<String> issueAdminStepUp(String password) async {
    issuedPassword = password;
    return 'step-up-token';
  }

  @override
  Future<String> decryptError(
    String trackingText, {
    String? stepUpToken,
  }) async {
    decryptCalls++;
    decryptedStepUpToken = stepUpToken;
    return 'decrypted-tracking-text';
  }
}
