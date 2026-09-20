import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:mime/mime.dart';
import 'package:diff_match_patch/diff_match_patch.dart' as diff_match_patch;

import 'data/admin_api_client.dart';
import 'data/models.dart';
import 'l10n/app_localizations.dart';
import 'components/web_stub.dart'
    if (dart.library.html) 'components/web_impl.dart'
    as web_helper;
import 'utils/storage_service.dart';
import 'services/seeray_analytics_service.dart';

part 'components/admin_ui.dart';
part 'components/admin_step_up.dart';
part 'components/admin_shortcuts.dart';
part 'components/notification_center.dart';
part 'pages/login_page.dart';
part 'pages/installation_page.dart';
part 'pages/home_page.dart';
part 'pages/overview_page.dart';
part 'pages/posts_page.dart';
part 'pages/post_editor_page.dart';
part 'pages/ai_providers_page.dart';
part 'pages/media_library_page.dart';
part 'components/progressive_image.dart';
part 'components/media_library_picker.dart';

part 'components/media_detail_dialog.dart';
part 'components/markdown_protocol.dart';
part 'components/markdown_plus_editor.dart';
part 'pages/user_management_page.dart';
part 'pages/permission_management_page.dart';
part 'pages/user_wallet_page.dart';
part 'pages/categories_page.dart';
part 'pages/tags_page.dart';

part 'pages/store_items_page.dart';
part 'pages/database_management_page.dart';

part 'pages/import_data_page.dart';

part 'pages/audit_logs_page.dart';

part 'pages/comments_page.dart';

part 'pages/queues_page.dart';

part 'pages/system_monitor_page.dart';

part 'pages/system_settings_page.dart';

part 'pages/email_center_page.dart';
part 'pages/elasticsearch_settings_page.dart';
part 'pages/elasticsearch_synonyms_page.dart';

part 'pages/add_link_page.dart';

part 'pages/links_page.dart';
part 'components/diff_viewer.dart';

part 'components/config_dynamic_form.dart';

part 'components/html_syntax_editor.dart';
part 'components/grafana_embed.dart';

part 'components/pagination_bar.dart';

part 'pages/storage_classes_page.dart';

part 'pages/storage_sync_panel.dart';

part 'pages/dead_letter_page.dart';

part 'pages/outbox_page.dart';

part 'pages/image_processing_config_page.dart';

part 'pages/edge_monitor_page.dart';

part 'pages/edge_nodes_page.dart';

part 'pages/region_management_page.dart';

part 'pages/amp_settings_page.dart';
part 'pages/security_services_page.dart';
part 'pages/codex_creator_page.dart';
part 'pages/topics_page.dart';

String _resolveMimeType(PlatformFile file) {
  final candidate = file.path ?? file.name;
  if (candidate.isEmpty) return 'application/octet-stream';
  return lookupMimeType(candidate) ?? 'application/octet-stream';
}

class SmoothScrollBehavior extends MaterialScrollBehavior {
  const SmoothScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.trackpad,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(
      controller: details.controller,
      thickness: 8.0,
      radius: const Radius.circular(4.0),
      interactive: true,
      child: child,
    );
  }
}

/// Scroll controller that animates mouse-wheel movement instead of applying
/// each wheel tick as an immediate one-line jump.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SmoothScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _SmoothScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  static const _wheelAnimationDuration = Duration(milliseconds: 180);
  double? _pendingWheelTarget;
  int _wheelAnimationGeneration = 0;

  void _clearPendingWheelTarget() {
    _pendingWheelTarget = null;
    _wheelAnimationGeneration++;
  }

  @override
  void pointerScroll(double delta) {
    if (delta == 0.0) {
      _clearPendingWheelTarget();
      super.pointerScroll(delta);
      return;
    }

    final baseOffset = _pendingWheelTarget ?? pixels;
    final targetOffset = (baseOffset + delta)
        .clamp(minScrollExtent, maxScrollExtent)
        .toDouble();
    if (targetOffset == pixels) {
      _clearPendingWheelTarget();
      return;
    }

    _pendingWheelTarget = targetOffset;
    final generation = ++_wheelAnimationGeneration;
    super
        .animateTo(
          targetOffset,
          duration: _wheelAnimationDuration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (generation == _wheelAnimationGeneration) {
            _pendingWheelTarget = null;
          }
        });
  }

  @override
  void applyUserOffset(double delta) {
    _clearPendingWheelTarget();
    super.applyUserOffset(delta);
  }

  @override
  void jumpTo(double value) {
    _clearPendingWheelTarget();
    super.jumpTo(value);
  }

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  }) {
    _clearPendingWheelTarget();
    return super.animateTo(to, duration: duration, curve: curve);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindBlogSeeRayAnalytics.initialize();
  runApp(const WindblogAdminApp());
}

class WindblogAdminApp extends StatelessWidget {
  const WindblogAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WindBlog Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.build(),
      scrollBehavior: const SmoothScrollBehavior(),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', ''), Locale('zh', '')],
      home: const AdminRootPage(),
    );
  }
}

class AdminRootPage extends StatefulWidget {
  const AdminRootPage({super.key});

  @override
  State<AdminRootPage> createState() => _AdminRootPageState();
}

class _AdminRootPageState extends State<AdminRootPage> {
  final api = AdminApiClient();
  final AdminNotificationController notificationController =
      AdminNotificationController();
  AdminUser? user;
  bool _loading = true;
  bool _showSessionExpiredLogin = false;
  bool _showSessionExpiredNotice = false;
  bool _showInstallationPage = false;

  @override
  void initState() {
    super.initState();
    api.onSessionExpired = _handleSessionExpired;
    api.onStepUpExpired = AdminStepUpAuthorization.clear;
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await StorageService.getSession();
    final baseUrl = session['baseUrl'];
    final token = session['token'];

    if (baseUrl != null && baseUrl.isNotEmpty) {
      api.baseUrl = baseUrl;
    }

    if (token != null && token.isNotEmpty) {
      api.token = token;
      VoidCallback? savedSessionExpiredHandler = api.onSessionExpired;
      api.onSessionExpired = null;
      try {
        user = await api.me();
      } on UnauthorizedException {
        api.token = null;
        await StorageService.clearSession();
        if (mounted) {
          setState(() {
            _showSessionExpiredNotice = true;
          });
        }
      } catch (e) {
        api.token = null;
        await StorageService.clearSession();
      } finally {
        api.onSessionExpired = savedSessionExpiredHandler;
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> onLogin(String baseUrl, String token) async {
    api.baseUrl = baseUrl;
    api.token = token;
    AdminUser authenticatedUser = await api.me();
    await StorageService.saveSession(baseUrl, token);
    if (mounted) {
      setState(() {
        user = authenticatedUser;
        _showSessionExpiredLogin = false;
        _showSessionExpiredNotice = false;
      });
    }
  }

  void onInstallationRequired(String baseUrl) {
    api.baseUrl = baseUrl;
    if (mounted) {
      setState(() {
        _showInstallationPage = true;
      });
    }
  }

  Future<void> onInstallationCompleted() async {
    if (!mounted) return;
    setState(() {
      _showInstallationPage = false;
      _showSessionExpiredNotice = false;
    });
  }

  void onLogout() async {
    notificationController.clear();
    AdminStepUpAuthorization.clear();
    api.token = null;
    user = null;
    _showSessionExpiredLogin = false;
    _showSessionExpiredNotice = false;
    await StorageService.clearSession();
    if (mounted) setState(() {});
  }

  void _handleSessionExpired() {
    if (!mounted || _showSessionExpiredLogin) {
      return;
    }

    api.token = null;
    AdminStepUpAuthorization.clear();
    setState(() {
      _showSessionExpiredLogin = true;
      _showSessionExpiredNotice = true;
    });
    unawaited(StorageService.clearSession());

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return SessionExpiredLoginDialog(
          api: api,
          onLogin: (String baseUrl, String token) async {
            await onLogin(baseUrl, token);
          },
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _showSessionExpiredLogin = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading) {
      content = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (_showInstallationPage) {
      content = InstallationPage(
        api: api,
        onCompleted: onInstallationCompleted,
      );
    } else if (api.token == null && !_showSessionExpiredLogin) {
      content = LoginPage(
        api: api,
        onLogin: onLogin,
        onInstallationRequired: onInstallationRequired,
        showSessionExpiredNotice: _showSessionExpiredNotice,
      );
    } else {
      content = AdminAuthenticatedWorkspace(
        api: api,
        notificationController: notificationController,
        workspace: HomePage(
          api: api,
          user: user,
          onLogout: onLogout,
          onAuthError: _handleSessionExpired,
        ),
      );
    }
    return AdminNotificationHost(
      api: api,
      controller: notificationController,
      child: AdminShortcutHost(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey<String>(
              _loading
                  ? 'bootstrap'
                  : _showInstallationPage
                  ? 'installation'
                  : api.token == null
                  ? 'login'
                  : 'workspace',
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class AdminAuthenticatedWorkspace extends StatelessWidget {
  const AdminAuthenticatedWorkspace({
    super.key,
    this.api,
    this.notificationController,
    required this.workspace,
    this.sessionExpiredLogin,
    this.showSessionExpiredLogin = false,
  });

  final Widget workspace;
  final AdminApiClient? api;
  final AdminNotificationController? notificationController;
  final Widget? sessionExpiredLogin;
  final bool showSessionExpiredLogin;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        workspace,
        if (showSessionExpiredLogin && sessionExpiredLogin != null)
          sessionExpiredLogin!,
      ],
    );
  }
}
