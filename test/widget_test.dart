// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:windblog_admin_flutter/main.dart';

void main() {
  testWidgets('show login page', (WidgetTester tester) async {
    await tester.pumpWidget(const WindblogAdminApp());
    expect(find.text('WindBlog 管理后台'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });
}
