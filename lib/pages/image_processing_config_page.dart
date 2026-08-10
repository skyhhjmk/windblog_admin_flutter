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
  List<ImageProcessingMetadata> metadata = [];
  bool loading = false;
  Map<String, String> testResults = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        widget.api.listImageProcessingConfigs(),
        widget.api.getImageProcessingMetadata(),
      ]);
      configs = results[0] as List<ImageProcessingConfigItem>;
      metadata = results[1] as List<ImageProcessingMetadata>;
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(context,
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _testTool(ImageProcessingMetadata meta) async {
    if (meta.testUrl == null) return;

    setState(() => testResults[meta.key] = '检测中...');
    try {
      final res = await widget.api.testImageProcessingTool(meta.testUrl!);
      setState(() {
        testResults[meta.key] =
            res['message'] ?? (res['available'] == true ? '可用' : '不可用');
      });
    } catch (e) {
      setState(() => testResults[meta.key] = '检测失败: $e');
    }
  }

  Future<void> _editConfig(ImageProcessingMetadata meta,
      ImageProcessingConfigItem? config) async {
    final initialValue = config?.configValue ?? '';
    final controller = TextEditingController(text: initialValue);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text('编辑: ${meta.label}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (meta.description != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(meta.description!, style: const TextStyle(
                        color: Colors.grey, fontSize: 13)),
                  ),
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: meta.label,
                    border: const OutlineInputBorder(),
                    helperText: meta.type == 'number' ? '请输入数字${meta.min !=
                        null ? ' (最小 ${meta.min})' : ''}${meta.max != null
                        ? ' (最大 ${meta.max})'
                        : ''}' : null,
                  ),
                  keyboardType: meta.type == 'number'
                      ? TextInputType.number
                      : TextInputType.text,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text('保存')),
            ],
          ),
    );

    if (confirmed != true) return;

    final updated = ImageProcessingConfigItem(
      id: config?.id ?? 0,
      configKey: meta.key,
      configValue: controller.text,
      version: config?.version ?? 0,
      isFrozen: config?.isFrozen ?? false,
    );

    try {
      await widget.api.updateImageProcessingConfig(updated);
      await _loadAll();
      if (meta.testUrl != null) {
        _testTool(meta);
      }
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(context,
            SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('媒体处理配置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: metadata.length,
      itemBuilder: (context, index) {
        final meta = metadata[index];
        final config = configs.cast<ImageProcessingConfigItem?>().firstWhere((
            c) => c?.configKey == meta.key, orElse: () => null);
        final testResult = testResults[meta.key];

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withAlpha(51)),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(meta.key.contains('path') ? Icons.terminal : Icons
                        .settings_applications, color: Theme
                        .of(context)
                        .primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(meta.label, style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(meta.key, style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    if (config?.isFrozen == true)
                      Chip(label: const Text(
                          '只读', style: TextStyle(fontSize: 10)),
                          backgroundColor: Colors.orange.shade50),
                  ],
                ),
                const SizedBox(height: 16),
                if (meta.description != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(meta.description!, style: TextStyle(
                        color: Colors.grey.shade700, fontSize: 13)),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    config?.configValue ?? '(未配置)',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 14),
                  ),
                ),
                if (testResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Icon(testResult.contains('失败') || testResult.contains(
                            '不') ? Icons.error_outline : Icons
                            .check_circle_outline,
                            size: 16,
                            color: testResult.contains('失败') || testResult
                                .contains('不') ? Colors.red : Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(testResult, style: TextStyle(
                            fontSize: 12,
                            color: testResult.contains('失败') ||
                                testResult.contains('不') ? Colors.red : Colors
                                .green))),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (config?.isFrozen != true)
                      FilledButton.icon(
                        onPressed: () => _editConfig(meta, config),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('修改'),
                      ),
                    if (meta.testUrl != null) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _testTool(meta),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('立即检测'),
                      ),
                    ],
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
