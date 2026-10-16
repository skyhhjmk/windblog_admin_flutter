import 'package:flutter/material.dart';
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
  });
  final String title;
  final String content;
  final bool html;
  @override
  State<LocalAiWritingDialog> createState() => _LocalAiWritingDialogState();
}

class _LocalAiWritingDialogState extends State<LocalAiWritingDialog> {
  final _codex = LocalCodex();
  final _instruction = TextEditingController();
  final _executable = TextEditingController(text: 'codex');
  final _output = TextEditingController();
  final _customModel = TextEditingController();
  final _prompt = TextEditingController(text: defaultWritingPrompt);
  List<String> _models = [];
  String _model = '';
  bool _customPrompt = false;
  String _action = '润色';

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    final models = await _codex.availableModels();
    if (mounted) setState(() => _models = models);
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

  Future<void> _generate() async {
    if ((_model == '__custom__' && _customModel.text.trim().isEmpty) ||
        (_customPrompt && _prompt.text.trim().isEmpty)) {
      setState(() => _error = '请填写自定义模型名称和提示词。');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ready = false;
    });
    try {
      final result = await _codex.generate(
        buildWritingPrompt(
          template: _customPrompt ? _prompt.text : defaultWritingPrompt,
          task: _action,
          requirements: _instruction.text,
          title: widget.title,
          content: widget.content,
          html: widget.html,
        ),
        model: _model == '__custom__' ? _customModel.text : _model,
        executable: _executable.text,
      );
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('本机 AI 写作 · Codex'),
    content: SizedBox(
      width: 720,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '使用此设备已安装、已登录的 Codex CLI。文章内容会发送至 Codex 配置的模型服务，并非离线推理。结果经你采用后才写入编辑器，不会自动保存或发布。',
            ),
            const SizedBox(height: 16),
            if (!_codex.supported)
              const Text('当前平台无法直接启动 Codex，请使用 Linux、macOS 或 Windows 桌面客户端。'),
            TextField(
              controller: _executable,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Codex 可执行文件 / 绝对路径',
              ),
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
                ..._models.map(
                  (m) => DropdownMenuItem(value: m, child: Text(m)),
                ),
                const DropdownMenuItem(
                  value: '__custom__',
                  child: Text('自定义模型…'),
                ),
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
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _action,
              decoration: const InputDecoration(labelText: '写作任务'),
              items: [
                '起草',
                '润色',
                '续写',
                '摘要',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
        onPressed: _busy || !_codex.supported ? null : _generate,
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
