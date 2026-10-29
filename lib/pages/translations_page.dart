part of 'package:windblog_admin_flutter/main.dart';

class TranslationsPage extends StatefulWidget {
  const TranslationsPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<TranslationsPage> createState() => _TranslationsPageState();
}

class _TranslationsPageState extends State<TranslationsPage> {
  static const int _pageSize = 20;
  static const List<(String, String)> _languages = [
    ('en-US', '英语'),
    ('zh-cn', '简体中文'),
  ];

  final TextEditingController _keywordCtrl = TextEditingController();
  final Set<int> _selected = {};
  final Set<int> _busy = {};

  List<TranslationItem> _items = [];
  int _page = 1;
  int _total = 0;
  String _targetLanguage = 'en-US';
  String _translationStatus = 'missing';
  int? _postStatus;
  bool _loading = true;
  bool _batchRunning = false;
  String? _activeBatchId;
  TranslationBatchStatus? _batchStatus;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _keywordCtrl.dispose();
    super.dispose();
  }

  bool get _queueActive => _batchStatus?.active == true;

  String get _targetLabel => _languages
      .firstWhere(
        (entry) => entry.$1.toLowerCase() == _targetLanguage.toLowerCase(),
        orElse: () => (_targetLanguage, _targetLanguage),
      )
      .$2;

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final result = await widget.api.listTranslations(
        page: _page,
        pageSize: _pageSize,
        targetLanguage: _targetLanguage,
        translationStatus: _translationStatus == 'all'
            ? null
            : _translationStatus,
        keyword: _keywordCtrl.text,
        status: _postStatus,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _page = result.page;
        _selected.removeWhere((id) => !_items.any((item) => item.id == id));
        _loading = false;
      });
    } on UnauthorizedException {
      widget.onAuthError();
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AdminFeedback.error(context, '读取译本状态失败：$error');
    }
  }

  void _applyFilter() {
    _page = 1;
    _selected.clear();
    _load();
  }

  void _changeTarget(String? language) {
    if (language == null || language == _targetLanguage) return;
    setState(() {
      _targetLanguage = language;
      _selected.clear();
      _page = 1;
    });
    _load();
  }

  void _changeTranslationStatus(String? status) {
    if (status == null || status == _translationStatus) return;
    setState(() {
      _translationStatus = status;
      _selected.clear();
      _page = 1;
    });
    _load();
  }

  void _changePostStatus(int? status) {
    if (status == _postStatus) return;
    setState(() {
      _postStatus = status;
      _selected.clear();
      _page = 1;
    });
    _load();
  }

  void _toggleSelected(TranslationItem item, bool value) {
    setState(() {
      if (value) {
        _selected.add(item.id);
      } else {
        _selected.remove(item.id);
      }
    });
  }

  Future<void> _translateOne(
    TranslationItem item, {
    bool overwrite = false,
  }) async {
    if (_queueActive) return;
    await _submitTasks([item.id], overwrite: overwrite);
  }

  Future<void> _batchTranslate() async {
    if (_selected.isEmpty || _batchRunning || _queueActive) return;
    bool overwrite = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('批量翻译为$_targetLabel'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '将提交 ${_selected.length} 篇文章到后台翻译队列，'
                  '由 AI 提供商（支持轮询组）逐篇执行。你可以关闭页面后稍后回来查看进度。',
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('覆盖已有译本'),
                  subtitle: const Text('重新翻译并生成新修订；已发布文章会同步更新公开版本。'),
                  value: overwrite,
                  onChanged: (value) => setDialogState(() => overwrite = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('提交任务'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _submitTasks(_selected.toList(), overwrite: overwrite);
  }

  Future<void> _submitTasks(List<int> postIds, {bool overwrite = false}) async {
    if (postIds.isEmpty || _batchRunning) return;
    setState(() => _batchRunning = true);
    try {
      final status = await widget.api.submitTranslationTasks(
        postIds,
        targetLanguage: _targetLanguage,
        overwrite: overwrite,
      );
      if (!mounted) return;
      setState(() {
        _activeBatchId = status.batchId;
        _batchStatus = status;
        _selected.clear();
        _batchRunning = false;
      });
      AdminFeedback.info(context, '已提交 ${status.total} 个翻译任务，后台排队执行');
      _startPolling();
    } on UnauthorizedException {
      widget.onAuthError();
      if (mounted) setState(() => _batchRunning = false);
    } catch (error) {
      if (mounted) {
        setState(() => _batchRunning = false);
        AdminFeedback.error(context, '提交翻译任务失败：$error');
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_pollTasks()),
    );
    unawaited(_pollTasks());
  }

  Future<void> _pollTasks() async {
    final batchId = _activeBatchId;
    if (batchId == null) return;
    try {
      final status = await widget.api.translationTaskBatch(batchId);
      if (!mounted) return;
      setState(() => _batchStatus = status);
      if (!status.active) {
        _pollTimer?.cancel();
        _pollTimer = null;
        await _load();
        if (!mounted) return;
        final failureText = status.failed > 0 ? '，失败 ${status.failed} 篇' : '';
        AdminFeedback.success(
          context,
          '翻译队列已完成：成功 ${status.succeeded} 篇，'
          '跳过 ${status.skipped} 篇$failureText',
        );
        if (status.failed > 0) {
          await _showTaskErrors(status);
        }
      }
    } on UnauthorizedException {
      _pollTimer?.cancel();
      _pollTimer = null;
      widget.onAuthError();
    } catch (error) {
      _pollTimer?.cancel();
      _pollTimer = null;
      if (mounted) AdminFeedback.error(context, '读取翻译任务进度失败：$error');
    }
  }

  Future<void> _showTaskErrors(TranslationBatchStatus status) async {
    final failures = status.tasks
        .where((task) => task.status == 'FAILED')
        .toList();
    if (failures.isEmpty || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('部分文章翻译失败'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: failures
                  .map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '文章 #${task.postId}：'
                        '${task.message?.isNotEmpty == true ? task.message : '未知错误'}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _publishTranslation(TranslationItem item) async {
    setState(() => _busy.add(item.id));
    try {
      await widget.api.publishLatestDraftPost(item.id);
      if (!mounted) return;
      AdminFeedback.success(context, '已发布 $_targetLabel 译本');
      await _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, '发布失败：$error');
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  Future<void> _openEditor(TranslationItem item) async {
    try {
      final detail = await widget.api.postDetail(item.id);
      if (!mounted) return;
      final notifications = AdminNotificationScope.maybeOf(context);
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) {
            final editor = PostEditorPage(detail: detail, api: widget.api);
            if (notifications == null) return editor;
            return AdminNotificationHost(
              api: widget.api,
              controller: notifications,
              child: editor,
            );
          },
        ),
      );
      await _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, '打开文章失败：$error');
    }
  }

  String _languageLabel(String language) {
    final normalized = language.toLowerCase();
    for (final entry in _languages) {
      if (entry.$1.toLowerCase() == normalized) return entry.$2;
    }
    return language;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _statusChip(TranslationItem item) {
    final translated = item.translated;
    final pendingPublish = translated && !item.currentRevisionPublished;
    final color = pendingPublish
        ? Colors.blue
        : (translated ? Colors.green : Colors.orange);
    final label = pendingPublish ? '待发布' : (translated ? '已翻译' : '待翻译');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _languageChips(TranslationItem item) {
    if (item.languages.isEmpty) {
      return Text(
        '无可用语言',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: item.languages.map((language) {
        final isTarget =
            language.toLowerCase() == _targetLanguage.toLowerCase();
        final color = isTarget ? Colors.blue : Colors.grey;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _languageLabel(language),
            style: TextStyle(
              color: color.shade700,
              fontSize: 11,
              fontWeight: isTarget ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _taskStatusLabel(TranslationTaskItem task) {
    return switch (task.status) {
      'QUEUED' => '排队中',
      'RUNNING' => '翻译中',
      'SUCCEEDED' => '已完成',
      'SKIPPED' => '已跳过',
      'FAILED' => '失败',
      'CANCELED' => '已取消',
      _ => task.status,
    };
  }

  Widget _taskStatusBadge(TranslationTaskItem task) {
    final color = switch (task.status) {
      'QUEUED' => Colors.orange,
      'RUNNING' => Colors.blue,
      'SUCCEEDED' => Colors.green,
      'SKIPPED' => Colors.blueGrey,
      'FAILED' => Colors.red,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _taskStatusLabel(task),
        style: TextStyle(
          color: color.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _rowActions(TranslationItem item, {bool compact = false}) {
    final busy = _busy.contains(item.id);
    if (busy) {
      return const SizedBox(
        width: 96,
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    final task = _batchStatus?.taskForPost(item.id);
    if (task != null && task.isActive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          _taskStatusBadge(task),
        ],
      );
    }
    if (task != null && task.status == 'FAILED') {
      return TextButton.icon(
        onPressed: _queueActive
            ? null
            : () => _translateOne(item, overwrite: task.overwrite),
        icon: const Icon(Icons.refresh, size: 17),
        label: const Text('重试'),
      );
    }
    if (item.translated) {
      return PopupMenuButton<String>(
        tooltip: '更多操作',
        onSelected: (value) {
          if (value == 'open') _openEditor(item);
          if (value == 'publish') _publishTranslation(item);
          if (value == 'retranslate') _translateOne(item, overwrite: true);
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'open', child: Text('编辑文章')),
          if (!item.currentRevisionPublished)
            const PopupMenuItem(value: 'publish', child: Text('发布最新草稿')),
          PopupMenuItem(
            value: 'retranslate',
            child: Text('重新翻译为$_targetLabel'),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 17,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 4),
              const Text('已完成', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }
    return TextButton.icon(
      onPressed: _queueActive ? null : () => _translateOne(item),
      icon: const Icon(Icons.translate, size: 17),
      label: Text(compact ? '翻译' : '译为$_targetLabel'),
    );
  }

  Widget _buildMobileCard(TranslationItem item) {
    final selected = _selected.contains(item.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => _toggleSelected(item, value == true),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(item),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _languageChips(item),
                  if (_batchStatus?.taskForPost(item.id) != null) ...[
                    const SizedBox(height: 4),
                    _taskStatusBadge(_batchStatus!.taskForPost(item.id)!),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '更新 ${_formatDate(item.updatedAt)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (!item.hasPublishedRevision)
                        Text(
                          '草稿',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      const Spacer(),
                      _rowActions(item, compact: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRow(TranslationItem item) {
    final selected = _selected.contains(item.id);
    return InkWell(
      onTap: () => _openEditor(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => _toggleSelected(item, value == true),
            ),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.slug,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _languageChips(item)),
            const SizedBox(width: 12),
            SizedBox(
              width: 88,
              child: Text(
                _formatDate(item.updatedAt),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 78, child: _statusChip(item)),
            const SizedBox(width: 8),
            SizedBox(
              width: 140,
              child: Align(
                alignment: Alignment.centerRight,
                child: _rowActions(item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(60, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 5,
            child: Text('文章', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            flex: 3,
            child: Text('已有语言', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          const SizedBox(
            width: 88,
            child: Text('更新时间', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          const SizedBox(
            width: 78,
            child: Text('状态', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 140,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('操作', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList({required bool mobile}) {
    if (_items.isEmpty) {
      return AdminStatusView.empty(
        title: '没有符合条件的文章',
        message: _translationStatus == 'missing'
            ? '当前筛选下所有文章都已有$_targetLabel译本。'
            : null,
      );
    }
    if (mobile) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: _items.map(_buildMobileCard).toList(),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: _items.length + 1,
        separatorBuilder: (_, index) =>
            index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
        itemBuilder: (_, index) {
          if (index == 0) return _desktopHeader();
          return _buildDesktopRow(_items[index - 1]);
        },
      ),
    );
  }

  Widget _pagination() {
    final totalPages = (_total / _pageSize).ceil().clamp(1, 999999);
    return PaginationBar(
      currentPage: _page,
      totalPages: totalPages,
      totalItems: _total,
      onPageChanged: (page) {
        if (page == _page) return;
        setState(() => _page = page);
        _load();
      },
    );
  }

  Widget? _taskBanner() {
    final status = _batchStatus;
    if (status == null || status.total == 0) return null;
    final progress = status.finished / status.total;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: status.active
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.25)
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.active
                        ? '后台翻译队列执行中：完成 ${status.finished}/${status.total}'
                        : '翻译队列已完成：成功 ${status.succeeded}，跳过 ${status.skipped}，失败 ${status.failed}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '排队 ${status.queued} · 执行中 ${status.running} · 已完成 ${status.succeeded} · 跳过 ${status.skipped} · 失败 ${status.failed}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  if (status.active) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: progress),
                  ],
                ],
              ),
            ),
            if (status.failed > 0)
              TextButton(
                onPressed: () => _showTaskErrors(status),
                child: const Text('失败原因'),
              ),
            if (!status.active)
              IconButton(
                tooltip: '关闭队列状态',
                onPressed: () => setState(() {
                  _batchStatus = null;
                  _activeBatchId = null;
                }),
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _selectionSummary() {
    return Text(
      '共 $_total 篇 · 已选 ${_selected.length} 篇 · 目标语言 $_targetLabel',
      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
    );
  }

  Widget _batchButton() {
    final enabled = _selected.isNotEmpty && !_batchRunning && !_queueActive;
    return FilledButton.icon(
      onPressed: enabled ? _batchTranslate : null,
      icon: _batchRunning
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.translate, size: 18),
      label: Text(_selected.isEmpty ? '批量翻译' : '翻译所选 (${_selected.length})'),
    );
  }

  List<Widget> _filterWidgets(bool mobile) {
    final search = SizedBox(
      width: mobile ? double.infinity : 240,
      child: TextField(
        controller: _keywordCtrl,
        decoration: const InputDecoration(
          hintText: '搜索标题或 slug',
          prefixIcon: Icon(Icons.search),
          isDense: true,
        ),
        onSubmitted: (_) => _applyFilter(),
      ),
    );
    final language = SizedBox(
      width: mobile ? double.infinity : 150,
      child: DropdownButtonFormField<String>(
        key: ValueKey<String>('target-$_targetLanguage'),
        initialValue: _targetLanguage,
        isExpanded: true,
        decoration: const InputDecoration(labelText: '目标语言', isDense: true),
        items: _languages
            .map(
              (entry) => DropdownMenuItem(
                value: entry.$1,
                child: Text('${entry.$2} (${entry.$1})'),
              ),
            )
            .toList(),
        onChanged: _changeTarget,
      ),
    );
    final translationStatus = SizedBox(
      width: mobile ? double.infinity : 150,
      child: DropdownButtonFormField<String>(
        initialValue: _translationStatus,
        isExpanded: true,
        decoration: const InputDecoration(labelText: '翻译状态', isDense: true),
        items: const [
          DropdownMenuItem(value: 'missing', child: Text('待翻译')),
          DropdownMenuItem(value: 'translated', child: Text('已翻译')),
          DropdownMenuItem(value: 'all', child: Text('全部')),
        ],
        onChanged: _changeTranslationStatus,
      ),
    );
    final postStatus = SizedBox(
      width: mobile ? double.infinity : 140,
      child: DropdownButtonFormField<int>(
        initialValue: _postStatus,
        isExpanded: true,
        decoration: const InputDecoration(labelText: '文章状态', isDense: true),
        items: const [
          DropdownMenuItem(value: null, child: Text('全部')),
          DropdownMenuItem(value: 1, child: Text('已发布')),
          DropdownMenuItem(value: 0, child: Text('草稿')),
          DropdownMenuItem(value: 2, child: Text('已归档')),
        ],
        onChanged: _changePostStatus,
      ),
    );
    return [
      search,
      language,
      translationStatus,
      postStatus,
      FilledButton.icon(
        onPressed: _applyFilter,
        icon: const Icon(Icons.search, size: 18),
        label: const Text('搜索'),
      ),
      OutlinedButton.icon(
        onPressed: _batchRunning ? null : _load,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('刷新'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final mobile = AdminBreakpoints.isPhone(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(child: _selectionSummary()),
              if (constraints.maxWidth > 520) _batchButton(),
            ],
          ),
        ),
        if (mobile) ...[
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: _batchButton()),
        ],
        if (_taskBanner() != null) ...[
          const SizedBox(height: 8),
          _taskBanner()!,
        ],
        const SizedBox(height: 8),
        Expanded(
          child: _loading && _items.isEmpty
              ? const AdminStatusView.loading(title: '正在读取译本状态')
              : _buildList(mobile: mobile),
        ),
      ],
    );

    if (mobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        bottomNavigationBar: _pagination(),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _filterWidgets(true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return AdminPageScaffold(
      title: '翻译管理',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: _batchRunning ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
        _batchButton(),
      ],
      filters: AdminToolbar(children: _filterWidgets(false)),
      footer: _pagination(),
      body: body,
    );
  }
}
