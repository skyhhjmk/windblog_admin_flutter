part of 'package:windblog_admin_flutter/main.dart';

class StorageSyncPanel extends StatefulWidget {
  const StorageSyncPanel({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<StorageSyncPanel> createState() => _StorageSyncPanelState();
}

class _StorageSyncPanelState extends State<StorageSyncPanel> {
  StorageSyncStatus? syncStatus;
  bool loading = false;
  bool _batchSyncing = false;
  int _currentPage = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => loading = true);
    try {
      syncStatus = await widget.api.getStorageSyncStatus(
        page: _currentPage - 1, // Convert to 0-based
        size: _pageSize,
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadStatus();
  }

  Future<void> _batchSync() async {
    if (_batchSyncing) return;
    setState(() => _batchSyncing = true);
    try {
      await widget.api.triggerBatchStorageSync();
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          const SnackBar(content: Text('批量同步任务已提交')),
        );
      }
      await _loadStatus();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('触发同步失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _batchSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: '存储同步监控',
      actions: [
        AdminActionButton(
          label: '批量同步',
          icon: Icons.sync,
          onPressed: _batchSyncing ? null : _batchSync,
          isBusy: _batchSyncing,
        ),
        OutlinedButton.icon(
          onPressed: loading ? null : _loadStatus,
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(loading ? '加载中' : '刷新'),
        ),
      ],
      body: loading
          ? const AdminStatusView.loading(title: '正在加载同步状态')
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (syncStatus == null) {
      return const Center(child: Text('暂无同步数据'));
    }

    final totalPages = (syncStatus!.totalDetails / _pageSize).ceil();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildStatsCard(),
                const SizedBox(height: 16),
                _buildDetailsCard(),
              ],
            ),
          ),
        ),
        if (totalPages > 1)
          PaginationBar(
            currentPage: _currentPage,
            totalPages: totalPages,
            totalItems: syncStatus!.totalDetails,
            pageSize: _pageSize,
            onPageChanged: _onPageChanged,
          ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '同步概览',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statItem('媒体总数', syncStatus!.totalMedia.toString()),
                _statItem('变体总数', syncStatus!.totalVariants.toString()),
                _statItem(
                  '已同步',
                  syncStatus!.syncedCount.toString(),
                  color: Colors.green,
                ),
                _statItem(
                  '待同步',
                  syncStatus!.pendingCount.toString(),
                  color: Colors.orange,
                ),
                _statItem(
                  '失败',
                  syncStatus!.failedCount.toString(),
                  color: Colors.red,
                ),
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
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, {Color? color}) {
    return SizedBox(
      width: AdminBreakpoints.isPhone(context) ? 130 : 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
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
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '同步详情',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (syncStatus!.details.isEmpty)
              const Center(child: Text('暂无详情数据'))
            else
              _buildDetailsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        dataRowMinHeight: 48,
        dataRowMaxHeight: 72,
        columns: const [
          DataColumn(label: Text('媒体ID')),
          DataColumn(label: Text('文件名')),
          DataColumn(label: Text('MIME 类型')),
          DataColumn(label: Text('存储类状态')),
        ],
        rows: _buildDetailRows(),
      ),
    );
  }

  List<DataRow> _buildDetailRows() {
    final List<DataRow> rows = [];
    for (int i = 0; i < syncStatus!.details.length; i++) {
      final detail = syncStatus!.details[i];
      final storageClassStatus = _getStorageClassStatusText(
        detail.storageClasses,
      );
      final row = DataRow(
        cells: [
          DataCell(Text(detail.mediaId.toString())),
          DataCell(
            SizedBox(
              width: 220,
              child: Text(
                detail.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          DataCell(Text(detail.mimeType)),
          DataCell(Text(storageClassStatus)),
        ],
      );
      rows.add(row);
    }
    return rows;
  }

  String _getStorageClassStatusText(Map<String, dynamic>? storageClasses) {
    if (storageClasses == null) {
      return '未同步';
    }
    final syncedCount = storageClasses.length;
    return '$syncedCount 个存储类';
  }
}
