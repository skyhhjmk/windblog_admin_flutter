part of 'package:windblog_admin_flutter/main.dart';

class CodexCreatorPage extends StatefulWidget {
  const CodexCreatorPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<CodexCreatorPage> createState() => _CodexCreatorPageState();
}

class _CodexCreatorPageState extends State<CodexCreatorPage> {
  bool _loading = true;
  Map<String, dynamic>? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await widget.api.codexCreatorStatus();
      if (mounted) setState(() => _status = status);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _status?['connected'] == true;
    final serviceStatus = _status?['status'];
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Codex Creator', style: Theme.of(context).textTheme.headlineSmall),
                ),
                IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(connected ? Icons.check_circle : Icons.error,
                    color: connected ? Colors.green : Colors.orange),
                title: Text(connected ? '内部服务已连接' : '内部服务不可用'),
                subtitle: Text(_error ?? (serviceStatus?.toString() ?? '尚未读取状态')),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '这里展示连接状态。供应商、模型、工作流、任务队列、知识库、话题中心和 AI 专区的写操作仍受 WindBlog 管理权限、Codex Creator 私有 API、HMAC 签名和人工审批策略约束。',
                ),
              ),
            ),
            if (_loading) const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}
