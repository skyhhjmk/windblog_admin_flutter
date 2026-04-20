part of 'package:windblog_admin_flutter/main.dart';

class AiProvidersPage extends StatefulWidget {
  const AiProvidersPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<AiProvidersPage> createState() => _AiProvidersPageState();
}

class _AiProvidersPageState extends State<AiProvidersPage> {
  final List<_ProviderForm> forms = [];
  bool loading = true;
  String? error;

  // 已知的三个提供商，确保没有配置时也能显示
  static const List<String> knownProviders = ['OPENAI', 'CHATGLM', 'OLLAMA'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final form in forms) {
      form.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final configs = await widget.api.listAiProviders();

      // 确保三个提供商都显示，即使数据库里没有现有记录
      final configsByProvider = <String, AiProviderConfig>{};
      for (final config in configs) {
        configsByProvider[config.provider.toUpperCase()] = config;
      }

      final allForms = <_ProviderForm>[];
      for (final providerName in knownProviders) {
        if (configsByProvider.containsKey(providerName)) {
          allForms.add(
              _ProviderForm.fromConfig(configsByProvider[providerName]!));
        } else {
          // 提供商在数据库中不存在，创建一个空的表单
          allForms.add(_ProviderForm.empty(providerName));
        }
      }

      setState(() {
        for (final form in forms) {
          form.dispose();
        }
        forms
          ..clear()
          ..addAll(allForms);
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _save(_ProviderForm form) async {
    if (form.saving) return;
    if (!mounted) return;
    setState(() => form.saving = true);
    try {
      final updated = await widget.api.updateAiProvider(
        form.provider,
        AiProviderConfigUpdateRequest(
          enabled: form.enabled,
          endpoint: form.endpointCtrl.text.trim(),
          model: form.modelCtrl.text.trim(),
          apiKey: form.apiKeyCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        form.enabled = updated.enabled;
        form.endpointCtrl.text = updated.endpoint ?? '';
        form.modelCtrl.text = updated.model ?? '';
        // API Key 保存后不回填，避免明文展示
        form.updatedAt = updated.updatedAt;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('保存成功'), backgroundColor: Colors.green),
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => form.saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('加载失败：$error'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: forms.length,
      itemBuilder: (context, index) {
        final form = forms[index];
        return _buildProviderCard(form);
      },
    );
  }

  Widget _buildProviderCard(_ProviderForm form) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildProviderIcon(form.provider),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _providerDisplayName(form.provider),
                      style: Theme
                          .of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _providerDescription(form.provider),
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(form.enabled ? '已启用' : '已禁用',
                          style: TextStyle(
                            color: form.enabled ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: form.enabled,
                          onChanged: (value) =>
                              setState(() => form.enabled = value),
                        ),
                      ],
                    ),
                    if (form.updatedAt != null)
                      Text(
                        '最后更新：${_formatDateTime(form.updatedAt!)}',
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            TextField(
              controller: form.endpointCtrl,
              decoration: InputDecoration(
                labelText: 'API Endpoint（接口地址）',
                border: const OutlineInputBorder(),
                hintText: _endpointHint(form.provider),
                prefixIcon: const Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: form.modelCtrl,
              decoration: InputDecoration(
                labelText: '模型名称',
                border: const OutlineInputBorder(),
                hintText: _modelHint(form.provider),
                prefixIcon: const Icon(Icons.smart_toy_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: form.apiKeyCtrl,
              obscureText: !form.showApiKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: const OutlineInputBorder(),
                hintText: '输入 API Key（留空则不更改）',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(form.showApiKey ? Icons.visibility_off : Icons
                      .visibility),
                  onPressed: () =>
                      setState(() => form.showApiKey = !form.showApiKey),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.tonal(
                  onPressed: form.saving ? null : () => _save(form),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (form.saving) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                      ] else
                        const Icon(Icons.save_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(form.saving ? '保存中...' : '保存设置'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderIcon(String provider) {
    final color = _providerColor(provider);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_providerIcon(provider), color: color, size: 22),
    );
  }

  Color _providerColor(String provider) {
    switch (provider.toUpperCase()) {
      case 'OPENAI':
        return const Color(0xFF10A37F);
      case 'CHATGLM':
        return const Color(0xFF5B5EA6);
      case 'OLLAMA':
        return const Color(0xFFE07B39);
      default:
        return Colors.grey;
    }
  }

  IconData _providerIcon(String provider) {
    switch (provider.toUpperCase()) {
      case 'OPENAI':
        return Icons.auto_awesome;
      case 'CHATGLM':
        return Icons.chat_bubble_outline;
      case 'OLLAMA':
        return Icons.computer;
      default:
        return Icons.smart_toy;
    }
  }

  String _providerDisplayName(String provider) {
    switch (provider.toUpperCase()) {
      case 'OPENAI':
        return 'OpenAI 兼容接口';
      case 'CHATGLM':
        return 'ChatGLM（智谱AI）';
      case 'OLLAMA':
        return 'Ollama（本地模型）';
      default:
        return provider;
    }
  }

  String _providerDescription(String provider) {
    switch (provider.toUpperCase()) {
      case 'OPENAI':
        return '支持 OpenAI / Azure / 通义千问等兼容接口';
      case 'CHATGLM':
        return '智谱 AI 官方 GLM 系列模型';
      case 'OLLAMA':
        return '本地部署的开源模型（如 llama、qwen）';
      default:
        return '';
    }
  }

  String _endpointHint(String provider) {
    switch (provider.toUpperCase()) {
      case 'OPENAI':
        return 'https://api.openai.com/v1';
      case 'CHATGLM':
        return '留空默认使用官方接口，私有部署可填写';
      case 'OLLAMA':
        return 'http://127.0.0.1:11434/v1';
      default:
        return 'https://...';
    }
  }

  String _modelHint(String provider) {
    switch (provider.toUpperCase()) {
      case 'OPENAI':
        return 'gpt-4o-mini';
      case 'CHATGLM':
        return 'glm-4-flash-250414';
      case 'OLLAMA':
        return 'qwen2.5:7b';
      default:
        return '';
    }
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day
        .toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute
        .toString()
        .padLeft(2, '0')}';
  }
}

class _ProviderForm {
  _ProviderForm({
    required this.provider,
    required this.endpointCtrl,
    required this.modelCtrl,
    required this.apiKeyCtrl,
    this.enabled = false,
    this.updatedAt,
  });

  factory _ProviderForm.fromConfig(AiProviderConfig config) {
    return _ProviderForm(
      provider: config.provider,
      endpointCtrl: TextEditingController(text: config.endpoint ?? ''),
      modelCtrl: TextEditingController(text: config.model ?? ''),
      apiKeyCtrl: TextEditingController(text: ''),
      enabled: config.enabled,
      updatedAt: config.updatedAt,
    );
  }

  factory _ProviderForm.empty(String providerName) {
    return _ProviderForm(
      provider: providerName,
      endpointCtrl: TextEditingController(),
      modelCtrl: TextEditingController(),
      apiKeyCtrl: TextEditingController(),
    );
  }

  final String provider;
  final TextEditingController endpointCtrl;
  final TextEditingController modelCtrl;
  final TextEditingController apiKeyCtrl;
  bool enabled;
  bool saving = false;
  bool showApiKey = false;
  DateTime? updatedAt;

  void dispose() {
    endpointCtrl.dispose();
    modelCtrl.dispose();
    apiKeyCtrl.dispose();
  }
}
