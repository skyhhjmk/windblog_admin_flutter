part of 'package:windblog_admin_flutter/main.dart';

class _OutboxTabFilter {
  const _OutboxTabFilter(this.label, this.status);

  final String label;
  final String status;
}

class OutboxPage extends StatefulWidget {
  const OutboxPage({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<OutboxPage> createState() => _OutboxPageState();
}

class _OutboxPageState extends State<OutboxPage>
    with SingleTickerProviderStateMixin {
  static const List<_OutboxTabFilter> _tabFilters = [
    _OutboxTabFilter('全部', ''),
    _OutboxTabFilter('待处理', 'PENDING'),
    _OutboxTabFilter('处理中', 'IN_FLIGHT'),
    _OutboxTabFilter('失败', 'FAILED'),
    _OutboxTabFilter('已发布', 'PUBLISHED'),
  ];

  late final TabController _tabController;
  final TextEditingController _eventTypeController = TextEditingController();
  final TextEditingController _traceIdController = TextEditingController();

  List<AdminOutboxItem> _items = [];
  int _page = 1;
  int _pageSize = 20;
  int _total = 0;
  int _activeTabIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabFilters.length, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _eventTypeController.dispose();
    _traceIdController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final result = await widget.api.listAdminOutbox(
        page: _page,
        pageSize: _pageSize,
        status: _tabFilters[_activeTabIndex].status,
        eventType: _eventTypeController.text.trim(),
        traceId: _traceIdController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _page = result.page;
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

  void _selectTab(int index) {
    if (index == _activeTabIndex) {
      return;
    }
    setState(() {
      _activeTabIndex = index;
      _page = 1;
    });
    _loadData();
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) {
      return;
    }
    setState(() {
      _pageSize = value;
      _page = 1;
    });
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
          _filterField(_eventTypeController, '事件类型', 'event.type'),
          _filterField(_traceIdController, 'Trace ID', 'trace-id'),
          SizedBox(
            width: AdminBreakpoints.isPhone(context) ? double.infinity : 130,
            child: DropdownButtonFormField<int>(
              initialValue: _pageSize,
              decoration: const InputDecoration(labelText: '每页条数'),
              items: const [20, 50, 100]
                  .map(
                    (size) => DropdownMenuItem<int>(
                      value: size,
                      child: Text('$size'),
                    ),
                  )
                  .toList(),
              onChanged: _changePageSize,
            ),
          ),
          FilledButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search),
            label: AdminShortcutText(
              '查询',
              AdminShortcutDefinitions.keyByAction['search']!,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              onTap: _selectTab,
              tabs: _tabFilters
                  .map((filter) => Tab(text: filter.label))
                  .toList(),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
          Expanded(child: _buildListBody()),
        ],
      ),
      footer: PaginationBar(
        currentPage: _page,
        totalPages: (_total / _pageSize).ceil().clamp(1, 999999),
        totalItems: _total,
        pageSize: _pageSize,
        onPageChanged: (page) {
          setState(() => _page = page);
          _loadData();
        },
      ),
    );
  }

  Widget _buildListBody() {
    if (_loading && _items.isEmpty) {
      return const AdminStatusView.loading(title: '正在加载 Outbox');
    }
    if (_items.isEmpty) {
      return const AdminStatusView.empty(title: '暂无 Outbox 事件');
    }
    return Card(
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) => _buildItem(_items[index]),
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
      child: AdminShortcutSearchField(
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
