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
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('${t(context, 'load_failed')}: $e')),
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
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text('${t(context, 'save_failed')}$e')),
      );
    }
  }

  CommentItem _copyComment(CommentItem comment, {bool? isReviewing}) {
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
      createdAt: comment.createdAt,
    );
  }

  void _replaceComment(CommentItem updated) {
    if (!mounted) return;
    setState(() {
      final index = comments.indexWhere((item) => item.id == updated.id);
      if (index >= 0) comments[index] = updated;
    });
  }

  Future<CommentItem?> _auditComment(CommentItem comment) async {
    _replaceComment(_copyComment(comment, isReviewing: true));
    try {
      final updated = await widget.api.auditComment(comment.id);
      _replaceComment(updated);
      return updated;
    } on UnauthorizedException {
      widget.onAuthError();
      _replaceComment(_copyComment(comment, isReviewing: false));
    } catch (e) {
      _replaceComment(_copyComment(comment, isReviewing: false));
      if (!mounted) return null;
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text('${t(context, 'save_failed')}$e')),
      );
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
            child: AdminShortcutSearchField(
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
                    dateText: _formatDate(comment.createdAt),
                    onOpenDetails: () => _showCommentDetails(comment),
                    t: (key) => t(context, key),
                  );
                },
              ),
            ),
      footer: _buildPagination(),
    );
  }

  Future<void> _showCommentDetails(CommentItem comment) async {
    var dialogComment = comment;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final aiData = dialogComment.aiReviewData;
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
                Text(t(context, 'comment_content')),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.65,
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
                      const SizedBox(height: 20),
                      Text(
                        t(context, 'ai_audit_suggestion'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (aiData == null)
                        Text(t(context, 'not_audited_yet'))
                      else ...[
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
                            onPressed: dialogComment.isReviewing
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _updateCommentStatus(dialogComment, 1);
                                  },
                            icon: const Icon(Icons.check, size: 16),
                            label: Text(t(context, 'approve')),
                          ),
                          OutlinedButton.icon(
                            onPressed: dialogComment.isReviewing
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _updateCommentStatus(dialogComment, 2);
                                  },
                            icon: const Icon(Icons.block, size: 16),
                            label: Text(t(context, 'reject')),
                          ),
                          OutlinedButton.icon(
                            onPressed: dialogComment.isReviewing
                                ? null
                                : () {
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
              FilledButton.icon(
                onPressed: dialogComment.isReviewing
                    ? null
                    : () async {
                        setDialogState(() {
                          dialogComment = _copyComment(
                            dialogComment,
                            isReviewing: true,
                          );
                        });
                        final updated = await _auditComment(dialogComment);
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            dialogComment =
                                updated ??
                                _copyComment(dialogComment, isReviewing: false);
                          });
                        }
                      },
                icon: dialogComment.isReviewing
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
                  dialogComment.isReviewing
                      ? t(context, 'auditing')
                      : t(context, 'ai_audit'),
                ),
              ),
            ],
          );
        },
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

class _CommentTile extends StatelessWidget {
  final CommentItem comment;
  final Color statusColor;
  final String dateText;
  final VoidCallback onOpenDetails;
  final String Function(String) t;

  const _CommentTile({
    required this.comment,
    required this.statusColor,
    required this.dateText,
    required this.onOpenDetails,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onOpenDetails,
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.2),
        child: Icon(Icons.comment, color: statusColor),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              comment.userName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
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
          if (comment.aiResultText != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'AI: ${comment.aiResultText}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.indigo, fontSize: 10),
              ),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t('article')}: ${comment.postTitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              dateText,
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
      ),
      trailing: Icon(
        comment.isReviewing ? Icons.hourglass_top : Icons.expand_more,
        color: comment.isReviewing ? Colors.indigo : Colors.grey,
      ),
    );
  }
}
