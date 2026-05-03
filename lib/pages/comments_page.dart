part of 'package:windblog_admin_flutter/main.dart';

class CommentsPage extends StatefulWidget {
  const CommentsPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

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
        ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'save_failed')}$e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'save_failed')}$e')),
      );
    }
  }

  Future<void> _deleteComment(CommentItem comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String?>(
                  initialValue: statusFilter,
                  decoration: InputDecoration(
                    labelText: t(context, 'status_filter'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: null,
                        child: Text(t(context, 'all_status'),
                            style: const TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: '0',
                        child: Text(t(context, 'comment_pending'),
                            style: const TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: '1',
                        child: Text(t(context, 'comment_approved'),
                            style: const TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: '2',
                        child: Text(t(context, 'comment_rejected'),
                            style: const TextStyle(fontSize: 13))),
                  ],
                  onChanged: _onFilterChanged,
                  isExpanded: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: t(context, 'search_comments'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                  onSubmitted: _onSearch,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loadComments,
                child: Text(t(context, 'refresh')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : comments.isEmpty
                ? Center(child: Text(t(context, 'no_comments')))
                : Card(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: comments.length,
                      separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return _CommentTile(
                          comment: comment,
                          statusColor: _getStatusColor(comment.status),
                          auditStatusColor: _getAuditStatusColor(
                              comment.auditStatus),
                          dateText: _formatDate(comment.createdAt),
                          onAudit: () => _auditComment(comment),
                          onUpdateStatus: (status) =>
                              _updateCommentStatus(comment, status),
                          onDelete: () => _deleteComment(comment),
                          t: (key) => t(context, key),
                        );
                      },
                    ),
                  ),
                  _buildPagination(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${t(context, 'total')}: $totalItems',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: currentPage > 1 ? () {
              setState(() => currentPage--);
              _loadComments();
            } : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('$currentPage / $totalPages'),
          IconButton(
            onPressed: currentPage < totalPages ? () {
              setState(() => currentPage++);
              _loadComments();
            } : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day
        .toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute
        .toString()
        .padLeft(2, '0')}';
  }
}

class _CommentTile extends StatefulWidget {
  final CommentItem comment;
  final Color statusColor;
  final Color auditStatusColor;
  final String dateText;
  final VoidCallback onAudit;
  final Function(int) onUpdateStatus;
  final VoidCallback onDelete;
  final String Function(String) t;

  const _CommentTile({
    required this.comment,
    required this.statusColor,
    required this.auditStatusColor,
    required this.dateText,
    required this.onAudit,
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
            child: Icon(
              Icons.comment,
              color: widget.statusColor,
            ),
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
                      color: widget.statusColor.withValues(alpha: 0.3)),
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
              if (comment.auditStatus != 0) ...[
                const SizedBox(width: 8),
                // AI 建议标签
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.auditStatusColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.smart_toy_outlined, size: 10,
                          color: widget.auditStatusColor),
                      const SizedBox(width: 2),
                      Text(
                        'AI: ${comment.auditStatusText.replaceAll('AI ', '')}',
                        style: TextStyle(
                          color: widget.auditStatusColor,
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
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.dateText,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
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
                _buildSectionHeader(Icons.text_fields, t('comment_content')),
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
                if (comment.auditStatus != 0 || (comment.auditReason != null &&
                    comment.auditReason!.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader(
                      Icons.analytics_outlined, t('audit_report')),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: comment.auditType == 1
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: comment.auditType == 1
                            ? Colors.red.shade100
                            : Colors.blue.shade100,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              comment.auditType == 1 ? Icons.smart_toy : Icons
                                  .person,
                              color: comment.auditType == 1 ? Colors.red
                                  .shade700 : Colors.blue.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              comment.auditType == 1
                                  ? t('ai_audit_suggestion')
                                  : t('manual_audit_record'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: comment.auditType == 1 ? Colors.red
                                    .shade700 : Colors.blue.shade700,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            if (comment.auditType == 1)
                              Text(
                                '${comment.aiDurationMs ?? 0}ms / ${comment
                                    .aiTotalTokens ?? 0} tokens',
                                style: TextStyle(
                                  color: Colors.red.shade300,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        if (comment.auditReason != null &&
                            comment.auditReason!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            comment.auditReason!,
                            style: TextStyle(
                              color: comment.auditType == 1 ? Colors.red
                                  .shade800 : Colors.blue.shade800,
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
                    _buildSectionHeader(Icons.touch_app, t('admin_actions')),
                    const Spacer(),
                    if (comment.status == 0) ...[
                      FilledButton.icon(
                        onPressed: widget.onAudit,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: Text(t('ai_audit')),
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => widget.onUpdateStatus(1),
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(t('approve')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => widget.onUpdateStatus(2),
                      icon: const Icon(Icons.block, size: 16),
                      label: Text(t('reject')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: widget.onDelete,
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
