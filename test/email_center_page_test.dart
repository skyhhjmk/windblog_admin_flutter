import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/main.dart';

class _EmailApi extends AdminApiClient {
  bool fail = true;
  Map<String, dynamic>? saved;
  @override
  Future<List<Map<String, dynamic>>> listEmailChannels() async => [];
  @override
  Future<List<Map<String, dynamic>>> listEmailGroups() async => [];
  @override
  Future<List<Map<String, dynamic>>> listEmailRoutes() async => [];
  @override
  Future<List<Map<String, dynamic>>> listEmailTemplates() async => [];
  @override
  Future<List<Map<String, dynamic>>> listEmailCampaigns() async => [];
  @override
  Future<PaginatedEmailDeliveryResult> listEmailDeliveries({
    int page = 1,
    String? status,
  }) async => PaginatedEmailDeliveryResult(
    items: [],
    total: 0,
    page: page,
    pageSize: 20,
  );
  @override
  Future<void> createEmailChannel(Map<String, dynamic> values) async {
    if (fail) throw Exception('SMTP 保存失败');
    saved = values;
  }
}

void main() {
  testWidgets('SMTP 保存失败保留输入，重试成功后关闭弹窗', (tester) async {
    final api = _EmailApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmailCenterPage(api: api, onAuthError: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增 SMTP 通道'));
    await tester.pumpAndSettle();
    Future<void> fill(String label, String value) async {
      final field = find.widgetWithText(TextField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await fill('名称', '测试通道');
    await fill('SMTP 主机', 'smtp.example.com');
    await fill('发件人邮箱', 'sender@example.com');
    await fill('SMTP 端口', '2525');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('保存失败：'), findsOneWidget);
    expect(find.text('测试通道'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(api.saved?['port'], 2525);
    expect(api.saved?['name'], '测试通道');
  });
}
