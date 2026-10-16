part of 'package:windblog_admin_flutter/main.dart';

class SeoToolsPage extends StatefulWidget {
  const SeoToolsPage({
    super.key,
    required this.api,
    required this.onAuthError,
    this.postId,
  });
  final AdminApiClient api;
  final VoidCallback onAuthError;
  final int? postId;
  @override
  State<SeoToolsPage> createState() => _SeoToolsPageState();
}

class _SeoToolsPageState extends State<SeoToolsPage> {
  late final TextEditingController _post = TextEditingController(
    text: widget.postId?.toString() ?? '',
  );
  final _keyword = TextEditingController();
  final _start = TextEditingController(
    text: DateTime.now()
        .subtract(const Duration(days: 31))
        .toIso8601String()
        .substring(0, 10),
  );
  final _end = TextEditingController(
    text: DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String()
        .substring(0, 10),
  );
  int _tab = 0;
  int _page = 1;
  bool _busy = false;
  bool _graphEnabled = false;
  String? _error;
  String _dimension = 'query';
  Map<String, dynamic> _data = {};
  Map<String, dynamic>? _policy;
  Map<String, dynamic>? _suggestion;

  @override
  void initState() {
    super.initState();
    _tab = widget.postId == null ? 0 : 2;
    _load();
    _loadGraphStatus();
  }

  Future<void> _loadGraphStatus() async {
    try {
      final status = await widget.api.seoGet('link-graph/status');
      if (mounted) setState(() => _graphEnabled = status['enabled'] == true);
    } catch (_) {
      /* Graph permissions do not prevent using other SEO tools. */
    }
  }

  void _openGraph([int? id]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InternalLinkGraphPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
          postId: id,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _post.dispose();
    _keyword.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
    Map<String, dynamic> data;
    switch (_tab) {
      case 0:
        data = await widget.api.seoGet('redirects?page=$_page');
      case 1:
        data = await widget.api.seoGet('not-found?page=$_page');
      case 2:
        final id = int.tryParse(_post.text);
        if (id == null) {
          if (mounted) setState(() => _data = {});
          return;
        }
        final policy = await widget.api.seoGet('posts/$id/policy');
        if (mounted) setState(() => _policy = policy);
        data = await widget.api.seoGet(
          'posts/$id/audit?keyword=${Uri.encodeQueryComponent(_keyword.text)}',
        );
      case 3:
        data = await widget.api.seoGet('links?page=$_page');
      default:
        data = await widget.api.seoGet('gsc');
    }
    if (mounted) setState(() => _data = data);
  });

  Future<void> _redirect([Map<String, dynamic>? existing]) async {
    final source = TextEditingController(
      text: existing?['source']?.toString() ?? '',
    );
    final target = TextEditingController(
      text: existing?['target']?.toString() ?? '',
    );
    int status = toInt(existing?['status']) ?? 301;
    bool enabled = existing?['enabled'] != false;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('重定向规则'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: source,
                  decoration: const InputDecoration(
                    labelText: '原路径',
                    hintText: '/post/old-slug',
                  ),
                ),
                TextField(
                  controller: target,
                  decoration: const InputDecoration(
                    labelText: '目标路径',
                    hintText: '/post/new-slug',
                  ),
                ),
                DropdownButton<int>(
                  value: status,
                  isExpanded: true,
                  items: [301, 302, 307, 308]
                      .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                      .toList(),
                  onChanged: (v) => setLocal(() => status = v ?? 301),
                ),
                SwitchListTile(
                  title: const Text('启用'),
                  value: enabled,
                  onChanged: (v) => setLocal(() => enabled = v),
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
              onPressed: () => Navigator.pop(context, {
                'id': existing?['id'],
                'source': source.text.trim(),
                'target': target.text.trim(),
                'status': status,
                'enabled': enabled,
              }),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    // Controllers remain alive until the dialog exit animation finishes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    source.dispose();
    target.dispose();
    if (result == null || !mounted) return;
    await _run(() async {
      await widget.api.seoPost('redirects', result);
    });
    if (mounted && _error == null) await _load();
  }

  List<Map<String, dynamic>> get _items => ((_data['items'] as List?) ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  Widget _pagination() => Row(
    children: [
      TextButton(
        onPressed: _busy || _page <= 1
            ? null
            : () {
                setState(() => _page--);
                _load();
              },
        child: const Text('上一页'),
      ),
      Text('第 $_page 页 · 共 ${_data['total'] ?? 0} 条'),
      TextButton(
        onPressed: _busy || _page * 50 >= (toInt(_data['total']) ?? 0)
            ? null
            : () {
                setState(() => _page++);
                _load();
              },
        child: const Text('下一页'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SEO 管理')),
    body: AdminPageScaffold(
      title: '搜索引擎优化',
      actions: [
        OutlinedButton(
          onPressed: _busy
              ? null
              : () {
                  _load();
                  _loadGraphStatus();
                },
          child: const Text('刷新'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in [
                  '重定向',
                  '404 监控',
                  '文章与图片检查',
                  '内链分析',
                  'Search Console',
                ].asMap().entries)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _tab == entry.key,
                      onSelected: _busy
                          ? null
                          : (_) {
                              setState(() {
                                _tab = entry.key;
                                _page = 1;
                                _data = {};
                                _policy = null;
                              });
                              _load();
                            },
                    ),
                  ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _body(),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _body() {
    switch (_tab) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('支持站内 301 / 302 / 307 / 308。修改文章 slug 时自动保留旧链接。'),
            FilledButton(
              onPressed: _busy ? null : () => _redirect(),
              child: const Text('新增规则'),
            ),
            for (final item in _items)
              ListTile(
                title: Text('${item['source']} → ${item['target']}'),
                subtitle: Text(
                  '${item['status']} · ${item['enabled'] == true ? '启用' : '停用'}',
                ),
                onTap: _busy ? null : () => _redirect(item),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy
                      ? null
                      : () async {
                          await _run(
                            () => widget.api.seoDeleteRedirect(
                              toInt(item['id'])!,
                            ),
                          );
                          if (mounted && _error == null) await _load();
                        },
                ),
              ),
            _pagination(),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('记录页面失效链接与最近来源，保留 90 天。修复后可标记已处理，再次访问失效地址会重新打开。'),
            for (final item in _items)
              ListTile(
                title: Text('${item['path']} · ${item['hits']} 次'),
                subtitle: Text('来源：${item['referer']}\n最近：${item['lastSeen']}'),
                trailing: TextButton(
                  onPressed: _busy || item['resolved'] == true
                      ? null
                      : () async {
                          await _run(() async {
                            await widget.api.seoPost('not-found/resolve', {
                              'path': item['path'],
                            });
                          });
                          if (mounted && _error == null) await _load();
                        },
                  child: Text(item['resolved'] == true ? '已处理' : '标记处理'),
                ),
              ),
            _pagination(),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (_) => setState(() {
                _policy = null;
                _suggestion = null;
                _data = {};
              }),
              enabled: !_busy,
              controller: _post,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '文章 ID'),
            ),
            TextField(
              enabled: !_busy,
              controller: _keyword,
              decoration: const InputDecoration(labelText: '目标关键词（可选）'),
            ),
            FilledButton(
              onPressed: _busy ? null : _load,
              child: const Text('检查已发布内容'),
            ),
            if (_graphEnabled && int.tryParse(_post.text) != null)
              OutlinedButton.icon(
                onPressed: () => _openGraph(int.parse(_post.text)),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('递归分析链接图'),
              ),
            if (_policy != null) ...[
              SwitchListTile(
                title: const Text('禁止收录此文章'),
                value: _policy!['noindex'] == true,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _policy!['noindex'] = v),
              ),
              SwitchListTile(
                title: const Text('禁止跟踪此文章链接'),
                value: _policy!['nofollow'] == true,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _policy!['nofollow'] = v),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final result = await widget.api.seoPost(
                          'posts/${int.parse(_post.text)}/policy',
                          _policy!,
                        );
                        if (mounted) setState(() => _policy = result);
                      }),
                child: const Text('保存收录设置'),
              ),
            ],
            OutlinedButton(
              onPressed: _busy || int.tryParse(_post.text) == null
                  ? null
                  : () => _run(() async {
                      final result = await widget.api.seoPost(
                        'posts/${int.parse(_post.text)}/suggest',
                        {},
                      );
                      if (mounted) setState(() => _suggestion = result);
                    }),
              child: const Text('AI 推荐标题、描述与关键词'),
            ),
            if (_suggestion != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('请核对建议与原文是否一致，确认后再用于文章。'),
                      SelectableText(
                        '标题：${_suggestion!['title']}\n描述：${_suggestion!['description']}\n关键词：${_suggestion!['keywords']}',
                      ),
                      if (widget.postId != null)
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop(_suggestion),
                          child: const Text('应用到编辑器（保存后生效）'),
                        ),
                    ],
                  ),
                ),
              ),
            if (_data['score'] != null)
              Text(
                'SEO 检查：${_data['score']} / 100',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            Text(_data['note']?.toString() ?? '选择文章后检查标题、描述、标题层级、关键词和图片 ALT。'),
            for (final issue in (_data['issues'] as List?) ?? [])
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(issue.toString()),
              ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_graphEnabled)
              OutlinedButton.icon(
                onPressed: () => _openGraph(),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('可视化内部链接图'),
              ),
            Text(_data['note']?.toString() ?? '统计已发布文章的正文内链。'),
            for (final item in _items)
              ListTile(
                trailing: _graphEnabled
                    ? IconButton(
                        tooltip: '递归链接图',
                        icon: const Icon(Icons.account_tree_outlined),
                        onPressed: () => _openGraph(toInt(item['id'])),
                      )
                    : null,
                title: Text(
                  '${item['slug']} · 入链 ${item['incomingReferences']}',
                ),
                subtitle: Text(
                  '${item['noArticleIncomingLinks'] == true ? '没有其他文章正文链接到此文章\n' : ''}失效目标：${(item['broken'] as List? ?? []).join(', ')}',
                ),
                onTap: _busy
                    ? null
                    : () {
                        setState(() {
                          _tab = 2;
                          _post.text = '${item['id']}';
                          _data = {};
                          _policy = null;
                        });
                        _load();
                      },
              ),
            _pagination(),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _data['configured'] == true
                  ? '已配置：${_data['siteUrl']}'
                  : '尚未授权 Google Search Console。请在系统 SEO 设置中填写站点验证码，并在服务器配置 OAuth 授权。',
            ),
            TextField(
              controller: _start,
              decoration: const InputDecoration(labelText: '开始日期 YYYY-MM-DD'),
            ),
            TextField(
              controller: _end,
              decoration: const InputDecoration(labelText: '结束日期 YYYY-MM-DD'),
            ),
            DropdownButton<String>(
              value: _dimension,
              items: const [
                DropdownMenuItem(value: 'query', child: Text('搜索词')),
                DropdownMenuItem(value: 'page', child: Text('页面')),
                DropdownMenuItem(value: 'date', child: Text('日期')),
                DropdownMenuItem(value: 'country', child: Text('国家')),
                DropdownMenuItem(value: 'device', child: Text('设备')),
              ],
              onChanged: (v) => setState(() => _dimension = v ?? 'query'),
            ),
            FilledButton(
              onPressed: _busy || _data['configured'] != true
                  ? null
                  : () => _run(() async {
                      final result = await widget.api.seoGet(
                        'gsc/analytics?start=${Uri.encodeQueryComponent(_start.text)}&end=${Uri.encodeQueryComponent(_end.text)}&dimension=$_dimension',
                      );
                      if (mounted) setState(() => _data['analytics'] = result);
                    }),
              child: const Text('查询统计'),
            ),
            for (final row
                in ((_data['analytics'] as Map?)?['rows'] as List?) ?? [])
              ListTile(
                title: Text((row['keys'] as List).join(' / ')),
                subtitle: Text(
                  '点击 ${row['clicks']} · 曝光 ${row['impressions']} · CTR ${((row['ctr'] as num) * 100).toStringAsFixed(2)}% · 平均排名 ${(row['position'] as num).toStringAsFixed(1)}',
                ),
              ),
          ],
        );
    }
  }
}
