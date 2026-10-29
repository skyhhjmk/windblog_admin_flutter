import 'package:flutter/material.dart';
import '../data/admin_api_client.dart';
import '../data/models.dart';
import '../services/local_codex/local_codex.dart';
import '../services/local_codex/writing_prompt.dart';

class LocalAiWritingResult {
  const LocalAiWritingResult(this.text, this.target);
  final String text;
  final String target;
}

class LocalAiWritingDialog extends StatefulWidget {
  const LocalAiWritingDialog({
    super.key,
    required this.title,
    required this.content,
    required this.html,
    this.api,
  });
  final String title;
  final String content;
  final bool html;
  final AdminApiClient? api;
  @override
  State<LocalAiWritingDialog> createState() => _LocalAiWritingDialogState();
}

class _LocalAiWritingDialogState extends State<LocalAiWritingDialog> {
  static const String _modeCodex = 'codex';
  static const String _modeProvider = 'provider';

  final _codex = LocalCodex();
  final _instruction = TextEditingController();
  final _executable = TextEditingController(text: 'codex');
  final _output = TextEditingController();
  final _customModel = TextEditingController();
  final _prompt = TextEditingController(text: defaultWritingPrompt);
  List<String> _models = [];
  List<AiProviderConfig> _providers = [];
  String _model = '';
  String _mode = _modeCodex;
  int? _providerId;
  bool _loadingProviders = false;
  bool _customPrompt = false;
  String _action = '润色';

  @override
  void initState() {
    super.initState();
    _loadModels();
    if (widget.api != null) _loadProviders();
  }

  Future<void> _loadModels() async {
    final models = await _codex.availableModels();
    if (mounted) setState(() => _models = models);
  }

  Future<void> _loadProviders() async {
    final api = widget.api;
    if (api == null) return;
    setState(() => _loadingProviders = true);
    try {
      final providers = await api.listAiProviders();
      if (!mounted) return;
      final enabled = providers.where((provider) => provider.enabled).toList();
      setState(() {
        _providers = enabled;
        _providerId ??= enabled.isEmpty ? null : enabled.first.id;
        _loadingProviders = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProviders = false);
    }
  }

  String? _error;
  bool _busy = false;
  bool _ready = false;

  @override
  void dispose() {
    _codex.cancel();
    _instruction.dispose();
    _executable.dispose();
    _output.dispose();
    _customModel.dispose();
    _prompt.dispose();
    super.dispose();
  }

  bool get _providerMode => _mode == _modeProvider;

  String _providerLabel(AiProviderConfig provider) {
    final kind = provider.type == 'POLLING_GROUP' ? '轮询组' : '提供商';
    final model = provider.model == null || provider.model!.isEmpty
        ? provider.provider
        : '${provider.provider} · ${provider.model}';
    return '${provider.name}（$kind / $model）';
  }

  Future<void> _generate() async {
    if (!_providerMode &&
        ((_model == '__custom__' && _customModel.text.trim().isEmpty) ||
            (_customPrompt && _prompt.text.trim().isEmpty))) {
      setState(() => _error = '请填写自定义模型名称和提示词。');
      return;
    }
    if (_providerMode && widget.api == null) {
      setState(() => _error = '当前页面未连接后端，无法使用 API 提供商模式。');
      return;
    }
    if (_providerMode && _providerId == null) {
      setState(() => _error = '没有可用的 AI 提供商，请先在“AI 供应商”中配置。');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ready = false;
    });
    try {
      final fullPrompt = buildWritingPrompt(
        template: _customPrompt ? _prompt.text : defaultWritingPrompt,
        task: _action,
        requirements: _instruction.text,
        title: widget.title,
        content: widget.content,
        html: widget.html,
      );
      String result;
      if (_providerMode) {
        final completion = await widget.api!.completeAi(
          providerId: _providerId,
          prompt: fullPrompt,
          systemPrompt:
              '你是严谨的中文技术博客写作助手。只输出可直接放入文章的正文，'
              '保留 Markdown 结构与代码块，不要解释你的思考过程。',
        );
        result = completion.text;
      } else {
        result = await _codex.generate(
          fullPrompt,
          model: _model == '__custom__' ? _customModel.text : _model,
          executable: _executable.text,
        );
      }
      if (mounted) {
        setState(() {
          _output.text = result;
          _ready = true;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _modeSelector() {
    return SegmentedButton<String>(
      segments: [
        const ButtonSegment(
          value: _modeCodex,
          icon: Icon(Icons.terminal, size: 16),
          label: Text('Codex CLI'),
        ),
        ButtonSegment(
          value: _modeProvider,
          icon: const Icon(Icons.cloud_outlined, size: 16),
          label: const Text('API 提供商'),
          enabled: widget.api != null,
        ),
      ],
      selected: {_mode},
      onSelectionChanged: _busy
          ? null
          : (values) => setState(() {
              _mode = values.first;
              _error = null;
              _ready = false;
            }),
    );
  }

  Widget _providerControls() {
    if (_loadingProviders) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (_providers.isEmpty) {
      return const Text('没有可用的 AI 提供商。请先在“系统设置 → AI 供应商”中添加提供商或轮询组。');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _providerId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'AI 提供商 / 轮询组',
            helperText: '轮询组会按配置的算法选择节点，并在失败时自动切换到下一个节点。',
          ),
          items: _providers
              .map(
                (provider) => DropdownMenuItem(
                  value: provider.id,
                  child: Text(
                    _providerLabel(provider),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _busy
              ? null
              : (value) => setState(() => _providerId = value),
        ),
      ],
    );
  }

  Widget _codexControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _executable,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'Codex 可执行文件 / 绝对路径'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _model,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '模型',
            helperText: '列表来自本机 Codex 缓存，实际可用性取决于当前账号和服务。',
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('跟随 Codex 默认配置')),
            ..._models.map((m) => DropdownMenuItem(value: m, child: Text(m))),
            const DropdownMenuItem(value: '__custom__', child: Text('自定义模型…')),
          ],
          onChanged: _busy ? null : (v) => setState(() => _model = v!),
        ),
        if (_model == '__custom__')
          TextField(
            controller: _customModel,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: '模型 ID',
              hintText: '填写当前 Codex 服务支持的模型名称',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 48;
    return AlertDialog(
      title: const Text('AI 写作助手'),
      content: SizedBox(
        width: maxWidth < 720 ? maxWidth : 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _modeSelector(),
              const SizedBox(height: 12),
              Text(
                _providerMode
                    ? '使用后端已配置的 AI 提供商或轮询组完成写作。内容会发送到对应模型服务；结果经你采用后才写入编辑器。'
                    : '使用此设备已安装、已登录的 Codex CLI。文章内容会发送至 Codex 配置的模型服务，并非离线推理。结果经你采用后才写入编辑器，不会自动保存或发布。',
              ),
              const SizedBox(height: 12),
              if (_providerMode)
                _providerControls()
              else ...[
                if (!_codex.supported)
                  const Text(
                    '当前平台无法直接启动 Codex，请使用 Linux、macOS 或 Windows 桌面客户端。',
                  ),
                _codexControls(),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _action,
                decoration: const InputDecoration(labelText: '写作任务'),
                items: ['起草', '润色', '续写', '摘要']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _action = v!;
                        _ready = false;
                      }),
              ),
              TextField(
                controller: _instruction,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '写作要求',
                  hintText: '例如：面向初学者，语气自然，保留代码示例',
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('高级选项 · 自定义提示词'),
                tilePadding: EdgeInsets.zero,
                children: [
                  SwitchListTile(
                    title: const Text('使用自定义提示词模板'),
                    subtitle: const Text('开启后替换完整默认提示词，写作任务仍决定结果采用到哪里。'),
                    value: _customPrompt,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _customPrompt = v),
                  ),
                  if (_customPrompt) ...[
                    const Text(
                      '可用变量：{{task}}、{{requirements}}、{{title}}、{{content}}、{{format}}、{{output_rules}}。仅插入模板中包含的内容。',
                    ),
                    TextField(
                      controller: _prompt,
                      enabled: !_busy,
                      minLines: 6,
                      maxLines: 14,
                      decoration: const InputDecoration(
                        labelText: '完整提示词模板',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(
                              () => _prompt.text = defaultWritingPrompt,
                            ),
                      child: const Text('恢复默认模板'),
                    ),
                  ],
                ],
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_ready)
                TextField(
                  controller: _output,
                  minLines: 8,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    labelText: '结果预览（可修改）',
                    border: OutlineInputBorder(),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_busy ? '取消任务并关闭' : '关闭'),
        ),
        FilledButton.tonal(
          onPressed:
              _busy ||
                  (!_providerMode && !_codex.supported) ||
                  (_providerMode && widget.api == null)
              ? null
              : _generate,
          child: const Text('生成'),
        ),
        if (_ready)
          FilledButton(
            onPressed: _busy
                ? null
                : () => Navigator.pop(
                    context,
                    LocalAiWritingResult(_output.text, _action),
                  ),
            child: Text(
              _action == '摘要'
                  ? '采用为摘要'
                  : _action == '续写'
                  ? '追加到正文'
                  : '替换正文',
            ),
          ),
      ],
    );
  }
}
