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
  String? _selectedGroup = 'general';

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
      final list = await widget.api.listSystemSettings();
      if (mounted) {
        setState(() {
          _settings = list;
          if (_settings.isNotEmpty) {
            _selectedGroup = _selectedGroup ?? _settings.first.groupName;
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
              child: ConfigDynamicForm(
                key: ValueKey(setting.configKey),
                schema: setting.uiSchema,
                initialValues: Map<String, dynamic>.from(
                  setting.configValue is Map ? setting.configValue : {},
                ),
                isFrozen: setting.isFrozen,
                onSave: (values) => _saveSetting(setting.configKey, values),
              ),
            ),
          ),
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

  Future<void> _saveSetting(String key, Map<String, dynamic> values) async {
    try {
      await widget.api.updateSystemSetting(key, values, reason: '管理员在后台手动修改');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(context, 'config_save_success_verifying')),
            backgroundColor: Colors.orange,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmSetting(String key) async {
    try {
      await widget.api.confirmSystemSetting(key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(context, 'config_confirmed')),
            backgroundColor: Colors.green,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rollbackSetting(String key) async {
    try {
      await widget.api.rollbackSystemSetting(key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(context, 'config_rolled_back')),
            backgroundColor: Colors.blue,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getGroupLabel(String g) {
    final key = 'setting_group_$g';
    final label = t(context, key);
    if (label == key) {
      return g.toUpperCase();
    }
    return label;
  }
}
