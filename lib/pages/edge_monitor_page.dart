part of 'package:windblog_admin_flutter/main.dart';

class EdgeMonitorPage extends StatefulWidget {
  const EdgeMonitorPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<EdgeMonitorPage> createState() => _EdgeMonitorPageState();
}

class _EdgeMonitorPageState extends State<EdgeMonitorPage> {
  bool loading = false;
  StorageSyncStatus? syncStatus;
  List<StorageClassItem> providers = [];
  List<EdgeNode> edgeNodes = [];
  Map<String, EdgeNodeDataStatus> edgeDataStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      final syncStatusFuture = widget.api.getStorageSyncStatus();
      final providersFuture = widget.api.listStorageClasses();
      final edgeNodesFuture = widget.api.listEdgeNodes();
      syncStatus = await syncStatusFuture;
      providers = await providersFuture;
      edgeNodes = await edgeNodesFuture;
      edgeDataStatuses = await _loadEdgeDataStatuses(edgeNodes);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(context,
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<Map<String, EdgeNodeDataStatus>> _loadEdgeDataStatuses(
      List<EdgeNode> nodes,) async {
    final Map<String, EdgeNodeDataStatus> loadedStatuses = {};
    for (int index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      try {
        final status = await widget.api.getEdgeNodeDataStatus(node.nodeId);
        loadedStatuses[node.nodeId] = status;
      } catch (_) {}
    }
    return loadedStatuses;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '边缘节点监控',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProviderOverview(),
          const SizedBox(height: 16),
          _buildEdgeDataOverview(),
          const SizedBox(height: 16),
          _buildSyncOverview(),
        ],
      ),
    );
  }

  Widget _buildEdgeDataOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '边缘数据状态',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _statItem('边缘节点', edgeNodes.length.toString())),
                Expanded(
                  child: _statItem(
                    '通道在线',
                    _onlineChannelCount.toString(),
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _statItem(
                    '只读节点',
                    _readOnlyCount.toString(),
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildEdgeNodeStatusList(),
          ],
        ),
      ),
    );
  }

  int get _onlineChannelCount {
    int count = 0;
    for (int index = 0; index < edgeDataStatuses.length; index++) {
      final status = edgeDataStatuses.values.elementAt(index);
      if (status.persistentChannelOnline) {
        count = count + 1;
      }
    }
    return count;
  }

  int get _readOnlyCount {
    int count = 0;
    for (int index = 0; index < edgeDataStatuses.length; index++) {
      final status = edgeDataStatuses.values.elementAt(index);
      if (status.readOnly) {
        count = count + 1;
      }
    }
    return count;
  }

  Widget _buildEdgeNodeStatusList() {
    if (edgeNodes.isEmpty) {
      return const Center(child: Text('暂无边缘节点'));
    }

    final List<Widget> rows = [];
    for (int index = 0; index < edgeNodes.length; index++) {
      final node = edgeNodes[index];
      final status = edgeDataStatuses[node.nodeId];
      rows.add(_buildEdgeNodeStatusRow(node, status));
      if (index < edgeNodes.length - 1) {
        rows.add(const Divider(height: 16));
      }
    }
    return Column(children: rows);
  }

  Widget _buildEdgeNodeStatusRow(EdgeNode node,
      EdgeNodeDataStatus? status,) {
    final bool channelOnline = status?.persistentChannelOnline ?? false;
    final bool readOnly = status?.readOnly ?? true;
    final String writeMode = readOnly ? '只读' : '写请求回源';

    return Row(
      children: [
        Icon(
          channelOnline ? Icons.cable : Icons.cable_outlined,
          color: channelOnline ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                node.name.isNotEmpty ? node.name : node.nodeId,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '节点 ${node.nodeId} / ${node.region.code.toUpperCase()}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        _statusChip(
          channelOnline ? '通道在线' : '通道离线',
          channelOnline ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        _statusChip(
          writeMode,
          readOnly ? Colors.deepOrange : Colors.green,
        ),
        const SizedBox(width: 8),
        _statusChip(
          '24h ${_formatRate(status?.availability?.last24Hours)}',
          _rateColor(status?.availability?.last24Hours.onlineRate),
        ),
      ],
    );
  }

  String _formatRate(EdgeNodeAvailabilityRate? rate) {
    if (rate == null || rate.onlineRate == null) {
      return '暂无';
    }
    return '${rate.onlineRate!.toStringAsFixed(1)}%';
  }

  Color _rateColor(double? rate) {
    if (rate == null) {
      return Colors.grey;
    }
    if (rate >= 99.0) {
      return Colors.green;
    }
    if (rate >= 95.0) {
      return Colors.lightGreen;
    }
    if (rate >= 80.0) {
      return Colors.orange;
    }
    return Colors.red;
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProviderOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '存储类概览',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _statItem('存储类总数', providers.length.toString())),
                Expanded(child: _statItem(
                    '已启用', _enabledCount.toString(), color: Colors.green)),
                Expanded(child: _statItem(
                    '主存储类', _primaryCount.toString(), color: Colors.blue)),
              ],
            ),
            const SizedBox(height: 12),
            _buildProviderList(),
          ],
        ),
      ),
    );
  }

  int get _enabledCount {
    int count = 0;
    for (int i = 0; i < providers.length; i++) {
      final provider = providers[i];
      if (provider.isEnabled) {
        count = count + 1;
      }
    }
    return count;
  }

  int get _primaryCount {
    int count = 0;
    for (int i = 0; i < providers.length; i++) {
      final provider = providers[i];
      if (provider.isPrimary) {
        count = count + 1;
      }
    }
    return count;
  }

  Widget _buildProviderList() {
    if (providers.isEmpty) {
      return const Center(child: Text('暂无存储类'));
    }
    final List<Widget> chips = [];
    for (int i = 0; i < providers.length; i++) {
      final provider = providers[i];
      final chip = Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: Chip(
          label: Text(provider.displayName),
          backgroundColor: provider.isEnabled
              ? Colors.green.shade50
              : Colors.grey.shade200,
        ),
      );
      chips.add(chip);
    }
    return Wrap(
      children: chips,
    );
  }

  Widget _buildSyncOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '同步状态',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (syncStatus == null)
              const Center(child: Text('暂无同步数据'))
            else
              _buildSyncStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _statItem(
                '已同步', syncStatus!.syncedCount.toString(),
                color: Colors.green)),
            Expanded(child: _statItem(
                '待同步', syncStatus!.pendingCount.toString(),
                color: Colors.orange)),
            Expanded(child: _statItem(
                '失败', syncStatus!.failedCount.toString(), color: Colors.red)),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: syncStatus!.syncPercent / 100,
          minHeight: 8,
        ),
        const SizedBox(height: 4),
        Text('同步进度: ${syncStatus!.syncPercent.toStringAsFixed(1)}%'),
      ],
    );
  }

  Widget _statItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
