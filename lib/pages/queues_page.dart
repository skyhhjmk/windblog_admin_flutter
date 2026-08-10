part of 'package:windblog_admin_flutter/main.dart';

class QueuesPage extends StatefulWidget {
  const QueuesPage({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<QueuesPage> createState() => _QueuesPageState();
}

class _QueuesPageState extends State<QueuesPage> {
  List<QueueInfo> queues = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadQueues();
  }

  Future<void> _loadQueues() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      queues = await widget.api.listQueues();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _publishTestMessage(QueueInfo queue) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PublishMessageDialog(queueName: queue.name),
    );
    if (result == null) return;

    try {
      await widget.api.publishTestMessage(
        queue.name,
        postId: result['postId'] as int?,
        commentId: result['commentId'] as int?,
        priority: result['priority'] as int?,
        content: result['content'] as String?,
      );
      if (mounted) {
        AdminFeedback.success(context, t(context, 'publish_success'));
      }
      await _loadQueues();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.error(context, '${t(context, 'publish_failed')}$e');
    }
  }

  Color _getQueueColor(QueueInfo queue) {
    if (queue.messageCount > 100) return Colors.red;
    if (queue.messageCount > 50) return Colors.orange;
    if (queue.messageCount > 10) return Colors.yellow.shade700;
    return Colors.green;
  }

  IconData _getQueueIcon(String queueName) {
    if (queueName.contains('dead-letter')) return Icons.error_outline;
    if (queueName.contains('ai')) return Icons.smart_toy;
    return Icons.queue;
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: t(context, 'queue_monitoring'),
      actions: [
        OutlinedButton.icon(
          onPressed: _loadQueues,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(t(context, 'refresh')),
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const AdminStatusView.loading(title: '正在加载队列');
    }

    if (error != null) {
      return AdminStatusView.error(
        title: t(context, 'load_failed'),
        message: error,
        action: FilledButton.icon(
          onPressed: _loadQueues,
          icon: const Icon(Icons.refresh),
          label: Text(t(context, 'refresh')),
        ),
      );
    }

    if (queues.isEmpty) {
      return AdminStatusView.empty(title: t(context, 'no_queues'));
    }

    if (AdminBreakpoints.isPhone(context)) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          SizedBox(height: 520, child: _buildQueueListCard()),
          const SizedBox(height: 12),
          _buildQueueInfoCard(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _buildQueueListCard()),
        const SizedBox(width: 16),
        Expanded(flex: 1, child: _buildQueueInfoCard()),
      ],
    );
  }

  Widget _buildQueueListCard() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              t(context, 'queue_list'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: queues.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final queue = queues[index];
                return _buildQueueTile(queue);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTile(QueueInfo queue) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getQueueColor(queue).withValues(alpha: 0.2),
        child: Icon(_getQueueIcon(queue.name), color: _getQueueColor(queue)),
      ),
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AdminBreakpoints.isPhone(context) ? 210 : 360,
            ),
            child: Text(
              queue.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (queue.description.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AdminBreakpoints.isPhone(context) ? 210 : 320,
              ),
              child: Text(
                '(${queue.description})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildStatChip(
                Icons.message,
                '${queue.messageCount}',
                _getQueueColor(queue),
              ),
              _buildStatChip(
                Icons.people,
                '${queue.consumerCount}',
                Colors.blue,
              ),
              if (queue.deadLetterMessageCount > 0)
                _buildStatChip(
                  Icons.error,
                  '${queue.deadLetterMessageCount}',
                  Colors.red,
                ),
            ],
          ),
          if (queue.deadLetterQueue.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${t(context, 'dead_letter_queue')}: ${queue.deadLetterQueue}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
      trailing: AdminBreakpoints.isPhone(context)
          ? IconButton(
              onPressed: () => _publishTestMessage(queue),
              icon: const Icon(Icons.send),
              tooltip: t(context, 'send_test'),
            )
          : FilledButton.tonal(
              onPressed: () => _publishTestMessage(queue),
              child: Text(t(context, 'send_test')),
            ),
    );
  }

  Widget _buildQueueInfoCard() {
    int totalMessages = 0;
    int totalConsumers = 0;
    for (QueueInfo queue in queues) {
      totalMessages = totalMessages + queue.messageCount;
      totalConsumers = totalConsumers + queue.consumerCount;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'queue_info'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.queue,
              t(context, 'total_queues'),
              '${queues.length}',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.message,
              t(context, 'total_messages'),
              '$totalMessages',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.people,
              t(context, 'total_consumers'),
              '$totalConsumers',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t(context, 'queue_tip'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PublishMessageDialog extends StatefulWidget {
  const _PublishMessageDialog({required this.queueName});

  final String queueName;

  @override
  State<_PublishMessageDialog> createState() => _PublishMessageDialogState();
}

class _PublishMessageDialogState extends State<_PublishMessageDialog> {
  late final TextEditingController _idCtrl;
  late final TextEditingController _contentCtrl;
  int _priority = 1;

  bool get isAudit => widget.queueName.contains('audit');

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController(text: '1');
    _contentCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_contentCtrl.text.isEmpty) {
      _contentCtrl.text = isAudit
          ? t(context, 'audit_test_content')
          : t(context, 'publish_test_message_default_content');
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double dialogWidth = max(
      280,
      min(400, MediaQuery.sizeOf(context).width - 48),
    );

    return AlertDialog(
      title: Text(t(context, 'publish_test_message')),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t(context, 'send_to_queue')}: ${widget.queueName}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _idCtrl,
                decoration: InputDecoration(
                  labelText: isAudit
                      ? 'Comment ID'
                      : t(context, 'article_id_label'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentCtrl,
                decoration: InputDecoration(
                  labelText: isAudit
                      ? t(context, 'comment_content')
                      : t(context, 'article_summary_label'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              if (!isAudit) ...[
                const SizedBox(height: 12),
                Text(
                  t(context, 'priority'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text(t(context, 'high'))),
                      ButtonSegment(
                        value: 1,
                        label: Text(t(context, 'medium')),
                      ),
                      ButtonSegment(value: 2, label: Text(t(context, 'low'))),
                    ],
                    selected: {_priority},
                    onSelectionChanged: (selected) {
                      setState(() => _priority = selected.first);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t(context, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            final id = int.tryParse(_idCtrl.text);
            if (id == null) {
              AdminFeedback.showSnackBar(context,
                SnackBar(
                  content: Text(
                    isAudit
                        ? 'Invalid Comment ID'
                        : t(context, 'invalid_post_id'),
                  ),
                ),
              );
              return;
            }
            Navigator.pop(context, {
              if (isAudit) 'commentId': id else 'postId': id,
              'priority': _priority,
              'content': _contentCtrl.text,
            });
          },
          child: Text(t(context, 'confirm')),
        ),
      ],
    );
  }
}
