part of 'package:windblog_admin_flutter/main.dart';

class CdnCachePage extends StatefulWidget {
  const CdnCachePage({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<CdnCachePage> createState() => _CdnCachePageState();
}

class _CdnCachePageState extends State<CdnCachePage> {
  Map<String, dynamic>? _report;
  Map<String, dynamic>? _recommendations;
  bool _loading = true;
  String? _error;

  final TextEditingController _targetBaseUrlController =
      TextEditingController();
  final TextEditingController _customPathController = TextEditingController();
  bool _probingCustom = false;
  Map<String, dynamic>? _customProbeResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _targetBaseUrlController.dispose();
    _customPathController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final targetUrl = _targetBaseUrlController.text.trim();
      final res = await widget.api.getCdnCacheStatus(
        targetBaseUrl: targetUrl.isNotEmpty ? targetUrl : null,
      );
      _report = res;
      _recommendations =
          (res['recommendations'] as Map<String, dynamic>?) ??
          await widget.api.getCdnCacheRecommendations();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _probeCustom() async {
    final path = _customPathController.text.trim();
    if (path.isEmpty) {
      AdminFeedback.error(context, '请输入要探测的相对路径');
      return;
    }
    setState(() => _probingCustom = true);
    try {
      final targetUrl = _targetBaseUrlController.text.trim();
      final res = await widget.api.probeCdnCachePath(
        targetBaseUrl: targetUrl.isNotEmpty ? targetUrl : null,
        path: path,
      );
      setState(() => _customProbeResult = res);
      if (mounted) AdminFeedback.info(context, '探测完成');
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) AdminFeedback.error(context, '探测失败: $e');
    } finally {
      if (mounted) setState(() => _probingCustom = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AdminFeedback.info(context, '已复制 $label 到剪贴板');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CDN 缓存诊断与配置'),
        actions: [
          IconButton(
            tooltip: '重新诊断',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading && _report == null) {
      return const AdminStatusView.loading(title: '正在探测源站响应标头并生成诊断报告');
    }
    if (_error != null && _report == null) {
      return AdminStatusView.error(
        title: '诊断失败',
        message: _error,
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      );
    }

    final probes = (_report?['probes'] as List<dynamic>?) ?? [];
    final overallStatus = _report?['overallStatus']?.toString() ?? 'HEALTHY';
    final checkedAt = _report?['checkedAt']?.toString() ?? '';
    final targetBaseUrl = _report?['targetBaseUrl']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTargetBaseUrlBar(),
          const SizedBox(height: 16),
          _buildOverallStatusBanner(overallStatus, checkedAt, targetBaseUrl),
          const SizedBox(height: 20),
          _buildSectionHeader(
            icon: Icons.checklist_rtl_rounded,
            title: '核心端点响应标头检测',
            subtitle: '验证各端点 Cache-Control 是否严密，杜绝个人隐私与登录态泄漏',
          ),
          const SizedBox(height: 12),
          ...probes.map((p) => _buildProbeCard(p as Map<String, dynamic>)),
          const SizedBox(height: 20),
          _buildCustomProbeCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(
            icon: Icons.recommend_rounded,
            title: '持久推荐 CDN 缓存配置规则',
            subtitle: '基于 Quarkus 标头行为制定的安全 CDN 配置标准（请对照 CDN 控制台配置）',
          ),
          const SizedBox(height: 12),
          _buildRecommendationsSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTargetBaseUrlBar() {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.language_rounded, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _targetBaseUrlController,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '探测基址（留空则默认探测本地回路，也可输入完整线上域名如 https://example.com）',
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('开始诊断'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatusBanner(
    String status,
    String checkedAt,
    String targetBaseUrl,
  ) {
    Color bg;
    Color border;
    Color fg;
    IconData icon;
    String statusText;
    String desc;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case 'DANGER':
        bg = isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
            : Colors.red.shade50;
        border = isDark ? Colors.red.shade800 : Colors.red.shade300;
        fg = Colors.red;
        icon = Icons.error_rounded;
        statusText = '检测到高危缓存隐患';
        desc = '存在私有数据、管理接口或错误响应未配置有效禁缓存标头的情况，极可能被 CDN 错误共享！';
        break;
      case 'WARNING':
        bg = isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.3)
            : Colors.orange.shade50;
        border = isDark ? Colors.orange.shade800 : Colors.orange.shade300;
        fg = Colors.orange.shade800;
        icon = Icons.warning_amber_rounded;
        statusText = '配置存在部分警告项';
        desc = '核心接口已受控，但存在部分可能影响性能或边缘命中率的提示，建议按下方指引优化。';
        break;
      case 'HEALTHY':
      default:
        bg = isDark
            ? const Color(0xFF14532D).withValues(alpha: 0.3)
            : Colors.green.shade50;
        border = isDark ? Colors.green.shade800 : Colors.green.shade300;
        fg = Colors.green;
        icon = Icons.check_circle_rounded;
        statusText = '全站源站缓存标头健康受控';
        desc = '管理后台、用户个人信息与错误响应已严格禁用共享缓存；公共文章与静态资源具备标准缓存策略。';
        break;
    }

    return Card(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(desc, style: const TextStyle(fontSize: 13, height: 1.4)),
                  const SizedBox(height: 8),
                  Text(
                    '探测目标: $targetBaseUrl | 检测时间: $checkedAt',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProbeCard(Map<String, dynamic> probe) {
    final name = probe['name']?.toString() ?? '';
    final path = probe['path']?.toString() ?? '';
    final statusCode = probe['statusCode'] as num? ?? 0;
    final cacheControl = probe['cacheControl']?.toString() ?? '';
    final vary = probe['vary']?.toString() ?? '';
    final level = probe['level']?.toString() ?? 'HEALTHY';
    final summary = probe['summary']?.toString() ?? '';
    final suggestion = probe['suggestion']?.toString() ?? '';

    Color badgeBg;
    Color badgeFg;
    switch (level) {
      case 'DANGER':
        badgeBg = Colors.red.withValues(alpha: 0.15);
        badgeFg = Colors.red;
        break;
      case 'WARNING':
        badgeBg = Colors.orange.withValues(alpha: 0.15);
        badgeFg = Colors.orange.shade800;
        break;
      case 'HEALTHY':
      default:
        badgeBg = Colors.green.withValues(alpha: 0.15);
        badgeFg = Colors.green;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (path.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          path,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'HTTP $statusCode',
                    style: TextStyle(
                      color: badgeFg,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildHeaderLine(
              'Cache-Control',
              cacheControl.isEmpty ? '(空/未提供)' : cacheControl,
            ),
            if (vary.isNotEmpty) _buildHeaderLine('Vary', vary),
            const SizedBox(height: 10),
            Text(
              summary,
              style: TextStyle(
                fontSize: 13,
                color: level == 'DANGER'
                    ? Colors.red
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (suggestion.isNotEmpty && level != 'HEALTHY') ...[
              const SizedBox(height: 4),
              Text(
                '建议: $suggestion',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderLine(String headerName, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$headerName:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomProbeCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '自定义单路径探测',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '输入站内的任意相对路径（如 /post/your-slug 或 /assets/css/style.css）测试其实时标头',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customPathController,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: '输入相对路径，例如 /post/hello-world',
                    ),
                    onSubmitted: (_) => _probeCustom(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _probingCustom ? null : _probeCustom,
                  child: _probingCustom
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('探测'),
                ),
              ],
            ),
            if (_customProbeResult != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildProbeCard(_customProbeResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    final rec = _recommendations ?? {};
    final cacheKeyCookies =
        (rec['cacheKeyCookies'] as List<dynamic>?) ?? ['user_lang_v2'];
    final bypassCookies =
        (rec['bypassCookies'] as List<dynamic>?) ??
        ['user_token', 'admin_jwt', 'post_access_ticket_*'];
    final bypassPaths =
        (rec['bypassPaths'] as List<dynamic>?) ??
        [
          '/api/admin/*',
          '/api/user/*',
          '/user/*',
          '/q/*',
          '/observability/*',
          '/api/internal/*',
        ];
    final cfRules = (rec['cloudflareRules'] as Map<String, dynamic>?) ?? {};
    final stdRules = (rec['standardCdnRules'] as Map<String, dynamic>?) ?? {};

    return Column(
      children: [
        // 1. 缓存键 Cookie (Cache Key Cookies)
        _buildConfigCard(
          icon: Icons.vpn_key_rounded,
          color: Colors.indigo,
          title: '必须加入 CDN 缓存键（Cache Key）的 Cookie 名',
          description:
              'WindBlog 服务端渲染多语言页面根据该 Cookie 判断显示语言。如果 CDN 支持按 Cookie 自定义 Cache Key，必须将其加入缓存键，否则多语言用户将互相看到其他语言的缓存。',
          items: cacheKeyCookies.map((e) => e.toString()).toList(),
          copyLabel: 'Cookie 名 (user_lang_v2)',
          copyContent: cacheKeyCookies.join(', '),
        ),
        const SizedBox(height: 12),

        // 2. 绕过缓存的 Cookie (Bypass Cache Cookies)
        _buildConfigCard(
          icon: Icons.no_accounts_rounded,
          color: Colors.amber.shade900,
          title: '必须配置 CDN 绕过缓存（Bypass Cache）的 Cookie 名',
          description:
              '当客户端请求带有以下任意 Cookie 时，代表用户处于已登录状态或拥有文章专属解锁阅读权限，CDN 规则必须强制绕过缓存、直接回源。',
          items: bypassCookies.map((e) => e.toString()).toList(),
          copyLabel: 'Bypass Cookies',
          copyContent: bypassCookies.join(', '),
        ),
        const SizedBox(height: 12),

        // 3. 必须 Bypass 的路径
        _buildConfigCard(
          icon: Icons.shield_outlined,
          color: Colors.red.shade700,
          title: '必须在 CDN 规则中强制 Bypass 的敏感路径清单',
          description: '管理后台、用户个人中心、运维探针及监控地址严禁由 CDN 边缘节点提供缓存，必须配置绝对回源。',
          items: bypassPaths.map((e) => e.toString()).toList(),
          copyLabel: 'Bypass 路径列表',
          copyContent: bypassPaths.join('\n'),
        ),
        const SizedBox(height: 12),

        // 4. 静态资源强缓存
        _buildSimpleNoticeCard(
          icon: Icons.timer_outlined,
          title: '静态资源与媒体强缓存策略',
          content:
              '目录 /assets/* 及 /uploads/* 已在 Quarkus 侧打上 30 天缓存标头。建议在 CDN 开启 30 天强缓存，并务必启用「保留 Query String」参数缓存区分。',
        ),
        const SizedBox(height: 12),

        // 5. 错误码负缓存防护
        _buildSimpleNoticeCard(
          icon: Icons.bug_report_outlined,
          title: '4xx / 5xx 错误码负缓存 (Negative Caching) 防护',
          content:
              '务必在 CDN 控制台将 404, 500, 502, 503, 504 状态码的缓存时间设为 0 秒！避免源站重启或临时故障被边缘节点锁定数分钟。',
        ),
        const SizedBox(height: 16),

        // 6. Cloudflare 推荐规则
        _buildProviderGuideCard(
          title: 'Cloudflare Cache Rules 配置示例',
          icon: Icons.cloud_queue_rounded,
          ruleSnippet:
              cfRules['bypassRule']?.toString() ??
              '(http.request.uri.path wildcard "/api/admin/*") or (http.cookie contains "user_token")',
          actionText: '操作: Cache eligibility -> Bypass cache',
          note:
              cfRules['cacheKeyAdvice']?.toString() ??
              '自定义 Cache Key: 启用 Query String 且在 Cookie 选项中添加 user_lang_v2',
        ),
        const SizedBox(height: 12),

        // 7. 阿里云 / 腾讯云 CDN 配置示例
        _buildProviderGuideCard(
          title: stdRules['title']?.toString() ?? '阿里云 / 腾讯云 CDN 配置要点',
          icon: Icons.dns_outlined,
          ruleSnippet:
              '【不缓存目录】: ${stdRules['directoryNoCache'] ?? '/api/admin/, /api/user/, /q/'}\n【强缓存目录】: ${stdRules['directoryLongCache'] ?? '/assets/ (30天), /uploads/ (30天)'}',
          actionText:
              '高级设置: ${stdRules['followOrigin'] ?? '开启遵循源站 Cache-Control'} / ${stdRules['paramCache'] ?? '开启保留 Query String'}',
          note: '状态码缓存: 将 4xx / 5xx 错误码过期时间统一设为 0 秒。',
        ),
      ],
    );
  }

  Widget _buildConfigCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required List<String> items,
    required String copyLabel,
    required String copyContent,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copyToClipboard(copyContent, copyLabel),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('复制全部'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                return Chip(
                  label: Text(
                    item,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  onDeleted: () => _copyToClipboard(item, item),
                  deleteIcon: const Icon(Icons.copy, size: 14),
                  deleteButtonTooltipMessage: '复制此项',
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleNoticeCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderGuideCard({
    required String title,
    required IconData icon,
    required String ruleSnippet,
    required String actionText,
    required String note,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copyToClipboard(ruleSnippet, title),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制规则'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: SelectableText(
                ruleSnippet,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              actionText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              note,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
