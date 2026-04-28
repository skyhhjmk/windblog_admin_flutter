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
  SystemSetting? _selectedSetting;
  String _selectedGroup = 'basic';

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
            _selectedSetting = _settings.firstWhere(
                  (s) => s.groupName == _selectedGroup,
              orElse: () => _settings.first,
            );
            _selectedGroup = _selectedSetting!.groupName;
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

  Future<void> _save(Map<String, dynamic> values) async {
    if (_selectedSetting == null) return;
    try {
      await widget.api.updateSystemSetting(
        _selectedSetting!.configKey,
        values,
        reason: '管理员在后台手动修改',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'config_save_success_verifying')),
              backgroundColor: Colors.orange),
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

  Future<void> _confirm() async {
    if (_selectedSetting == null) return;
    try {
      await widget.api.confirmSystemSetting(_selectedSetting!.configKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'config_confirmed')),
              backgroundColor: Colors.green),
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

  Future<void> _rollback() async {
    if (_selectedSetting == null) return;
    try {
      await widget.api.rollbackSystemSetting(_selectedSetting!.configKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'config_rolled_back')),
              backgroundColor: Colors.blue),
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

  @override
  Widget build(BuildContext context) {
    if (_loading && _settings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

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
                    _selectedSetting = _settings.firstWhere((s) =>
                    s.groupName == g);
                  });
                },
              );
            }).toList(),
          ),
        ),
        const VerticalDivider(width: 1),
        // Main content
        Expanded(
          child: _selectedSetting == null
              ? const Center(child: Text('请选择配置组'))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          _selectedSetting!.configKey,
                          style: Theme
                              .of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text('${t(context,
                            'config_version')}: ${_selectedSetting!.version}',
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                    if (_selectedSetting!.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 24),
                        child: Text(_selectedSetting!.description!,
                            style: TextStyle(color: Colors.grey.shade700)),
                      )
                    else
                      const SizedBox(height: 24),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: ConfigDynamicForm(
                          schema: _selectedSetting!.uiSchema,
                          initialValues: Map<String, dynamic>.from(
                              _selectedSetting!.configValue is Map
                                  ? _selectedSetting!.configValue
                                  : {}),
                          isFrozen: _selectedSetting!.isFrozen,
                          onSave: _save,
                        ),
                      ),
                    ),

                    if (_selectedSetting!.isFrozen) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: _rollback,
                            icon: const Icon(Icons.history, color: Colors.blue),
                            label: Text(t(context, 'rollback_and_cancel')),
                          ),
                          const SizedBox(width: 16),
                          FilledButton.icon(
                            onPressed: _confirm,
                            icon: const Icon(Icons.check),
                            label: Text(t(context, 'confirm_and_unfreeze')),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
