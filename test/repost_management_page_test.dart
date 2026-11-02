import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/l10n/app_localizations.dart';
import 'package:windblog_admin_flutter/main.dart';

late AppLocalizations _zh;

class _SyncLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncLocalizationsDelegate(this.value);

  final AppLocalizations value;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(value);

  @override
  bool shouldReload(_SyncLocalizationsDelegate old) => false;
}

void main() {
  setUpAll(() async {
    _zh = AppLocalizations(const Locale('zh'));
    await _zh.load();
  });

  testWidgets('repost management page exposes licenses and risk tabs', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          _SyncLocalizationsDelegate(_zh),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        theme: AdminTheme.build(),
        home: Scaffold(
          body: RepostManagementPage(
            api: _EmptyRepostApi(),
            onAuthError: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('转载管理'), findsOneWidget);
    expect(find.text('转载授权'), findsOneWidget);
    expect(find.text('商业链接'), findsOneWidget);
    expect(find.text('短链 Token'), findsOneWidget);
    expect(find.text('原文转化'), findsOneWidget);
    expect(find.text('封禁域名'), findsOneWidget);
    expect(find.text('风险设备'), findsOneWidget);
    expect(find.text('用户转载权限'), findsOneWidget);
    expect(find.byType(PaginationBar), findsWidgets);
  });

  testWidgets('repost user permissions card displays banned status and unban action', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final api = _UserRepostApi();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          _SyncLocalizationsDelegate(_zh),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        theme: AdminTheme.build(),
        home: Scaffold(
          body: RepostManagementPage(
            api: api,
            onAuthError: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap on users tab
    await tester.tap(find.text('用户转载权限'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('banned_user'), findsOneWidget);
    expect(find.text('已封禁'), findsOneWidget);
    expect(find.text('恢复转载权限'), findsOneWidget);
    expect(find.byType(PaginationBar), findsWidgets);
  });

  testWidgets('repost affiliate link explainer renders with dark mode styling', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          _SyncLocalizationsDelegate(_zh),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: RepostManagementPage(
            api: _EmptyRepostApi(),
            onAuthError: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap on affiliate links tab
    await tester.tap(find.text('商业链接'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final card = tester.widget<Card>(
      find.ancestor(
        of: find.byIcon(Icons.info_outline),
        matching: find.byType(Card),
      ).first,
    );
    expect(card.color, isNot(Colors.blue.shade50));
  });
}

class _UserRepostApi extends _EmptyRepostApi {
  @override
  Future<PageResult<Map<String, dynamic>>> listRepostUsers({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    bool? banned,
  }) async {
    return PageResult<Map<String, dynamic>>(
      items: [
        {
          'id': 101,
          'username': 'banned_user',
          'email': 'banned@example.com',
          'nickname': 'Banned User',
          'status': 1,
          'repostBanned': true,
          'repostBanReason': '违规转载',
          'licenseCount': 3,
          'activeLicenseCount': 0,
        },
      ],
      total: 1,
      page: 1,
      pageSize: 20,
    );
  }
}

class _EmptyRepostApi extends AdminApiClient {
  static final PageResult<Map<String, dynamic>> _empty =
      PageResult<Map<String, dynamic>>(
        items: const [],
        total: 0,
        page: 1,
        pageSize: 20,
      );

  @override
  Future<Map<String, dynamic>> repostStats() async => const {
    'licenses': 0,
    'activeLicenses': 0,
    'tokens': 0,
    'clickEvents': 0,
    'suspiciousReposts': 0,
    'affiliateLinks': 0,
    'blockedDomains': 0,
    'riskDevices': 0,
  };

  @override
  Future<PageResult<Map<String, dynamic>>> listRepostLicenses({
    int page = 1,
    int pageSize = 20,
    int? status,
    String? keyword,
  }) async => _empty;

  @override
  Future<PageResult<Map<String, dynamic>>> listRepostTokens({
    int page = 1,
    int pageSize = 20,
    int? status,
    String? tokenType,
    String? keyword,
  }) async => _empty;

  @override
  Future<PageResult<Map<String, dynamic>>> listRepostClickEvents({
    int page = 1,
    int pageSize = 20,
    String? refererCategory,
  }) async => _empty;

  @override
  Future<PageResult<Map<String, dynamic>>> listSuspiciousReposts({
    int page = 1,
    int pageSize = 20,
  }) async => _empty;

  @override
  Future<PageResult<Map<String, dynamic>>> listRepostAffiliateLinks({
    int page = 1,
    int pageSize = 20,
    int? status,
  }) async => _empty;

  @override
  Future<PageResult<Map<String, dynamic>>> listRepostBlockedDomains({
    int page = 1,
    int pageSize = 20,
  }) async => _empty;

  @override
  Future<PageResult<Map<String, dynamic>>> listRepostReferrals({
    int page = 1,
    int pageSize = 20,
  }) async => _empty;

  @override
  Future<PageResult<Map<String, dynamic>>> listRepostUsers({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    bool? banned,
  }) async => _empty;

  @override
  Future<PageResult<Map<String, dynamic>>> listRepostRiskDevices({
    int page = 1,
    int pageSize = 20,
  }) async => _empty;
}
