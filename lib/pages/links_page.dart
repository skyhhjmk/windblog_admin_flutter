part of 'package:windblog_admin_flutter/main.dart';

class _LinkIconAvatar extends StatelessWidget {
  const _LinkIconAvatar({required this.url, required this.api});

  final String? url;
  final AdminApiClient api;

  @override
  Widget build(BuildContext context) {
    final validUrl = _validatedMediaImageUrl(api, url);
    if (validUrl == null) {
      return const CircleAvatar(child: Icon(Icons.link));
    }

    return ClipOval(
      child: Image.network(
        validUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const CircleAvatar(child: Icon(Icons.link)),
      ),
    );
  }
}

class LinksPage extends StatefulWidget {
  const LinksPage({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<LinksPage> createState() => _LinksPageState();
}

class _LinksPageState extends State<LinksPage>
    with SingleTickerProviderStateMixin {
  static const int _linkPageSize = 20;

  List<AdminLinkItem> links = [];
  bool loading = false;
  int _activeTab = 0;
  int _currentPage = 1;
  int _totalLinks = 0;
  int _loadGeneration = 0;
  final Set<int> _checkingLinkIds = {};
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _loadLinks();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    final nextTab = _tabController.index;
    if (_tabController.indexIsChanging || nextTab == _activeTab) {
      return;
    }
    setState(() => _activeTab = nextTab);
    _loadLinks(page: 1);
  }

  Future<void> _loadLinks({int? page}) async {
    final generation = ++_loadGeneration;
    final requestedPage = page ?? _currentPage;
    if (mounted) {
      setState(() => loading = true);
    }
    try {
      var result = await widget.api.listLinks(
        page: requestedPage,
        pageSize: _linkPageSize,
        type: _activeTab == 1 ? 3 : null,
        excludeType: _activeTab == 0 ? 3 : null,
      );
      var effectivePage = requestedPage;
      final totalPages = result.total == 0
          ? 1
          : (result.total + _linkPageSize - 1) ~/ _linkPageSize;
      if (effectivePage > totalPages) {
        effectivePage = totalPages;
        result = await widget.api.listLinks(
          page: effectivePage,
          pageSize: _linkPageSize,
          type: _activeTab == 1 ? 3 : null,
          excludeType: _activeTab == 0 ? 3 : null,
        );
      }
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        links = result.items;
        _totalLinks = result.total;
        _currentPage = effectivePage;
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('${t(context, 'load_failed')}$e')),
        );
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _deleteLink(AdminLinkItem link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'confirm_delete')),
        content: Text(
          t(context, 'confirm_delete_link').replaceAll('%s', link.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(t(context, 'delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.api.deleteLink(link.id);
      await _loadLinks();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('${t(context, 'delete_failed')}$e')),
        );
      }
    }
  }

  Future<void> _checkLink(AdminLinkItem link) async {
    if (_checkingLinkIds.contains(link.id)) {
      return;
    }
    setState(() => _checkingLinkIds.add(link.id));
    try {
      var job = await widget.api.checkLink(link.id);
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          const SnackBar(content: Text('检测任务已提交，正在后台执行')),
        );
      }
      while (mounted && job.status == 'RUNNING') {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) {
          return;
        }
        job = await widget.api.getLinkCheckJob(link.id, job.jobId);
      }
      if (!mounted) {
        return;
      }
      await _loadLinks(page: _currentPage);
      if (mounted) {
        final message = switch (job.status) {
          'COMPLETED' => '多节点检测已完成',
          'FAILED' => job.errorMessage ?? '检测失败',
          _ => '检测状态已刷新',
        };
        AdminFeedback.showSnackBar(context, SnackBar(content: Text(message)));
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('检测失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _checkingLinkIds.remove(link.id));
      }
    }
  }

  Future<void> _reviewApplication(AdminLinkItem link, bool approved) async {
    try {
      await widget.api.reviewLinkApplication(link.id, approved: approved);
      await _loadLinks();
      if (mounted) {
        String message = '申请已拒绝';
        if (approved) {
          message = '申请已通过，首次检测已提交后台执行';
        }
        AdminFeedback.showSnackBar(context, SnackBar(content: Text(message)));
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('审核失败：$error')),
        );
      }
    }
  }

  Future<void> _showMonitorLogs(AdminLinkItem link) async {
    try {
      final logs = await widget.api.listLinkMonitorLogs(link.id);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('${link.name} 节点检测记录'),
            content: SizedBox(
              width: 760,
              height: 480,
              child: Column(
                children: [
                  Card(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '检测记录仅保留最近 90 天，超期记录会自动清理。关键词欺诈依据注释、隐藏元素和异常 DOM 等线索判定，可点击记录查看详情。',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _buildMonitorLogList(logs)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('加载检测记录失败：$error')),
        );
      }
    }
  }

  Future<void> _openLinkEditor({
    AdminLinkItem? initialLink,
    int? defaultLinkType,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return AddLinkPage(
            api: widget.api,
            onAuthError: widget.onAuthError,
            initialLink: initialLink,
            defaultLinkType: defaultLinkType,
          );
        },
      ),
    );
    await _loadLinks();
  }

  String _buildMonitorLogDescription(LinkMonitorLogItem log) {
    final sourceLabel = switch (log.checkSource) {
      'MANUAL' => '手动检测',
      'AUTOMATIC' => '自动检测',
      _ => '来源未记录',
    };
    final checkTime =
        log.checkTime?.toLocal().toString().split('.').first ?? '-';
    String description =
        '检测来源：$sourceLabel · 检查时间：$checkTime\n节点：${log.nodeId}  状态码：${log.statusCode}  耗时：${log.loadTimeMs}ms';
    if (log.errorMessage != null && log.errorMessage!.isNotEmpty) {
      description = '$description\n失败原因：${log.errorMessage}';
    }
    return description;
  }

  Future<void> _showMonitorLogDetails(LinkMonitorLogItem log) async {
    final details = log.detectionDetails;
    String value(String key, [String fallback = '未记录']) {
      final raw = details[key];
      if (raw == null || raw.toString().isEmpty) return fallback;
      return raw.toString();
    }

    String listValue(String key) {
      final raw = details[key];
      if (raw is List) {
        return raw
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .join('、');
      }
      return raw?.toString() ?? '';
    }

    Widget detailRow(String label, String text, {bool selectable = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            selectable ? SelectableText(text) : Text(text),
          ],
        ),
      );
    }

    final evidenceAvailable = details['evidenceAvailable'] == true;
    final expectedKeywords = listValue('expectedKeywords');
    final matchedKeywords = listValue('matchedKeywords');
    final matchedUrls = listValue('matchedBacklinkUrls');
    final anchorTexts = listValue('matchedAnchorTexts');
    final fraudReasons = listValue('fraudReasons');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('检测详情 · ${log.nodeName}'),
        content: SizedBox(
          width: 660,
          height: 460,
          child: ListView(
            children: [
              detailRow('检测目标', value('targetName', log.linkName)),
              detailRow('实际检测 URL', value('checkedUrl'), selectable: true),
              detailRow('本站站点名', value('siteName'), selectable: true),
              detailRow('本站 URL', value('siteUrl'), selectable: true),
              detailRow(
                '检测关键词',
                expectedKeywords.isEmpty ? '未记录' : expectedKeywords,
              ),
              detailRow(
                '命中的关键词',
                matchedKeywords.isEmpty ? '无' : matchedKeywords,
              ),
              detailRow(
                '命中的本站反链 URL',
                matchedUrls.isEmpty ? '无' : matchedUrls,
                selectable: true,
              ),
              detailRow('反链锚文本', anchorTexts.isEmpty ? '无' : anchorTexts),
              detailRow(
                '关键词欺诈',
                !evidenceAvailable
                    ? '此节点未提供新版关键词欺诈判定'
                    : log.keywordFraudDetected
                    ? '检测到：${fraudReasons.isEmpty ? '原因未记录' : fraudReasons}'
                    : '未检测到',
              ),
              detailRow('DOM 解析错误数', value('domParseErrorCount', '0')),
              if (!evidenceAvailable)
                const Text(
                  '该节点未返回新版 DOM 检测证据；检测目标和关键词仍来自本次任务。',
                  style: TextStyle(color: Colors.orange),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorLogList(List<LinkMonitorLogItem> logs) {
    if (logs.isEmpty) {
      return const Center(child: Text('暂无检测记录'));
    }
    return ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (context, index) {
        return const Divider(height: 1);
      },
      itemBuilder: (context, index) {
        final log = logs[index];
        IconData statusIcon = Icons.error_outline;
        Color statusColor = Colors.red;
        if (log.ok) {
          statusIcon = Icons.check_circle;
          statusColor = Colors.green;
        }
        final evidenceAvailable =
            log.detectionDetails['evidenceAvailable'] == true;
        final backlinkLabel = !evidenceAvailable
            ? '反链未验证'
            : log.backlinkFound
            ? '有反链'
            : '无反链';
        return ListTile(
          leading: Icon(statusIcon, color: statusColor),
          title: Text(log.nodeName),
          subtitle: Text(_buildMonitorLogDescription(log)),
          onTap: () => _showMonitorLogDetails(log),
          trailing: Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(label: Text(backlinkLabel)),
              if (log.keywordFraudDetected)
                Chip(
                  label: const Text('检测到关键词欺诈'),
                  backgroundColor: Colors.red.shade50,
                  side: BorderSide(color: Colors.red.shade200),
                ),
              const Tooltip(
                message: '点击查看详情',
                child: Icon(Icons.info_outline, size: 18),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: '友情链接'),
                    Tab(text: '文章外链'),
                  ],
                  isScrollable: true,
                ),
              ),
              const SizedBox(width: 16),
              LinksAddButton(
                label: t(context, 'add_link'),
                tabIndex: _activeTab,
                onOpen: (defaultLinkType) {
                  _openLinkEditor(defaultLinkType: defaultLinkType);
                },
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loadLinks,
                icon: const Icon(Icons.refresh),
                label: Text(t(context, 'refresh')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [_buildLinkList(links), _buildLinkList(links)],
                  ),
          ),
          if (!loading)
            PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalLinks == 0
                  ? 1
                  : (_totalLinks + _linkPageSize - 1) ~/ _linkPageSize,
              totalItems: _totalLinks,
              pageSize: _linkPageSize,
              onPageChanged: (page) => _loadLinks(page: page),
            ),
        ],
      ),
    );
  }

  Widget _buildLinkList(List<AdminLinkItem> pageLinks) {
    if (pageLinks.isEmpty) {
      return Center(child: Text(t(context, 'no_links')));
    }
    return Card(
      child: ListView.separated(
        itemCount: pageLinks.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final link = pageLinks[index];
          return ListTile(
            leading: _LinkIconAvatar(url: link.icon, api: widget.api),
            title: Text('#${link.id} · ${link.name}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.url, style: const TextStyle(fontSize: 12)),
                if (link.description != null)
                  Text(
                    link.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildApplicationStatusChip(link),
                      _buildRegionChip(link),
                      _buildAvailabilityChip(link),
                      _buildBacklinkChip(link),
                      _buildKeywordFraudChip(link),
                    ],
                  ),
                ),
                if (link.autoHideMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      link.autoHideMessage,
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (link.applicationStatus == 2 && link.placementType != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _buildPlacementDescription(link),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (link.type == 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Chip(
                          label: Text(
                            '引用文章 ${link.referencedPostCount}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            '总引用 ${link.referenceCount}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (link.referenceCount == 0)
                          Chip(
                            label: const Text(
                              '无引用，可删除',
                              style: TextStyle(fontSize: 10),
                            ),
                            backgroundColor: Colors.orange.shade50,
                            side: BorderSide(color: Colors.orange.shade200),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            onTap: () async {
              await _openLinkEditor(initialLink: link);
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (link.applicationStatus == 2)
                  IconButton(
                    tooltip: '通过申请',
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    onPressed: () => _reviewApplication(link, true),
                  ),
                if (link.applicationStatus == 2)
                  IconButton(
                    tooltip: '拒绝申请',
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: Colors.orange,
                    ),
                    onPressed: () => _reviewApplication(link, false),
                  ),
                if (link.type != 3 && link.applicationStatus == 1)
                  IconButton(
                    tooltip: '立即执行多节点检测',
                    icon: _checkingLinkIds.contains(link.id)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.monitor_heart_outlined),
                    onPressed: _checkingLinkIds.contains(link.id)
                        ? null
                        : () => _checkLink(link),
                  ),
                if (link.type != 3)
                  IconButton(
                    tooltip: '查看节点检测记录',
                    icon: const Icon(Icons.receipt_long_outlined),
                    onPressed: () => _showMonitorLogs(link),
                  ),
                if (link.status == 2)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(
                        t(context, 'disabled'),
                        style: const TextStyle(fontSize: 10),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await _openLinkEditor(initialLink: link);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteLink(link),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildApplicationStatusChip(AdminLinkItem link) {
    String label = '已通过';
    Color color = Colors.green;
    if (link.applicationStatus == 2) {
      label = '待审核';
      color = Colors.orange;
    }
    if (link.applicationStatus == 3) {
      label = '已拒绝';
      color = Colors.red;
    }
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildRegionChip(AdminLinkItem link) {
    final region = BlogRegion.fromCode(link.displayRegion);
    final label = region == BlogRegion.global ? '全球' : region.displayName;
    return Chip(
      avatar: const Icon(Icons.public_outlined, size: 15),
      label: Text('展示：$label', style: const TextStyle(fontSize: 10)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAvailabilityChip(AdminLinkItem link) {
    String label = '未检测';
    Color color = Colors.grey;
    if (link.availabilityStatus == 'ONLINE') {
      label = '在线';
      color = Colors.green;
    }
    if (link.availabilityStatus == 'OFFLINE') {
      label = '所有节点离线';
      color = Colors.red;
    }
    return Chip(
      avatar: Icon(Icons.public, size: 16, color: color),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildBacklinkChip(AdminLinkItem link) {
    String label = '反链未检测';
    Color color = Colors.grey;
    if (link.backlinkStatus == 'FOUND') {
      label = '已发现反链';
      color = Colors.green;
    }
    if (link.backlinkStatus == 'MISSING') {
      label = '缺少反链';
      color = Colors.orange;
    }
    return Chip(
      avatar: Icon(Icons.compare_arrows, size: 16, color: color),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildKeywordFraudChip(AdminLinkItem link) {
    final detected = link.keywordFraudStatus == 'DETECTED';
    final known = link.keywordFraudStatus == 'CLEAN' || detected;
    final label = detected
        ? '检测到关键词欺诈'
        : known
        ? '未发现关键词欺诈'
        : '关键词欺诈未检测';
    final color = detected
        ? Colors.red
        : known
        ? Colors.green
        : Colors.grey;
    return Chip(
      avatar: Icon(
        detected ? Icons.warning_amber : Icons.fact_check_outlined,
        size: 16,
        color: color,
      ),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      visualDensity: VisualDensity.compact,
    );
  }

  String _buildPlacementDescription(AdminLinkItem link) {
    String placementLabel = '其他页面';
    if (link.placementType == 'HOME_PAGE') {
      placementLabel = '首页';
    }
    if (link.placementType == 'LINK_PAGE') {
      placementLabel = '专用友链页';
    }

    String description = '放置位置：$placementLabel';
    if (link.placementPageName != null && link.placementPageName!.isNotEmpty) {
      description = '$description · ${link.placementPageName}';
    }
    if (link.placementUrl != null && link.placementUrl!.isNotEmpty) {
      description = '$description\n${link.placementUrl}';
    }
    if (link.placementDescription != null &&
        link.placementDescription!.isNotEmpty) {
      description = '$description\n${link.placementDescription}';
    }
    return description;
  }
}

class LinksAddButton extends StatelessWidget {
  const LinksAddButton({
    super.key,
    required this.label,
    this.tabIndex = 0,
    required this.onOpen,
  });

  final String label;
  final int tabIndex;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('linksAddButton'),
      onPressed: () {
        int defaultLinkType = 0;
        if (tabIndex == 1) {
          defaultLinkType = 3;
        }
        onOpen(defaultLinkType);
      },
      icon: const Icon(Icons.add),
      label: Text(label),
    );
  }
}
