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
      return Center(child: Text('错误: $_error'));
    }

    final groups = _settings.map((s) => s.groupName).toSet().toList();

    return Row(
      children: [
        // Sidebar for groups
        Container(
          width: 200,
          color: Colors.white,
          child: ListView(
            children: groups.map((g) {
              return ListTile(
                title: Text(g),
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
        const VerticalDivider(width: 1),
        // Main content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _selectedGroup == null
              ? const Center(child: Text('请选择配置组'))
              : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _selectedGroup!.toUpperCase(),
                      style: Theme
                          .of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ..._settings
                        .where((s) => s.groupName == _selectedGroup)
                        .map((setting) => _buildSettingItem(setting)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(SystemSetting setting) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                setting.configKey,
                style: Theme
                    .of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${t(context, 'config_version')}: ${setting.version}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          if (setting.description != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Text(
                setting.description!,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
            )
          else
            const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConfigDynamicForm(
                key: ValueKey(setting.configKey),
                schema: setting.uiSchema,
                initialValues: Map<String, dynamic>.from(
                    setting.configValue is Map ? setting.configValue : {}),
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
                  label: Text(t(context, 'rollback_and_cancel'),
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _confirmSetting(setting.configKey),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(t(context, 'confirm_and_unfreeze'),
                      style: const TextStyle(fontSize: 13)),
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
      await widget.api.updateSystemSetting(
        key,
        values,
        reason: '管理员在后台手动修改',
      );
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
}
