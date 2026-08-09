part of 'package:windblog_admin_flutter/main.dart';

class AmpSettingsPage extends StatefulWidget {
  const AmpSettingsPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<AmpSettingsPage> createState() => _AmpSettingsPageState();
}

class _AmpSettingsPageState extends State<AmpSettingsPage> {
  AmpInfo? _info;
  AmpCheckResult? _checkResult;
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _languageController = TextEditingController(
    text: 'zh-cn',
  );
  bool _loading = true;
  bool _checking = false;
  String? _error;
  String? _checkError;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void dispose() {
    _slugController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _info = await widget.api.getAmpInfo();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkArticle() async {
    final slug = _slugController.text.trim();
    if (slug.isEmpty) {
      setState(() => _checkError = '请输入文章 slug');
      return;
    }

    setState(() {
      _checking = true;
      _checkError = null;
      _checkResult = null;
    });
    try {
      _checkResult = await widget.api.checkAmpArticle(
        slug: slug,
        language: _languageController.text.trim().isEmpty
            ? 'zh-cn'
            : _languageController.text.trim(),
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      _checkError = error.toString();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'AMP / SEO',
      actions: [
        OutlinedButton.icon(
          onPressed: _loading ? null : _loadInfo,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('刷新'),
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AdminStatusView.loading(title: '正在加载 AMP 配置');
    }
    if (_error != null) {
      return AdminStatusView.error(
        title: '加载失败',
        message: _error,
        action: FilledButton.icon(
          onPressed: _loadInfo,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      );
    }
    if (_info == null) {
      return const AdminStatusView.empty(title: '暂无 AMP 配置');
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCard(_info!),
          const SizedBox(height: 16),
          _buildCheckCard(),
          if (_checkResult != null) ...[
            const SizedBox(height: 16),
            _buildResultCard(_checkResult!),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoCard(AmpInfo info) {
    final color = info.enabled ? Colors.green : Colors.orange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(info.enabled ? Icons.bolt : Icons.pause_circle,
                    color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    info.enabled ? 'AMP 已启用' : 'AMP 已关闭',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color.shade700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoGrid([
              _AmpInfoItem('公开站点', info.publicBaseUrl),
              _AmpInfoItem('默认路由', info.defaultRoute),
              _AmpInfoItem('多语言路由', info.localizedRoute),
              _AmpInfoItem('缓存时间', '${info.cacheMaxAgeSeconds} 秒'),
            ]),
            const SizedBox(height: 12),
            Text(info.protectedContentPolicy),
            const SizedBox(height: 6),
            Text(
              info.configurationSource,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('检查文章 AMP 页面',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '只检查已发布文章。私有、密码保护和付费文章不会生成可缓存 AMP 页面。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final fields = [
                  TextField(
                    controller: _slugController,
                    decoration: const InputDecoration(
                      labelText: '文章 slug',
                      hintText: '例如 hello-world',
                    ),
                  ),
                  TextField(
                    controller: _languageController,
                    decoration: const InputDecoration(
                      labelText: '语言',
                      hintText: 'zh-cn / en',
                    ),
                  ),
                ];
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      fields[0],
                      const SizedBox(height: 10),
                      fields[1],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 10),
                    SizedBox(width: 180, child: fields[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _checking ? null : _checkArticle,
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: const Text('开始检查'),
                ),
                if (_checkError != null)
                  Text(
                    _checkError!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(AmpCheckResult result) {
    final color = result.available ? Colors.green : Colors.orange;
    return Card(
      color: color.shade50,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(result.available ? Icons.check_circle : Icons.info,
                    color: color.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.available ? 'AMP 页面可用' : 'AMP 页面不可用',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color.shade700,
                        ),
                  ),
                ),
                if (result.available && result.ampUrl.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => web_helper.openUrl(result.ampUrl),
                    icon: const Icon(Icons.open_in_new, size: 17),
                    label: const Text('打开预览'),
                  ),
              ],
            ),
            if (result.reason != null && result.reason!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(result.reason!),
            ],
            const SizedBox(height: 14),
            _buildInfoGrid([
              _AmpInfoItem('标题', result.title),
              _AmpInfoItem('语言', result.language),
              _AmpInfoItem('正文长度', '${result.contentLength} 字符'),
              _AmpInfoItem('图片', '${result.imageCount} 张'),
              _AmpInfoItem('移除元素', '${result.removedElementCount} 个'),
              _AmpInfoItem('更新时间', _formatDate(result.lastUpdated)),
            ]),
            const SizedBox(height: 12),
            SelectableText('AMP: ${result.ampUrl}'),
            const SizedBox(height: 4),
            SelectableText('Canonical: ${result.canonicalUrl}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(List<_AmpInfoItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 640 ? constraints.maxWidth : 300.0;
        return Wrap(
          spacing: 22,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: _buildInfoItem(item),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildInfoItem(_AmpInfoItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.grey.shade700,
                )),
        const SizedBox(height: 2),
        SelectableText(item.value),
      ],
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return value.toLocal().toString().split('.').first;
  }
}

class _AmpInfoItem {
  const _AmpInfoItem(this.label, this.value);

  final String label;
  final String value;
}
