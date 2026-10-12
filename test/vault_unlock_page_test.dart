import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_local_authentication');

  testWidgets('waiting authentication leaves cancellation interactive', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final pending = Completer<void>();
    FlutterSecureStorage.setMockInitialValues({
      'admin_instance_vault_system_enabled_v1': 'true',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'canAuthenticate') return true;
          if (call.method == 'cancelAuthentication') {
            pending.complete();
            return true;
          }
          return null;
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await tester.pumpWidget(
      MaterialApp(home: VaultUnlockPage(onUnlock: (_) => pending.future)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用系统认证解锁'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('取消认证'));
    await tester.pumpAndSettle();
    expect(find.text('取消认证'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
