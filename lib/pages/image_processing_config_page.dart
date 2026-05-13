part of 'package:windblog_admin_flutter/main.dart';

class ImageProcessingConfigPage extends StatefulWidget {
  const ImageProcessingConfigPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<ImageProcessingConfigPage> createState() =>
      _ImageProcessingConfigPageState();
}

class _ImageProcessingConfigPageState extends State<ImageProcessingConfigPage> {
  List<ImageProcessingConfigItem> configs = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    setState(() => loading = true);
    try {
      configs = await widget.api.listImageProcessingConfigs();
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

  Future<void> _editConfig(ImageProcessingConfigItem config) async {
    final controller = TextEditingController(text: config.configValue);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text('编辑配置: ${config.configKey}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (config.description != null &&
                    config.description!.isNotEmpty)
                  Text(
                    config.description!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '配置值',
                  ),
                  maxLines: 3,
                ),
              ],
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
          ),
    );

    if (confirmed != true) {
      return;
    }

    final newValue = controller.text;
    final updatedConfig = ImageProcessingConfigItem(
      id: config.id,
      configKey: config.configKey,
      configValue: newValue,
      description: config.description,
      version: config.version,
      isFrozen: config.isFrozen,
    );

    try {
      await widget.api.updateImageProcessingConfig(updatedConfig);
      await _loadConfigs();
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '图片处理配置',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _loadConfigs,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (configs.isEmpty) {
      return const Center(child: Text('暂无配置项'));
    }
    return ListView.builder(
      itemCount: configs.length,
      itemBuilder: (context, index) {
        final config = configs[index];
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
                      config.configKey,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (config.isFrozen)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '已冻结',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (config.description != null &&
                    config.description!.isNotEmpty)
                  Text(
                    config.description!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    config.configValue,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 8),
                Text('版本: ${config.version}'),
                const SizedBox(height: 8),
                if (!config.isFrozen)
                  OutlinedButton.icon(
                    onPressed: () => _editConfig(config),
                    icon: const Icon(Icons.edit),
                    label: const Text('编辑'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
