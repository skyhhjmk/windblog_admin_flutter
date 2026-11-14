import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/l10n/app_localizations.dart';

void main() {
  test('zh.json and en.json key parity and non-empty values', () {
    final zhFile = File('assets/l10n/zh.json');
    final enFile = File('assets/l10n/en.json');

    expect(zhFile.existsSync(), isTrue);
    expect(enFile.existsSync(), isTrue);

    final Map<String, dynamic> zh = json.decode(zhFile.readAsStringSync());
    final Map<String, dynamic> en = json.decode(enFile.readAsStringSync());

    expect(
      zh.keys.toSet(),
      en.keys.toSet(),
      reason: 'zh.json and en.json should contain the exact same keys',
    );

    for (final entry in zh.entries) {
      expect(
        entry.value.toString().trim().isNotEmpty,
        isTrue,
        reason: 'Key ${entry.key} in zh.json should not be empty',
      );
    }

    for (final entry in en.entries) {
      expect(
        entry.value.toString().trim().isNotEmpty,
        isTrue,
        reason: 'Key ${entry.key} in en.json should not be empty',
      );
    }
  });

  testWidgets('t() helper fallback behavior without localization context', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('placeholder'))),
    );

    final context = tester.element(find.text('placeholder'));

    expect(t(context, 'non_existent_key'), 'non_existent_key');
    expect(t(context, 'non_existent_key', fallback: '默认回退文本'), '默认回退文本');
  });
}
