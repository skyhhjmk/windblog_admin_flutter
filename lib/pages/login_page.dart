part of 'package:windblog_admin_flutter/main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.api,
    required this.onLogin,
    this.onInstallationRequired,
    this.showSessionExpiredNotice = false,
    this.onManageInstances,
    this.instanceLoginError,
  });

  final AdminApiClient api;
  final Future<void> Function(String baseUrl, String token) onLogin;
  final void Function(String baseUrl)? onInstallationRequired;
  final bool showSessionExpiredNotice;
  final VoidCallback? onManageInstances;
  final String? instanceLoginError;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  late final baseUrlCtrl = TextEditingController(text: widget.api.baseUrl);
  final accountCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    baseUrlCtrl.dispose();
    accountCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      widget.api.baseUrl = widget.api.normalizeBaseUrl(baseUrlCtrl.text);
      final token = await widget.api.login(
        account: accountCtrl.text.trim(),
        password: passwordCtrl.text,
      );
      await widget.onLogin(widget.api.baseUrl, token);
    } on InstallationRequiredException {
      if (mounted) {
        widget.onInstallationRequired?.call(widget.api.baseUrl);
      }
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(context, SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Dynamic vibrant gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AdminTheme.navigationColor,
                    AdminTheme.brandColor,
                    Color(0xFF0EA5E9),
                    Color(0xFF06B6D4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Subtle glowing ambient circles
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.3), // Sky
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF93C5FD).withValues(alpha: 0.25), // Blue
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 40,
                      ),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Beautiful brand logo
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AdminTheme.brandColor,
                                    Color(0xFF0EA5E9),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.air,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            if (widget.onManageInstances != null) ...[
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: loading
                                    ? null
                                    : widget.onManageInstances,
                                icon: const Icon(Icons.dns_outlined),
                                label: const Text('多实例管理 / 保存登录方式'),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Text(
                              t(context, 'login_title'),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF1E293B),
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            if (widget.instanceLoginError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '实例自动登录失败：${widget.instanceLoginError}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            const Text(
                              'WindBlog Administration System',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.showSessionExpiredNotice) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Color(0xFFB45309),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        t(context, 'token_expired'),
                                        style: const TextStyle(
                                          color: Color(0xFF92400E),
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: baseUrlCtrl,
                              decoration: InputDecoration(
                                labelText: t(context, 'api_base_url'),
                                prefixIcon: const Icon(
                                  Icons.link,
                                  color: AdminTheme.brandColor,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AdminTheme.brandColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? t(context, 'required')
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: accountCtrl,
                              decoration: InputDecoration(
                                labelText: t(context, 'username'),
                                prefixIcon: const Icon(
                                  Icons.person_outline,
                                  color: AdminTheme.brandColor,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AdminTheme.brandColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? t(context, 'required')
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passwordCtrl,
                              obscureText: true,
                              onFieldSubmitted: (_) {
                                if (!loading) submit();
                              },
                              decoration: InputDecoration(
                                labelText: t(context, 'password'),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: AdminTheme.brandColor,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AdminTheme.brandColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? t(context, 'required')
                                  : null,
                            ),
                            const SizedBox(height: 28),
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    AdminTheme.brandColor,
                                    Color(0xFF0EA5E9),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0EA5E9,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: loading ? null : submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: loading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : AdminShortcutText(
                                        t(context, 'login'),
                                        AdminShortcutDefinitions
                                            .keyByAction['submit']!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SessionExpiredLoginDialog extends StatefulWidget {
  const SessionExpiredLoginDialog({
    super.key,
    required this.api,
    required this.onLogin,
  });

  final AdminApiClient api;
  final Future<void> Function(String baseUrl, String token) onLogin;

  @override
  State<SessionExpiredLoginDialog> createState() {
    return _SessionExpiredLoginDialogState();
  }
}

class _SessionExpiredLoginDialogState extends State<SessionExpiredLoginDialog> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final TextEditingController baseUrlController;
  final TextEditingController accountController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isSubmitting = false;
  String? loginErrorMessage;

  @override
  void initState() {
    super.initState();
    baseUrlController = TextEditingController(text: widget.api.baseUrl);
  }

  @override
  void dispose() {
    baseUrlController.dispose();
    accountController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FormState? currentFormState = formKey.currentState;
    if (currentFormState == null || !currentFormState.validate()) {
      return;
    }

    setState(() {
      isSubmitting = true;
      loginErrorMessage = null;
    });

    try {
      String normalizedBaseUrl = widget.api.normalizeBaseUrl(
        baseUrlController.text,
      );
      widget.api.baseUrl = normalizedBaseUrl;
      String token = await widget.api.login(
        account: accountController.text.trim(),
        password: passwordController.text,
      );
      await widget.onLogin(normalizedBaseUrl, token);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        loginErrorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget loginButtonChild = Text(t(context, 'login'));
    VoidCallback? loginButtonAction = submit;
    if (isSubmitting) {
      loginButtonChild = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
      loginButtonAction = null;
    }

    return PopScope(
      key: const Key('sessionExpiredLoginDialog'),
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_clock_outlined,
                      size: 48,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t(context, 'token_expired'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t(context, 'session_relogin_preserves_progress'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: baseUrlController,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: t(context, 'api_base_url'),
                        prefixIcon: const Icon(Icons.link),
                      ),
                      validator: (String? baseUrl) {
                        if (baseUrl == null || baseUrl.trim().isEmpty) {
                          return t(context, 'required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: accountController,
                      enabled: !isSubmitting,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: t(context, 'username'),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (String? account) {
                        if (account == null || account.trim().isEmpty) {
                          return t(context, 'required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      enabled: !isSubmitting,
                      obscureText: true,
                      onFieldSubmitted: (String password) {
                        if (!isSubmitting) {
                          submit();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: t(context, 'password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (String? password) {
                        if (password == null || password.isEmpty) {
                          return t(context, 'required');
                        }
                        return null;
                      },
                    ),
                    if (loginErrorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        loginErrorMessage!,
                        key: const Key('sessionExpiredLoginError'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: loginButtonAction,
                      child: loginButtonAction == null
                          ? loginButtonChild
                          : AdminShortcutText(
                              t(context, 'login'),
                              AdminShortcutDefinitions.keyByAction['submit']!,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
