part of 'package:windblog_admin_flutter/main.dart';

class LinksPage extends StatefulWidget {
  const LinksPage({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<LinksPage> createState() => _LinksPageState();
}

class _LinksPageState extends State<LinksPage> {
  List<AdminLinkItem> links = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    setState(() => loading = true);
    try {
      links = await widget.api.listLinks();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(context,
          SnackBar(content: Text('${t(context, 'load_failed')}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _deleteLink(AdminLinkItem link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
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
        AdminFeedback.showSnackBar(context,
          SnackBar(content: Text('${t(context, 'delete_failed')}$e')),
        );
      }
    }
  }

  Future<void> _checkLink(AdminLinkItem link) async {
    try {
      await widget.api.checkLink(link.id);
      await _loadLinks();
      if (mounted) {
        AdminFeedback.showSnackBar(context, const SnackBar(content: Text('多节点检测已完成')));
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(context, SnackBar(content: Text('检测失败：$error')));
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
          message = '申请已通过，并完成首次检测';
        }
        AdminFeedback.showSnackBar(context, SnackBar(content: Text(message)));
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(context, SnackBar(content: Text('审核失败：$error')));
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
              child: _buildMonitorLogList(logs),
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
        AdminFeedback.showSnackBar(context, SnackBar(content: Text('加载检测记录失败：$error')));
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
    String description =
        '节点：${log.nodeId}  状态码：${log.statusCode}  耗时：${log
        .loadTimeMs}ms';
    if (log.errorMessage != null && log.errorMessage!.isNotEmpty) {
      description = '$description\n失败原因：${log.errorMessage}';
    }
    return description;
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
        String backlinkLabel = '无反链';
        if (log.backlinkFound) {
          backlinkLabel = '有反链';
        }
        return ListTile(
          leading: Icon(statusIcon, color: statusColor),
          title: Text(log.nodeName),
          subtitle: Text(_buildMonitorLogDescription(log)),
          trailing: Chip(label: Text(backlinkLabel)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: TabBar(
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
                children: [
                  _buildLinkList(
                    links.where((l) => l.type != 3).toList(),
                  ),
                  _buildLinkList(
                    links.where((l) => l.type == 3).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkList(List<AdminLinkItem> filteredLinks) {
    if (filteredLinks.isEmpty) {
      return Center(child: Text(t(context, 'no_links')));
    }
    return Card(
      child: ListView.separated(
        itemCount: filteredLinks.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final link = filteredLinks[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: link.icon != null
                  ? NetworkImage(link.icon!)
                  : null,
              child: link.icon == null ? const Icon(Icons.link) : null,
            ),
            title: Text(link.name),
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
                      _buildAvailabilityChip(link),
                      _buildBacklinkChip(link),
                    ],
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
                    icon: const Icon(Icons.monitor_heart_outlined),
                    onPressed: () => _checkLink(link),
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
  const LinksAddButton({super.key, required this.label, required this.onOpen});

  final String label;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('linksAddButton'),
      onPressed: () {
        int defaultLinkType = 0;
        int tabIndex = DefaultTabController
            .of(context)
            .index;
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
