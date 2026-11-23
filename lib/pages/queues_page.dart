part of 'package:windblog_admin_flutter/main.dart';

class QueuesPage extends StatefulWidget {
  const QueuesPage({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<QueuesPage> createState() => _QueuesPageState();
}

class _QueuesPageState extends State<QueuesPage> {
  QueueMonitorOverview? overview;
  bool loading = true;
  String? error;
  bool _autoRefresh = true;
  Timer? _refreshTimer;
  bool _refreshInFlight = false;
  final Set<int> _abortingCommentIds = {};

  List<QueueInfo> get queues => overview?.queues ?? const [];

  @override
  void initState() {
    super.initState();
    _loadQueues();
    _syncAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _syncAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (_autoRefresh) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && !_refreshInFlight) {
          _loadQueues(silent: true);
        }
      });
    }
  }

  Future<void> _loadQueues({bool silent = false}) async {
    if (silent) {
      _refreshInFlight = true;
    } else {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final result = await widget.api.getQueueMonitorOverview();
      if (!mounted) return;
      setState(() {
        overview = result;
        error = null;
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() => error = e.toString());
      }
    } finally {
      _refreshInFlight = false;
      if (mounted && !silent) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _abortActiveCommentAudit(int commentId) async {
    setState(() => _abortingCommentIds.add(commentId));
    try {
      await widget.api.abortCommentAudit(commentId);
      if (mounted) {
        AdminFeedback.success(context, '已强制中断评论 #$commentId 的 AI 审核');
      }
      await _loadQueues(silent: true);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.error(context, '强制中断失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _abortingCommentIds.remove(commentId));
      }
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
    switch (queue.status) {
      case 'BROKER_OFFLINE':
      case 'NO_CONSUMER':
      case 'DEGRADED':
      case 'BACKLOG':
        return Colors.red;
      case 'MISSING':
        return Colors.orange;
      case 'ACTIVE':
        return Colors.indigo;
      default:
        if (queue.messageCount > 50) return Colors.orange;
        return Colors.green;
    }
  }

  String _getQueueStatusLabel(QueueInfo queue) {
    switch (queue.status) {
      case 'BROKER_OFFLINE':
        return 'Broker 离线';
      case 'MISSING':
        return '未声明';
      case 'NO_CONSUMER':
        return '无消费者';
      case 'DEGRADED':
        return '存在异常';
      case 'BACKLOG':
        return '有积压';
      case 'ACTIVE':
        return '运行中';
      default:
        return '正常';
    }
  }

  IconData _getQueueIcon(String queueName) {
    if (queueName.contains('dead-letter')) return Icons.error_outline;
    if (queueName.contains('ai')) return Icons.smart_toy;
    if (queueName.contains('es-sync')) return Icons.search;
    if (queueName.contains('storage')) return Icons.cloud_sync_outlined;
    return Icons.queue;
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final min = seconds ~/ 60;
    final rem = seconds % 60;
    return '${min}m ${rem}s';
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: t(context, 'queue_monitoring'),
      actions: [
        FilterChip(
          selected: _autoRefresh,
          label: const Text('5s 自动刷新'),
          avatar: Icon(
            _autoRefresh ? Icons.autorenew : Icons.pause_circle_outline,
            size: 16,
          ),
          onSelected: (val) {
            setState(() => _autoRefresh = val);
            _syncAutoRefresh();
          },
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: loading ? null : () => _loadQueues(),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(t(context, 'refresh')),
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const AdminStatusView.loading(title: '正在加载队列与任务监控');
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

    final data = overview;
    if (data == null || data.queues.isEmpty) {
      return AdminStatusView.empty(title: t(context, 'no_queues'));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.summary != null) _buildSummarySection(data.summary!),
          const SizedBox(height: 12),
          _buildActiveTasksCard(data.activeTasks),
          const SizedBox(height: 12),
          if (AdminBreakpoints.isPhone(context)) ...[
            _buildQueueListCard(data.queues),
            const SizedBox(height: 12),
            _buildOutboxIssuesCard(data.recentOutboxIssues),
            const SizedBox(height: 12),
            _buildRecentEventsCard(data.recentEvents),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildQueueListCard(data.queues)),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildOutboxIssuesCard(data.recentOutboxIssues),
                      const SizedBox(height: 12),
                      _buildRecentEventsCard(data.recentEvents),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummarySection(QueueSummary summary) {
    final brokerColor = summary.brokerConnected ? Colors.green : Colors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildStatChip(
                  summary.brokerConnected
                      ? Icons.check_circle_outline
                      : Icons.cloud_off,
                  summary.brokerConnected
                      ? 'RabbitMQ 已连接 (${summary.brokerHost}:${summary.brokerPort})'
                      : 'RabbitMQ 连接失败 (${summary.brokerHost}:${summary.brokerPort})',
                  brokerColor,
                ),
                _buildStatChip(
                  Icons.hub_outlined,
                  '节点角色: ${summary.nodeRole}',
                  Colors.blueGrey,
                ),
                _buildStatChip(
                  Icons.outbox_outlined,
                  'Outbox: ${summary.outboxEnabled ? '已启用' : '已关闭'}',
                  summary.outboxEnabled ? Colors.teal : Colors.red,
                ),
                if (summary.checkedAt != null)
                  Text(
                    '更新于 ${DateTimeFormatter.formatDateTime(context, summary.checkedAt!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
            if (!summary.brokerConnected &&
                summary.brokerError != null &&
                summary.brokerError!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Broker 错误：${summary.brokerError}',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMetricTile(
                  '活跃执行任务',
                  '${summary.activeTaskCount}',
                  summary.activeTaskCount > 0 ? Colors.indigo : Colors.grey,
                  Icons.play_circle_outline,
                ),
                _buildMetricTile(
                  '审核中评论',
                  '${summary.reviewingCommentsCount}',
                  summary.reviewingCommentsCount > 0
                      ? Colors.orange
                      : Colors.grey,
                  Icons.rate_review_outlined,
                ),
                _buildMetricTile(
                  'Outbox 待发/投递中',
                  '${summary.outboxPending} / ${summary.outboxInFlight}',
                  (summary.outboxPending + summary.outboxInFlight) > 0
                      ? Colors.amber.shade800
                      : Colors.green,
                  Icons.schedule_send_outlined,
                ),
                _buildMetricTile(
                  'Outbox 失败',
                  '${summary.outboxFailed}',
                  summary.outboxFailed > 0 ? Colors.red : Colors.green,
                  Icons.error_outline,
                ),
                _buildMetricTile(
                  '24h 已投递',
                  '${summary.outboxPublished24h}',
                  Colors.teal,
                  Icons.done_all,
                ),
                _buildMetricTile(
                  '未处理死信',
                  '${summary.unprocessedDeadLetters}',
                  summary.unprocessedDeadLetters > 0
                      ? Colors.red
                      : Colors.green,
                  Icons.mark_email_unread_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTasksCard(List<ActiveQueueTask> tasks) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.memory, size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  '正在执行的实时任务 (${tasks.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '当前工作线程空闲，没有正在执行中的 AI 队列任务。',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final task = tasks[index];
                final isCommentAudit =
                    task.targetType == 'COMMENT' &&
                    task.queueName == 'ai-audit-tasks';
                final isAborting =
                    task.aborting ||
                    _abortingCommentIds.contains(task.targetId);
                final slow = task.elapsedSeconds > 60;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (slow ? Colors.deepOrange : Colors.indigo)
                        .withValues(alpha: 0.15),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: slow ? Colors.deepOrange : Colors.indigo,
                      ),
                    ),
                  ),
                  title: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${task.queueName} · ${task.targetType} #${task.targetId}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      _buildStatChip(
                        Icons.bolt,
                        task.stageLabel,
                        slow ? Colors.deepOrange : Colors.indigo,
                      ),
                      _buildStatChip(
                        Icons.timer_outlined,
                        _formatDuration(task.elapsedSeconds),
                        slow ? Colors.deepOrange : Colors.blueGrey,
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${task.stageDetail}（重试 ${task.retryCount}/${task.maxRetries}）',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  trailing: isCommentAudit
                      ? OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepOrange,
                            side: const BorderSide(color: Colors.deepOrange),
                          ),
                          onPressed: isAborting
                              ? null
                              : () => _abortActiveCommentAudit(task.targetId),
                          icon: const Icon(
                            Icons.stop_circle_outlined,
                            size: 16,
                          ),
                          label: Text(isAborting ? '中断中...' : '强制中断'),
                        )
                      : null,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQueueListCard(List<QueueInfo> items) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.queue, size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  '${t(context, 'queue_list')} (${items.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _buildQueueTile(items[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTile(QueueInfo queue) {
    final color = _getQueueColor(queue);
    final canSendTest =
        !queue.isDeadLetter &&
        (queue.name == 'ai-audit-tasks' || queue.name == 'ai-summary-tasks');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(_getQueueIcon(queue.name), color: color, size: 20),
      ),
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(queue.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              _getQueueStatusLabel(queue),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          if (queue.description.isNotEmpty)
            Text(
              queue.description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildStatChip(
                  Icons.inbox_outlined,
                  '积压 ${queue.messageCount}',
                  queue.messageCount > 0 ? Colors.orange : Colors.green,
                ),
                _buildStatChip(
                  Icons.people_outline,
                  '消费者 ${queue.consumerCount}',
                  queue.consumerCount > 0 ? Colors.blue : Colors.grey,
                ),
                if (queue.activeTaskCount > 0)
                  _buildStatChip(
                    Icons.play_arrow,
                    '执行中 ${queue.activeTaskCount}',
                    Colors.indigo,
                  ),
                if (queue.outboxPendingCount > 0 ||
                    queue.outboxInFlightCount > 0)
                  _buildStatChip(
                    Icons.schedule_send_outlined,
                    'Outbox 待发 ${queue.outboxPendingCount + queue.outboxInFlightCount}',
                    Colors.amber.shade800,
                  ),
                if (queue.outboxFailedCount > 0)
                  _buildStatChip(
                    Icons.error_outline,
                    'Outbox 失败 ${queue.outboxFailedCount}',
                    Colors.red,
                  ),
                if (queue.unprocessedDeadLetterCount > 0)
                  _buildStatChip(
                    Icons.mark_email_unread_outlined,
                    '未处理死信 ${queue.unprocessedDeadLetterCount}',
                    Colors.red,
                  ),
              ],
            ),
            if (queue.error != null && queue.error!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                queue.error!,
                style: const TextStyle(fontSize: 11.5, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      trailing: canSendTest
          ? (AdminBreakpoints.isPhone(context)
                ? IconButton(
                    onPressed: () => _publishTestMessage(queue),
                    icon: const Icon(Icons.send),
                    tooltip: t(context, 'send_test'),
                  )
                : FilledButton.tonal(
                    onPressed: () => _publishTestMessage(queue),
                    child: Text(t(context, 'send_test')),
                  ))
          : null,
    );
  }

  Widget _buildOutboxIssuesCard(List<OutboxIssueItem> issues) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: issues.isEmpty ? Colors.green : Colors.deepOrange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Outbox 投递异常 / 重试 (${issues.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (issues.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Outbox 投递通道正常，当前无失败或重试中的任务。',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: issues.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = issues[index];
                final isFailed = item.status == 'FAILED';
                final color = isFailed ? Colors.red : Colors.deepOrange;
                return ListTile(
                  dense: true,
                  title: Text(
                    '${item.eventType} · ${item.aggregateType} #${item.aggregateId}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '状态: ${item.status} · 已尝试 ${item.attemptCount} 次',
                        style: TextStyle(fontSize: 11.5, color: color),
                      ),
                      if (item.lastError != null && item.lastError!.isNotEmpty)
                        Text(
                          item.lastError!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentEventsCard(List<RecentQueueEvent> events) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.history, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  '最近任务执行记录 (${events.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '应用启动以来暂无已完成的 AI 队列任务记录。',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ev = events[index];
                final color = switch (ev.status) {
                  'SUCCESS' => Colors.green,
                  'ABORTED' => Colors.amber.shade800,
                  'RETRYING' => Colors.deepOrange,
                  _ => Colors.red,
                };
                return ListTile(
                  dense: true,
                  leading: Icon(
                    ev.status == 'SUCCESS'
                        ? Icons.check_circle_outline
                        : (ev.status == 'ABORTED'
                              ? Icons.stop_circle_outlined
                              : Icons.error_outline),
                    color: color,
                    size: 18,
                  ),
                  title: Text(
                    '${ev.queueName} · ${ev.targetType} #${ev.targetId} (${ev.durationMs}ms)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ev.detail,
                        style: TextStyle(fontSize: 11.5, color: color),
                      ),
                      if (ev.error != null && ev.error!.isNotEmpty)
                        Text(
                          ev.error!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
                  trailing: ev.finishedAt != null
                      ? Text(
                          DateTimeFormatter.formatDateTime(
                            context,
                            ev.finishedAt!,
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        )
                      : null,
                );
              },
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
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
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
              AdminFeedback.showSnackBar(
                context,
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
