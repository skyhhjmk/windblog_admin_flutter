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
  List<StorageProviderItem> providers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      final syncStatusFuture = widget.api.getStorageSyncStatus();
      final providersFuture = widget.api.listStorageProviders();
      syncStatus = await syncStatusFuture;
      providers = await providersFuture;
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
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
          _buildSyncOverview(),
        ],
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
              '节点概览',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _statItem('节点总数', providers.length.toString())),
                Expanded(child: _statItem(
                    '已启用', _enabledCount.toString(), color: Colors.green)),
                Expanded(child: _statItem(
                    '主节点', _primaryCount.toString(), color: Colors.blue)),
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
      return const Center(child: Text('暂无节点'));
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
