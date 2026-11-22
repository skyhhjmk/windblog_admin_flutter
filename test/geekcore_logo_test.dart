import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/components/geekcore_logo.dart';

void main() {
  testWidgets('GeekCoreLogo renders CustomPaint at requested size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: GeekCoreLogo(size: 64, showShadow: true)),
        ),
      ),
    );

    final logoFinder = find.byType(GeekCoreLogo);
    expect(logoFinder, findsOneWidget);
    expect(tester.getSize(logoFinder), const Size(64, 64));
    expect(
      find.descendant(of: logoFinder, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
  });
}
