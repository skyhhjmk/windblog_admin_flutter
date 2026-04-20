part of 'package:windblog_admin_flutter/main.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  int _page = 1;
  final int _pageSize = 20;
  String _entityType = '';
  String _action = '';

  List<AuditLogItem> _logs = [];
  int _total = 0;
  bool _loading = false;

  final _entityTypeCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _entityTypeCtrl.dispose();
    _actionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.listAuditLogs(
        page: _page,
        pageSize: _pageSize,
        entityType: _entityType,
        action: _action,
      );
      setState(() {
        _logs = res.items;
        _total = res.total;
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onSearch() {
    setState(() {
      _entityType = _entityTypeCtrl.text.trim();
      _action = _actionCtrl.text.trim();
      _page = 1;
    });
    _loadData();
  }

  void _showDetail(AuditLogItem item) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('审计日志详细信息'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('日志 ID', '${item.id}'),
                    _buildDetailRow('实体类型 (entityType)', item.entityType),
                    _buildDetailRow('实体 ID (entityId)', '${item.entityId}'),
                    _buildDetailRow('操作 (action)', item.action),
                    _buildDetailRow(
                        '操作人', item.performedByUsername ?? '系统/未知'),
                    _buildDetailRow('时间', item.createdAt?.toString() ?? ''),
                    const Divider(),
                    const Text('变更前 (oldValue):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        const JsonEncoder.withIndent('  ').convert(
                            item.oldValue),
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('变更后 (newValue):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        const JsonEncoder.withIndent('  ').convert(
                            item.newValue),
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
                label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('审计日志',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _entityTypeCtrl,
                  decoration: const InputDecoration(
                    labelText: '实体类型 (如 post)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _actionCtrl,
                  decoration: const InputDecoration(
                    labelText: '操作 (如 ai_summary_generated)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _onSearch,
                icon: const Icon(Icons.search),
                label: const Text('搜索'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: _loading && _logs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: _logs.length,
                    separatorBuilder: (context, index) =>
                    const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _logs[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.history, size: 20),
                        ),
                        title: Text('${item.action} - ${item.entityType} #${item
                            .entityId}'),
                        subtitle: Text(
                          '操作人: ${item.performedByUsername ??
                              '系统'} | 时间: ${item.createdAt}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showDetail(item),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildPagination(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return Row(
      children: [
        Text('每页 $_pageSize 条，共 $_total 条'),
        const Spacer(),
        IconButton(
          onPressed: _page <= 1
              ? null
              : () {
            setState(() => _page--);
            _loadData();
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Text('$_page'),
        IconButton(
          onPressed: _page * _pageSize >= _total
              ? null
              : () {
            setState(() => _page++);
            _loadData();
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
