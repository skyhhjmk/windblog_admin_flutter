part of 'package:windblog_admin_flutter/main.dart';

class DeadLetterPage extends StatefulWidget {
  const DeadLetterPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<DeadLetterPage> createState() => _DeadLetterPageState();
}

class _DeadLetterPageState extends State<DeadLetterPage> {
  List<DeadLetterMessageItem> messages = [];
  bool loading = false;
  int currentPage = 1;
  int pageSize = 20;
  int totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => loading = true);
    try {
      messages = await widget.api.listDeadLetterMessages(
        page: currentPage,
        pageSize: pageSize,
      );
      totalCount = messages.length;
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _retryMessage(DeadLetterMessageItem message) async {
    try {
      await widget.api.retryDeadLetterMessage(message.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('重试任务已提交')),
        );
      }
      await _loadMessages();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重试失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(DeadLetterMessageItem message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除此死信消息吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.api.deleteDeadLetterMessage(message.id);
      await _loadMessages();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
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
              const Text(
                '死信队列管理',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (messages.isEmpty) {
      return const Center(child: Text('暂无死信消息'));
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '消息 ID: ${message.id}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Chip(
                            label: Text(message.statusText),
                            backgroundColor: _getStatusColor(message.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('队列: ${message.queueName}'),
                      Text('重试次数: ${message.retryCount}'),
                      Text('创建时间: ${message.createdAt.toString()}'),
                      if (message.errorReason != null &&
                          message.errorReason!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '错误原因: ${message.errorReason}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _retryMessage(message),
                            icon: const Icon(Icons.replay),
                            label: const Text('重试'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _deleteMessage(message),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                                '删除', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(int status) {
    if (status == 0) {
      return Colors.orange.shade100;
    }
    if (status == 1) {
      return Colors.blue.shade100;
    }
    if (status == 2) {
      return Colors.green.shade100;
    }
    return Colors.grey.shade200;
  }
}
