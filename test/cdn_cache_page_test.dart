import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/main.dart';

class MockAdminApiClient extends AdminApiClient {
  @override
  Future<Map<String, dynamic>> getCdnCacheStatus({
    String? targetBaseUrl,
  }) async {
    return {
      'checkedAt': '2026-11-09T09:30:00Z',
      'overallStatus': 'HEALTHY',
      'targetBaseUrl': 'http://127.0.0.1:8080',
      'probes': [
        {
          'id': '1',
          'name': '公开首页 (GET /)',
          'path': '/',
          'statusCode': 200,
          'cacheControl': 'private, no-cache, must-revalidate',
          'vary': 'Accept-Language, Cookie',
          'level': 'HEALTHY',
          'summary': '安全受控：首页使用私有/协商缓存',
          'suggestion': '',
        },
        {
          'id': '2',
          'name': '管理后台 API',
          'path': '/api/admin/system/monitor',
          'statusCode': 200,
          'cacheControl': 'no-cache, no-store, must-revalidate',
          'vary': 'Cookie',
          'level': 'HEALTHY',
          'summary': '安全受控：私有敏感接口已严格禁止共享缓存',
          'suggestion': '',
        },
      ],
      'recommendations': {
        'cacheKeyCookies': ['user_lang_v2'],
        'bypassCookies': ['user_token', 'admin_jwt', 'post_access_ticket_*'],
        'bypassPaths': ['/api/admin/*', '/api/user/*'],
        'cloudflareRules': {
          'title': 'Cloudflare Cache Rules 推荐配置',
          'bypassRule': '(http.request.uri.path wildcard "/api/admin/*")',
          'cacheKeyAdvice': '在 Cache Key 中添加 user_lang_v2',
        },
        'standardCdnRules': {
          'title': '阿里云 / 腾讯云 CDN 配置要点',
          'directoryNoCache': '/api/admin/, /api/user/',
          'directoryLongCache': '/assets/ (30天)',
          'paramCache': '开启保留 Query String',
          'followOrigin': '开启遵循源站 Cache-Control',
        },
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getCdnCacheRecommendations() async {
    return {
      'cacheKeyCookies': ['user_lang_v2'],
      'bypassCookies': ['user_token', 'admin_jwt'],
      'bypassPaths': ['/api/admin/*'],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('CdnCachePage loads report and renders recommendations', (
    tester,
  ) async {
    final mockApi = MockAdminApiClient();
    await tester.pumpWidget(
      MaterialApp(
        home: CdnCachePage(api: mockApi, onAuthError: () {}),
      ),
    );

    // 等待异步数据加载
    await tester.pumpAndSettle();

    // 验证标题与综合评分
    expect(find.text('CDN 缓存诊断与配置'), findsOneWidget);
    expect(find.text('全站源站缓存标头健康受控'), findsOneWidget);
    expect(find.text('公开首页 (GET /)'), findsOneWidget);
    expect(find.text('管理后台 API'), findsOneWidget);

    // 验证持久显示的推荐配置
    expect(find.text('必须加入 CDN 缓存键（Cache Key）的 Cookie 名'), findsOneWidget);
    expect(find.text('user_lang_v2'), findsOneWidget);
    expect(find.text('必须配置 CDN 绕过缓存（Bypass Cache）的 Cookie 名'), findsOneWidget);
    expect(find.text('user_token'), findsOneWidget);
  });
}
