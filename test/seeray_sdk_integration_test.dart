import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seeray_analytics_flutter/seeray_analytics_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'WindBlog Admin can initialize SeeRay and send a consented screen event',
    () async {
      Map<String, dynamic>? requestBody;
      final analytics = await SeeRayAnalytics.create(
        const SeeRayAnalyticsOptions(
          siteId: 'srl_windblog_admin_test',
          apiOrigin: 'https://analytics.example.test',
          requireConsent: true,
        ),
        client: MockClient((request) async {
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('', 202);
        }),
      );

      expect(analytics.consentState, SeeRayConsentState.unknown);
      analytics.trackScreen(
        name: 'admin_home',
        url: 'https://www.example.test/admin?token=must-not-send',
      );
      expect(analytics.pendingEventCount, 0);

      await analytics.setConsent(granted: true);
      analytics.trackScreen(
        name: 'admin_home',
        url: 'https://www.example.test/admin?token=must-not-send#overview',
      );
      expect(await analytics.flush(), isTrue);

      final event =
          (requestBody!['events'] as List).single as Map<String, dynamic>;
      expect(requestBody!['schemaVersion'], 1);
      expect(requestBody!['siteId'], 'srl_windblog_admin_test');
      expect(event['type'], 'page_view');
      expect(event['url'], 'https://www.example.test/admin');
      expect((event['properties'] as Map)['screen'], 'admin_home');
      analytics.close();
    },
  );
}
