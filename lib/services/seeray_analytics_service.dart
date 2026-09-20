import 'package:seeray_analytics_flutter/seeray_analytics_flutter.dart';

import '../config/seeray_analytics_config.dart';

/// Small application boundary around the SeeRay SDK.
///
/// Pages use stable internal screen names; they never send account names,
/// article titles, query parameters, or other admin data as analytics fields.
class WindBlogSeeRayAnalytics {
  WindBlogSeeRayAnalytics._();

  static SeeRayAnalytics? _client;
  static Future<void>? _initialization;

  static Future<void> initialize() {
    if (!WindBlogSeeRayConfig.enabled || WindBlogSeeRayConfig.siteId.isEmpty) {
      return Future<void>.value();
    }
    return _initialization ??= _create();
  }

  static Future<void> _create() async {
    try {
      _client = await SeeRayAnalytics.create(
        const SeeRayAnalyticsOptions(
          siteId: WindBlogSeeRayConfig.siteId,
          apiOrigin: WindBlogSeeRayConfig.apiOrigin,
          requireConsent: WindBlogSeeRayConfig.requireConsent,
          allowInsecureLocalhost: WindBlogSeeRayConfig.allowInsecureLocalhost,
        ),
      );
    } catch (_) {
      // Analytics must never prevent the Admin application from starting.
      _client = null;
    }
  }

  static void trackScreen(String screenName) {
    final client = _client;
    if (client == null) return;
    final safeName = screenName.trim();
    if (safeName.isEmpty) return;
    client.trackScreen(name: safeName, url: _screenUrl(safeName));
  }

  static void trackEvent({
    required String type,
    required String screenName,
    String? action,
    String? name,
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    final client = _client;
    if (client == null) return;
    client.trackEvent(
      type: type,
      url: _screenUrl(screenName),
      action: action,
      name: name,
      properties: properties,
    );
  }

  static Future<bool> flush() => _client?.flush() ?? Future<bool>.value(false);

  static String _screenUrl(String screenName) {
    final encoded = Uri.encodeComponent(screenName);
    return Uri.parse(
      WindBlogSeeRayConfig.appOrigin,
    ).replace(path: '/admin/$encoded').toString();
  }
}
