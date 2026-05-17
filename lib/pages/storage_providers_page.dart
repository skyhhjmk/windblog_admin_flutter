part of 'package:windblog_admin_flutter/main.dart';

class StorageProvidersPage extends StatefulWidget {
  const StorageProvidersPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<StorageProvidersPage> createState() => _StorageProvidersPageState();
}

class _StorageProvidersPageState extends State<StorageProvidersPage> {
  List<StorageProviderItem> providers = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() => loading = true);
    try {
      providers = await widget.api.listStorageProviders();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _deleteProvider(StorageProviderItem provider) async {
    if (provider.id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除存储节点 "${provider.displayName}" 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.api.deleteStorageProvider(provider.id!);
      await _loadProviders();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Future<void> _testProvider(String name) async {
    try {
      await widget.api.testStorageProvider(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接测试成功')),
        );
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('测试失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '存储节点管理',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('新建'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loadProviders,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _buildProviderList(),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final displayNameController = TextEditingController();
    final cdnDomainController = TextEditingController();
    final endpointController = TextEditingController();
    final accessKeyIdController = TextEditingController();
    final accessKeySecretController = TextEditingController();
    final bucketNameController = TextEditingController();
    String selectedProviderType = 'aliyun_oss_v2';
    String selectedRole = 'backup';
    List<String> selectedSupportedTypes = ['image', 'video'];
    bool isEnabled = true;
    bool isPrimary = false;
    bool cdnEnabled = false;
    final priorityController = TextEditingController(text: '0');
    BlogRegion selectedRegion = BlogRegion.global;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setDialogState) {
              bool showCloudFields = selectedProviderType != 'local_fs';
              return AlertDialog(
                title: const Text('新建存储节点'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: '名称',
                          hintText: '唯一标识符，如 aliyun-oss',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: displayNameController,
                        decoration: const InputDecoration(
                          labelText: '显示名称',
                          hintText: '如 阿里云 OSS',
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedProviderType,
                        decoration: const InputDecoration(
                            labelText: '提供商类型'),
                        items: const [
                          DropdownMenuItem(
                            value: 'aliyun_oss_v2',
                            child: Text('阿里云 OSS v2'),
                          ),
                          DropdownMenuItem(
                            value: 'local_fs',
                            child: Text('本地文件系统'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedProviderType = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                            labelText: '角色 (Role)'),
                        items: const [
                          DropdownMenuItem(value: 'primary', child: Text(
                              '主存储 (Primary)')),
                          DropdownMenuItem(value: 'backup', child: Text(
                              '备份存储 (Backup)')),
                          DropdownMenuItem(value: 'archive', child: Text(
                              '归档存储 (Archive)')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedRole = value;
                              if (value == 'primary') {
                                isPrimary = true;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('允许存储的多媒体类型:',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: ['image', 'video', 'audio', 'document', '*']
                            .map((type) {
                          final isSelected = selectedSupportedTypes.contains(
                              type);
                          return FilterChip(
                            label: Text(type),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  if (type == '*') {
                                    selectedSupportedTypes = ['*'];
                                  } else {
                                    selectedSupportedTypes.remove('*');
                                    selectedSupportedTypes.add(type);
                                  }
                                } else {
                                  selectedSupportedTypes.remove(type);
                                  if (selectedSupportedTypes.isEmpty) {
                                    selectedSupportedTypes.add('*');
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      if (showCloudFields) ...[
                        TextField(
                          controller: endpointController,
                          decoration: const InputDecoration(
                            labelText: 'Endpoint',
                            hintText: '如 oss-cn-hangzhou.aliyuncs.com',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: accessKeyIdController,
                          decoration: const InputDecoration(
                            labelText: 'AccessKey ID',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: accessKeySecretController,
                          decoration: const InputDecoration(
                            labelText: 'AccessKey Secret',
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: bucketNameController,
                          decoration: const InputDecoration(
                            labelText: 'Bucket 名称',
                            hintText: '如 my-blog-bucket',
                          ),
                        ),
                      ] else
                        ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              '本地文件系统存储将使用应用配置的 storage.path 目录',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        ],
                      const SizedBox(height: 8),
                      DropdownButtonFormField<BlogRegion>(
                        initialValue: selectedRegion,
                        decoration: const InputDecoration(labelText: '区域'),
                        items: BlogRegion.values.map((r) =>
                            DropdownMenuItem(
                                value: r, child: Text(r.displayName))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedRegion = v);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cdnDomainController,
                        decoration: const InputDecoration(
                          labelText: 'CDN 域名',
                          hintText: '如 cdn.example.com',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: priorityController,
                        decoration: const InputDecoration(labelText: '优先级'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('启用此节点'),
                        value: isEnabled,
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              isEnabled = value;
                            });
                          }
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('设为主节点 (Primary)'),
                        value: isPrimary,
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              isPrimary = value;
                              if (value) {
                                selectedRole = 'primary';
                              }
                            });
                          }
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('启用 CDN 访问'),
                        value: cdnEnabled,
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              cdnEnabled = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('创建'),
                  ),
                ],
              );
            },
          ),
    );

    if (confirmed != true) {
      return;
    }

    final name = nameController.text;
    final displayName = displayNameController.text;
    final cdnDomain = cdnDomainController.text;

    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('名称不能为空')),
        );
      }
      return;
    }
    if (displayName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('显示名称不能为空')),
        );
      }
      return;
    }

    String configJson = '{}';
    if (selectedProviderType == 'aliyun_oss_v2') {
      final endpoint = endpointController.text;
      final accessKeyId = accessKeyIdController.text;
      final accessKeySecret = accessKeySecretController.text;
      final bucketName = bucketNameController.text;
      final buffer = StringBuffer();
      buffer.write('{');
      buffer.write('"endpoint":"');
      buffer.write(endpoint);
      buffer.write('",');
      buffer.write('"accessKeyId":"');
      buffer.write(accessKeyId);
      buffer.write('",');
      buffer.write('"accessKeySecret":"');
      buffer.write(accessKeySecret);
      buffer.write('",');
      buffer.write('"bucketName":"');
      buffer.write(bucketName);
      buffer.write('"}');
      configJson = buffer.toString();
    }

    final item = StorageProviderItem(
      id: null,
      name: name,
      displayName: displayName,
      providerType: selectedProviderType,
      isEnabled: isEnabled,
      isPrimary: isPrimary,
      role: selectedRole,
      configJson: configJson,
      supportedTypes: selectedSupportedTypes.join(','),
      cdnDomain: cdnDomain.isNotEmpty ? cdnDomain : null,
      cdnEnabled: cdnEnabled,
      region: selectedRegion.code,
      priority: int.tryParse(priorityController.text) ?? 0,
    );

    try {
      await widget.api.createStorageProvider(item);
      await _loadProviders();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  Future<void> _showEditDialog(StorageProviderItem provider) async {
    final displayNameController = TextEditingController(
        text: provider.displayName);
    final cdnDomainController = TextEditingController(text: provider.cdnDomain);
    final configController = TextEditingController(text: provider.configJson);
    String selectedRole = provider.role ?? 'backup';
    List<String> selectedSupportedTypes = (provider.supportedTypes ??
        'image,video').split(',').map((e) => e.trim()).where((e) =>
    e.isNotEmpty).toList();
    bool isEnabled = provider.isEnabled;
    bool isPrimary = provider.isPrimary;
    bool cdnEnabled = provider.cdnEnabled ?? false;
    int priority = provider.priority ?? 0;
    final priorityController = TextEditingController(text: priority.toString());
    BlogRegion selectedRegion = BlogRegion.fromCode(provider.region ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('编辑存储节点: ${provider.name}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: displayNameController,
                        decoration: const InputDecoration(
                            labelText: '显示名称'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                            labelText: '角色 (Role)'),
                        items: const [
                          DropdownMenuItem(value: 'primary', child: Text(
                              '主存储 (Primary)')),
                          DropdownMenuItem(value: 'backup', child: Text(
                              '备份存储 (Backup)')),
                          DropdownMenuItem(value: 'archive', child: Text(
                              '归档存储 (Archive)')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedRole = value;
                              if (value == 'primary') {
                                isPrimary = true;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('允许存储的多媒体类型:',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: ['image', 'video', 'audio', 'document', '*']
                            .map((type) {
                          final isSelected = selectedSupportedTypes.contains(
                              type);
                          return FilterChip(
                            label: Text(type),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  if (type == '*') {
                                    selectedSupportedTypes = ['*'];
                                  } else {
                                    selectedSupportedTypes.remove('*');
                                    selectedSupportedTypes.add(type);
                                  }
                                } else {
                                  selectedSupportedTypes.remove(type);
                                  if (selectedSupportedTypes.isEmpty) {
                                    selectedSupportedTypes.add('*');
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: configController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: '配置 JSON',
                          hintText: '{"rootPath": "...", "baseUrl": "..."}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<BlogRegion>(
                        initialValue: selectedRegion,
                        decoration: const InputDecoration(labelText: '区域'),
                        items: BlogRegion.values.map((r) =>
                            DropdownMenuItem(
                                value: r, child: Text(r.displayName))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedRegion = v);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cdnDomainController,
                        decoration: const InputDecoration(
                            labelText: 'CDN 域名'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: priorityController,
                        decoration: const InputDecoration(labelText: '优先级'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('启用此节点'),
                        value: isEnabled,
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              isEnabled = value;
                            });
                          }
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('设为主节点 (Primary)'),
                        value: isPrimary,
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              isPrimary = value;
                              if (value) {
                                selectedRole = 'primary';
                              }
                            });
                          }
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('启用 CDN 访问'),
                        value: cdnEnabled,
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              cdnEnabled = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          ),
    );

    if (confirmed != true) return;

    final updated = StorageProviderItem(
      id: provider.id,
      name: provider.name,
      displayName: displayNameController.text,
      providerType: provider.providerType,
      isEnabled: isEnabled,
      isPrimary: isPrimary,
      role: selectedRole,
      configJson: configController.text,
      supportedTypes: selectedSupportedTypes.join(','),
      cdnDomain: cdnDomainController.text,
      cdnEnabled: cdnEnabled,
      region: selectedRegion.code,
      priority: int.tryParse(priorityController.text) ?? 0,
    );

    try {
      await widget.api.updateStorageProvider(provider.id!, updated);
      await _loadProviders();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  Widget _buildProviderList() {
    if (providers.isEmpty) {
      return const Center(child: Text('暂无存储节点配置'));
    }
    return ListView.builder(
      itemCount: providers.length,
      itemBuilder: (context, index) {
        final provider = providers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      provider.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (provider.isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '主节点',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Chip(
                      label: Text(provider.providerTypeText),
                      backgroundColor: provider.isEnabled
                          ? Colors.green.shade50
                          : Colors.grey.shade200,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('名称: ${provider.name}'),
                if (provider.region != null && provider.region!.isNotEmpty)
                  Text('区域: ${BlogRegion
                      .fromCode(provider.region!)
                      .displayName}'),
                if (provider.role != null && provider.role!.isNotEmpty)
                  Text('角色: ${provider.roleText}'),
                if (provider.supportedTypes != null &&
                    provider.supportedTypes!.isNotEmpty)
                  Text('支持类型: ${provider.supportedTypes}'),
                if (provider.cdnEnabled == true)
                  Text('CDN: ${provider.cdnDomain ?? '未配置域名'}'),
                Text('优先级: ${provider.priority ?? 0}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        if (provider.name.isNotEmpty) {
                          _testProvider(provider.name);
                        }
                      },
                      icon: const Icon(Icons.wifi_find),
                      label: const Text('测试连接'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showEditDialog(provider),
                      icon: const Icon(Icons.edit),
                      label: const Text('编辑'),
                    ),
                    const SizedBox(width: 8),
                    if (provider.id != null)
                      OutlinedButton.icon(
                        onPressed: () => _deleteProvider(provider),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('删除', style: TextStyle(color: Colors
                            .red)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
