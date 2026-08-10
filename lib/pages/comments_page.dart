part of 'package:windblog_admin_flutter/main.dart';

class CommentsPage extends StatefulWidget {
  const CommentsPage({super.key, required this.api, required this.onAuthError});

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
  String keyword = '';

  final pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => loading = true);
    try {
      final result = await widget.api.listComments(
        page: currentPage,
        pageSize: pageSize,
        status: statusFilter,
        keyword: keyword.isEmpty ? null : keyword,
      );
      comments = result.items;
      totalItems = result.total;
      totalPages = (result.total / pageSize).ceil();
      if (totalPages < 1) totalPages = 1;
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(context,
          SnackBar(content: Text('${t(context, 'load_failed')}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
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
      AdminFeedback.showSnackBar(context, SnackBar(content: Text('${t(context, 'save_failed')}$e')));
    }
  }

  Future<void> _auditComment(CommentItem comment) async {
    try {
      await widget.api.auditComment(comment.id);
      await _loadComments();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(context, SnackBar(content: Text('${t(context, 'save_failed')}$e')));
    }
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
      await _loadComments();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(context,
        SnackBar(content: Text('${t(context, 'delete_failed')}$e')),
      );
    }
  }

  void _onFilterChanged(String? status) {
    setState(() {
      statusFilter = status;
      currentPage = 1;
    });
    _loadComments();
  }

  void _onSearch(String value) {
    setState(() {
      keyword = value;
      currentPage = 1;
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

  Color _getAuditStatusColor(int auditStatus) {
    switch (auditStatus) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: t(context, 'comments'),
      filters: AdminToolbar(
        children: [
          SizedBox(
            width: AdminBreakpoints.isPhone(context) ? double.infinity : 180,
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
            width: AdminBreakpoints.isPhone(context) ? double.infinity : 320,
            child: TextField(
              decoration: InputDecoration(
                labelText: t(context, 'search_comments'),
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: _onSearch,
            ),
          ),
          FilledButton.icon(
            onPressed: _loadComments,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(t(context, 'refresh')),
          ),
        ],
      ),
      body: loading
          ? const AdminStatusView.loading(title: '正在加载评论')
          : comments.isEmpty
          ? AdminStatusView.empty(title: t(context, 'no_comments'))
          : Card(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: comments.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return _CommentTile(
                    comment: comment,
                    statusColor: _getStatusColor(comment.status),
                    auditStatusColor: _getAuditStatusColor(comment.auditStatus),
                    dateText: _formatDate(comment.createdAt),
                    onAudit: () => _auditComment(comment),
                    onViewReport: () => _showAuditReport(comment),
                    onUpdateStatus: (status) =>
                        _updateCommentStatus(comment, status),
                    onDelete: () => _deleteComment(comment),
                    t: (key) => t(context, key),
                  );
                },
              ),
            ),
      footer: _buildPagination(),
    );
  }

  Future<void> _showAuditReport(CommentItem comment) async {
    final aiData = comment.aiReviewData;
    final score = aiData != null ? (aiData['score'] as num?)?.toInt() : null;
    final reason = aiData != null ? aiData['reason']?.toString() : null;
    final durationMs = aiData != null ? aiData['durationMs'] : null;
    final totalTokens = aiData != null ? (aiData['totalTokens'] ?? 0) : null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Colors.indigo),
            const SizedBox(width: 10),
            Text(t(context, 'audit_report')),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSimpleInfoRow(
                Icons.person_outline,
                t(context, 'username'),
                comment.userName,
              ),
              _buildSimpleInfoRow(
                Icons.article_outlined,
                t(context, 'article'),
                comment.postTitle,
              ),
              _buildSimpleInfoRow(
                Icons.access_time,
                t(context, 'time'),
                _formatDate(comment.createdAt),
              ),
              const Divider(height: 24),
              Text(
                t(context, 'comment_content'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  comment.content,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t(context, 'ai_audit_suggestion'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              if (aiData == null)
                // 未审核状态
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.hourglass_empty_outlined,
                        size: 28,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t(context, 'not_audited_yet'),
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              else
                // AI 审核结果
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.indigo.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题行：AI 建议结论 + 耗时/Token
                      Row(
                        children: [
                          const Icon(
                            Icons.smart_toy,
                            size: 16,
                            color: Colors.indigo,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI ${t(context, 'ai_audit')}: ${comment.aiResultText ?? '-'}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: comment.aiResultText == '建议通过'
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          if (durationMs != null)
                            Text(
                              '$durationMs ms · $totalTokens tokens',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                      // 可信度评分条
                      if (score != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              t(context, 'ai_score'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$score',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: score >= 80
                                    ? Colors.green.shade700
                                    : score >= 50
                                    ? Colors.orange.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                            Text(
                              ' / 100',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: score / 100,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              score >= 80
                                  ? Colors.green.shade500
                                  : score >= 50
                                  ? Colors.orange.shade500
                                  : Colors.red.shade500,
                            ),
                          ),
                        ),
                      ],
                      // AI 审核理由
                      if (reason != null && reason.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.indigo.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(context, 'close')),
          ),
          FilledButton.icon(
            onPressed: comment.isReviewing
                ? null
                : () {
                    Navigator.pop(context);
                    _auditComment(comment);
                  },
            icon: comment.isReviewing
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
              comment.isReviewing
                  ? t(context, 'auditing')
                  : t(context, 'ai_audit'),
            ),
          ),
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
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
        setState(() => currentPage = newPage);
        _loadComments();
      },
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    return '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')} '
        '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
  }
}

class _CommentTile extends StatefulWidget {
  final CommentItem comment;
  final Color statusColor;
  final Color auditStatusColor;
  final String dateText;
  final VoidCallback onAudit;
  final VoidCallback onViewReport;
  final Function(int) onUpdateStatus;
  final VoidCallback onDelete;
  final String Function(String) t;

  const _CommentTile({
    required this.comment,
    required this.statusColor,
    required this.auditStatusColor,
    required this.dateText,
    required this.onAudit,
    required this.onViewReport,
    required this.onUpdateStatus,
    required this.onDelete,
    required this.t,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final t = widget.t;

    return Column(
      children: [
        ListTile(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          leading: CircleAvatar(
            backgroundColor: widget.statusColor.withValues(alpha: 0.2),
            child: Icon(Icons.comment, color: widget.statusColor),
          ),
          title: Row(
            children: [
              Text(
                comment.userName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              // 当前状态标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.statusColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: widget.statusColor.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${t('status')}: ${comment.statusText}',
                  style: TextStyle(
                    color: widget.statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (comment.aiResultText != null) ...[
                const SizedBox(width: 8),
                // AI 建议标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.smart_toy_outlined,
                        size: 10,
                        color: Colors.indigo,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'AI: ${comment.aiResultText}',
                        style: const TextStyle(
                          color: Colors.indigo,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${t('article')}: ${comment.postTitle}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                widget.dateText,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const SizedBox(height: 6),
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
            ],
          ),
          trailing: Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.grey,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _isExpanded
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        Icons.text_fields,
                        t('comment_content'),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          comment.content,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                      if (comment.aiReviewData != null) ...[
                        const SizedBox(height: 16),
                        _buildSectionHeader(
                          Icons.analytics_outlined,
                          t('audit_report'),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.indigo.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.smart_toy,
                                    color: Colors.indigo,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${t('ai_audit')}: ${comment.aiResultText}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (comment.aiReviewData != null &&
                                      comment.aiReviewData!['durationMs'] !=
                                          null)
                                    Text(
                                      '${comment.aiReviewData!['durationMs']}ms / ${comment.aiReviewData!['totalTokens'] ?? 0} tokens',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                              if (comment.aiReviewData != null &&
                                  comment.aiReviewData!['score'] != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '${t('ai_score')}: ',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${comment.aiReviewData!['score']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.indigo,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (comment.aiReviewData != null &&
                                  comment.aiReviewData!['reason'] != null &&
                                  comment.aiReviewData!['reason']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  comment.aiReviewData!['reason'].toString(),
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildSectionHeader(
                            Icons.touch_app,
                            t('admin_actions'),
                          ),
                          const Spacer(),
                          if (comment.auditStatus != 0) ...[
                            OutlinedButton.icon(
                              onPressed: widget.onViewReport,
                              icon: const Icon(
                                Icons.analytics_outlined,
                                size: 16,
                              ),
                              label: Text(t('view_audit_report')),
                            ),
                            const SizedBox(width: 8),
                          ],
                          FilledButton.icon(
                            onPressed: comment.isReviewing
                                ? null
                                : widget.onAudit,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.indigo.withValues(
                                alpha: 0.5,
                              ),
                              disabledForegroundColor: Colors.white,
                            ),
                            icon: comment.isReviewing
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
                              comment.isReviewing
                                  ? t('auditing')
                                  : t('ai_audit'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: comment.isReviewing
                                ? null
                                : () => widget.onUpdateStatus(1),
                            icon: const Icon(Icons.check, size: 16),
                            label: Text(t('approve')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: BorderSide(
                                color: comment.isReviewing
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: comment.isReviewing
                                ? null
                                : () => widget.onUpdateStatus(2),
                            icon: const Icon(Icons.block, size: 16),
                            label: Text(t('reject')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: BorderSide(
                                color: comment.isReviewing
                                    ? Colors.red.withValues(alpha: 0.3)
                                    : Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: comment.isReviewing
                                ? null
                                : widget.onDelete,
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
