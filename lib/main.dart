import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

part 'components/admin_ui.dart';
part 'components/admin_step_up.dart';
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
    PointerDeviceKind.mouse,
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

void main() {
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
      child: content,
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
