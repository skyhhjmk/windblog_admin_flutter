import 'package:flutter/material.dart';

import 'data/admin_api_client.dart';
import 'data/models.dart';

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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, required this.onLogin});

  final AdminApiClient api;
  final Future<void> Function(String baseUrl, String token) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final baseUrlCtrl = TextEditingController(text: 'http://localhost:8080');
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
      widget.api.baseUrl = baseUrlCtrl.text.trim();
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
                      'WindBlog 管理后台',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: baseUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'API Base URL',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入 API 地址' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: accountCtrl,
                      decoration: const InputDecoration(
                        labelText: '账号',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入账号' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '请输入密码' : null,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: loading ? null : submit,
                        child: Text(loading ? '登录中...' : '登录'),
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

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
  });

  final AdminApiClient api;
  final AdminUser? user;
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: tab,
            onDestinationSelected: (v) => setState(() => tab = v),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('概览'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article),
                label: Text('文章'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.memory_outlined),
                selectedIcon: Icon(Icons.memory),
                label: Text('AI'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(tab == 0
                          ? '后台概览'
                          : tab == 1
                          ? '文章管理'
                          : 'AI 配置'),
                      const Spacer(),
                      if (widget.user != null) Text(widget.user!.username),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: widget.onLogout,
                        child: const Text('退出'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: tab == 0
                      ? OverviewPage(
                    api: widget.api,
                    onAuthError: widget.onLogout,
                  )
                      : tab == 1
                      ? PostsPage(
                    api: widget.api,
                    onAuthError: widget.onLogout,
                  )
                      : AiProvidersPage(
                    api: widget.api,
                    onAuthError: widget.onLogout,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      data = await widget.api.overview();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return Center(child: Text(error!));
    final map = data;
    if (map == null) return const Center(child: CircularProgressIndicator());

    Widget card(String label, Object value) {
      return SizedBox(
        width: 160,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 8),
                Text('$value'),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            card('用户', map['users'] ?? 0),
            card('文章', map['posts'] ?? 0),
            card('评论', map['comments'] ?? 0),
            card('标签', map['tags'] ?? 0),
            card('分类', map['categories'] ?? 0),
          ],
        ),
        const SizedBox(height: 12),
        Text('文档: ${widget.api.baseUrl}/api/admin/docs'),
      ],
    );
  }
}

class PostsPage extends StatefulWidget {
  const PostsPage({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  final keywordCtrl = TextEditingController();
  List<PostItem> items = [];
  int page = 1;
  int total = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final res = await widget.api.listPosts(
        page: page,
        pageSize: 10,
        keyword: keywordCtrl.text.trim().isEmpty
            ? null
            : keywordCtrl.text.trim(),
      );
      items = res.items;
      total = res.total;
      if (mounted) setState(() {});
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> createOrEdit({PostItem? item}) async {
    PostDetail? detail;
    if (item != null) {
      detail = await widget.api.postDetail(item.id);
    }
    if (!mounted) return;
    final req = await showDialog<PostEditRequest>(
      context: context,
      builder: (_) => PostDialog(detail: detail),
    );
    if (req == null) return;

    try {
      if (item == null) {
        await widget.api.createPost(req);
      } else {
        await widget.api.updatePost(
          item.id,
          req.copyWith(version: detail!.version),
        );
      }
      await load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: keywordCtrl,
                  decoration: const InputDecoration(
                    hintText: '按 slug 搜索',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  page = 1;
                  load();
                },
                child: const Text('搜索'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => createOrEdit(),
                child: const Text('新建文章'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = items[i];
                  return ListTile(
                    title: Text(it.zhTitle.isEmpty ? it.slug : it.zhTitle),
                    subtitle: Text(
                      'slug: ${it.slug} | 状态: ${it.statusText} | 渲染: ${it.renderTypeText} | v${it.version}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => createOrEdit(item: it),
                          child: const Text('编辑'),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await widget.api.publishPost(it.id);
                              await load();
                            } on UnauthorizedException {
                              widget.onAuthError();
                            }
                          },
                          child: const Text('发布'),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await widget.api.deletePost(it.id);
                              await load();
                            } on UnauthorizedException {
                              widget.onAuthError();
                            }
                          },
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('共 $total 条'),
              const Spacer(),
              IconButton(
                onPressed: page <= 1
                    ? null
                    : () {
                        page--;
                        load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text('第 $page 页'),
              IconButton(
                onPressed: page * 10 >= total
                    ? null
                    : () {
                        page++;
                        load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PostDialog extends StatefulWidget {
  const PostDialog({super.key, this.detail});

  final PostDetail? detail;

  @override
  State<PostDialog> createState() => _PostDialogState();
}

class _PostDialogState extends State<PostDialog> {
  late final TextEditingController slugCtrl;
  late final TextEditingController titleCtrl;
  late final TextEditingController summaryCtrl;
  late final TextEditingController contentCtrl;

  int status = 0;
  int visibility = 0;
  int renderType = 0;
  int editorType = 0;

  @override
  void initState() {
    super.initState();
    final d = widget.detail;
    slugCtrl = TextEditingController(text: d?.slug ?? '');
    titleCtrl = TextEditingController(text: d?.title['zh-cn'] ?? '');
    summaryCtrl = TextEditingController(text: d?.summary['zh-cn'] ?? '');
    contentCtrl = TextEditingController(
      text: d?.contentMarkdown['zh-cn'] ?? '',
    );
    status = d?.status ?? 0;
    visibility = d?.visibility ?? 0;
    renderType = d?.renderType ?? 0;
    editorType = d?.editorType ?? 0;
  }

  @override
  void dispose() {
    slugCtrl.dispose();
    titleCtrl.dispose();
    summaryCtrl.dispose();
    contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.detail == null ? '新建文章' : '编辑文章'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: slugCtrl,
                decoration: const InputDecoration(labelText: 'Slug'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '标题(zh-cn)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: summaryCtrl,
                decoration: const InputDecoration(labelText: '摘要(zh-cn)'),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentCtrl,
                decoration: const InputDecoration(
                  labelText: '正文 Markdown(zh-cn)',
                ),
                minLines: 8,
                maxLines: 10,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: '状态'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('草稿')),
                        DropdownMenuItem(value: 1, child: Text('发布')),
                        DropdownMenuItem(value: 2, child: Text('归档')),
                      ],
                      onChanged: (v) => status = v ?? 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: visibility,
                      decoration: const InputDecoration(labelText: '可见性'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('公开')),
                        DropdownMenuItem(value: 1, child: Text('私密')),
                        DropdownMenuItem(value: 2, child: Text('密码')),
                      ],
                      onChanged: (v) => visibility = v ?? 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: renderType,
                decoration: const InputDecoration(labelText: '渲染类型'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Markdown')),
                  DropdownMenuItem(value: 1, child: Text('HTML')),
                  DropdownMenuItem(value: 2, child: Text('Vditor')),
                  DropdownMenuItem(value: 3, child: Text('V Builder')),
                  DropdownMenuItem(value: 4, child: Text('Gutenberg')),
                ],
                onChanged: (v) => renderType = v ?? 0,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: editorType,
                decoration: const InputDecoration(labelText: '编辑器'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Markdown')),
                  DropdownMenuItem(value: 1, child: Text('HTML')),
                ],
                onChanged: (v) => editorType = v ?? 0,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (slugCtrl.text.trim().isEmpty ||
                titleCtrl.text.trim().isEmpty ||
                contentCtrl.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              PostEditRequest(
                slug: slugCtrl.text.trim(),
                title: {'zh-cn': titleCtrl.text.trim()},
                summary: {'zh-cn': summaryCtrl.text.trim()},
                aiSummary: const {},
                contentMarkdown: {'zh-cn': contentCtrl.text.trim()},
                status: status,
                visibility: visibility,
                renderType: renderType,
                editorType: editorType,
                version: 0,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class AiProvidersPage extends StatefulWidget {
  const AiProvidersPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<AiProvidersPage> createState() => _AiProvidersPageState();
}

class _AiProvidersPageState extends State<AiProvidersPage> {
  final List<_ProviderForm> forms = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final form in forms) {
      form.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final configs = await widget.api.listAiProviders();
      setState(() {
        for (final form in forms) {
          form.dispose();
        }
        forms
          ..clear()
          ..addAll(configs.map(_ProviderForm.fromConfig));
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _save(_ProviderForm form) async {
    if (form.saving) return;
    if (!mounted) return;
    setState(() => form.saving = true);
    try {
      final updated = await widget.api.updateAiProvider(
        form.provider,
        AiProviderConfigUpdateRequest(
          enabled: form.enabled,
          endpoint: form.endpointCtrl.text.trim(),
          model: form.modelCtrl.text.trim(),
          apiKey: form.apiKeyCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        form.enabled = updated.enabled;
        form.endpointCtrl.text = updated.endpoint ?? '';
        form.modelCtrl.text = updated.model ?? '';
        form.apiKeyCtrl.text = updated.apiKey ?? '';
        form.updatedAt = updated.updatedAt;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 配置已保存')),
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')));
    } finally {
      if (mounted) {
        setState(() => form.saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text(error!));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: forms.length,
      itemBuilder: (context, index) {
        final form = forms[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      form.provider,
                      style: Theme
                          .of(context)
                          .textTheme
                          .titleMedium,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Text('启用'),
                        Switch(
                          value: form.enabled,
                          onChanged: (value) =>
                              setState(() => form.enabled = value),
                        ),
                      ],
                    ),
                  ],
                ),
                if (form.updatedAt != null)
                  Text(
                    '上次更新: ${form.updatedAt!.toLocal()}',
                    style: Theme
                        .of(context)
                        .textTheme
                        .bodySmall,
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: form.endpointCtrl,
                  decoration: const InputDecoration(
                    labelText: '接口 URL',
                    border: OutlineInputBorder(),
                    hintText: '如 http://localhost:11434',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: form.modelCtrl,
                  decoration: const InputDecoration(
                    labelText: '模型标识',
                    border: OutlineInputBorder(),
                    hintText: '如 ollama/llama3',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: form.apiKeyCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    border: OutlineInputBorder(),
                    hintText: '如需 Bearer Token',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: form.saving ? null : () => _save(form),
                    child: Text(form.saving ? '保存中...' : '保存'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProviderForm {
  _ProviderForm({
    required this.provider,
    required this.endpointCtrl,
    required this.modelCtrl,
    required this.apiKeyCtrl,
    this.enabled = false,
    this.updatedAt,
  });

  factory _ProviderForm.fromConfig(AiProviderConfig config) {
    return _ProviderForm(
      provider: config.provider,
      endpointCtrl: TextEditingController(text: config.endpoint ?? ''),
      modelCtrl: TextEditingController(text: config.model ?? ''),
      apiKeyCtrl: TextEditingController(text: config.apiKey ?? ''),
      enabled: config.enabled,
      updatedAt: config.updatedAt,
    );
  }

  final String provider;
  final TextEditingController endpointCtrl;
  final TextEditingController modelCtrl;
  final TextEditingController apiKeyCtrl;
  bool enabled;
  bool saving = false;
  DateTime? updatedAt;

  void dispose() {
    endpointCtrl.dispose();
    modelCtrl.dispose();
    apiKeyCtrl.dispose();
  }
}
