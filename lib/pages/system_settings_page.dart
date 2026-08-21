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
  String? _stepUpToken;
  DateTime? _stepUpTokenExpiresAt;

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
    final stepUpToken = await _getStepUpToken();
    if (stepUpToken == null) return;
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
    final stepUpToken = await _getStepUpToken();
    if (stepUpToken == null) return;
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
    final stepUpToken = await _getStepUpToken();
    if (stepUpToken == null) return;
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
    final expiresAt = _stepUpTokenExpiresAt;
    if (_stepUpToken != null &&
        expiresAt != null &&
        DateTime.now().isBefore(expiresAt)) {
      return _stepUpToken;
    }

    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认系统设置修改'),
        content: TextField(
          controller: password,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: '管理员密码'),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    final rawPassword = password.text;
    password.dispose();
    if (confirmed != true || rawPassword.isEmpty) return null;

    try {
      final token = await widget.api.issueAdminStepUp(rawPassword);
      // The server token is valid for five minutes; leave a small margin for clock and request delay.
      _stepUpToken = token;
      _stepUpTokenExpiresAt = DateTime.now().add(
        const Duration(minutes: 4, seconds: 30),
      );
      return token;
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(
            content: Text('高风险操作授权失败：$error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  String _getGroupLabel(String g) {
    return g;
  }
}
