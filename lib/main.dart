import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:mime/mime.dart';
import 'package:diff_match_patch/diff_match_patch.dart' as diff_match_patch;


import 'data/admin_api_client.dart';
import 'data/models.dart';
import 'l10n/app_localizations.dart';
import 'components/web_stub.dart' if (dart.library.html) 'components/web_impl.dart' as web_helper;

part 'pages/login_page.dart';
part 'pages/home_page.dart';
part 'pages/overview_page.dart';
part 'pages/posts_page.dart';
part 'pages/ai_providers_page.dart';
part 'pages/media_library_page.dart';
part 'components/progressive_image.dart';
part 'components/media_library_picker.dart';
part 'components/markdown_protocol.dart';
part 'components/markdown_plus_editor.dart';
part 'pages/user_management_page.dart';
part 'pages/permission_management_page.dart';
part 'pages/user_wallet_page.dart';
part 'pages/categories_page.dart';
part 'pages/tags_page.dart';
part 'pages/database_management_page.dart';

part 'pages/audit_logs_page.dart';

part 'pages/comments_page.dart';

part 'pages/queues_page.dart';

part 'pages/system_monitor_page.dart';

part 'pages/system_settings_page.dart';
part 'components/diff_viewer.dart';

part 'components/config_dynamic_form.dart';


String _resolveMimeType(PlatformFile file) {
  final candidate = file.path ?? file.name;
  if (candidate.isEmpty) return 'application/octet-stream';
  return lookupMimeType(candidate) ?? 'application/octet-stream';
}

class SmoothScrollBehavior extends MaterialScrollBehavior {
  const SmoothScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices =>
      {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };

  @override
  Widget buildScrollbar(BuildContext context, Widget child,
      ScrollableDetails details) {
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5ED7)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      scrollBehavior: const SmoothScrollBehavior(),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('zh', ''),
      ],
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
  AdminUser? user;

  Future<void> onLogin(String baseUrl, String token) async {
    api.baseUrl = baseUrl;
    api.token = token;
    user = await api.me();
    if (mounted) setState(() {});
  }

  void onLogout() {
    api.token = null;
    user = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (api.token == null) {
      return LoginPage(api: api, onLogin: onLogin);
    }
    return HomePage(api: api, user: user, onLogout: onLogout);
  }
}

