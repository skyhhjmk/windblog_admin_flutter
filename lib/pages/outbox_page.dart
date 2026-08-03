part of 'package:windblog_admin_flutter/main.dart';

class OutboxPage extends StatefulWidget {
  const OutboxPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<OutboxPage> createState() => _OutboxPageState();
}

class _OutboxPageState extends State<OutboxPage> {
  final int _pageSize = 20;
  final TextEditingController _statusController = TextEditingController();
  final TextEditingController _eventTypeController = TextEditingController();
  final TextEditingController _traceIdController = TextEditingController();

  List<AdminOutboxItem> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _statusController.dispose();
    _eventTypeController.dispose();
    _traceIdController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final result = await widget.api.listAdminOutbox(
        page: _page,
        pageSize: _pageSize,
        status: _statusController.text.trim(),
        eventType: _eventTypeController.text.trim(),
        traceId: _traceIdController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, '加载 Outbox 失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _search() {
    setState(() => _page = 1);
    _loadData();
  }

  Future<void> _replay(AdminOutboxItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认重放 Outbox 事件'),
        content: Text(
          '仅允许重放 FAILED 事件。\n事件：${item.eventType}\nTrace ID：${item.traceId}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认重放'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.api.replayAdminOutbox(item.id);
      if (mounted) AdminFeedback.success(context, '已提交 Outbox 重放');
      await _loadData();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, '重放失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Outbox 审计',
      filters: AdminToolbar(
        children: [
          _filterField(_statusController, '状态', 'FAILED / PENDING'),
          _filterField(_eventTypeController, '事件类型', 'event.type'),
          _filterField(_traceIdController, 'Trace ID', 'trace-id'),
          FilledButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search),
            label: const Text('查询'),
          ),
          OutlinedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新'),
          ),
        ],
      ),
      body: _loading && _items.isEmpty
          ? const AdminStatusView.loading(title: '正在加载 Outbox')
          : _items.isEmpty
          ? const AdminStatusView.empty(title: '暂无 Outbox 事件')
          : Card(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) => _buildItem(_items[index]),
              ),
            ),
      footer: PaginationBar(
        currentPage: _page,
        totalPages: (_total / _pageSize).ceil().clamp(1, 999999),
        totalItems: _total,
        onPageChanged: (page) {
          setState(() => _page = page);
          _loadData();
        },
      ),
    );
  }

  Widget _filterField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return SizedBox(
      width: AdminBreakpoints.isPhone(context) ? double.infinity : 190,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onSubmitted: (_) => _search(),
      ),
    );
  }

  Widget _buildItem(AdminOutboxItem item) {
    final failed = item.status == 'FAILED';
    final statusColor = failed ? Colors.red : Colors.blue;
    final createdAt = item.createdAt?.toLocal().toString() ?? '-';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.12),
        child: Icon(Icons.sync_alt, color: statusColor),
      ),
      title: Text(
        '#${item.id} ${item.eventType}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '状态：${item.status} · 尝试：${item.attemptCount} · Trace：${item.traceId}\n创建：$createdAt'
        '${item.lastError == null || item.lastError!.isEmpty ? '' : '\n错误：${item.lastError}'}',
        maxLines: AdminBreakpoints.isPhone(context) ? 5 : 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: failed
          ? FilledButton.tonal(
              onPressed: () => _replay(item),
              child: const Text('重放'),
            )
          : const Icon(Icons.lock_outline, size: 20),
    );
  }
}
