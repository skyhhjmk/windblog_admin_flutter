import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:mime/mime.dart';

import 'data/admin_api_client.dart';
import 'data/models.dart';

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
    final isSuperAdmin = widget.user?.roleName == 'SUPER_ADMIN';
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
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(Icons.photo_library),
                label: Text('媒体'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('用户'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.security_outlined),
                selectedIcon: Icon(Icons.security),
                label: Text('权限'),
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
                      Text(
                        switch (tab) {
                          0 => '后台概览',
                          1 => '文章管理',
                          2 => '媒体库',
                          3 => '用户管理',
                          4 => '权限组',
                          _ => 'AI 管理',
                        },
                      ),
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
                  child: _pageForIndex(tab, isSuperAdmin),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageForIndex(int index, bool isSuperAdmin) {
    return switch (index) {
      0 => OverviewPage(api: widget.api, onAuthError: widget.onLogout),
      1 => PostsPage(api: widget.api, onAuthError: widget.onLogout),
      2 => MediaLibraryPage(api: widget.api, onAuthError: widget.onLogout),
      3 => UserManagementPage(
          api: widget.api,
          onAuthError: widget.onLogout,
          isSuperAdmin: isSuperAdmin,
        ),
      4 => PermissionManagementPage(
          api: widget.api,
          isSuperAdmin: isSuperAdmin,
          onAuthError: widget.onLogout,
        ),
      _ => AiProvidersPage(api: widget.api, onAuthError: widget.onLogout),
    };
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
      builder: (_) => PostDialog(detail: detail, api: widget.api),
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
  const PostDialog({super.key, this.detail, required this.api});

  final PostDetail? detail;
  final AdminApiClient api;

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
  }

  @override
  void dispose() {
    slugCtrl.dispose();
    titleCtrl.dispose();
    summaryCtrl.dispose();
    contentCtrl.dispose();
    super.dispose();
  }

  Widget _buildEditorPane() {
    return SizedBox(
      height: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: _uploadMedia,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('上传媒体'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _buildMarkdownEditor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownEditor() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: TextField(
            controller: contentCtrl,
            decoration: const InputDecoration(
              labelText: 'Markdown 内容',
              border: OutlineInputBorder(),
            ),
            minLines: 12,
            maxLines: null,
            expands: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade50,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: contentCtrl,
                builder: (context, value, child) {
                  return MarkdownBody(data: value.text);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _uploadMedia() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      return;
    }
    final mimeType = _resolveMimeType(file);
    try {
      final media = await widget.api.uploadMedia(
        fileName: file.name,
        bytes: bytes,
        mimeType: mimeType,
      );
      final currentText = contentCtrl.text;
      final selection = contentCtrl.selection;
      final insertText = '![${media.fileName}](${media.url})\n';
      final newText = currentText.replaceRange(
        selection.baseOffset,
        selection.extentOffset,
        insertText,
      );
      contentCtrl.text = newText;
      contentCtrl.selection = TextSelection.collapsed(
        offset: selection.baseOffset + insertText.length,
      );
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已插入 ${media.fileName}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败：$e')),
        );
      }
    }
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
              _buildEditorPane(),
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
                  DropdownMenuItem(value: 5, child: Text('Flutter Quill')),
                  DropdownMenuItem(value: 6, child: Text('Flutter Markdown Plus')),
                ],
                onChanged: (v) => renderType = v ?? 0,
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
            final finalContent = contentCtrl.text.trim();
            if (slugCtrl.text.trim().isEmpty ||
                titleCtrl.text.trim().isEmpty ||
                finalContent.isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              PostEditRequest(
                slug: slugCtrl.text.trim(),
                title: {'zh-cn': titleCtrl.text.trim()},
                summary: {'zh-cn': summaryCtrl.text.trim()},
                aiSummary: const {},
                contentMarkdown: {'zh-cn': finalContent},
                status: status,
                visibility: visibility,
                renderType: renderType,
                editorType: 0,
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

class MediaLibraryPage extends StatefulWidget {
  const MediaLibraryPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<MediaLibraryPage> createState() => _MediaLibraryPageState();
}

class _MediaLibraryPageState extends State<MediaLibraryPage> {
  bool gridMode = true;
  MediaListResult? mediaResult;
  MediaListResult? unreferencedResult;
  MediaScanResult? scanResult;
  bool loadingMedia = true;
  bool loadingUnreferenced = true;
  bool scanning = false;
  int page = 1;
  int unreferencedPage = 1;

  @override
  void initState() {
    super.initState();
    _loadMedia();
    _loadUnreferenced();
  }

  Future<void> _loadMedia() async {
    setState(() => loadingMedia = true);
    try {
      mediaResult = await widget.api.listMedia(page: page, pageSize: 24);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('媒体列表加载失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loadingMedia = false);
    }
  }

  Future<void> _loadUnreferenced() async {
    setState(() => loadingUnreferenced = true);
    try {
      unreferencedResult = await widget.api.listMedia(
        page: unreferencedPage,
        pageSize: 24,
        unreferenced: true,
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未引用媒体加载失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loadingUnreferenced = false);
    }
  }

  Future<void> _scanReferences() async {
    setState(() => scanning = true);
    try {
      scanResult = await widget.api.scanMedia();
      await _loadMedia();
      await _loadUnreferenced();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _uploadMedia() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final mimeType = _resolveMimeType(file);
    try {
      await widget.api.uploadMedia(
        fileName: file.name,
        bytes: bytes,
        mimeType: mimeType,
      );
      await _loadMedia();
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上传成功')),
        );
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: '资源'),
                Tab(text: '未引用'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMediaTab(),
                  _buildUnreferencedTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTab() {
    final total = mediaResult?.total ?? 0;
    return Column(
      children: [
        Row(
          children: [
            ToggleButtons(
              isSelected: [gridMode, !gridMode],
              onPressed: (index) => setState(() => gridMode = index == 0),
              children: const [
                Icon(Icons.grid_view),
                Icon(Icons.list),
              ],
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _uploadMedia,
              child: const Text('上传媒体'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: scanning ? null : _scanReferences,
              child: Text(scanning ? '扫描中...' : '重新扫描'),
            ),
            const Spacer(),
            Text('共 $total 条'),
          ],
        ),
        if (scanResult != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '扫描: ${scanResult!.postsScanned} 篇文章，引用 ${scanResult!.referencesCreated} 次，未引用 ${scanResult!.unreferenced} 个',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: loadingMedia
              ? const Center(child: CircularProgressIndicator())
              : gridMode
                  ? _buildGridView()
                  : _buildListView(),
        ),
        const SizedBox(height: 8),
        _buildPagination(),
      ],
    );
  }

  Widget _buildUnreferencedTab() {
    return loadingUnreferenced
        ? const Center(child: CircularProgressIndicator())
        : unreferencedResult == null || unreferencedResult!.items.isEmpty
            ? const Center(child: Text('暂无未引用媒体'))
            : ListView.separated(
                itemCount: unreferencedResult!.items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = unreferencedResult!.items[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(item.fileName.isEmpty
                          ? '?'
                          : item.fileName[0].toUpperCase()),
                    ),
                    title: Text(item.fileName),
                    subtitle: Text('${_formatBytes(item.size)} • 上传 ${item.createdAt.toLocal()}'),
                  );
                },
              );
  }

  Widget _buildGridView() {
    final items = mediaResult?.items ?? [];
    if (items.isEmpty) {
      return const Center(child: Text('暂无媒体'));
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildMediaCard(items[index]),
    );
  }

  Widget _buildListView() {
    final items = mediaResult?.items ?? [];
    if (items.isEmpty) {
      return const Center(child: Text('暂无媒体'));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          onTap: () => _openMediaDetail(item),
          leading: item.isImage
              ? ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _ProgressiveImage(
              previewUrl: item.previewUrl,
              thumbnailUrl: item.thumbnailUrl,
              fallbackUrl: item.url,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          )
              : const Icon(Icons.insert_drive_file),
          title: Text(item.fileName),
          subtitle: Text(
              '${_formatBytes(item.size)} • 引用 ${item.references.length} 次'),
        );
      },
    );
  }
  Widget _buildMediaCard(MediaItem item) {
    final preview = item.isImage
        ? _ProgressiveImage(
      previewUrl: item.previewUrl,
      thumbnailUrl: item.thumbnailUrl,
      fallbackUrl: item.url,
            width: double.infinity,
      height: 140,
      fit: BoxFit.contain,
          )
        : const SizedBox(
      height: 140,
            child: Center(child: Icon(Icons.insert_drive_file, size: 48)),
          );
    return Card(
      child: InkWell(
        onTap: () => _openMediaDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 140,
              color: Colors.grey.shade100,
              child: preview,
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                item.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${_formatBytes(item.size)} • ${item.uploadedByName ??
                    '未知用户'}',
                style: Theme
                    .of(context)
                    .textTheme
                    .bodySmall,
              ),
            ),
            if (item.requiresManualOriginal)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '原文件>5MB，详情页手动加载',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Wrap(
                spacing: 4,
                children: item.references
                    .map((ref) =>
                    Chip(
                      label: Text(ref.postSlug),
                      visualDensity: VisualDensity.compact,
                    ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMediaDetail(MediaItem item) async {
    bool loadOriginal = !item.requiresManualOriginal;
    await showDialog<void>(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setLocalState) =>
                AlertDialog(
                  title: Text(item.fileName),
                  content: SizedBox(
                    width: 640,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.isImage)
                          Container(
                            width: double.infinity,
                            height: 320,
                            color: Colors.black12,
                            child: loadOriginal
                                ? Image.network(
                              item.url,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image)),
                            )
                                : _ProgressiveImage(
                              previewUrl: item.previewUrl,
                              thumbnailUrl: item.thumbnailUrl,
                              fallbackUrl: item.url,
                              width: double.infinity,
                              height: 320,
                              fit: BoxFit.contain,
                            ),
                          )
                        else
                          const SizedBox(
                            height: 120,
                            child: Center(
                                child: Icon(Icons.insert_drive_file, size: 56)),
                          ),
                        const SizedBox(height: 8),
                        Text('类型: ${item.mimeType}'),
                        Text('大小: ${_formatBytes(item.size)}'),
                        SelectableText('原始地址: ${item.url}'),
                        if (item.requiresManualOriginal)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton(
                              onPressed: loadOriginal
                                  ? null
                                  : () =>
                                  setLocalState(() => loadOriginal = true),
                              child: Text(item.isImage
                                  ? '手动加载原图'
                                  : '手动加载原始文件'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
          ),
    );
  }
  Widget _buildPagination() {
    final total = mediaResult?.total ?? 0;
    return Row(
      children: [
        Text('第 $page 页 / 共 $total 条'),
        const Spacer(),
        IconButton(
          onPressed: page <= 1
              ? null
              : () {
                  setState(() => page--);
                  _loadMedia();
                },
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: page * 24 >= total
              ? null
              : () {
                  setState(() => page++);
                  _loadMedia();
                },
          icon: const Icon(Icons.chevron_right),
        ),
        FilledButton(
          onPressed: _loadMedia,
          child: const Text('刷新'),
        ),
      ],
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '-';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class _ProgressiveImage extends StatefulWidget {
  const _ProgressiveImage({
    required this.previewUrl,
    required this.thumbnailUrl,
    required this.fallbackUrl,
    required this.width,
    required this.height,
    required this.fit,
  });

  final String? previewUrl;
  final String? thumbnailUrl;
  final String fallbackUrl;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  State<_ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<_ProgressiveImage> {
  late String _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = _pickInitialUrl();
    _upgradeToThumbnail();
  }

  @override
  void didUpdateWidget(covariant _ProgressiveImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewUrl != widget.previewUrl ||
        oldWidget.thumbnailUrl != widget.thumbnailUrl ||
        oldWidget.fallbackUrl != widget.fallbackUrl) {
      _currentUrl = _pickInitialUrl();
      _upgradeToThumbnail();
    }
  }

  String _pickInitialUrl() {
    final preview = widget.previewUrl?.trim();
    if (preview != null && preview.isNotEmpty) {
      return preview;
    }
    final thumb = widget.thumbnailUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      return thumb;
    }
    return widget.fallbackUrl;
  }

  Future<void> _upgradeToThumbnail() async {
    final thumb = widget.thumbnailUrl?.trim();
    if (thumb == null || thumb.isEmpty || thumb == _currentUrl) {
      return;
    }
    final provider = NetworkImage(thumb);
    try {
      await precacheImage(provider, context);
      if (!mounted) return;
      setState(() => _currentUrl = thumb);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _currentUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, __, ___) =>
      const Center(child: Icon(Icons.broken_image)),
    );
  }
}
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({
    super.key,
    required this.api,
    required this.onAuthError,
    required this.isSuperAdmin,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;
  final bool isSuperAdmin;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final keywordCtrl = TextEditingController();
  PageResult<UserListItem>? pageResult;
  bool loading = false;
  bool loadingRoles = true;
  List<PermissionRoleItem> roles = [];
  int page = 1;

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _loadUsers();
  }

  @override
  void dispose() {
    keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => loading = true);
    try {
      pageResult = await widget.api.listUsers(
        page: page,
        pageSize: 20,
        keyword: keywordCtrl.text.trim(),
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('用户列表加载失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadRoles() async {
    setState(() => loadingRoles = true);
    try {
      roles = await widget.api.listRoles();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (_) {}
    if (mounted) setState(() => loadingRoles = false);
  }

  Future<void> _editUser(UserListItem user) async {
    final result = await showDialog<_UserEditResult>(
      context: context,
      builder: (context) => _UserEditDialog(
        user: user,
        roles: roles,
        isSuperAdmin: widget.isSuperAdmin,
      ),
    );
    if (result == null) return;
    try {
      await widget.api.updateUser(
        user.id,
        email: result.email,
        status: result.status,
        roleName: result.role,
      );
      await _loadUsers();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = pageResult?.items ?? [];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: keywordCtrl,
                  decoration: const InputDecoration(
                    hintText: '按用户名或邮箱搜索',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  page = 1;
                  _loadUsers();
                },
                child: const Text('搜索'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loadUsers,
                child: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? const Center(child: Text('暂无用户'))
                    : ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(user.username.isEmpty
                                  ? '?'
                                  : user.username[0].toUpperCase()),
                            ),
                            title: Text(user.username),
                            subtitle: Text('${user.email} • ${user.roleName}'),
                            trailing: Text(user.statusText),
                            onTap: () => _editUser(user),
                          );
                        },
                      ),
          ),
          if (pageResult != null)
            Row(
              children: [
                Text('第 ${pageResult!.page} 页 / 共 ${pageResult!.total} 条'),
                const Spacer(),
                IconButton(
                  onPressed: page <= 1 ? null : () => setState(() => page--),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: page * pageResult!.pageSize >= pageResult!.total
                      ? null
                      : () => setState(() => page++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _UserEditDialog extends StatefulWidget {
  const _UserEditDialog({
    required this.user,
    required this.roles,
    required this.isSuperAdmin,
  });

  final UserListItem user;
  final List<PermissionRoleItem> roles;
  final bool isSuperAdmin;

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late final TextEditingController emailCtrl;
  late int status;
  late String roleName;

  List<PermissionRoleItem> get _availableRoles {
    if (widget.roles.isNotEmpty) return widget.roles;
    return [
      PermissionRoleItem(
        name: widget.user.roleName,
        displayName: widget.user.roleName,
        description: '',
        canUpload: false,
        allowedMimeTypes: const [],
        createdAt: null,
        updatedAt: null,
      )
    ];
  }

  @override
  void initState() {
    super.initState();
    emailCtrl = TextEditingController(text: widget.user.email);
    status = widget.user.status;
    roleName = widget.user.roleName;
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑用户'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: '邮箱'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: status,
              decoration: const InputDecoration(labelText: '状态'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('未激活')),
                DropdownMenuItem(value: 1, child: Text('正常')),
                DropdownMenuItem(value: 2, child: Text('已封禁')),
              ],
              onChanged: (v) => setState(() => status = v ?? 0),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: roleName,
              decoration: const InputDecoration(labelText: '角色'),
              items: _availableRoles
                  .map((role) => DropdownMenuItem(
                        value: role.name,
                        child: Text(role.displayName),
                      ))
                  .toList(),
              onChanged: widget.isSuperAdmin
                  ? (v) => setState(() => roleName = v ?? roleName)
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _UserEditResult(
              emailCtrl.text.trim(),
              status,
              roleName,
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _UserEditResult {
  _UserEditResult(this.email, this.status, this.role);

  final String email;
  final int status;
  final String role;
}

class PermissionManagementPage extends StatefulWidget {
  const PermissionManagementPage({
    super.key,
    required this.api,
    required this.isSuperAdmin,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final bool isSuperAdmin;
  final VoidCallback onAuthError;

  @override
  State<PermissionManagementPage> createState() => _PermissionManagementPageState();
}

class _PermissionManagementPageState extends State<PermissionManagementPage> {
  List<PermissionRoleItem> roles = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() => loading = true);
    try {
      roles = await widget.api.listRoles();
    } on UnauthorizedException {
      widget.onAuthError();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openRoleDialog([PermissionRoleItem? role]) async {
    final result = await showDialog<PermissionRoleRequest>(
      context: context,
      builder: (_) => _RoleFormDialog(
        role: role,
      ),
    );
    if (result == null) return;
    try {
      if (role == null) {
        await widget.api.createRole(result);
      } else {
        await widget.api.updateRole(role.name, result);
      }
      await _loadRoles();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    }
  }

  Future<void> _deleteRole(String name) async {
    try {
      await widget.api.deleteRole(name);
      await _loadRoles();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e')),
      );
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
              const Text('权限角色'),
              const Spacer(),
              ElevatedButton(
                onPressed: widget.isSuperAdmin ? () => _openRoleDialog() : null,
                child: const Text('新增角色'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : roles.isEmpty
                    ? const Center(child: Text('暂无角色'))
                    : ListView.separated(
                        itemCount: roles.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final role = roles[index];
                          return ListTile(
                            title: Text(role.displayName),
                            subtitle: Text(
                                '${role.canUpload ? '可上传' : '不可上传'} • ${role.allowedMimeTypes.join(', ')}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: widget.isSuperAdmin
                                      ? () => _openRoleDialog(role)
                                      : null,
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  onPressed: widget.isSuperAdmin &&
                                          !_defaultRoles.contains(role.name)
                                      ? () => _deleteRole(role.name)
                                      : null,
                                  icon: const Icon(Icons.delete),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

const List<String> _defaultRoles = ['SUPER_ADMIN', 'ADMIN', 'USER', 'GUEST'];

class _RoleFormDialog extends StatefulWidget {
  const _RoleFormDialog({this.role});

  final PermissionRoleItem? role;

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController displayCtrl;
  late final TextEditingController descriptionCtrl;
  late final TextEditingController mimeCtrl;
  late final TextEditingController singleCtrl;
  late final TextEditingController totalCtrl;
  bool canUpload = false;

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    nameCtrl = TextEditingController(text: role?.name ?? '');
    displayCtrl = TextEditingController(text: role?.displayName ?? '');
    descriptionCtrl = TextEditingController(text: role?.description ?? '');
    mimeCtrl = TextEditingController(
      text: role?.allowedMimeTypes.join(', ') ?? '',
    );
    singleCtrl = TextEditingController(
      text: role?.maxSingleUploadBytes?.toString() ?? '',
    );
    totalCtrl = TextEditingController(
      text: role?.maxTotalUploadBytes?.toString() ?? '',
    );
    canUpload = role?.canUpload ?? false;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    displayCtrl.dispose();
    descriptionCtrl.dispose();
    mimeCtrl.dispose();
    singleCtrl.dispose();
    totalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.role == null ? '新增角色' : '编辑角色'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '角色标识'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: displayCtrl,
                decoration: const InputDecoration(labelText: '显示名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionCtrl,
                decoration: const InputDecoration(labelText: '描述'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: mimeCtrl,
                decoration: const InputDecoration(labelText: '允许的 MIME，逗号分隔'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: singleCtrl,
                decoration: const InputDecoration(labelText: '单文件大小上限（字节）'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: totalCtrl,
                decoration: const InputDecoration(labelText: '总上传配额（字节）'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: canUpload,
                onChanged: (value) => setState(() => canUpload = value ?? false),
                title: const Text('允许上传'),
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
            final request = PermissionRoleRequest(
              name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
              displayName: displayCtrl.text.trim(),
              description: descriptionCtrl.text.trim(),
              canUpload: canUpload,
              allowedMimeTypes: mimeCtrl.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
              maxSingleUploadBytes: int.tryParse(singleCtrl.text.trim()),
              maxTotalUploadBytes: int.tryParse(totalCtrl.text.trim()),
            );
            Navigator.pop(context, request);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
