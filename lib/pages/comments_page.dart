part of 'package:windblog_admin_flutter/main.dart';

class CommentsPage extends StatefulWidget {
  const CommentsPage({
    super.key,
    required this.api,
    required this.onAuthError,
    this.postId,
    this.postTitle,
  });

  final int? postId;
  final String? postTitle;
  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  List<CommentItem> comments = [];
  bool loading = true;
  int currentPage = 1;
  int totalPages = 1;
  int totalItems = 0;
  String? statusFilter;
  String? auditStatusFilter;
  String keyword = '';

  final Set<int> _selected = {};
  final Set<int> _abortingIds = {};
  bool _bulkRunning = false;
  Timer? _pollTimer;
  bool _pollingInFlight = false;

  final pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _syncPolling() {
    final hasReviewing = comments.any((c) => c.canAbortAudit);
    if (hasReviewing && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && !_pollingInFlight && !_bulkRunning) {
          _loadComments(silent: true);
        }
      });
    } else if (!hasReviewing && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _loadComments({bool silent = false}) async {
    if (silent) {
      _pollingInFlight = true;
    } else {
      setState(() => loading = true);
    }
    try {
      final result = await widget.api.listComments(
        postId: widget.postId,
        page: currentPage,
        pageSize: pageSize,
        status: statusFilter,
        auditStatus: auditStatusFilter,
        keyword: keyword.isEmpty ? null : keyword,
      );
      if (!mounted) return;
      setState(() {
        comments = result.items;
        totalItems = result.total;
        totalPages = (result.total / pageSize).ceil();
        if (totalPages < 1) totalPages = 1;
        final visibleIds = comments.map((e) => e.id).toSet();
        _selected.removeWhere((id) => !visibleIds.contains(id));
      });
      _syncPolling();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted && !silent) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('${t(context, 'load_failed')}: $e')),
        );
      }
    } finally {
      _pollingInFlight = false;
      if (mounted && !silent) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _updateCommentStatus(CommentItem comment, int newStatus) async {
    try {
      await widget.api.updateComment(comment.id, status: newStatus);
      await _loadComments();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text('${t(context, 'save_failed')}$e')),
      );
    }
  }

  CommentItem _copyComment(
    CommentItem comment, {
    bool? isReviewing,
    AiAuditState? aiAuditState,
  }) {
    return CommentItem(
      id: comment.id,
      postId: comment.postId,
      postTitle: comment.postTitle,
      userId: comment.userId,
      userName: comment.userName,
      guestEmail: comment.guestEmail,
      content: comment.content,
      status: comment.status,
      auditStatus: isReviewing == true ? 1 : comment.auditStatus,
      aiReviewData: comment.aiReviewData,
      isReviewing: isReviewing ?? comment.isReviewing,
      aiAuditState: aiAuditState ?? comment.aiAuditState,
      createdAt: comment.createdAt,
      quoteId: comment.quoteId,
      quoteType: comment.quoteType,
      quoteText: comment.quoteText,
      quoteAnchorData: comment.quoteAnchorData,
      quoteStatus: comment.quoteStatus,
    );
  }

  void _replaceComment(CommentItem updated) {
    if (!mounted) return;
    setState(() {
      final index = comments.indexWhere((item) => item.id == updated.id);
      if (index >= 0) comments[index] = updated;
    });
    _syncPolling();
  }

  Future<CommentItem?> _auditComment(CommentItem comment) async {
    final previous = comments.firstWhere(
      (item) => item.id == comment.id,
      orElse: () => comment,
    );
    _replaceComment(
      _copyComment(
        comment,
        isReviewing: true,
        aiAuditState: AiAuditState(
          phase: 'OUTBOX_PENDING',
          label: '等待 Outbox 调度',
          detail: '正在提交 AI 审核任务...',
          stuck: false,
          canAbort: true,
        ),
      ),
    );
    try {
      final updated = await widget.api.auditComment(comment.id);
      _replaceComment(updated);
      return updated;
    } on UnauthorizedException {
      widget.onAuthError();
      _replaceComment(previous);
    } catch (e) {
      _replaceComment(previous);
      await _loadComments();
      if (!mounted) return null;
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text('${t(context, 'save_failed')}$e')),
      );
    }
    return null;
  }

  Future<CommentItem?> _abortCommentAudit(
    CommentItem comment, {
    bool confirm = true,
  }) async {
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('强制中断 AI 审核'),
          content: Text(
            '确定要强制中断评论 #${comment.id} 的 AI 审核吗？\n'
            '将取消排队中的 Outbox 任务、尝试中断当前执行线程，并立即解锁评论操作。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t(context, 'cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('强制中断'),
            ),
          ],
        ),
      );
      if (ok != true) return null;
    }

    if (mounted) {
      setState(() => _abortingIds.add(comment.id));
    }
    try {
      final updated = await widget.api.abortCommentAudit(comment.id);
      _replaceComment(updated);
      if (mounted) {
        AdminFeedback.success(context, '已强制中断评论 #${comment.id} 的 AI 审核');
      }
      return updated;
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.error(context, '强制中断失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _abortingIds.remove(comment.id));
      }
    }
    return null;
  }

  Future<void> _deleteComment(CommentItem comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'confirm_delete')),
        content: Text(t(context, 'confirm_delete_comment')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t(context, 'delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.api.deleteComment(comment.id);
      _selected.remove(comment.id);
      await _loadComments();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text('${t(context, 'delete_failed')}$e')),
      );
    }
  }

  void _toggleSelect(int id, bool? selected) {
    setState(() {
      if (selected == true) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selected.addAll(comments.map((e) => e.id));
      } else {
        _selected.clear();
      }
    });
  }

  Future<void> _runBatchAction({
    required String action,
    required String title,
    required String confirmMessage,
    bool destructive = false,
  }) async {
    if (_selected.isEmpty || _bulkRunning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(t(context, 'confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _bulkRunning = true);
    try {
      final result = await widget.api.batchComments(
        ids: _selected.toList(),
        action: action,
      );
      if (mounted) {
        AdminFeedback.success(
          context,
          result.message.isNotEmpty
              ? result.message
              : '已完成：成功 ${result.succeeded} 条',
        );
      }
      _selected.clear();
      await _loadComments();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.error(context, '批量操作失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _bulkRunning = false);
      }
    }
  }

  void _onFilterChanged(String? status) {
    setState(() {
      statusFilter = status;
      currentPage = 1;
      _selected.clear();
    });
    _loadComments();
  }

  void _onAuditFilterChanged(String? auditStatus) {
    setState(() {
      auditStatusFilter = auditStatus;
      currentPage = 1;
      _selected.clear();
    });
    _loadComments();
  }

  void _onSearch(String value) {
    setState(() {
      keyword = value;
      currentPage = 1;
      _selected.clear();
    });
    _loadComments();
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.green;
      case 2:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getAuditStateColor(AiAuditState? state, CommentItem comment) {
    if (state == null) return Colors.indigo;
    if (state.stuck) return Colors.deepOrange;
    switch (state.phase) {
      case 'EXECUTING':
      case 'OUTBOX_IN_FLIGHT':
      case 'OUTBOX_PENDING':
      case 'MQ_QUEUED':
        return Colors.indigo;
      case 'OUTBOX_RETRYING':
      case 'STUCK':
      case 'ABORTING':
        return Colors.deepOrange;
      case 'ABORTED':
        return Colors.amber.shade800;
      case 'FAILED':
        return Colors.red;
      case 'COMPLETED':
        final isSafe = comment.aiReviewData?['isSafe'];
        return isSafe == true ? Colors.teal : Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _formatElapsed(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final rem = seconds % 60;
    if (minutes < 60) return '${minutes}m ${rem}s';
    final hours = minutes ~/ 60;
    return '${hours}h ${minutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final reviewingCount = comments.where((c) => c.canAbortAudit).length;
    final selectedAbortableCount = comments
        .where((c) => _selected.contains(c.id) && c.canAbortAudit)
        .length;

    return AdminPageScaffold(
      title: widget.postId == null
          ? t(context, 'comments')
          : '${t(context, 'comments')} · ${widget.postTitle ?? '#${widget.postId}'}',
      filters: AdminToolbar(
        children: [
          SizedBox(
            width: AdminBreakpoints.isPhone(context) ? double.infinity : 160,
            child: DropdownButtonFormField<String?>(
              initialValue: statusFilter,
              decoration: InputDecoration(
                labelText: t(context, 'status_filter'),
                prefixIcon: const Icon(Icons.filter_list),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    t(context, 'all_status'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                DropdownMenuItem(
                  value: '0',
                  child: Text(
                    t(context, 'comment_pending'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Text(
                    t(context, 'comment_approved'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                DropdownMenuItem(
                  value: '2',
                  child: Text(
                    t(context, 'comment_rejected'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
              onChanged: _onFilterChanged,
              isExpanded: true,
            ),
          ),
          SizedBox(
            width: AdminBreakpoints.isPhone(context) ? double.infinity : 165,
            child: DropdownButtonFormField<String?>(
              initialValue: auditStatusFilter,
              decoration: const InputDecoration(
                labelText: 'AI 审核状态',
                prefixIcon: Icon(Icons.smart_toy_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: null,
                  child: Text('全部 AI 状态', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Text('审核中', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: '4',
                  child: Text('失败 / 已中断', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: '0',
                  child: Text('未审核 / 待人工', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: '2',
                  child: Text('审核通过', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: '3',
                  child: Text('审核拒绝', style: TextStyle(fontSize: 13)),
                ),
              ],
              onChanged: _onAuditFilterChanged,
              isExpanded: true,
            ),
          ),
          SizedBox(
            width: AdminBreakpoints.isPhone(context) ? double.infinity : 260,
            child: AdminShortcutSearchField(
              decoration: InputDecoration(
                labelText: t(context, 'search_comments'),
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: _onSearch,
            ),
          ),
          FilledButton.icon(
            onPressed: loading ? null : () => _loadComments(),
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(t(context, 'refresh')),
          ),
        ],
      ),
      body: loading
          ? AdminStatusView.loading(
              title: t(context, 'loading_comments', fallback: '正在加载评论'),
            )
          : comments.isEmpty
          ? AdminStatusView.empty(title: t(context, 'no_comments'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSelectionAndBatchBar(
                  reviewingCount: reviewingCount,
                  selectedAbortableCount: selectedAbortableCount,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Card(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: comments.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final isSelected = _selected.contains(comment.id);
                        final isAborting = _abortingIds.contains(comment.id);
                        return _CommentTile(
                          comment: comment,
                          selected: isSelected,
                          onSelectChanged: _bulkRunning
                              ? null
                              : (val) => _toggleSelect(comment.id, val),
                          statusColor: _getStatusColor(comment.status),
                          auditStateColor: _getAuditStateColor(
                            comment.aiAuditState,
                            comment,
                          ),
                          dateText: _formatDate(comment.createdAt),
                          formatElapsed: _formatElapsed,
                          isAborting: isAborting,
                          onAbortAudit: comment.canAbortAudit
                              ? () => _abortCommentAudit(comment)
                              : null,
                          onOpenDetails: () => _showCommentDetails(comment),
                          t: (key, {fallback}) =>
                              t(context, key, fallback: fallback),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      footer: _buildPagination(),
    );
  }

  Widget _buildSelectionAndBatchBar({
    required int reviewingCount,
    required int selectedAbortableCount,
  }) {
    final allSelected =
        comments.isNotEmpty && _selected.length == comments.length;
    final checkboxValue = _selected.isEmpty
        ? false
        : (allSelected ? true : null);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  tristate: true,
                  value: checkboxValue,
                  onChanged: _bulkRunning ? null : _toggleSelectAll,
                ),
                Text(
                  _selected.isEmpty
                      ? '全选本页 (${comments.length})'
                      : '已选 ${_selected.length} 条',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (reviewingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '本页 $reviewingCount 条 AI 审核中（每 5 秒自动刷新）',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                onPressed: _bulkRunning
                    ? null
                    : () => _runBatchAction(
                        action: 'APPROVE',
                        title: '批量通过评论',
                        confirmMessage: '确定要将所选 ${_selected.length} 条评论设为通过吗？',
                      ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('批量通过'),
              ),
              FilledButton.tonalIcon(
                onPressed: _bulkRunning
                    ? null
                    : () => _runBatchAction(
                        action: 'REJECT',
                        title: '批量驳回评论',
                        confirmMessage: '确定要将所选 ${_selected.length} 条评论设为驳回吗？',
                      ),
                icon: const Icon(Icons.block, size: 16),
                label: const Text('批量驳回'),
              ),
              FilledButton.tonalIcon(
                onPressed: _bulkRunning
                    ? null
                    : () => _runBatchAction(
                        action: 'AUDIT',
                        title: '批量 AI 审核',
                        confirmMessage:
                            '确定要对所选 ${_selected.length} 条评论发起 AI 审核吗？（已在审核中的将自动跳过）',
                      ),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('批量 AI 审核'),
              ),
              if (selectedAbortableCount > 0)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepOrange,
                    side: const BorderSide(color: Colors.deepOrange),
                  ),
                  onPressed: _bulkRunning
                      ? null
                      : () => _runBatchAction(
                          action: 'ABORT_AUDIT',
                          title: '批量强制中断 AI 审核',
                          confirmMessage:
                              '确定要强制中断所选中 $selectedAbortableCount 条正在审核的评论吗？',
                          destructive: true,
                        ),
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: Text('批量中断 ($selectedAbortableCount)'),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: _bulkRunning
                    ? null
                    : () => _runBatchAction(
                        action: 'DELETE',
                        title: '批量删除评论',
                        confirmMessage:
                            '确定要删除所选 ${_selected.length} 条评论吗？此操作会软删除评论。',
                        destructive: true,
                      ),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('批量删除'),
              ),
              TextButton(
                onPressed: _bulkRunning
                    ? null
                    : () => setState(_selected.clear),
                child: const Text('取消选择'),
              ),
            ],
            if (_bulkRunning)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCommentDetails(CommentItem comment) async {
    var dialogComment = comment;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final aiData = dialogComment.aiReviewData;
          final auditState = dialogComment.aiAuditState;
          final stateColor = _getAuditStateColor(auditState, dialogComment);
          final rawScore = aiData?['score'];
          final score = rawScore is num ? rawScore.toInt() : null;
          final reason = aiData?['reason']?.toString();
          final duration = aiData?['durationMs'];
          final tokens = aiData?['totalTokens'] ?? 0;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.comment_outlined, color: Colors.indigo),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${t(context, 'comment_content')} #${dialogComment.id}',
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.68,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSimpleInfoRow(
                        Icons.person_outline,
                        t(context, 'username'),
                        dialogComment.userName,
                      ),
                      _buildSimpleInfoRow(
                        Icons.article_outlined,
                        t(context, 'article'),
                        dialogComment.postTitle,
                      ),
                      _buildSimpleInfoRow(
                        Icons.access_time,
                        t(context, 'time'),
                        _formatDate(dialogComment.createdAt),
                      ),
                      const Divider(height: 24),
                      Text(
                        dialogComment.content,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                      if (dialogComment.hasQuote)
                        _buildQuoteCard(dialogComment),
                      const SizedBox(height: 20),
                      Text(
                        t(context, 'ai_audit_suggestion'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (auditState != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: stateColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: stateColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    auditState.stuck
                                        ? Icons.warning_amber_rounded
                                        : (dialogComment.canAbortAudit
                                              ? Icons.sync
                                              : Icons.smart_toy),
                                    size: 18,
                                    color: stateColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${auditState.label} (${auditState.phase})',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: stateColor,
                                      ),
                                    ),
                                  ),
                                  if (auditState.elapsedSeconds != null)
                                    Text(
                                      '已耗时 ${_formatElapsed(auditState.elapsedSeconds!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: stateColor,
                                      ),
                                    ),
                                ],
                              ),
                              if (auditState.detail != null &&
                                  auditState.detail!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  auditState.detail!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              if (auditState.attemptCount > 0 &&
                                  auditState.maxAttempts > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '尝试次数：${auditState.attemptCount} / ${auditState.maxAttempts}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                              if (auditState.lastError != null &&
                                  auditState.lastError!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                SelectableText(
                                  '最近错误：${auditState.lastError}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (aiData == null && auditState == null)
                        Text(t(context, 'not_audited_yet'))
                      else if (aiData != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.smart_toy, color: Colors.indigo),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogComment.aiResultText ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                            if (duration != null)
                              Text('$duration ms · $tokens tokens'),
                          ],
                        ),
                        if (score != null) ...[
                          const SizedBox(height: 10),
                          Text('${t(context, 'ai_score')}: $score / 100'),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: score.clamp(0, 100) / 100,
                              minHeight: 8,
                            ),
                          ),
                        ],
                        if (reason != null && reason.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(reason),
                        ],
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _updateCommentStatus(dialogComment, 1);
                            },
                            icon: const Icon(Icons.check, size: 16),
                            label: Text(t(context, 'approve')),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _updateCommentStatus(dialogComment, 2);
                            },
                            icon: const Icon(Icons.block, size: 16),
                            label: Text(t(context, 'reject')),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteComment(dialogComment);
                            },
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: Text(t(context, 'delete')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t(context, 'close')),
              ),
              if (dialogComment.canAbortAudit)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                  ),
                  onPressed: () async {
                    final updated = await _abortCommentAudit(
                      dialogComment,
                      confirm: false,
                    );
                    if (dialogContext.mounted && updated != null) {
                      setDialogState(() {
                        dialogComment = updated;
                      });
                    }
                  },
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: const Text('强制中断 AI 审核'),
                ),
              FilledButton.icon(
                onPressed: dialogComment.canAbortAudit
                    ? null
                    : () async {
                        final previousDialogComment = dialogComment;
                        setDialogState(() {
                          dialogComment = _copyComment(
                            dialogComment,
                            isReviewing: true,
                            aiAuditState: AiAuditState(
                              phase: 'OUTBOX_PENDING',
                              label: '等待 Outbox 调度',
                              detail: '正在提交 AI 审核任务...',
                              stuck: false,
                              canAbort: true,
                            ),
                          );
                        });
                        final updated = await _auditComment(dialogComment);
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            dialogComment = updated ?? previousDialogComment;
                          });
                        }
                      },
                icon: dialogComment.canAbortAudit
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(
                  dialogComment.canAbortAudit
                      ? (auditState?.label ?? t(context, 'auditing'))
                      : t(context, 'ai_audit'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _quoteTypeText(BuildContext context, CommentItem comment) {
    switch (comment.quoteType) {
      case 'CORRECTION':
        return t(context, 'quote_type_correction', fallback: '纠错');
      case 'QUOTE':
        return t(context, 'quote_type_quote', fallback: '引用');
      default:
        return comment.quoteType ?? '';
    }
  }

  String _quoteStatusText(BuildContext context, CommentItem comment) {
    switch (comment.quoteStatus) {
      case 0:
        return t(context, 'quote_status_pending', fallback: '待处理');
      case 1:
        return t(context, 'quote_status_accepted', fallback: '已采纳');
      case 2:
        return t(context, 'quote_status_rejected', fallback: '已驳回');
      default:
        return t(context, 'quote_status_unknown', fallback: '未知');
    }
  }

  Widget _buildQuoteCard(CommentItem comment) {
    final isCorrection = comment.quoteType == 'CORRECTION';
    final color = isCorrection ? Colors.orange : Colors.blueGrey;
    final paragraphIndex = comment.quoteAnchorData?['paragraphIndex'];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrection
                    ? Icons.report_problem_outlined
                    : Icons.format_quote,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                _quoteTypeText(context, comment),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCorrection) ...[
                const SizedBox(width: 10),
                Text(
                  t(
                    context,
                    'quote_status_label',
                    fallback: '状态：%s',
                  ).replaceFirst('%s', _quoteStatusText(context, comment)),
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '“${comment.quoteText ?? ''}”',
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          if (paragraphIndex is num) ...[
            const SizedBox(height: 4),
            Text(
              t(
                context,
                'quote_anchor_paragraph',
                fallback: '定位段落 #%d',
              ).replaceFirst('%d', (paragraphIndex.toInt() + 1).toString()),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return PaginationBar(
      currentPage: currentPage,
      totalPages: totalPages,
      totalItems: totalItems,
      onPageChanged: (newPage) {
        setState(() {
          currentPage = newPage;
          _selected.clear();
        });
        _loadComments();
      },
    );
  }

  String _formatDate(DateTime date) {
    return DateTimeFormatter.formatDateTime(context, date);
  }
}

class _CommentTile extends StatelessWidget {
  final CommentItem comment;
  final bool selected;
  final ValueChanged<bool?>? onSelectChanged;
  final Color statusColor;
  final Color auditStateColor;
  final String dateText;
  final String Function(int seconds) formatElapsed;
  final bool isAborting;
  final VoidCallback? onAbortAudit;
  final VoidCallback onOpenDetails;
  final String Function(String key, {String? fallback}) t;

  const _CommentTile({
    required this.comment,
    required this.selected,
    required this.onSelectChanged,
    required this.statusColor,
    required this.auditStateColor,
    required this.dateText,
    required this.formatElapsed,
    required this.isAborting,
    required this.onAbortAudit,
    required this.onOpenDetails,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final auditState = comment.aiAuditState;
    final showDiagnosticLine =
        auditState != null &&
        (comment.canAbortAudit ||
            auditState.stuck ||
            auditState.phase == 'FAILED' ||
            auditState.phase == 'ABORTED') &&
        (auditState.detail != null && auditState.detail!.isNotEmpty);

    return ListTile(
      selected: selected,
      onTap: onOpenDetails,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: selected, onChanged: onSelectChanged),
          CircleAvatar(
            radius: 18,
            backgroundColor: statusColor.withValues(alpha: 0.18),
            child: Icon(Icons.comment, size: 18, color: statusColor),
          ),
        ],
      ),
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            comment.userName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${t('status')}: ${comment.statusText}',
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (comment.aiResultText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: auditStateColor.withValues(alpha: 0.12),
                border: Border.all(
                  color: auditStateColor.withValues(alpha: 0.35),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (comment.canAbortAudit && !(auditState?.stuck ?? false))
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: SizedBox(
                        width: 9,
                        height: 9,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: auditStateColor,
                        ),
                      ),
                    )
                  else if (auditState?.stuck == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 12,
                        color: auditStateColor,
                      ),
                    ),
                  Text(
                    auditState?.elapsedSeconds != null && comment.canAbortAudit
                        ? 'AI: ${comment.aiResultText} (${formatElapsed(auditState!.elapsedSeconds!)})'
                        : 'AI: ${comment.aiResultText}',
                    style: TextStyle(
                      color: auditStateColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t('article')}: ${comment.postTitle} · $dateText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 5),
            Text(
              comment.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (showDiagnosticLine) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: auditStateColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  auditState.detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: auditStateColor,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            if (comment.hasQuote) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    comment.quoteType == 'CORRECTION'
                        ? Icons.report_problem_outlined
                        : Icons.format_quote,
                    size: 12,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    comment.quoteType == 'CORRECTION'
                        ? t('quote_type_correction', fallback: '纠错')
                        : (comment.quoteType == 'QUOTE'
                              ? t('quote_type_quote', fallback: '引用')
                              : comment.quoteTypeText),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '“${comment.quoteText ?? ''}”',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      trailing: onAbortAudit != null
          ? Tooltip(
              message: '强制中断 AI 审核',
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepOrange,
                  side: const BorderSide(color: Colors.deepOrange),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: isAborting ? null : onAbortAudit,
                icon: isAborting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.stop_circle_outlined, size: 16),
                label: const Text('中断', style: TextStyle(fontSize: 12)),
              ),
            )
          : const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}
