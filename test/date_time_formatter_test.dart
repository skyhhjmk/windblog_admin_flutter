import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/utils/date_time_formatter.dart';

void main() {
  testWidgets('DateTimeFormatter formats zh and en locales cleanly', (
    tester,
  ) async {
    final sample = DateTime.utc(2026, 11, 20, 5, 30, 45);
    final local = sample.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final expectedZh =
        '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';

    late String zhFormatted;
    late String enFormatted;
    late String justNowZh;
    late String minutesAgoEn;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) {
            zhFormatted = DateTimeFormatter.formatDateTime(
              context,
              sample.toIso8601String(),
            );
            justNowZh = DateTimeFormatter.formatHuman(
              context,
              local.subtract(const Duration(seconds: 20)),
              now: local,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(zhFormatted, expectedZh);
    expect(zhFormatted.contains('T'), isFalse);
    expect(justNowZh, '刚刚');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) {
            enFormatted = DateTimeFormatter.formatDateTime(
              context,
              sample.toIso8601String(),
            );
            minutesAgoEn = DateTimeFormatter.formatHuman(
              context,
              local.subtract(const Duration(minutes: 5)),
              now: local,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(enFormatted, contains('Nov'));
    expect(enFormatted, contains('2026'));
    expect(minutesAgoEn, '5m ago');
  });

  testWidgets('DateTimeFormatter handles null and invalid values safely', (
    tester,
  ) async {
    late String nullResult;
    late String invalidResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            nullResult = DateTimeFormatter.formatDateTime(context, null);
            invalidResult = DateTimeFormatter.formatDateTime(
              context,
              'invalid-ts',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(nullResult, '-');
    expect(invalidResult, 'invalid-ts');
  });
}
