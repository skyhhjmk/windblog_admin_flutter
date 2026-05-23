part of 'package:windblog_admin_flutter/main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, required this.onLogin});

  final AdminApiClient api;
  final Future<void> Function(String baseUrl, String token) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  late final baseUrlCtrl = TextEditingController(text: widget.api.baseUrl);
  final accountCtrl = TextEditingController(text: 'admin');
  final passwordCtrl = TextEditingController(text: 'admin');
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t(context, 'login_title'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: baseUrlCtrl,
                      decoration: InputDecoration(
                        labelText: t(context, 'api_base_url'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? t(context, 'required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: accountCtrl,
                      decoration: InputDecoration(
                        labelText: t(context, 'username'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? t(context, 'required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: t(context, 'password'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? t(context, 'required') : null,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: loading ? null : submit,
                        child: Text(loading ? t(context, 'logging_in') : t(context, 'login')),
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

