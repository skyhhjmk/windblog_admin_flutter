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

  Future<void> _auditComment(CommentItem comment, bool approve) async {
    try {
      await widget.api.auditComment(comment.id, approve: approve);
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
                        return ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(comment.status)
                                .withValues(alpha: 0.2),
                            child: Icon(
                              Icons.comment,
                              color: _getStatusColor(comment.status),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  comment.userName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(comment.status)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  comment.statusText,
                                  style: TextStyle(
                                    color: _getStatusColor(comment.status),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getAuditStatusColor(
                                      comment.auditStatus).withValues(
                                      alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  comment.auditStatusText,
                                  style: TextStyle(
                                    color: _getAuditStatusColor(
                                        comment.auditStatus),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${t(context, 'article')}: ${comment
                                    .postTitle}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(comment.createdAt),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.content,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  if (comment.auditReason != null &&
                                      comment.auditReason!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.warning,
                                              color: Colors.red.shade700,
                                              size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${t(context, 'ai_audit_reason')}: ${comment
                                                  .auditReason}',
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (comment.status == 0) ...[
                                        FilledButton.tonal(
                                          onPressed: () =>
                                              _auditComment(comment, true),
                                          child: Text(t(context, 'approve')),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.tonal(
                                          onPressed: () =>
                                              _auditComment(comment, false),
                                          child: Text(t(context, 'reject')),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (comment.status != 1)
                                        TextButton(
                                          onPressed: () =>
                                              _updateCommentStatus(comment, 1),
                                          child: Text(t(context, 'approve')),
                                        ),
                                      if (comment.status != 2)
                                        TextButton(
                                          onPressed: () =>
                                              _updateCommentStatus(comment, 2),
                                          child: Text(t(context, 'reject')),
                                        ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () =>
                                            _deleteComment(comment),
                                        child: Text(
                                          t(context, 'delete'),
                                          style: const TextStyle(
                                              color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
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
