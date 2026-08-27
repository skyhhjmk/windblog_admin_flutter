part of 'package:windblog_admin_flutter/main.dart';

class InstallationPage extends StatefulWidget {
  const InstallationPage({
    super.key,
    required this.api,
    required this.onCompleted,
  });

  final AdminApiClient api;
  final Future<void> Function() onCompleted;

  @override
  State<InstallationPage> createState() => _InstallationPageState();
}

class _InstallationPageState extends State<InstallationPage> {
  final formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final titleController = TextEditingController(text: 'WindBlog');
  final subtitleController = TextEditingController();
  final descriptionController = TextEditingController();
  final keywordsController = TextEditingController(text: 'blog, tech');
  final authorController = TextEditingController();
  late final siteUrlController = TextEditingController(
    text: widget.api.baseUrl,
  );
  bool loading = false;

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    titleController.dispose();
    subtitleController.dispose();
    descriptionController.dispose();
    keywordsController.dispose();
    authorController.dispose();
    siteUrlController.dispose();
    super.dispose();
  }

  String? requiredValue(String? value) {
    return value == null || value.trim().isEmpty ? '必填项' : null;
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => loading = true);
    try {
      final keywords = keywordsController.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      await widget.api.install(
        username: usernameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        siteTitle: titleController.text.trim(),
        siteSubtitle: subtitleController.text.trim(),
        siteDescription: descriptionController.text.trim(),
        siteKeywords: keywords,
        siteAuthor: authorController.text.trim(),
        siteUrl: widget.api.normalizeBaseUrl(siteUrlController.text),
      );
      if (!mounted) return;
      AdminFeedback.showSnackBar(
        context,
        const SnackBar(content: Text('安装初始化完成，请使用新管理员账号登录')),
      );
      await widget.onCompleted();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(context, SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  InputDecoration decoration(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon));
  }

  Widget field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
    int maxLines = 1,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        maxLines: obscureText ? 1 : maxLines,
        decoration: decoration(label, icon),
        validator: validator ?? requiredValue,
        onFieldSubmitted: onFieldSubmitted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WindBlog 安装初始化')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '欢迎完成首次安装',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text('安装只允许执行一次。请设置超级管理员账号和网站基础信息。'),
                      const SizedBox(height: 24),
                      Text(
                        '超级管理员',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      field(
                        controller: usernameController,
                        label: '用户名',
                        icon: Icons.person_outline,
                      ),
                      field(
                        controller: emailController,
                        label: '邮箱',
                        icon: Icons.email_outlined,
                        validator: (value) =>
                            value != null && value.contains('@')
                            ? null
                            : '请输入有效邮箱',
                      ),
                      field(
                        controller: passwordController,
                        label: '密码（至少 12 个字符）',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        validator: (value) =>
                            value != null && value.length >= 12
                            ? null
                            : '密码至少需要 12 个字符',
                      ),
                      field(
                        controller: confirmPasswordController,
                        label: '确认密码',
                        icon: Icons.lock_reset,
                        obscureText: true,
                        onFieldSubmitted: (_) {
                          if (!loading) submit();
                        },
                        validator: (value) =>
                            value == passwordController.text ? null : '两次密码不一致',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '网站信息',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      field(
                        controller: titleController,
                        label: '站点标题',
                        icon: Icons.title,
                      ),
                      field(
                        controller: subtitleController,
                        label: '站点副标题',
                        icon: Icons.subtitles_outlined,
                      ),
                      field(
                        controller: descriptionController,
                        label: 'SEO 描述',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                      field(
                        controller: keywordsController,
                        label: 'SEO 关键词（逗号分隔）',
                        icon: Icons.sell_outlined,
                      ),
                      field(
                        controller: authorController,
                        label: '站点作者',
                        icon: Icons.badge_outlined,
                      ),
                      field(
                        controller: siteUrlController,
                        label: '本站链接',
                        icon: Icons.link,
                        validator: (value) =>
                            value != null &&
                                (value.startsWith('http://') ||
                                    value.startsWith('https://'))
                            ? null
                            : '请输入 http(s) 地址',
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: loading ? null : submit,
                        icon: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.rocket_launch_outlined),
                        label: loading
                            ? const Text('正在初始化…')
                            : AdminShortcutText(
                                '完成安装初始化',
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
      ),
    );
  }
}
