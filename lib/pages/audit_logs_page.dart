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
          _AuditLogDetailDialog(
            item: item,
            api: widget.api,
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
                    physics: const BouncingScrollPhysics(),
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
        Text(t(context, 'page_of').replaceFirst('%d', '$_page').replaceFirst(
            '%d', '${(_total / _pageSize).ceil()}')),
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

class _AuditLogDetailDialog extends StatefulWidget {
  final AuditLogItem item;
  final AdminApiClient api;

  const _AuditLogDetailDialog({required this.item, required this.api});

  @override
  State<_AuditLogDetailDialog> createState() => _AuditLogDetailDialogState();
}

class _AuditLogDetailDialogState extends State<_AuditLogDetailDialog> {
  SystemSetting? _currentSetting;
  bool _loadingCurrent = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.entityType == 'system_setting') {
      _loadCurrentSetting();
    }
  }

  Future<void> _loadCurrentSetting() async {
    final key = widget.item.newValue['key'] ?? widget.item.oldValue['key'];
    if (key == null) return;

    setState(() => _loadingCurrent = true);
    try {
      final setting = await widget.api.getSystemSetting(key.toString());
      if (mounted) setState(() => _currentSetting = setting);
    } catch (e) {
      debugPrint('Failed to load current setting: $e');
    } finally {
      if (mounted) setState(() => _loadingCurrent = false);
    }
  }

  Future<void> _applyValue(dynamic value, String label) async {
    final key = widget.item.newValue['key'] ?? widget.item.oldValue['key'];
    if (key == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(t(context, 'confirm_action')),
            content: Text('确定要将配置回滚/应用到 $label 吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: Text(t(context, 'cancel'))),
              FilledButton(onPressed: () => Navigator.pop(context, true),
                  child: Text(t(context, 'confirm'))),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _applying = true);
    try {
      // value should be the full configValue Map/dynamic
      final configValue = (value is Map && value.containsKey('value'))
          ? value['value']
          : value;
      await widget.api.applyAuditSettingValue(key.toString(), configValue);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已应用并进入验证期'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('应用失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSetting = item.entityType == 'system_setting';

    return AlertDialog(
      title: Text(t(context, 'audit_log_details')),
      content: SizedBox(
        width: 800,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(t(context, 'log_id'), '${item.id}'),
              _buildDetailRow(t(context, 'entity_type'), item.entityType),
              _buildDetailRow(t(context, 'entity_id'), '${item.entityId}'),
              _buildDetailRow(t(context, 'action'), item.action),
              _buildDetailRow(t(context, 'operator'),
                  item.performedByUsername ?? t(context, 'system_unknown')),
              _buildDetailRow(t(context, 'time'),
                  item.createdAtFormatted ?? item.createdAt?.toString() ?? ''),
              const Divider(height: 32),

              if (isSetting) ...[
                _buildCurrentValueSection(),
                const SizedBox(height: 24),
              ],

              Text('${t(context, 'diff_view')}:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DiffViewer(
                oldText: const JsonEncoder.withIndent('  ').convert(
                    item.oldValue),
                newText: const JsonEncoder.withIndent('  ').convert(
                    item.newValue),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${t(context, 'old_value')}:',
                            style: const TextStyle(fontWeight: FontWeight
                                .bold)),
                        const SizedBox(height: 8),
                        _buildJsonBox(item.oldValue),
                        if (isSetting && item.oldValue.containsKey('value'))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton.icon(
                              onPressed: _applying ? null : () =>
                                  _applyValue(
                                      item.oldValue, t(context, 'old_value')),
                              icon: const Icon(Icons.history, size: 16),
                              label: const Text('回滚到此版本'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${t(context, 'new_value')}:',
                            style: const TextStyle(fontWeight: FontWeight
                                .bold)),
                        const SizedBox(height: 8),
                        _buildJsonBox(item.newValue),
                        if (isSetting && item.newValue.containsKey('value'))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton.icon(
                              onPressed: _applying ? null : () =>
                                  _applyValue(
                                      item.newValue, t(context, 'new_value')),
                              icon: const Icon(Icons.restore, size: 16),
                              label: const Text('重新应用此版本'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_applying)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t(context, 'close')),
        ),
      ],
    );
  }

  Widget _buildCurrentValueSection() {
    if (_loadingCurrent) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_currentSetting == null) {
      return const Text('无法加载当前值');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${t(context, 'current_value')}:', style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(width: 8),
            if (_currentSetting!.isFrozen)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange,
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('验证锁定中',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            const Spacer(),
            Text('Version: ${_currentSetting!.version}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        _buildJsonBox(_currentSetting!.configValue, color: Colors.blue.shade50),
      ],
    );
  }

  Widget _buildJsonBox(dynamic data, {Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: color != null ? Border.all(color: Colors.blue.shade200) : null,
      ),
      child: Text(
        const JsonEncoder.withIndent('  ').convert(data),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
}
