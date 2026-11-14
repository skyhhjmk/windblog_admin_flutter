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

  // 用量统计相关
  AiUsageSummary? _usageSummary;
  bool _loadingUsage = false;
  String? _usageError;
  int _usageDays = 30;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 3 &&
          _usageSummary == null &&
          !_loadingUsage) {
        _loadUsage();
      }
    });
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
            final idx = _configs.indexWhere(
              (c) => c.id == _selectedTestConfig!.id,
            );
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
      AdminFeedback.showSnackBar(
        context,
        SnackBar(
          content: Text(t(context, 'save_success')),
          backgroundColor: Colors.green,
        ),
      );
      _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(
        context,
        SnackBar(
          content: Text('${t(context, 'save_failed')}$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteConfig(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'ai_delete_confirm_title')),
        content: Text(t(context, 'ai_delete_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
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
        AdminFeedback.showSnackBar(
          context,
          SnackBar(
            content: Text('${t(context, 'delete_failed')}$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static const Map<String, Map<String, String>> _providerOptions = {
    'OpenAI': {'provider': 'OPENAI', 'endpoint': 'https://api.openai.com/v1'},
    'DeepSeek': {'provider': 'OPENAI', 'endpoint': 'https://api.deepseek.com'},
    'SiliconFlow': {
      'provider': 'OPENAI',
      'endpoint': 'https://api.siliconflow.cn/v1',
    },
    'Groq': {
      'provider': 'OPENAI',
      'endpoint': 'https://api.groq.com/openai/v1',
    },
    'Cerebras': {
      'provider': 'CEREBRAS',
      'endpoint': 'https://api.cerebras.ai/v1',
    },
    'ChatGLM (SDK)': {
      'provider': 'CHATGLM',
      'endpoint': 'https://open.bigmodel.cn/api/paas/v4',
    },
    'Ollama (Local)': {
      'provider': 'OLLAMA',
      'endpoint': 'http://localhost:11434',
    },
    'Custom (OpenAI Compatible)': {'provider': 'OPENAI', 'endpoint': ''},
  };

  void _showConfigDialog(AiProviderConfig? existing, String type) {
    var name = existing?.name ?? '';
    var provider = existing?.provider ?? 'OPENAI';
    var endpoint = existing?.endpoint ?? 'https://api.openai.com/v1';
    var model = existing?.model ?? '';
    var rateLimitPerMinute = existing?.rateLimitPerMinute ?? 0;
    var concurrencyLimit = existing?.concurrencyLimit ?? 0;
    var apiKey = existing?.apiKey ?? '';
    var configText = existing?.config ?? '';
    var enabled = existing?.enabled ?? true;

    // 解析附加配置
    bool forceEndpoint = false;
    bool proxyEnabled = false;
    String proxyType = 'HTTP';
    String proxyHost = '127.0.0.1';
    int proxyPort = 7890;
    final Map<String, Map<String, dynamic>> modelCapabilities = {};
    const supportedModalities = ['TEXT', 'IMAGE', 'AUDIO', 'VIDEO'];

    try {
      if (configText.isNotEmpty) {
        final map = jsonDecode(configText);
        if (map is Map) {
          if (map.containsKey('force_endpoint')) {
            forceEndpoint = map['force_endpoint'] == true;
          }
          if (map.containsKey('proxy_enabled')) {
            proxyEnabled = map['proxy_enabled'] == true;
          }
          if (map.containsKey('proxy_type')) {
            proxyType = map['proxy_type']?.toString() ?? 'HTTP';
          }
          if (map.containsKey('proxy_host')) {
            proxyHost = map['proxy_host']?.toString() ?? '127.0.0.1';
          }
          if (map.containsKey('proxy_port')) {
            proxyPort =
                int.tryParse(map['proxy_port']?.toString() ?? '7890') ?? 7890;
          }
          final rawCaps = map['modelCapabilities'];
          if (rawCaps is Map) {
            rawCaps.forEach((k, v) {
              if (k != null && v is Map) {
                modelCapabilities[k.toString()] = {
                  'contextWindow': v['contextWindow'],
                  'inputModalities': (v['inputModalities'] is List)
                      ? List<String>.from(
                          (v['inputModalities'] as List).map(
                            (e) => e.toString(),
                          ),
                        )
                      : <String>['TEXT'],
                  'outputModalities': (v['outputModalities'] is List)
                      ? List<String>.from(
                          (v['outputModalities'] as List).map(
                            (e) => e.toString(),
                          ),
                        )
                      : <String>['TEXT'],
                };
              }
            });
          }
        }
      }
    } catch (_) {}

    String capabilityTargetModel = model;
    Map<String, dynamic> ensureCapabilityFor(String target) {
      return modelCapabilities.putIfAbsent(target, () {
        return {
          'contextWindow': null,
          'inputModalities': <String>['TEXT'],
          'outputModalities': <String>['TEXT'],
        };
      });
    }

    // 尝试匹配预设选项
    String? selectedPreset;
    _providerOptions.forEach((key, value) {
      if (value['provider'] == provider &&
          (value['endpoint'] == endpoint ||
              (value['endpoint']!.isEmpty && endpoint.isNotEmpty))) {
        if (selectedPreset == null || value['endpoint'] == endpoint) {
          selectedPreset = key;
        }
      }
    });
    selectedPreset ??= 'Custom (OpenAI Compatible)';

    List<String> fetchedModels = [];
    bool fetchingModels = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> doFetchModels() async {
              setState(() => fetchingModels = true);
              try {
                // 构造临时配置用于测试，需要包含当前的 forceEndpoint 状态
                Map<String, dynamic> extraConfig = {};
                try {
                  if (configText.isNotEmpty) {
                    extraConfig = jsonDecode(configText);
                  }
                } catch (_) {}
                extraConfig['force_endpoint'] = forceEndpoint;
                extraConfig['proxy_enabled'] = proxyEnabled;
                extraConfig['proxy_type'] = proxyType;
                extraConfig['proxy_host'] = proxyHost;
                extraConfig['proxy_port'] = proxyPort;

                final req = AiProviderConfigUpdateRequest(
                  type: type,
                  name: name,
                  provider: provider,
                  enabled: enabled,
                  endpoint: endpoint,
                  model: model,
                  rateLimitPerMinute: rateLimitPerMinute,
                  concurrencyLimit: concurrencyLimit,
                  apiKey: apiKey,
                  config: jsonEncode(extraConfig),
                );
                final models = await widget.api.fetchAiModels(req);
                setState(() {
                  fetchedModels = models;
                  if (models.isNotEmpty && model.isEmpty) {
                    model = models.first;
                  }
                });
                if (context.mounted) {
                  AdminFeedback.showSnackBar(
                    context,
                    SnackBar(
                      content: Text(
                        '${t(context, 'fetch_models_success')} ${models.length}',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  AdminFeedback.showSnackBar(
                    context,
                    SnackBar(
                      content: Text('${t(context, 'fetch_models_failed')}: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                setState(() => fetchingModels = false);
              }
            }

            return AlertDialog(
              title: Text(
                existing == null
                    ? (type == "PROVIDER"
                          ? t(context, 'ai_add_provider')
                          : t(context, 'ai_add_polling_group'))
                    : t(context, 'ai_edit_config'),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          labelText: t(context, 'ai_config_name'),
                        ),
                        controller: TextEditingController(text: name)
                          ..selection = TextSelection.collapsed(
                            offset: name.length,
                          ),
                        onChanged: (v) => name = v,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: Text(t(context, 'ai_is_enabled')),
                        value: enabled,
                        onChanged: (v) => setState(() => enabled = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '每分钟请求上限',
                          hintText: '0 或留空表示不限制',
                          helperText: '该提供商/轮询组每分钟最多发起的 AI 请求次数',
                        ),
                        controller:
                            TextEditingController(
                                text: rateLimitPerMinute == 0
                                    ? ''
                                    : '$rateLimitPerMinute',
                              )
                              ..selection = TextSelection.collapsed(
                                offset: rateLimitPerMinute == 0
                                    ? 0
                                    : '$rateLimitPerMinute'.length,
                              ),
                        onChanged: (v) =>
                            rateLimitPerMinute = int.tryParse(v.trim()) ?? 0,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '最大并发数',
                          hintText: '0 或留空表示不限制',
                          helperText: '允许同时发送给该提供商的任务数量',
                        ),
                        controller:
                            TextEditingController(
                                text: concurrencyLimit == 0
                                    ? ''
                                    : '$concurrencyLimit',
                              )
                              ..selection = TextSelection.collapsed(
                                offset: concurrencyLimit == 0
                                    ? 0
                                    : '$concurrencyLimit'.length,
                              ),
                        onChanged: (v) =>
                            concurrencyLimit = int.tryParse(v.trim()) ?? 0,
                      ),
                      if (type == 'PROVIDER') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: t(context, 'ai_provider_type'),
                          ),
                          initialValue: selectedPreset,
                          items: _providerOptions.keys
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                selectedPreset = v;
                                provider = _providerOptions[v]!['provider']!;
                                if (_providerOptions[v]!['endpoint']!
                                    .isNotEmpty) {
                                  endpoint = _providerOptions[v]!['endpoint']!;
                                }
                                if (provider == 'CHATGLM') {
                                  forceEndpoint = false;
                                } else {
                                  forceEndpoint = true;
                                }
                              });
                            }
                          },
                        ),
                        if (provider == 'CHATGLM') ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: Text(
                              t(context, 'ai_force_endpoint'),
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              t(context, 'ai_force_endpoint_hint'),
                            ),
                            value: forceEndpoint,
                            onChanged: (v) => setState(() => forceEndpoint = v),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          enabled: provider != 'CHATGLM' || forceEndpoint,
                          decoration: InputDecoration(
                            labelText: t(context, 'api_base_url'),
                            hintText: t(context, 'ai_endpoint_hint_long'),
                            fillColor: (provider == 'CHATGLM' && !forceEndpoint)
                                ? Colors.grey.withAlpha(20)
                                : null,
                            filled: provider == 'CHATGLM' && !forceEndpoint,
                          ),
                          controller: TextEditingController(text: endpoint)
                            ..selection = TextSelection.collapsed(
                              offset: endpoint.length,
                            ),
                          onChanged: (v) => endpoint = v,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: InputDecoration(
                            labelText: t(context, 'ai_api_key_modify_hint'),
                          ),
                          obscureText: true,
                          controller: TextEditingController(text: apiKey)
                            ..selection = TextSelection.collapsed(
                              offset: apiKey.length,
                            ),
                          onChanged: (v) => apiKey = v,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: fetchedModels.isEmpty
                                  ? TextField(
                                      decoration: InputDecoration(
                                        labelText: t(context, 'ai_model_name'),
                                      ),
                                      controller:
                                          TextEditingController(text: model)
                                            ..selection =
                                                TextSelection.collapsed(
                                                  offset: model.length,
                                                ),
                                      onChanged: (v) => model = v,
                                    )
                                  : DropdownButtonFormField<String>(
                                      decoration: InputDecoration(
                                        labelText: t(context, 'ai_model_name'),
                                      ),
                                      initialValue:
                                          fetchedModels.contains(model)
                                          ? model
                                          : (fetchedModels.isNotEmpty
                                                ? fetchedModels.first
                                                : null),
                                      items: [
                                        ...fetchedModels.map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        ),
                                        const DropdownMenuItem(
                                          value: "__manual__",
                                          child: Text("-- 手动输入 (Manual) --"),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        if (v == "__manual__") {
                                          setState(() {
                                            fetchedModels = [];
                                          });
                                        } else if (v != null) {
                                          model = v;
                                        }
                                      },
                                    ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: fetchingModels ? null : doFetchModels,
                              icon: fetchingModels
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                              tooltip: t(context, 'ai_fetch_models_tooltip'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final candidateModels = <String>{
                              if (model.trim().isNotEmpty) model.trim(),
                              ...fetchedModels,
                              ...modelCapabilities.keys,
                            }.toList();
                            if (capabilityTargetModel.isEmpty &&
                                candidateModels.isNotEmpty) {
                              capabilityTargetModel = candidateModels.first;
                            }
                            final currentCap = capabilityTargetModel.isNotEmpty
                                ? ensureCapabilityFor(capabilityTargetModel)
                                : null;
                            final inputMods = currentCap != null
                                ? List<String>.from(
                                    currentCap['inputModalities'] ?? ['TEXT'],
                                  )
                                : <String>['TEXT'];
                            final outputMods = currentCap != null
                                ? List<String>.from(
                                    currentCap['outputModalities'] ?? ['TEXT'],
                                  )
                                : <String>['TEXT'];
                            final ctxVal =
                                currentCap?['contextWindow']?.toString() ?? '';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '模型能力设置（上下文与模态）',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (candidateModels.isEmpty)
                                  const Text(
                                    '请先填写或拉取模型名称后再配置上下文与模态。',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  )
                                else ...[
                                  DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: '配置目标模型',
                                    ),
                                    initialValue:
                                        candidateModels.contains(
                                          capabilityTargetModel,
                                        )
                                        ? capabilityTargetModel
                                        : candidateModels.first,
                                    items: candidateModels
                                        .map(
                                          (m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(m),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          capabilityTargetModel = v;
                                          ensureCapabilityFor(v);
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey('ctx_$capabilityTargetModel'),
                                    initialValue: ctxVal,
                                    decoration: const InputDecoration(
                                      labelText: '上下文大小 (Tokens)',
                                      hintText: '例如 128000',
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) {
                                      final cap = ensureCapabilityFor(
                                        capabilityTargetModel,
                                      );
                                      cap['contextWindow'] = int.tryParse(
                                        v.trim(),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '输入模态 (Input Modalities)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    children: supportedModalities.map((mod) {
                                      final selected = inputMods.contains(mod);
                                      return FilterChip(
                                        label: Text(mod),
                                        selected: selected,
                                        onSelected: (on) {
                                          setState(() {
                                            final cap = ensureCapabilityFor(
                                              capabilityTargetModel,
                                            );
                                            final next = List<String>.from(
                                              cap['inputModalities'] ??
                                                  ['TEXT'],
                                            );
                                            if (on) {
                                              if (!next.contains(mod)) {
                                                next.add(mod);
                                              }
                                            } else {
                                              next.remove(mod);
                                            }
                                            cap['inputModalities'] = next;
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '输出模态 (Output Modalities)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    children: supportedModalities.map((mod) {
                                      final selected = outputMods.contains(mod);
                                      return FilterChip(
                                        label: Text(mod),
                                        selected: selected,
                                        onSelected: (on) {
                                          setState(() {
                                            final cap = ensureCapabilityFor(
                                              capabilityTargetModel,
                                            );
                                            final next = List<String>.from(
                                              cap['outputModalities'] ??
                                                  ['TEXT'],
                                            );
                                            if (on) {
                                              if (!next.contains(mod)) {
                                                next.add(mod);
                                              }
                                            } else {
                                              next.remove(mod);
                                            }
                                            cap['outputModalities'] = next;
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text(
                            '启用代理 (Enable Proxy)',
                            style: TextStyle(fontSize: 14),
                          ),
                          value: proxyEnabled,
                          onChanged: (v) => setState(() => proxyEnabled = v),
                        ),
                        if (proxyEnabled) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: '代理类型',
                                  ),
                                  initialValue: proxyType,
                                  items: ['HTTP', 'SOCKS5']
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => proxyType = v);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: '代理主机',
                                    hintText: '127.0.0.1',
                                  ),
                                  controller:
                                      TextEditingController(text: proxyHost)
                                        ..selection = TextSelection.collapsed(
                                          offset: proxyHost.length,
                                        ),
                                  onChanged: (v) => proxyHost = v,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: '端口',
                                    hintText: '7890',
                                  ),
                                  keyboardType: TextInputType.number,
                                  controller:
                                      TextEditingController(
                                          text: proxyPort.toString(),
                                        )
                                        ..selection = TextSelection.collapsed(
                                          offset: proxyPort.toString().length,
                                        ),
                                  onChanged: (v) =>
                                      proxyPort = int.tryParse(v) ?? 7890,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                      if (type == 'POLLING_GROUP') ...[
                        const SizedBox(height: 12),
                        TextField(
                          decoration: InputDecoration(
                            labelText: t(context, 'ai_json_config'),
                            hintText: t(context, 'ai_json_config_hint'),
                          ),
                          controller: TextEditingController(text: configText)
                            ..selection = TextSelection.collapsed(
                              offset: configText.length,
                            ),
                          onChanged: (v) => configText = v,
                          maxLines: 4,
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
                    // 更新 JSON 配置
                    Map<String, dynamic> extraConfig = {};
                    try {
                      if (configText.isNotEmpty) {
                        extraConfig = jsonDecode(configText);
                      }
                    } catch (_) {}

                    if (provider == 'CHATGLM') {
                      extraConfig['force_endpoint'] = forceEndpoint;
                    } else {
                      extraConfig.remove('force_endpoint');
                    }
                    extraConfig['proxy_enabled'] = proxyEnabled;
                    extraConfig['proxy_type'] = proxyType;
                    extraConfig['proxy_host'] = proxyHost;
                    extraConfig['proxy_port'] = proxyPort;
                    if (modelCapabilities.isNotEmpty) {
                      extraConfig['modelCapabilities'] = modelCapabilities;
                    } else {
                      extraConfig.remove('modelCapabilities');
                    }

                    final req = AiProviderConfigUpdateRequest(
                      type: type,
                      name: name,
                      provider: provider,
                      enabled: enabled,
                      endpoint: endpoint,
                      model: model,
                      rateLimitPerMinute: rateLimitPerMinute,
                      concurrencyLimit: concurrencyLimit,
                      apiKey: apiKey,
                      config: extraConfig.isEmpty
                          ? null
                          : jsonEncode(extraConfig),
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
    if (_testPromptCtrl.text.trim().isEmpty) {
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
              _testOutput +=
                  '\n[${t(context, 'ai_data_parse_failed')}]: $e\n${t(context, 'ai_raw_data')}: $line';
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
            Tab(text: t(context, 'ai_usage_stats')),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text('${t(context, 'error')}: $_error'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildConfigsList('PROVIDER'),
                    _buildConfigsList('POLLING_GROUP'),
                    _buildTestTab(),
                    _buildUsageTab(),
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
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final config = list[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text(
                    '${config.name} (ID: ${config.id})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${t(context, 'status')}: ${config.enabled ? t(context, 'enabled') : t(context, 'disabled')}\n'
                    '${type == 'PROVIDER' ? '${t(context, 'ai_provider_type')}: ${config.provider}\n${t(context, 'api_base_url')}: ${config.endpoint ?? t(context, 'no_parent')}\n${t(context, 'ai_model_name')}: ${config.model}\n每分钟请求上限: ${config.rateLimitPerMinute ?? 0} · 最大并发: ${config.concurrencyLimit ?? '不限'}' : '${t(context, 'ai_json_config')}: ${config.config}\n每分钟请求上限: ${config.rateLimitPerMinute ?? 0} · 最大并发: ${config.concurrencyLimit ?? '不限'}'}',
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
              Text(
                t(context, 'ai_test_select_config'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              if (_configs.isEmpty)
                Text(t(context, 'ai_no_configs'))
              else
                DropdownButton<AiProviderConfig>(
                  value: _selectedTestConfig,
                  items: _configs
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            '${c.name} (${c.type == "PROVIDER" ? c.provider : "POLLING"})',
                          ),
                        ),
                      )
                      .toList(),
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
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
                _testing
                    ? t(context, 'ai_testing')
                    : t(context, 'ai_send_request'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t(context, 'ai_response_result'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_testReasoning.isNotEmpty) ...[
                      Text(
                        t(context, 'ai_deep_thinking'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade400,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(top: 4, bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          border: Border(
                            left: BorderSide(
                              color: Colors.indigo.shade200,
                              width: 4,
                            ),
                          ),
                        ),
                        child: SelectableText(
                          _testReasoning,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                    SelectableText(
                      _testOutput.isEmpty && !_testing
                          ? t(context, 'ai_waiting_result')
                          : _testOutput,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUsage() async {
    setState(() {
      _loadingUsage = true;
      _usageError = null;
    });
    try {
      final summary = await widget.api.getAiUsageSummary(days: _usageDays);
      if (mounted) {
        setState(() {
          _usageSummary = summary;
        });
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) setState(() => _usageError = '$e');
    } finally {
      if (mounted) setState(() => _loadingUsage = false);
    }
  }

  Widget _buildUsageTab() {
    if (_loadingUsage && _usageSummary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usageError != null && _usageSummary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${t(context, 'error')}: $_usageError'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadUsage,
              icon: const Icon(Icons.refresh),
              label: Text(t(context, 'retry')),
            ),
          ],
        ),
      );
    }

    final summary = _usageSummary;
    if (summary == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _loadUsage,
          icon: const Icon(Icons.refresh),
          label: Text(t(context, 'ai_usage_stats')),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t(context, 'ai_usage_stats'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              DropdownButton<int>(
                value: _usageDays,
                items: const [
                  DropdownMenuItem(value: 7, child: Text('最近 7 天 (7 Days)')),
                  DropdownMenuItem(value: 30, child: Text('最近 30 天 (30 Days)')),
                  DropdownMenuItem(value: 90, child: Text('最近 90 天 (90 Days)')),
                  DropdownMenuItem(value: 365, child: Text('最近 1 年 (1 Year)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _usageDays = v);
                    _loadUsage();
                  }
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadingUsage ? null : _loadUsage,
                icon: _loadingUsage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: t(context, 'refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth > 700
                  ? (constraints.maxWidth - 48) / 4
                  : (constraints.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildKpiCard(
                    cardWidth,
                    t(context, 'ai_total_requests'),
                    '${summary.totalRequests}',
                    subtitle:
                        '成功: ${summary.successRequests} / 失败: ${summary.failedRequests}',
                    icon: Icons.api,
                    color: Colors.blue,
                  ),
                  _buildKpiCard(
                    cardWidth,
                    t(context, 'ai_total_tokens'),
                    _formatTokens(summary.totalTokens),
                    subtitle: '精确: ${summary.totalTokens}',
                    icon: Icons.token,
                    color: Colors.purple,
                  ),
                  _buildKpiCard(
                    cardWidth,
                    t(context, 'ai_prompt_tokens'),
                    _formatTokens(summary.promptTokens),
                    subtitle: '精确: ${summary.promptTokens}',
                    icon: Icons.input,
                    color: Colors.teal,
                  ),
                  _buildKpiCard(
                    cardWidth,
                    t(context, 'ai_completion_tokens'),
                    _formatTokens(summary.completionTokens),
                    subtitle: '精确: ${summary.completionTokens}',
                    icon: Icons.output,
                    color: Colors.orange,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            t(context, 'ai_feature_breakdown'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: summary.features.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text(t(context, 'no_data'))),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('功能模块 (Feature)')),
                        DataColumn(label: Text('请求次数 (Requests)')),
                        DataColumn(label: Text('输入 Token (Prompt)')),
                        DataColumn(label: Text('输出 Token (Completion)')),
                        DataColumn(label: Text('总 Token (Total)')),
                      ],
                      rows: summary.features.map((f) {
                        return DataRow(
                          cells: [
                            DataCell(Text(_featureLabel(f.feature))),
                            DataCell(Text('${f.requests}')),
                            DataCell(Text('${f.promptTokens}')),
                            DataCell(Text('${f.completionTokens}')),
                            DataCell(Text('${f.totalTokens}')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            t(context, 'ai_provider_breakdown'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: summary.providers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text(t(context, 'no_data'))),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('提供商 (Provider)')),
                        DataColumn(label: Text('引擎 (Engine)')),
                        DataColumn(label: Text('模型 (Model)')),
                        DataColumn(label: Text('请求 (成功/失败)')),
                        DataColumn(label: Text('输入 Token')),
                        DataColumn(label: Text('输出 Token')),
                        DataColumn(label: Text('总 Token')),
                        DataColumn(label: Text('最近调用')),
                      ],
                      rows: summary.providers.map((p) {
                        return DataRow(
                          cells: [
                            DataCell(Text(p.providerName)),
                            DataCell(Text(p.providerType)),
                            DataCell(Text(p.model ?? '-')),
                            DataCell(
                              Text(
                                '${p.requests} (${p.successRequests}/${p.failedRequests})',
                              ),
                            ),
                            DataCell(Text('${p.promptTokens}')),
                            DataCell(Text('${p.completionTokens}')),
                            DataCell(Text('${p.totalTokens}')),
                            DataCell(
                              Text(
                                p.lastUsedAt != null
                                    ? _formatDateTime(p.lastUsedAt!)
                                    : '-',
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    double width,
    String title,
    String value, {
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTokens(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(2)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  String _featureLabel(String feature) {
    switch (feature.toLowerCase()) {
      case 'translate':
        return '文章翻译 (Translate)';
      case 'summarize':
        return '文章摘要 (Summarize)';
      case 'moderate':
        return '内容审核 (Moderate)';
      case 'topic':
        return '选题灵感 (Topic)';
      case 'writing':
      case 'assistant':
        return '写作助手 (Writing)';
      case 'slug':
        return 'Slug 生成 (Slug)';
      case 'test':
        return '连通性测试 (Test)';
      default:
        return feature;
    }
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
