import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
                      Text(tab == 0 ? '后台概览' : '文章管理'),
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
                      : PostsPage(
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
                      'slug: ${it.slug} | 状态: ${it.statusText} | v${it.version}',
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

class AdminApiClient {
  String baseUrl = 'http://localhost:8080';
  String? token;

  Future<String> login({
    required String account,
    required String password,
  }) async {
    final res = await _post(
      '/api/admin/auth/login',
      body: {'account': account, 'password': password},
      auth: false,
      authFailureAsSessionExpired: false,
    );
    final map = _map(jsonDecode(res.body));
    final t = map['token'] as String?;
    if (t == null || t.isEmpty) throw Exception('登录失败: token 为空');
    token = t;
    return t;
  }

  Future<AdminUser> me() async {
    final res = await _get('/api/admin/auth/me');
    final map = _map(jsonDecode(res.body));
    final user = _map(map['user']);
    return AdminUser(
      id: (user['id'] as num?)?.toInt() ?? 0,
      username: user['username']?.toString() ?? '-',
      email: user['email']?.toString() ?? '-',
    );
  }

  Future<Map<String, dynamic>> overview() async {
    final res = await _get('/api/admin/base/overview');
    final map = _map(jsonDecode(res.body));
    return _map(map['data']);
  }

  Future<PostListResult> listPosts({
    required int page,
    required int pageSize,
    String? keyword,
  }) async {
    final query = {
      'page': '$page',
      'pageSize': '$pageSize',
      if ((keyword?.isNotEmpty ?? false)) 'keyword': keyword!,
    };
    final res = await _get('/api/admin/posts', query: query);
    final map = _map(jsonDecode(res.body));
    final list = (map['items'] as List<dynamic>? ?? [])
        .map((e) => PostItem.fromMap(_map(e)))
        .toList();
    return PostListResult(
      items: list,
      total: (map['total'] as num?)?.toInt() ?? 0,
      page: (map['page'] as num?)?.toInt() ?? 1,
      pageSize: (map['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<PostDetail> postDetail(int id) async {
    final res = await _get('/api/admin/posts/$id');
    return PostDetail.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> createPost(PostEditRequest req) async =>
      _post('/api/admin/posts', body: req.toCreateBody());
  Future<void> updatePost(int id, PostEditRequest req) async =>
      _put('/api/admin/posts/$id', body: req.toUpdateBody());
  Future<void> publishPost(int id) async =>
      _post('/api/admin/posts/$id/publish', body: const {});
  Future<void> deletePost(int id) async => _delete('/api/admin/posts/$id');

  Future<http.Response> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers(true));
    _check(res, authFailureAsSessionExpired: true);
    return res;
  }

  Future<http.Response> _post(
    String path, {
    required Map<String, dynamic> body,
    bool auth = true,
    bool authFailureAsSessionExpired = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(
      uri,
      headers: _headers(auth),
      body: jsonEncode(body),
    );
    _check(res, authFailureAsSessionExpired: authFailureAsSessionExpired);
    return res;
  }

  Future<http.Response> _put(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.put(
      uri,
      headers: _headers(true),
      body: jsonEncode(body),
    );
    _check(res, authFailureAsSessionExpired: true);
    return res;
  }

  Future<http.Response> _delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.delete(uri, headers: _headers(true));
    _check(res, authFailureAsSessionExpired: true);
    return res;
  }

  Map<String, String> _headers(bool auth) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      if (token == null || token!.isEmpty) throw UnauthorizedException('请先登录');
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  void _check(http.Response res, {required bool authFailureAsSessionExpired}) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String message = '请求失败(${res.statusCode})';
    try {
      final map = _map(jsonDecode(res.body));
      final m = map['message']?.toString();
      if (m != null && m.isNotEmpty) message = m;
    } catch (_) {}

    if ((res.statusCode == 401 || res.statusCode == 403) &&
        authFailureAsSessionExpired) {
      throw UnauthorizedException('登录已过期或无权限');
    }
    throw Exception(message);
  }

  Map<String, dynamic> _map(Object? obj) {
    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) return obj.map((k, v) => MapEntry('$k', v));
    return {};
  }
}

class UnauthorizedException implements Exception {
  UnauthorizedException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AdminUser {
  AdminUser({required this.id, required this.username, required this.email});
  final int id;
  final String username;
  final String email;
}

class PostListResult {
  PostListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<PostItem> items;
  final int total;
  final int page;
  final int pageSize;
}

class PostItem {
  PostItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.status,
    required this.version,
  });
  final int id;
  final String slug;
  final Map<String, String> title;
  final int status;
  final int version;

  String get zhTitle =>
      title['zh-cn'] ?? (title.isEmpty ? '' : title.values.first);
  String get statusText => status == 1 ? '已发布' : (status == 2 ? '归档' : '草稿');

  factory PostItem.fromMap(Map<String, dynamic> map) {
    return PostItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      slug: map['slug']?.toString() ?? '',
      title: toStringMap(map['title']),
      status: (map['status'] as num?)?.toInt() ?? 0,
      version: (map['version'] as num?)?.toInt() ?? 0,
    );
  }
}

class PostDetail {
  PostDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.contentMarkdown,
    required this.status,
    required this.visibility,
    required this.editorType,
    required this.version,
  });

  final int id;
  final String slug;
  final Map<String, String> title;
  final Map<String, String> summary;
  final Map<String, String> contentMarkdown;
  final int status;
  final int visibility;
  final int editorType;
  final int version;

  factory PostDetail.fromMap(Map<String, dynamic> map) {
    return PostDetail(
      id: (map['id'] as num?)?.toInt() ?? 0,
      slug: map['slug']?.toString() ?? '',
      title: toStringMap(map['title']),
      summary: toStringMap(map['summary']),
      contentMarkdown: toStringMap(map['contentMarkdown']),
      status: (map['status'] as num?)?.toInt() ?? 0,
      visibility: (map['visibility'] as num?)?.toInt() ?? 0,
      editorType: (map['editorType'] as num?)?.toInt() ?? 0,
      version: (map['version'] as num?)?.toInt() ?? 0,
    );
  }
}

class PostEditRequest {
  PostEditRequest({
    required this.slug,
    required this.title,
    required this.summary,
    required this.aiSummary,
    required this.contentMarkdown,
    required this.status,
    required this.visibility,
    required this.editorType,
    required this.version,
  });

  final String slug;
  final Map<String, String> title;
  final Map<String, String> summary;
  final Map<String, String> aiSummary;
  final Map<String, String> contentMarkdown;
  final int status;
  final int visibility;
  final int editorType;
  final int version;

  Map<String, dynamic> toCreateBody() {
    return {
      'slug': slug,
      'title': title,
      'summary': summary,
      'aiSummary': aiSummary,
      'contentMarkdown': contentMarkdown,
      'status': status,
      'visibility': visibility,
      'editorType': editorType,
    };
  }

  Map<String, dynamic> toUpdateBody() {
    return {
      'slug': slug,
      'title': title,
      'summary': summary,
      'aiSummary': aiSummary,
      'contentMarkdown': contentMarkdown,
      'status': status,
      'visibility': visibility,
      'editorType': editorType,
      'version': version,
    };
  }

  PostEditRequest copyWith({int? version}) {
    return PostEditRequest(
      slug: slug,
      title: title,
      summary: summary,
      aiSummary: aiSummary,
      contentMarkdown: contentMarkdown,
      status: status,
      visibility: visibility,
      editorType: editorType,
      version: version ?? this.version,
    );
  }
}

Map<String, String> toStringMap(Object? value) {
  if (value is Map<String, String>) return value;
  if (value is Map) return value.map((k, v) => MapEntry('$k', '${v ?? ''}'));
  return {};
}
