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

class _AiProvidersPageState extends State<AiProvidersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<AiProviderConfig> _configs = [];

  // 测试相关
  AiProviderConfig? _selectedTestConfig;
  final _systemPromptCtrl = TextEditingController();
  final _testPromptCtrl = TextEditingController();
  String _testReasoning = '';
  String _testOutput = '';
  bool _testing = false;
  bool _testStream = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _systemPromptCtrl.dispose();
    _testPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.listAiProviders();
      if (mounted) {
        setState(() {
          _configs = list;
          if (_selectedTestConfig == null && _configs.isNotEmpty) {
            _selectedTestConfig = _configs.first;
          } else if (_selectedTestConfig != null) {
            final idx = _configs.indexWhere((c) =>
            c.id == _selectedTestConfig!.id);
            if (idx != -1) {
              _selectedTestConfig = _configs[idx];
            } else {
              _selectedTestConfig = _configs.isNotEmpty ? _configs.first : null;
            }
          }
        });
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig(int? id, AiProviderConfigUpdateRequest req) async {
    try {
      if (id == null || id == 0) {
        await widget.api.createAiProvider(req);
      } else {
        await widget.api.updateAiProvider(id, req);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('保存成功'), backgroundColor: Colors.green),
      );
      _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('失败：$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteConfig(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('删除确认'),
            content: const Text('确定要删除这个配置吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      try {
        await widget.api.deleteAiProvider(id);
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showConfigDialog(AiProviderConfig? existing, String type) {
    var name = existing?.name ?? '';
    var provider = existing?.provider ?? '';
    var endpoint = existing?.endpoint ?? '';
    var model = existing?.model ?? '';
    var apiKey = existing?.apiKey ?? '';
    var configText = existing?.config ?? '';
    var enabled = existing?.enabled ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existing == null ? '添加${type == "PROVIDER"
                  ? "提供商"
                  : "轮询组"}' : '编辑配置'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                          labelText: '名称 (标识这个配置)'),
                      controller: TextEditingController(text: name)
                        ..selection = TextSelection.collapsed(offset: name
                            .length),
                      onChanged: (v) => name = v,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('是否启用'),
                      value: enabled,
                      onChanged: (v) => setState(() => enabled = v),
                    ),
                    if (type == 'PROVIDER') ...[
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: '提供商 (供应商类型)',
                          hintText: '例如: OPENAI, CHATGLM (OpenAI V4), OLLAMA',
                        ),
                        controller: TextEditingController(text: provider)
                          ..selection = TextSelection.collapsed(
                              offset: provider.length),
                        onChanged: (v) => provider = v,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'API Endpoint (接口地址)',
                          hintText: 'ChatGLM: https://open.bigmodel.cn/api/paas/v4/',
                        ),
                        controller: TextEditingController(text: endpoint)
                          ..selection = TextSelection.collapsed(
                              offset: endpoint.length),
                        onChanged: (v) => endpoint = v,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                            labelText: '模型名称'),
                        controller: TextEditingController(text: model)
                          ..selection = TextSelection.collapsed(
                              offset: model.length),
                        onChanged: (v) => model = v,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                            labelText: 'API Key (留空不修改)'),
                        controller: TextEditingController(text: ''),
                        onChanged: (v) => apiKey = v,
                      ),
                    ],
                    if (type == 'POLLING_GROUP') ...[
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                            labelText: 'JSON 配置 (algorithm, nodes)',
                            hintText: '{"algorithm":"WEIGHTED_ROUND_ROBIN","nodes":[{"id":1,"weight":5}]}'),
                        controller: TextEditingController(text: configText)
                          ..selection = TextSelection.collapsed(
                              offset: configText.length),
                        onChanged: (v) => configText = v,
                        maxLines: 4,
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context),
                    child: const Text('取消')),
                FilledButton(
                  onPressed: () {
                    final req = AiProviderConfigUpdateRequest(
                      type: type,
                      name: name,
                      provider: provider,
                      enabled: enabled,
                      endpoint: endpoint,
                      model: model,
                      apiKey: apiKey,
                      config: configText,
                    );
                    _saveConfig(existing?.id, req);
                    Navigator.pop(context);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _runTest() async {
    if (_selectedTestConfig == null) return;
    if (_testPromptCtrl.text
        .trim()
        .isEmpty) return;

    setState(() {
      _testing = true;
      _testReasoning = '';
      _testOutput = '';
    });

    try {
      final stream = widget.api.testAiStream(
        _selectedTestConfig!.id,
        prompt: _testPromptCtrl.text.trim(),
        systemPrompt: _systemPromptCtrl.text.trim(),
        stream: _testStream,
      );

      await for (final line in stream) {
        if (!mounted) break;
        try {
          final decoded = jsonDecode(line);
          final String type = decoded['type'] ?? 'content';
          final String content = decoded['content'] ?? '';

          setState(() {
            if (type == 'reasoning') {
              _testReasoning += content;
            } else {
              _testOutput += content;
            }
          });
        } catch (e) {
          if (mounted) {
            setState(() {
              _testOutput += '\n[数据解析失败]: $e\n原始数据: $line';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testOutput += '\n\n[测试出错]: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '提供商配置'),
            Tab(text: '轮询组配置'),
            Tab(text: '接口测试'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text('错误: $_error'))
              : TabBarView(
            controller: _tabController,
            children: [
              _buildConfigsList('PROVIDER'),
              _buildConfigsList('POLLING_GROUP'),
              _buildTestTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigsList(String type) {
    final list = _configs.where((c) => c.type == type).toList();
    return Stack(
      children: [
        if (list.isEmpty)
          const Center(child: Text('没有数据'))
        else
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final config = list[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text('${config.name} (ID: ${config.id})',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '状态: ${config.enabled ? '启用' : '禁用'}\n'
                          '${type == 'PROVIDER'
                          ? '提供商: ${config.provider}\n端点: ${config
                          .endpoint ?? '默认'}\n模型: ${config.model}'
                          : '组配置 JSON: ${config.config}'}'
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showConfigDialog(config, type),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteConfig(config.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            heroTag: 'fab_$type',
            onPressed: () => _showConfigDialog(null, type),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildTestTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('选择配置测试: ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              if (_configs.isEmpty)
                const Text('没有配置')
              else
                DropdownButton<AiProviderConfig>(
                  value: _selectedTestConfig,
                  items: _configs.map((c) =>
                      DropdownMenuItem(
                        value: c,
                        child: Text('${c.name} (${c.type == "PROVIDER"
                            ? c.provider
                            : "POLLING"})'),
                      )).toList(),
                  onChanged: (val) {
                    setState(() => _selectedTestConfig = val);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _systemPromptCtrl,
            decoration: const InputDecoration(
              labelText: 'System Prompt (系统提示词可选)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _testPromptCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'User Prompt (输入提示词)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('流式输出 (Streaming)'),
            subtitle: const Text(
                '开启后实时显示生成内容，关闭则等待完成后一次性显示'),
            value: _testStream,
            onChanged: (val) => setState(() => _testStream = val),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _testing ? null : _runTest,
              icon: _testing ? const SizedBox(width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)) : const Icon(
                  Icons.send),
              label: Text(_testing ? '测试中...' : '发送请求'),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
              '响应结果:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_testReasoning.isNotEmpty) ...[
                      Text('深度思考:', style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.indigo
                          .shade400)),
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(top: 4, bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          border: Border(left: BorderSide(
                              color: Colors.indigo.shade200, width: 4)),
                        ),
                        child: SelectableText(
                            _testReasoning, style: const TextStyle(
                            color: Colors.black87)),
                      ),
                    ],
                    SelectableText(_testOutput.isEmpty && !_testing
                        ? '等待请求结果...'
                        : _testOutput),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
