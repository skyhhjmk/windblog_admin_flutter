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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(t(context, 'save_success')), backgroundColor: Colors.green),
      );
      _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'save_failed')}$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteConfig(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(t(context, 'ai_delete_confirm_title')),
            content: Text(t(context, 'ai_delete_confirm_desc')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: Text(t(context, 'cancel'))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: Text(t(context, 'delete')),
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
          SnackBar(content: Text('${t(context, 'delete_failed')}$e'), backgroundColor: Colors.red),
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
              title: Text(existing == null ? (type == "PROVIDER"
                  ? t(context, 'ai_add_provider')
                  : t(context, 'ai_add_polling_group')) : t(context, 'ai_edit_config')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                          labelText: t(context, 'ai_config_name')),
                      controller: TextEditingController(text: name)
                        ..selection = TextSelection.collapsed(offset: name
                            .length),
                      onChanged: (v) => name = v,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(t(context, 'ai_is_enabled')),
                      value: enabled,
                      onChanged: (v) => setState(() => enabled = v),
                    ),
                    if (type == 'PROVIDER') ...[
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: t(context, 'ai_provider_type'),
                          hintText: t(context, 'ai_provider_type_hint'),
                        ),
                        controller: TextEditingController(text: provider)
                          ..selection = TextSelection.collapsed(
                              offset: provider.length),
                        onChanged: (v) => provider = v,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: t(context, 'api_base_url'),
                          hintText: t(context, 'ai_endpoint_hint_long'),
                        ),
                        controller: TextEditingController(text: endpoint)
                          ..selection = TextSelection.collapsed(
                              offset: endpoint.length),
                        onChanged: (v) => endpoint = v,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                            labelText: t(context, 'ai_model_name')),
                        controller: TextEditingController(text: model)
                          ..selection = TextSelection.collapsed(
                              offset: model.length),
                        onChanged: (v) => model = v,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                            labelText: t(context, 'ai_api_key_modify_hint')),
                        controller: TextEditingController(text: ''),
                        onChanged: (v) => apiKey = v,
                      ),
                    ],
                    if (type == 'POLLING_GROUP') ...[
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                            labelText: t(context, 'ai_json_config'),
                            hintText: t(context, 'ai_json_config_hint')),
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
                    child: Text(t(context, 'cancel'))),
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
                  child: Text(t(context, 'save')),
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
        .isEmpty) {
      return;
    }

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
              _testOutput += '\n[${t(context, 'ai_data_parse_failed')}]: $e\n${t(context, 'ai_raw_data')}: $line';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testOutput += '\n\n[${t(context, 'ai_test_error')}]: $e';
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
          tabs: [
            Tab(text: t(context, 'ai_providers_config')),
            Tab(text: t(context, 'ai_polling_groups')),
            Tab(text: t(context, 'ai_test_api')),
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
          Center(child: Text(t(context, 'no_data')))
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
                      '${t(context, 'status')}: ${config.enabled ? t(context, 'enabled') : t(context, 'disabled')}\n'
                          '${type == 'PROVIDER'
                          ? '${t(context, 'ai_provider_type')}: ${config.provider}\n${t(context, 'api_base_url')}: ${config
                          .endpoint ?? t(context, 'no_parent')}\n${t(context, 'ai_model_name')}: ${config.model}'
                          : '${t(context, 'ai_json_config')}: ${config.config}'}'
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
              Text(t(context, 'ai_test_select_config'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              if (_configs.isEmpty)
                Text(t(context, 'ai_no_configs'))
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
            decoration: InputDecoration(
              labelText: t(context, 'ai_system_prompt'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _testPromptCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: t(context, 'ai_user_prompt'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text(t(context, 'ai_streaming')),
            subtitle: Text(t(context, 'ai_streaming_hint')),
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
              label: Text(_testing ? t(context, 'ai_testing') : t(context, 'ai_send_request')),
            ),
          ),
          const SizedBox(height: 16),
          Text(
              t(context, 'ai_response_result'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      Text(t(context, 'ai_deep_thinking'), style: TextStyle(
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
                        ? t(context, 'ai_waiting_result')
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
