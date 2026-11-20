part of 'package:windblog_admin_flutter/main.dart';

class StaticHtmlCachePage extends StatefulWidget {
  const StaticHtmlCachePage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<StaticHtmlCachePage> createState() => _StaticHtmlCachePageState();
}

class _StaticHtmlCachePageState extends State<StaticHtmlCachePage> {
  static const int _defaultPageSize = 25;

  Map<String, dynamic>? _status;
  Map<String, dynamic>? _warmupStatus;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _searchQuery = '';
  Timer? _warmupPollTimer;

  final TextEditingController _purgePathController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  late final AdminPaginationController _pagination;

  @override
  void initState() {
    super.initState();
    _pagination = AdminPaginationController(pageSize: _defaultPageSize);
    _pagination.addListener(_onPaginationChanged);
    _load();
  }

  @override
  void dispose() {
    _warmupPollTimer?.cancel();
    _pagination.removeListener(_onPaginationChanged);
    _pagination.dispose();
    _purgePathController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onPaginationChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> get _filteredEntries {
    final raw = (_status?['entries'] as List<dynamic>?) ?? const [];
    final all = raw.whereType<Map<String, dynamic>>().toList();
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) {
      return all;
    }
    return all.where((item) {
      final path = (item['path']?.toString() ?? '').toLowerCase();
      final lang = (item['lang']?.toString() ?? '').toLowerCase();
      final region = (item['region']?.toString() ?? '').toLowerCase();
      return path.contains(q) || lang.contains(q) || region.contains(q);
    }).toList();
  }

  void _syncPaginationTotal({bool resetPage = false}) {
    final total = _filteredEntries.length;
    _pagination.updateTotal(
      total,
      page: resetPage ? 1 : null,
      pageSize: _defaultPageSize,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getStaticHtmlCacheStatus(),
        widget.api.getStaticCacheWarmupStatus(),
      ]);
      _status = results[0];
      _warmupStatus = results[1];
      _syncPaginationTotal();
      if (_warmupStatus?['running'] == true) {
        _startWarmupPolling();
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _startWarmupPolling() {
    _warmupPollTimer?.cancel();
    _warmupPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final ws = await widget.api.getStaticCacheWarmupStatus();
        final stillRunning = ws['running'] == true;
        if (!stillRunning) {
          timer.cancel();
          final status = await widget.api.getStaticHtmlCacheStatus();
          if (mounted) {
            setState(() {
              _warmupStatus = ws;
              _status = status;
              _syncPaginationTotal();
            });
            AdminFeedback.info(
              context,
              '全站缓存预生成完成：成功 ${ws['succeededTasks'] ?? 0}，失败 ${ws['failedTasks'] ?? 0}',
            );
          }
        } else if (mounted) {
          setState(() => _warmupStatus = ws);
        }
      } catch (_) {
        timer.cancel();
      }
    });
  }

  Future<void> _startWarmup() async {
    setState(() => _busy = true);
    try {
      final ws = await widget.api.startStaticCacheWarmup(includePjax: true);
      setState(() => _warmupStatus = ws);
      _startWarmupPolling();
      if (mounted) {
        AdminFeedback.info(context, '已启动全站静态缓存预生成（含 HTML 与 PJAX 片段）');
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) AdminFeedback.error(context, '启动预生成失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelWarmup() async {
    try {
      final ws = await widget.api.cancelStaticCacheWarmup();
      if (mounted) {
        setState(() => _warmupStatus = ws);
        AdminFeedback.info(context, '已请求中止预生成任务');
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) AdminFeedback.error(context, '中止失败: $e');
    }
  }

  Future<void> _toggleEnabled(bool enabled) async {
    setState(() => _busy = true);
    try {
      final updated = await widget.api.toggleStaticHtmlCache(enabled);
      _status = updated;
      _syncPaginationTotal();
      if (mounted) {
        AdminFeedback.info(
          context,
          enabled ? '全站静态 HTML 缓存已启用' : '全站静态 HTML 缓存已暂停',
        );
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) AdminFeedback.error(context, '切换缓存状态失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _purge({String? key, String? path}) async {
    setState(() => _busy = true);
    try {
      final res = await widget.api.purgeStaticHtmlCache(key: key, path: path);
      final data = res['data'];
      if (data is Map<String, dynamic>) {
        _status = data;
        _syncPaginationTotal();
      }
      final count = res['purgedCount'] ?? 0;
      if (mounted) AdminFeedback.info(context, '已清理 $count 个静态缓存文件');
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) AdminFeedback.error(context, '清理静态缓存失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _purgeAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认一键全清静态缓存'),
        content: const Text('将删除磁盘上所有已生成的静态 HTML 文件与命中索引，后续访问会重新生成。确认继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认全清'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final res = await widget.api.purgeAllStaticHtmlCache();
      final data = res['data'];
      if (data is Map<String, dynamic>) {
        _status = data;
        _syncPaginationTotal(resetPage: true);
      }
      final count = res['purgedCount'] ?? 0;
      if (mounted) AdminFeedback.info(context, '已一键清空 $count 个静态缓存文件');
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) AdminFeedback.error(context, '一键全清失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatBytes(num bytes) {
    final b = bytes.toDouble();
    if (b < 1024) return '${b.toInt()} B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatRelativeTime(String? iso) {
    return DateTimeFormatter.formatHuman(context, iso, fallback: '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('全站静态缓存'),
        actions: [
          IconButton(
            tooltip: '刷新状态',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _status == null) {
      return const AdminStatusView.loading(title: '正在加载全站静态缓存状态');
    }
    if (_error != null && _status == null) {
      return AdminStatusView.error(
        title: '加载失败',
        message: _error,
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      );
    }

    final status = _status ?? const {};
    final enabled = status['enabled'] == true;
    final cacheDir = status['cacheDir']?.toString() ?? '-';
    final entryCount = (status['entryCount'] as num?)?.toInt() ?? 0;
    final totalSizeBytes = (status['totalSizeBytes'] as num?)?.toInt() ?? 0;
    final totalHits = (status['totalHits'] as num?)?.toInt() ?? 0;
    final totalMisses = (status['totalMisses'] as num?)?.toInt() ?? 0;
    final hitRate = (status['hitRate'] as num?)?.toDouble() ?? 0.0;

    final filtered = _filteredEntries;
    final pageEntries = _pagination.slice(filtered);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        enabled
                            ? Icons.check_circle_rounded
                            : Icons.pause_circle_rounded,
                        color: enabled ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              enabled ? '运行中（已启用磁盘 HTML 缓存）' : '已暂停',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '存储目录: $cacheDir',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: enabled,
                        onChanged: _busy ? null : _toggleEnabled,
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed:
                            (_busy ||
                                !enabled ||
                                _warmupStatus?['running'] == true)
                            ? null
                            : _startWarmup,
                        icon: const Icon(Icons.bolt_rounded),
                        label: const Text('全站预生成'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _purgeAll,
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: const Text('一键全清'),
                      ),
                    ],
                  ),
                  if (_warmupStatus?['running'] == true ||
                      (_warmupStatus?['totalTasks'] as num? ?? 0) > 0) ...[
                    const SizedBox(height: 12),
                    _buildWarmupProgressBanner(),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildMetricChip('缓存文件数', '$entryCount 个'),
                      _buildMetricChip('磁盘占用', _formatBytes(totalSizeBytes)),
                      _buildMetricChip('总命中次数', '$totalHits 次'),
                      _buildMetricChip(
                        '命中率 / 未命中',
                        '${hitRate.toStringAsFixed(1)}% ($totalMisses 未命中)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _purgePathController,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: '按路径前缀手动清理（如 /post/ 或 /）',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () {
                                final p = _purgePathController.text.trim();
                                if (p.isEmpty) {
                                  AdminFeedback.error(context, '请输入要清理的路径前缀');
                                  return;
                                }
                                _purge(path: p);
                              },
                        icon: const Icon(Icons.cleaning_services_rounded),
                        label: const Text('手动清理'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '已缓存页面明细（共 ${filtered.length} 项，每页 $_defaultPageSize 项）',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '筛选路径 / 语言 / 区域',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _syncPaginationTotal(resetPage: true);
                                      });
                                    },
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _syncPaginationTotal(resetPage: true);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (pageEntries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('暂无匹配的静态 HTML 缓存文件')),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pageEntries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = pageEntries[index];
                        final key = item['key']?.toString() ?? '';
                        final path = item['path']?.toString() ?? '';
                        final lang = item['lang']?.toString() ?? '';
                        final region = item['region']?.toString() ?? '';
                        final variant = (item['variant']?.toString() ?? 'full')
                            .toUpperCase();
                        final sizeBytes =
                            (item['sizeBytes'] as num?)?.toInt() ?? 0;
                        final hits = (item['hits'] as num?)?.toInt() ?? 0;
                        final lastHitAt = item['lastHitAt']?.toString();
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: variant == 'PJAX'
                                      ? Colors.teal.withValues(alpha: 0.14)
                                      : Colors.blue.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  variant,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: variant == 'PJAX'
                                        ? Colors.teal
                                        : Colors.blue,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  path,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '语言: $lang · 区域: $region · 大小: ${_formatBytes(sizeBytes)} · 命中: $hits 次'
                            '${lastHitAt != null ? ' · 最近命中: ${_formatRelativeTime(lastHitAt)}' : ''}',
                          ),
                          trailing: TextButton.icon(
                            onPressed: _busy ? null : () => _purge(key: key),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('清理'),
                          ),
                        );
                      },
                    ),
                  if (filtered.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    PaginationBar(controller: _pagination),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarmupProgressBanner() {
    final ws = _warmupStatus ?? const {};
    final running = ws['running'] == true;
    final total = (ws['totalTasks'] as num?)?.toInt() ?? 0;
    final completed = (ws['completedTasks'] as num?)?.toInt() ?? 0;
    final succeeded = (ws['succeededTasks'] as num?)?.toInt() ?? 0;
    final failed = (ws['failedTasks'] as num?)?.toInt() ?? 0;
    final currentTarget = ws['currentTarget']?.toString() ?? '';
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  running
                      ? '正在预生成全站缓存 ($completed / $total) · 成功 $succeeded · 失败 $failed'
                      : '上次预生成结果：共 $total 项 · 成功 $succeeded · 失败 $failed',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (running)
                TextButton.icon(
                  onPressed: _cancelWarmup,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('中止'),
                ),
            ],
          ),
          if (running) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: total > 0 ? progress : null),
            if (currentTarget.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '当前处理: $currentTarget',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
