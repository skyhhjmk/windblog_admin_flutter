part of 'package:windblog_admin_flutter/main.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  bool _loading = true;
  String? _error;
  List<SystemSetting> _settings = [];
  String? _selectedGroup;

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
      final loadedSettings = await widget.api.listSystemSettings();
      List<SystemSetting> list = [];
      for (SystemSetting loadedSetting in loadedSettings) {
        if (loadedSetting.configKey != 'elasticsearch') {
          list.add(loadedSetting);
        }
      }
      if (mounted) {
        setState(() {
          _settings = list;
          if (_settings.isNotEmpty) {
            bool selectedGroupExists = false;
            for (SystemSetting loadedSetting in _settings) {
              if (loadedSetting.groupName == _selectedGroup) {
                selectedGroupExists = true;
              }
            }
            if (!selectedGroupExists) {
              _selectedGroup = _settings.first.groupName;
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

  @override
  Widget build(BuildContext context) {
    if (_error != null && _settings.isEmpty) {
      return AdminPageScaffold(
        title: t(context, 'system_settings'),
        body: AdminStatusView.error(
          title: '加载系统设置失败',
          message: _error,
          action: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(t(context, 'refresh')),
          ),
        ),
      );
    }

    final groups = _settings.map((s) => s.groupName).toSet().toList();
    if (AdminBreakpoints.isPhone(context)) {
      return _buildPhoneLayout(groups);
    }

    return AdminPageScaffold(
      title: t(context, 'system_settings'),
      body: Row(
        children: [
          Card(
            child: SizedBox(
              width: AdminBreakpoints.isTablet(context) ? 180 : 220,
              child: ListView(
                children: groups.map((g) {
                  return ListTile(
                    title: Text(_getGroupLabel(g)),
                    selected: _selectedGroup == g,
                    onTap: () {
                      setState(() {
                        _selectedGroup = g;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildSettingsContent()),
        ],
      ),
    );
  }

  Widget _buildPhoneLayout(List<String> groups) {
    String? selectedGroupValue;
    if (groups.contains(_selectedGroup)) {
      selectedGroupValue = _selectedGroup;
    }

    return AdminPageScaffold(
      title: t(context, 'system_settings'),
      filters: groups.isEmpty
          ? null
          : AdminToolbar(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedGroupValue,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.tune),
                    ),
                    isExpanded: true,
                    items: groups.map((groupName) {
                      return DropdownMenuItem<String>(
                        value: groupName,
                        child: Text(
                          _getGroupLabel(groupName),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (groupName) {
                      if (groupName == null) {
                        return;
                      }
                      setState(() {
                        _selectedGroup = groupName;
                      });
                    },
                  ),
                ),
              ],
            ),
      body: _buildSettingsContent(),
    );
  }

  Widget _buildSettingsContent() {
    if (_loading) {
      return const AdminStatusView.loading(title: '正在加载系统设置');
    }

    if (_selectedGroup == null) {
      return const AdminStatusView.empty(title: '请选择配置组');
    }

    List<SystemSetting> selectedSettings = [];
    for (SystemSetting setting in _settings) {
      if (setting.groupName == _selectedGroup) {
        selectedSettings.add(setting);
      }
    }

    if (selectedSettings.isEmpty) {
      return const AdminStatusView.empty(title: '暂无配置项');
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _getGroupLabel(_selectedGroup!),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              for (SystemSetting setting in selectedSettings)
                _buildSettingItem(setting),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(SystemSetting setting) {
    final title = setting.description ?? setting.configKey;
    final subtitle = setting.description != null ? setting.configKey : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Chip(
                label: Text(
                  '${t(context, 'config_version')}: ${setting.version}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            )
          else
            const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: EdgeInsets.all(
                AdminBreakpoints.isPhone(context) ? 16 : 24,
              ),
              child: setting.configKey == 'analytics_tracking'
                  ? AnalyticsRegionTrackingEditor(
                      schema: setting.uiSchema,
                      initialValues: Map<String, dynamic>.from(
                        setting.configValue is Map ? setting.configValue : {},
                      ),
                      isFrozen: setting.isFrozen,
                      onSave: (values) =>
                          _saveSetting(setting.configKey, values),
                    )
                  : ConfigDynamicForm(
                      key: ValueKey(setting.configKey),
                      schema: setting.uiSchema,
                      initialValues: Map<String, dynamic>.from(
                        setting.configValue is Map ? setting.configValue : {},
                      ),
                      isFrozen: setting.isFrozen,
                      onSave: (values) =>
                          _saveSetting(setting.configKey, values),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _copySetting(setting),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制到剪贴板'),
              ),
              OutlinedButton.icon(
                onPressed: () => _importSettingFromClipboard(setting),
                icon: const Icon(Icons.content_paste_go, size: 18),
                label: const Text('从剪贴板导入'),
              ),
            ],
          ),
          if (setting.configKey == 'security_network') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _showClientIpTools,
                icon: const Icon(Icons.network_check),
                label: const Text('IP 测试'),
              ),
            ),
          ],
          if (setting.isFrozen) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _rollbackSetting(setting.configKey),
                  icon: const Icon(Icons.history, size: 18, color: Colors.blue),
                  label: Text(
                    t(context, 'rollback_and_cancel'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _confirmSetting(setting.configKey),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    t(context, 'confirm_and_unfreeze'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copySetting(SystemSetting setting) async {
    final value = setting.configValue is Map
        ? Map<String, dynamic>.from(setting.configValue as Map)
        : <String, dynamic>{};
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert({
          'configKey': setting.configKey,
          'configValue': value,
        }),
      ),
    );
    if (mounted) {
      AdminFeedback.showSnackBar(
        context,
        const SnackBar(content: Text('设置已复制到剪贴板')),
      );
    }
  }

  Future<void> _importSettingFromClipboard(SystemSetting setting) async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          const SnackBar(content: Text('剪贴板中没有可导入的内容')),
        );
      }
      return;
    }

    Map<String, dynamic> values;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) throw const FormatException('JSON 顶层必须是对象');
      final object = Map<String, dynamic>.from(decoded);
      final isEnvelope = object['configKey'] != null &&
          object.containsKey('configValue');
      if (isEnvelope && object['configKey'].toString() != setting.configKey) {
        throw const FormatException('剪贴板中的配置项与当前配置项不匹配');
      }
      final legacyEnvelope = object.length == 1 &&
          object['configValue'] is Map;
      final payload = isEnvelope || legacyEnvelope
          ? object['configValue']
          : object;
      if (payload is! Map) throw const FormatException('配置内容必须是 JSON 对象');
      values = Map<String, dynamic>.from(payload);
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('无法导入剪贴板内容：$error')),
        );
      }
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('导入“${setting.description ?? setting.configKey}”'),
        content: SingleChildScrollView(
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(values),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认导入并保存'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _saveSetting(setting.configKey, values);
    }
  }

  Future<void> _showClientIpTools() async {
    final remoteIpController = TextEditingController(text: '10.0.0.1');
    final headerValueController = TextEditingController();
    Map<String, dynamic>? actualResult;
    Map<String, dynamic>? simulatedResult;
    try {
      actualResult = await widget.api.inspectClientIp();
    } catch (error) {
      actualResult = {'message': '读取失败: $error'};
    }
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('客户端 IP 测试'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('真实请求解析结果'),
                    const SizedBox(height: 8),
                    SelectableText('${actualResult ?? {}}'),
                    const Divider(height: 32),
                    TextField(
                      controller: remoteIpController,
                      decoration: const InputDecoration(labelText: '模拟代理 IP'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: headerValueController,
                      decoration: const InputDecoration(
                        labelText: '模拟客户端 IP 请求头值',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          final result = await widget.api.simulateClientIp(
                            remoteIp: remoteIpController.text.trim(),
                            headerValue: headerValueController.text.trim(),
                          );
                          setDialogState(() {
                            simulatedResult = result;
                          });
                        } catch (error) {
                          setDialogState(() {
                            simulatedResult = {'message': '模拟失败: $error'};
                          });
                        }
                      },
                      child: const Text('模拟解析'),
                    ),
                    if (simulatedResult != null) ...[
                      const SizedBox(height: 8),
                      SelectableText('${simulatedResult!}'),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
    remoteIpController.dispose();
    headerValueController.dispose();
  }

  Future<void> _saveSetting(String key, Map<String, dynamic> values) async {
    final stepUpToken = await _stepUpTokenFor(key);
    if (_requiresStepUp(key) && stepUpToken == null) return;
    try {
      await widget.api.updateSystemSetting(
        key,
        values,
        reason: '管理员在后台手动修改',
        stepUpToken: stepUpToken,
      );
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(
            content: Text(t(context, 'config_save_success_verifying')),
            backgroundColor: Colors.orange,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmSetting(String key) async {
    final stepUpToken = await _stepUpTokenFor(key);
    if (_requiresStepUp(key) && stepUpToken == null) return;
    try {
      await widget.api.confirmSystemSetting(key, stepUpToken: stepUpToken);
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(
            content: Text(t(context, 'config_confirmed')),
            backgroundColor: Colors.green,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rollbackSetting(String key) async {
    final stepUpToken = await _stepUpTokenFor(key);
    if (_requiresStepUp(key) && stepUpToken == null) return;
    try {
      await widget.api.rollbackSystemSetting(key, stepUpToken: stepUpToken);
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(
            content: Text(t(context, 'config_rolled_back')),
            backgroundColor: Colors.blue,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _getStepUpToken() async {
    return AdminStepUpAuthorization.obtain(
      context,
      widget.api,
      title: '确认系统设置操作',
    );
  }

  bool _requiresStepUp(String key) {
    final normalized = key.toLowerCase();
    return const [
      'secret',
      'password',
      'token',
      'credential',
      'key',
      'auth',
      'security',
      'elasticsearch',
      'redis',
      'database',
      'storage',
      'mail',
    ].any(normalized.contains);
  }

  Future<String?> _stepUpTokenFor(String key) =>
      _requiresStepUp(key) ? _getStepUpToken() : Future.value();

  String _getGroupLabel(String g) {
    return g;
  }
}

class AnalyticsRegionTrackingEditor extends StatefulWidget {
  const AnalyticsRegionTrackingEditor({
    super.key,
    required this.schema,
    required this.initialValues,
    required this.onSave,
    required this.isFrozen,
  });

  final UISchema schema;
  final Map<String, dynamic> initialValues;
  final ValueChanged<Map<String, dynamic>> onSave;
  final bool isFrozen;

  @override
  State<AnalyticsRegionTrackingEditor> createState() =>
      _AnalyticsRegionTrackingEditorState();
}

class _AnalyticsRegionTrackingEditorState
    extends State<AnalyticsRegionTrackingEditor> {
  static const _regionLabels = <BlogRegion, String>{
    BlogRegion.global: '全局默认',
    BlogRegion.cn: '中国',
    BlogRegion.us: '美国',
    BlogRegion.eu: '欧洲',
    BlogRegion.jp: '日本',
    BlogRegion.hk: '中国香港',
    BlogRegion.tw: '中国台湾',
  };

  String _region = 'global';
  bool _creatingOverride = false;

  Map<String, dynamic> get _values =>
      Map<String, dynamic>.from(widget.initialValues);

  Map<String, dynamic> get _regionalValues {
    final rawRegions = _values['regions'];
    if (rawRegions is! Map) return {};
    final rawValue = rawRegions[_region];
    if (rawValue is! Map) return {};
    return Map<String, dynamic>.from(rawValue);
  }

  bool get _hasOverride {
    final rawRegions = _values['regions'];
    return rawRegions is Map && rawRegions.containsKey(_region);
  }

  Map<String, dynamic> _globalValues() {
    final values = _values;
    values.remove('regions');
    return values;
  }

  @override
  void didUpdateWidget(covariant AnalyticsRegionTrackingEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValues != widget.initialValues) {
      _creatingOverride = false;
    }
  }

  void _saveGlobal(Map<String, dynamic> globalValues) {
    final values = _values;
    values
      ..remove('regions')
      ..addAll(globalValues);
    widget.onSave(values);
  }

  void _saveRegion(Map<String, dynamic> regionalValues) {
    final values = _values;
    final rawRegions = values['regions'];
    final regions = rawRegions is Map
        ? Map<String, dynamic>.from(rawRegions)
        : <String, dynamic>{};
    regions[_region] = regionalValues;
    values['regions'] = regions;
    widget.onSave(values);
  }

  Future<void> _restoreGlobal() async {
    final values = _values;
    final rawRegions = values['regions'];
    if (rawRegions is Map) {
      final regions = Map<String, dynamic>.from(rawRegions)..remove(_region);
      if (regions.isEmpty) {
        values.remove('regions');
      } else {
        values['regions'] = regions;
      }
    }
    setState(() => _creatingOverride = false);
    widget.onSave(values);
  }

  @override
  Widget build(BuildContext context) {
    final isGlobal = _region == 'global';
    final hasOverride = _hasOverride || _creatingOverride;
    final initialValues = isGlobal
        ? _globalValues()
        : (_hasOverride ? _regionalValues : _globalValues());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _region,
          decoration: const InputDecoration(
            labelText: '配置区域',
            border: OutlineInputBorder(),
          ),
          items: BlogRegion.values
              .map(
                (region) => DropdownMenuItem<String>(
                  value: region.code,
                  child: Text(_regionLabels[region] ?? region.displayName),
                ),
              )
              .toList(),
          onChanged: widget.isFrozen
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _region = value;
                    _creatingOverride = false;
                  });
                },
        ),
        const SizedBox(height: 16),
        if (!isGlobal && !hasOverride) ...[
          const AlertBanner(message: '此区域当前沿用全局默认追踪配置。', type: AlertType.info),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.isFrozen
                ? null
                : () => setState(() => _creatingOverride = true),
            icon: const Icon(Icons.add),
            label: const Text('复制全局配置并独立编辑'),
          ),
        ] else ...[
          if (!isGlobal)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  const Text('此区域使用独立追踪配置。'),
                  OutlinedButton.icon(
                    onPressed: widget.isFrozen ? null : _restoreGlobal,
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('恢复继承全局配置'),
                  ),
                ],
              ),
            ),
          ConfigDynamicForm(
            key: ValueKey('analytics-$_region-$hasOverride'),
            schema: widget.schema,
            initialValues: initialValues,
            isFrozen: widget.isFrozen,
            onSave: isGlobal ? _saveGlobal : _saveRegion,
          ),
        ],
      ],
    );
  }
}
