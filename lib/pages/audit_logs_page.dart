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
  bool _loading = true;

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
          SnackBar(content: Text('${t(context, 'load_failed')}$e')),
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
            title: Text(t(context, 'audit_log_details')),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(t(context, 'log_id'), '${item.id}'),
                    _buildDetailRow(t(context, 'entity_type'), item.entityType),
                    _buildDetailRow(t(context, 'entity_id'), '${item.entityId}'),
                    _buildDetailRow(t(context, 'action'), item.action),
                    _buildDetailRow(
                        t(context, 'operator'), item.performedByUsername ?? t(context, 'system_unknown')),
                    _buildDetailRow(t(context, 'time'),
                        item.createdAtFormatted ?? item.createdAt?.toString() ??
                            ''),
                    if (item.durationMs != null)
                      _buildDetailRow(t(context, 'duration'), '${item.durationMs} ${t(context, 'milliseconds')}'),
                    if (item.inputTokens != null)
                      _buildDetailRow(t(context, 'input_tokens'), '${item.inputTokens}'),
                    if (item.outputTokens != null)
                      _buildDetailRow(t(context, 'output_tokens'), '${item.outputTokens}'),
                    if (item.totalTokens != null)
                      _buildDetailRow(t(context, 'total_tokens'), '${item.totalTokens}'),
                    const Divider(),
                    Text('${t(context, 'old_value')}:',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    Text('${t(context, 'new_value')}:',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
                child: Text(t(context, 'close')),
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
              Text(t(context, 'audit_logs'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _entityTypeCtrl,
                  decoration: InputDecoration(
                    labelText: t(context, 'entity_type_hint'),
                    border: const OutlineInputBorder(),
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
                  decoration: InputDecoration(
                    labelText: t(context, 'action_hint'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _onSearch,
                icon: const Icon(Icons.search),
                label: Text(t(context, 'search')),
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
                          '${t(context, 'operator')}: ${item.performedByUsername ??
                              t(context, 'system_unknown')} | ${t(context, 'time')}: ${item.createdAtFormatted ??
                              item.createdAt}',
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
        Text(t(context, 'page_of').replaceAll('%d', '$_pageSize').replaceFirst('%d', '$_total')),
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
