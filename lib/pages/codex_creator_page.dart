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
  final _endpointController = TextEditingController();
  final _sharedSecretController = TextEditingController();
  final _modelController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _enabled = true;
  String? _error;
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _config;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _sharedSecretController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    String? firstError;
    try {
      final config = await widget.api.codexCreatorConfig();
      if (mounted) {
        final hasDatabaseConfig = config['hasDatabaseConfig'] == true;
        setState(() {
          _config = config;
          _endpointController.text = config['endpoint']?.toString() ?? '';
          _modelController.text = config['model']?.toString() ?? '';
          _enabled = hasDatabaseConfig ? config['enabled'] == true : true;
        });
      }
    } on UnauthorizedException {
      widget.onAuthError();
      if (mounted) setState(() => _loading = false);
      return;
    } catch (error) {
      firstError = '读取连接配置失败：$error';
    }

    try {
      final status = await widget.api.codexCreatorStatus();
      if (mounted) setState(() => _status = status);
    } on UnauthorizedException {
      widget.onAuthError();
      if (mounted) setState(() => _loading = false);
      return;
    } catch (error) {
      firstError ??= '读取服务状态失败：$error';
    }

    if (mounted) {
      setState(() {
        _error = firstError;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final endpoint = _endpointController.text.trim();
    if (endpoint.isEmpty) {
      AdminFeedback.showSnackBar(
        context,
        const SnackBar(
          content: Text('请输入 Codex Creator 地址'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (mounted) setState(() => _saving = true);
    try {
      final stepUpToken = await AdminStepUpAuthorization.obtain(
        context,
        widget.api,
        title: '确认 Codex Creator 连接配置',
      );
      if (stepUpToken == null) return;

      final saved = await widget.api.updateCodexCreatorConfig(
        endpoint: endpoint,
        enabled: _enabled,
        sharedSecret: _sharedSecretController.text.trim().isEmpty
            ? null
            : _sharedSecretController.text.trim(),
        model: _modelController.text.trim(),
        stepUpToken: stepUpToken,
      );
      if (!mounted) return;
      _sharedSecretController.clear();
      setState(() => _config = saved);
      AdminFeedback.showSnackBar(
        context,
        const SnackBar(
          content: Text('连接配置已保存，密钥不会回显'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text('保存连接配置失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Codex Creator',
      actions: [
        IconButton(
          onPressed: _loading || _saving ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: '刷新状态',
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: AdminBreakpoints.pagePadding(context),
          ),
          children: [
            if (_error != null) ...[
              AlertBanner(message: _error!, type: AlertType.error),
              const SizedBox(height: 12),
            ],
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildConnectionCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final connected = _status?['connected'] == true;
    final runtime = _status?['status'] is Map
        ? Map<String, dynamic>.from(_status!['status'] as Map)
        : <String, dynamic>{};
    final lastError = runtime['lastError']?.toString() ?? '';
    final detail = _loading
        ? '正在读取 Codex Creator 状态…'
        : connected
        ? '服务健康检查已通过'
        : (lastError.isNotEmpty
              ? lastError
              : (_status?['error']?.toString() ?? '服务暂不可用'));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _loading
                  ? Icons.sync
                  : connected
                  ? Icons.check_circle
                  : Icons.error,
              color: _loading
                  ? Colors.blue
                  : connected
                  ? Colors.green
                  : Colors.orange,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loading
                        ? '正在检查内部服务'
                        : connected
                        ? '内部服务已连接'
                        : '内部服务不可用',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(detail),
                  if (_config != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '当前地址：${_config!['endpoint'] ?? '-'}\n'
                      '配置来源：${_config!['source'] == 'database' ? '后台保存' : '部署环境变量'}\n'
                      '共享密钥：${_config!['sharedSecretConfigured'] == true ? '已配置（已隐藏）' : '未配置'}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    final secretConfigured = _config?['sharedSecretConfigured'] == true;
    final editable = !_loading && !_saving;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AdminBreakpoints.isPhone(context) ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '连接配置',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '配置 WindBlog 访问 Codex Creator 私有 API 所需的地址和 HMAC 共享密钥。保存后会同步用于状态检查、AI 请求和事件投递。',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _endpointController,
              enabled: editable,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Codex Creator 地址',
                hintText: 'http://codex-creator:8681',
                helperText: '只填写服务根地址，不要附加 /internal/health 或 API 路径',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _sharedSecretController,
              enabled: editable,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'HMAC 共享密钥',
                hintText: secretConfigured ? '已配置，留空保持不变' : '请输入共享密钥',
                helperText: '仅在修改时输入；现有密钥不会从服务器回显。',
                prefixIcon: const Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _modelController,
              enabled: editable,
              decoration: const InputDecoration(
                labelText: '默认模型 Profile（可选）',
                hintText: 'codex-default',
                helperText: '留空时使用 Codex Creator 的默认 Profile。',
                prefixIcon: Icon(Icons.auto_awesome),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用 Codex Creator'),
              subtitle: const Text('启用后，AI 选择器可以优先使用该内部供应商。'),
              value: _enabled,
              onChanged: !editable
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _loading || _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? '保存中…' : '保存连接配置'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
