part of 'package:windblog_admin_flutter/main.dart';

class QueuesPage extends StatefulWidget {
  const QueuesPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<QueuesPage> createState() => _QueuesPageState();
}

class _QueuesPageState extends State<QueuesPage> {
  List<QueueInfo> queues = [];
  bool loading = false;
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
        priority: result['priority'] as int?,
        content: result['content'] as String?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(context, 'publish_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadQueues();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t(context, 'publish_failed')}$e'),
          backgroundColor: Colors.red,
        ),
      );
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton(
                onPressed: _loadQueues,
                child: Text(t(context, 'refresh')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            if (error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade300,
                          size: 48),
                      const SizedBox(height: 16),
                      Text(
                        '${t(context, 'load_failed')}$error',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                  ),
                ),
              )
            else
              if (queues.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(t(context, 'no_queues')),
                  ),
                )
              else
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  t(context, 'queue_list'),
                                  style: Theme
                                      .of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: queues.length,
                                  separatorBuilder: (context,
                                      index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final queue = queues[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: _getQueueColor(queue)
                                            .withValues(alpha: 0.2),
                                        child: Icon(
                                          _getQueueIcon(queue.name),
                                          color: _getQueueColor(queue),
                                        ),
                                      ),
                                      title: Text(
                                        queue.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment
                                            .start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              _buildStatChip(
                                                Icons.message,
                                                '${queue.messageCount}',
                                                _getQueueColor(queue),
                                              ),
                                              const SizedBox(width: 8),
                                              _buildStatChip(
                                                Icons.people,
                                                '${queue.consumerCount}',
                                                Colors.blue,
                                              ),
                                              if (queue.deadLetterMessageCount >
                                                  0) ...[
                                                const SizedBox(width: 8),
                                                _buildStatChip(
                                                  Icons.error,
                                                  '${queue
                                                      .deadLetterMessageCount}',
                                                  Colors.red,
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (queue.deadLetterQueue
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '${t(context,
                                                  'dead_letter_queue')}: ${queue
                                                  .deadLetterQueue}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      trailing: FilledButton.tonal(
                                        onPressed: () =>
                                            _publishTestMessage(queue),
                                        child: Text(t(context, 'send_test')),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t(context, 'queue_info'),
                                  style: Theme
                                      .of(context)
                                      .textTheme
                                      .titleMedium,
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
                                  '${queues.fold<int>(
                                      0, (sum, q) => sum + q.messageCount)}',
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  Icons.people,
                                  t(context, 'total_consumers'),
                                  '${queues.fold<int>(
                                      0, (sum, q) => sum + q.consumerCount)}',
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          color: Colors.blue.shade700,
                                          size: 20),
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
                        ),
                      ),
                    ],
                  ),
                ),
        ],
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
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
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
  final _postIdCtrl = TextEditingController(text: '1');
  final _contentCtrl = TextEditingController(
    text: '这是一篇测试文章的摘要内容，用于测试消息队列功能。',
  );
  int _priority = 1;

  @override
  void dispose() {
    _postIdCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t(context, 'publish_test_message')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '发送到队列: ${widget.queueName}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _postIdCtrl,
              decoration: const InputDecoration(
                labelText: '文章 ID (postId)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(
                labelText: '文章内容摘要',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Text('优先级', style: Theme
                .of(context)
                .textTheme
                .bodySmall),
            const SizedBox(height: 4),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('高')),
                ButtonSegment(value: 1, label: Text('中')),
                ButtonSegment(value: 2, label: Text('低')),
              ],
              selected: {_priority},
              onSelectionChanged: (selected) {
                setState(() => _priority = selected.first);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t(context, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            final postId = int.tryParse(_postIdCtrl.text);
            if (postId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入有效的文章 ID')),
              );
              return;
            }
            Navigator.pop(context, {
              'postId': postId,
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
