import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/main.dart';

class _ObservabilityApiStub extends AdminApiClient {
  bool grafanaCalled = false;
  bool kibanaCalled = false;
  bool throwGrafanaError = false;

  @override
  Future<Map<String, dynamic>> grafanaEmbedUrl() async {
    grafanaCalled = true;
    if (throwGrafanaError) {
      throw Exception('Grafana mock error');
    }
    return {
      'url':
          '/observability/grafana/d/windblog-platform-slo/windblog-platform-slo?orgId=1&kiosk',
      'expiresAt': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 900,
    };
  }

  @override
  Future<Map<String, dynamic>> kibanaUrl() async {
    kibanaCalled = true;
    return {'url': 'http://localhost:5601'};
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (MethodCall methodCall) async => true,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        );
  });

  testWidgets('GrafanaEmbed 显示 Grafana 与 Kibana 快捷按钮', (
    WidgetTester tester,
  ) async {
    final api = _ObservabilityApiStub();
    api.baseUrl = 'http://localhost:8080';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrafanaEmbed(api: api, onAuthError: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('系统监控与日志 / Observability'), findsOneWidget);
    expect(find.text('在浏览器中打开 Grafana Dashboard'), findsOneWidget);
    expect(find.text('快捷打开 Kibana 控制台'), findsOneWidget);

    // Tap Kibana shortcut button
    await tester.tap(find.text('快捷打开 Kibana 控制台'));
    await tester.pumpAndSettle();

    expect(api.grafanaCalled, isTrue);
    expect(api.kibanaCalled, isTrue);
  });

  testWidgets('Grafana 加载失败时 Kibana 按钮仍然可用', (WidgetTester tester) async {
    final api = _ObservabilityApiStub();
    api.throwGrafanaError = true;
    api.baseUrl = 'http://localhost:8080';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrafanaEmbed(api: api, onAuthError: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('系统监控与日志 / Observability'), findsOneWidget);
    expect(find.text('Grafana 观测面板暂不可用'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('快捷打开 Kibana'), findsOneWidget);

    await tester.tap(find.text('快捷打开 Kibana'));
    await tester.pumpAndSettle();

    expect(api.kibanaCalled, isTrue);
  });
}
