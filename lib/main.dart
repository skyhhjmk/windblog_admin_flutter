import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:mime/mime.dart';

import 'data/admin_api_client.dart';
import 'data/models.dart';
import 'l10n/app_localizations.dart';

part 'pages/login_page.dart';
part 'pages/home_page.dart';
part 'pages/overview_page.dart';
part 'pages/posts_page.dart';
part 'pages/ai_providers_page.dart';
part 'pages/media_library_page.dart';
part 'components/progressive_image.dart';
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

String _resolveMimeType(PlatformFile file) {
  final candidate = file.path ?? file.name;
  if (candidate.isEmpty) return 'application/octet-stream';
  return lookupMimeType(candidate) ?? 'application/octet-stream';
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

