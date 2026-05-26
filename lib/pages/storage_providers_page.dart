part of 'package:windblog_admin_flutter/main.dart';

class StorageClassesPage extends StatefulWidget {
  const StorageClassesPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<StorageClassesPage> createState() => _StorageClassesPageState();
}

class _StorageClassesPageState extends State<StorageClassesPage> {
  List<StorageClassItem> providers = [];
  bool loading = false;
  static const List<String> _mediaTypes = [
    'image',
    'video',
    'audio',
    'document',
    '*',
  ];

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() => loading = true);
    try {
      providers = await widget.api.listStorageClasses();
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

  Future<void> _deleteProvider(StorageClassItem provider) async {
    if (provider.id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除存储类 "${provider.displayName}" 吗？'),
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
      await widget.api.deleteStorageClass(provider.id!);
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
      await widget.api.testStorageClass(name);
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
                '存储类管理',
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
    final ossRegionController = TextEditingController(text: 'cn-hangzhou');
    final accessKeyIdController = TextEditingController();
    final accessKeySecretController = TextEditingController();
    final bucketNameController = TextEditingController();
    final localBaseUrlController = TextEditingController(text: '/uploads');
    final localRootPathController = TextEditingController(text: 'uploads');
    final serviceRegionController = TextEditingController();
    String selectedProviderType = 'oss_aliyun';
    String selectedRole = 'origin';
    List<String> selectedSupportedTypes = ['image', 'video'];
    List<String> selectedContentRegions = ['global'];
    bool isEnabled = true;
    bool cdnEnabled = false;
    final priorityController = TextEditingController(text: '0');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setDialogState) {
              bool showCloudFields = selectedProviderType != 'local_fs';
              return AlertDialog(
                title: const Text('新建存储类'),
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
                            value: 'oss_aliyun',
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
                            labelText: '存储类角色'),
                        items: const [
                          DropdownMenuItem(
                            value: 'primary',
                            child: Text('主写入存储'),
                          ),
                          DropdownMenuItem(
                            value: 'origin',
                            child: Text('对象存储同步源'),
                          ),
                          DropdownMenuItem(
                            value: 'backup',
                            child: Text('普通副本'),
                          ),
                          DropdownMenuItem(
                            value: 'archive',
                            child: Text('归档存储'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedRole = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _storageClassRoleDescription(selectedRole),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('允许存储的多媒体类型:',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: _mediaTypes.map((type) {
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
                      const Text('内容区域:',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      _buildRegionChips(
                        selectedRegions: selectedContentRegions,
                        onChanged: (regions) {
                          setDialogState(() {
                            selectedContentRegions = regions;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: serviceRegionController,
                        decoration: const InputDecoration(
                          labelText: '存储服务区域',
                          hintText: '如 cn-hangzhou，留空表示未指定',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (showCloudFields) ...[
                        TextField(
                          controller: ossRegionController,
                          decoration: const InputDecoration(
                            labelText: 'OSS Region',
                            hintText: '如 cn-hangzhou',
                          ),
                        ),
                        const SizedBox(height: 8),
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
                          TextField(
                            controller: localBaseUrlController,
                            decoration: const InputDecoration(
                              labelText: '访问前缀 baseUrl',
                              hintText: '/uploads',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: localRootPathController,
                            decoration: const InputDecoration(
                              labelText: '根目录 rootPath',
                              hintText: 'uploads',
                            ),
                          ),
                        ],
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
                        title: const Text('启用此存储类'),
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

    final configJson = _buildConfigJson(
      providerType: selectedProviderType,
      ossRegion: ossRegionController.text,
      endpoint: endpointController.text,
      accessKeyId: accessKeyIdController.text,
      accessKeySecret: accessKeySecretController.text,
      bucketName: bucketNameController.text,
      localBaseUrl: localBaseUrlController.text,
      localRootPath: localRootPathController.text,
    );

    final item = StorageClassItem(
      id: null,
      name: name,
      displayName: displayName,
      providerType: selectedProviderType,
      isEnabled: isEnabled,
      isPrimary: selectedRole == 'primary',
      role: selectedRole,
      configJson: configJson,
      supportedTypes: selectedSupportedTypes.join(','),
      cdnDomain: cdnDomain.isNotEmpty ? cdnDomain : null,
      cdnEnabled: cdnEnabled,
      serviceRegion: _normalizeText(serviceRegionController.text),
      contentRegions: selectedContentRegions,
      priority: int.tryParse(priorityController.text) ?? 0,
    );

    try {
      await widget.api.createStorageClass(item);
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

  Future<void> _showEditDialog(StorageClassItem provider) async {
    final displayNameController = TextEditingController(
        text: provider.displayName);
    final cdnDomainController = TextEditingController(text: provider.cdnDomain);
    final configValues = _parseConfigValues(provider.configJson);
    final ossRegionController = TextEditingController(
        text: configValues['region'] ?? '');
    final endpointController = TextEditingController(
        text: configValues['endpoint'] ?? '');
    final accessKeyIdController = TextEditingController(
        text: configValues['accessKeyId'] ?? '');
    final accessKeySecretController = TextEditingController(
        text: configValues['accessKeySecret'] ?? '');
    final bucketNameController = TextEditingController(
        text: configValues['bucketName'] ?? '');
    final localBaseUrlController = TextEditingController(
        text: configValues['baseUrl'] ?? '/uploads');
    final localRootPathController = TextEditingController(
        text: configValues['rootPath'] ?? 'uploads');
    final serviceRegionController = TextEditingController(
        text: provider.serviceRegion ?? '');
    String selectedRole = _normalizeSelectedStorageClassRole(provider);
    List<String> selectedSupportedTypes = (provider.supportedTypes ??
        'image,video').split(',').map((e) => e.trim()).where((e) =>
    e.isNotEmpty).toList();
    List<String> selectedContentRegions = _normalizeContentRegions(
        provider.contentRegions);
    bool isEnabled = provider.isEnabled;
    bool cdnEnabled = provider.cdnEnabled ?? false;
    int priority = provider.priority ?? 0;
    final priorityController = TextEditingController(text: priority.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('编辑存储类: ${provider.name}'),
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
                            labelText: '存储类角色'),
                        items: const [
                          DropdownMenuItem(
                            value: 'primary',
                            child: Text('主写入存储'),
                          ),
                          DropdownMenuItem(
                            value: 'origin',
                            child: Text('对象存储同步源'),
                          ),
                          DropdownMenuItem(
                            value: 'backup',
                            child: Text('普通副本'),
                          ),
                          DropdownMenuItem(
                            value: 'archive',
                            child: Text('归档存储'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedRole = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _storageClassRoleDescription(selectedRole),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('允许存储的多媒体类型:',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: _mediaTypes.map((type) {
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
                      const Text('内容区域:',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      _buildRegionChips(
                        selectedRegions: selectedContentRegions,
                        onChanged: (regions) {
                          setDialogState(() {
                            selectedContentRegions = regions;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: serviceRegionController,
                        decoration: const InputDecoration(
                          labelText: '存储服务区域',
                          hintText: '如 cn-hangzhou，留空表示未指定',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (provider.providerType == 'local_fs') ...[
                        TextField(
                          controller: localBaseUrlController,
                          decoration: const InputDecoration(
                            labelText: '访问前缀 baseUrl',
                            hintText: '/uploads',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: localRootPathController,
                          decoration: const InputDecoration(
                            labelText: '根目录 rootPath',
                            hintText: 'uploads',
                          ),
                        ),
                      ] else
                        ...[
                          TextField(
                            controller: ossRegionController,
                            decoration: const InputDecoration(
                              labelText: 'OSS Region',
                              hintText: '如 cn-hangzhou',
                            ),
                          ),
                          const SizedBox(height: 8),
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
                            ),
                          ),
                        ],
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
                        title: const Text('启用此存储类'),
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

    final configJson = _buildConfigJson(
      providerType: provider.providerType,
      ossRegion: ossRegionController.text,
      endpoint: endpointController.text,
      accessKeyId: accessKeyIdController.text,
      accessKeySecret: accessKeySecretController.text,
      bucketName: bucketNameController.text,
      localBaseUrl: localBaseUrlController.text,
      localRootPath: localRootPathController.text,
      existingValues: configValues,
    );

    final updated = StorageClassItem(
      id: provider.id,
      name: provider.name,
      displayName: displayNameController.text,
      providerType: provider.providerType,
      isEnabled: isEnabled,
      isPrimary: selectedRole == 'primary',
      role: selectedRole,
      configJson: configJson,
      supportedTypes: selectedSupportedTypes.join(','),
      cdnDomain: cdnDomainController.text,
      cdnEnabled: cdnEnabled,
      serviceRegion: _normalizeText(serviceRegionController.text),
      contentRegions: selectedContentRegions,
      priority: int.tryParse(priorityController.text) ?? 0,
    );

    try {
      await widget.api.updateStorageClass(provider.id!, updated);
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

  Map<String, String> _parseConfigValues(String? configJson) {
    final values = <String, String>{};
    if (configJson == null || configJson.trim().isEmpty) {
      return values;
    }

    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return values;
      }

      for (final entry in decoded.entries) {
        if (entry.value == null) {
          continue;
        }
        values[entry.key.toString()] = entry.value.toString();
      }
    } catch (_) {
      return values;
    }

    return values;
  }

  String _buildConfigJson({
    required String providerType,
    required String ossRegion,
    required String endpoint,
    required String accessKeyId,
    required String accessKeySecret,
    required String bucketName,
    required String localBaseUrl,
    required String localRootPath,
    Map<String, String>? existingValues,
  }) {
    final values = <String, String>{};
    if (existingValues != null) {
      for (final entry in existingValues.entries) {
        values[entry.key] = entry.value;
      }
    }

    if (providerType == 'local_fs') {
      _putConfigValue(values, 'baseUrl', localBaseUrl);
      _putConfigValue(values, 'rootPath', localRootPath);
    } else {
      _putConfigValue(values, 'region', ossRegion);
      _putConfigValue(values, 'endpoint', endpoint);
      _putConfigValue(values, 'accessKeyId', accessKeyId);
      _putConfigValue(values, 'accessKeySecret', accessKeySecret);
      _putConfigValue(values, 'bucketName', bucketName);
    }

    return jsonEncode(values);
  }

  void _putConfigValue(
    Map<String, String> values,
    String key,
    String value,
  ) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      values.remove(key);
      return;
    }
    values[key] = normalizedValue;
  }

  List<String> _normalizeContentRegions(List<String>? selectedRegions) {
    if (selectedRegions == null || selectedRegions.isEmpty) {
      return [BlogRegion.global.code];
    }
    return List<String>.from(selectedRegions);
  }

  String _buildRegionDisplayText(List<String> selectedRegions) {
    final names = <String>[];
    for (final regionCode in selectedRegions) {
      names.add(BlogRegion.fromCode(regionCode).displayName);
    }
    return names.join(', ');
  }

  String? _normalizeText(String text) {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return null;
    }
    return normalizedText;
  }

  String _normalizeSelectedStorageClassRole(StorageClassItem storageClass) {
    if (storageClass.isPrimary) {
      return 'primary';
    }
    final role = storageClass.role;
    if (role == 'origin') {
      return 'origin';
    }
    if (role == 'archive') {
      return 'archive';
    }
    return 'backup';
  }

  String _storageClassRoleDescription(String role) {
    if (role == 'primary') {
      return '主节点收到写入请求后首先写入此存储类，通常是主节点本地磁盘。';
    }
    if (role == 'origin') {
      return '主写入完成后同步到这里，其他存储类优先从这里拉取，适合阿里云 OSS。';
    }
    if (role == 'archive') {
      return '用于长期保存或低频访问，也会从对象存储同步源拉取。';
    }
    return '普通副本或边缘缓存，会优先从对象存储同步源拉取。';
  }

  Widget _buildRegionChips({
    required List<String> selectedRegions,
    required ValueChanged<List<String>> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: BlogRegion.values.map((region) {
        final isSelected = selectedRegions.contains(region.code);
        return FilterChip(
          label: Text(region.displayName),
          selected: isSelected,
          onSelected: (selected) {
            final newRegions = List<String>.from(selectedRegions);
            if (selected) {
              if (region == BlogRegion.global) {
                newRegions.clear();
              } else {
                newRegions.remove(BlogRegion.global.code);
              }
              newRegions.add(region.code);
            } else {
              newRegions.remove(region.code);
            }
            if (newRegions.isEmpty) {
              newRegions.add(BlogRegion.global.code);
            }
            onChanged(newRegions);
          },
        );
      }).toList(),
    );
  }

  Widget _buildProviderList() {
    if (providers.isEmpty) {
      return const Center(child: Text('暂无存储类配置'));
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
                          '主存储',
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
                if (provider.contentRegions.isNotEmpty)
                  Text('内容区域: ${_buildRegionDisplayText(
                      provider.contentRegions)}'),
                if (provider.serviceRegion != null &&
                    provider.serviceRegion!.isNotEmpty)
                  Text('存储服务区域: ${provider.serviceRegion!}'),
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
