part of 'package:windblog_admin_flutter/main.dart';

class GoogleAdSenseSettingsEditor extends StatefulWidget {
  const GoogleAdSenseSettingsEditor({
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
  State<GoogleAdSenseSettingsEditor> createState() =>
      _GoogleAdSenseSettingsEditorState();
}

class _GoogleAdSenseSettingsEditorState
    extends State<GoogleAdSenseSettingsEditor> {
  final _formKey = GlobalKey<_ConfigDynamicFormState>();
  late List<Map<String, dynamic>> _blocks;
  String? _blocksError;

  @override
  void initState() {
    super.initState();
    _readBlocks();
  }

  @override
  void didUpdateWidget(covariant GoogleAdSenseSettingsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValues != widget.initialValues) _readBlocks();
  }

  void _readBlocks() {
    final raw = widget.initialValues['blocks'];
    try {
      final decoded = raw is String
          ? jsonDecode(raw.isEmpty ? '[]' : raw)
          : raw;
      if (decoded == null) {
        _blocks = [];
        _blocksError = null;
      } else if (decoded is List) {
        _blocks = decoded
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList();
        _blocksError = decoded.length == _blocks.length
            ? null
            : '广告块数据中包含无法识别的项目。保存前请清空并重新添加。';
      } else {
        _blocks = [];
        _blocksError = '广告块配置不是数组。保存前请清空并重新添加。';
      }
    } catch (_) {
      _blocks = [];
      _blocksError = '广告块 JSON 无法解析。为避免覆盖原配置，请先清空并重新添加。';
    }
  }

  Future<void> _editBlock({Map<String, dynamic>? current, int? index}) async {
    final block = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AdBlockDialog(initialValue: current ?? const {}),
    );
    if (block == null || !mounted) return;
    setState(() {
      if (index == null) {
        _blocks.add(block);
      } else {
        _blocks[index] = block;
      }
    });
  }

  void _save(Map<String, dynamic> values) {
    if (_blocksError != null) return;
    values['blocks'] = jsonEncode(_blocks);
    widget.onSave(values);
  }

  String _label(Map<String, dynamic> block) {
    final slot = block['slot']?.toString().trim() ?? '';
    final placement = block['placement']?.toString() ?? 'content_top';
    return '${slot.isEmpty ? '未填写广告位 ID' : '广告位 $slot'} · ${_placementLabel(placement)}';
  }

  String _placementLabel(String value) => switch (value) {
    'content_bottom' => '文章内容底部',
    'sidebar' => '侧栏',
    _ => '文章内容顶部',
  };

  @override
  Widget build(BuildContext context) {
    final configSchema = UISchema(
      type: widget.schema.type,
      fields: widget.schema.fields
          .where((field) => field.key != 'blocks')
          .toList(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConfigDynamicForm(
          key: _formKey,
          schema: configSchema,
          initialValues: widget.initialValues,
          isFrozen: widget.isFrozen,
          showSaveButton: false,
          onSave: _save,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '手动广告块',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (!widget.isFrozen && _blocksError == null)
              OutlinedButton.icon(
                onPressed: _blocks.length >= 20 ? null : () => _editBlock(),
                icon: const Icon(Icons.add),
                label: const Text('添加广告块'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '每个广告块可独立设置广告位 ID、页面位置、格式、响应式尺寸和设备范围，最多 20 个。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (_blocksError != null)
          AlertBanner(message: _blocksError!, type: AlertType.warning)
        else if (_blocks.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('尚未添加手动广告块。'),
            ),
          )
        else
          ..._blocks.asMap().entries.map((entry) {
            final index = entry.key;
            final block = entry.value;
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(_label(block)),
                subtitle: Text(
                  '${block['format'] ?? 'auto'} · ${block['device'] ?? 'all'}'
                  '${block['enabled'] == false ? ' · 已停用' : ''}',
                ),
                trailing: widget.isFrozen
                    ? null
                    : Wrap(
                        children: [
                          IconButton(
                            tooltip: '编辑',
                            onPressed: () =>
                                _editBlock(current: block, index: index),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: '删除',
                            onPressed: () =>
                                setState(() => _blocks.removeAt(index)),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
              ),
            );
          }),
        if (_blocksError != null && !widget.isFrozen) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _blocks = [];
              _blocksError = null;
            }),
            icon: const Icon(Icons.restart_alt),
            label: const Text('清空异常数据并重新配置广告块'),
          ),
        ],
        const SizedBox(height: 16),
        if (!widget.isFrozen)
          FilledButton.icon(
            onPressed: _blocksError == null
                ? () => _formKey.currentState?._submit()
                : null,
            icon: const Icon(Icons.save),
            label: Text(t(context, 'save_config')),
          )
        else
          AlertBanner(
            message: t(context, 'config_frozen_msg'),
            type: AlertType.warning,
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AdBlockDialog extends StatefulWidget {
  const _AdBlockDialog({required this.initialValue});

  final Map<String, dynamic> initialValue;

  @override
  State<_AdBlockDialog> createState() => _AdBlockDialogState();
}

class _AdBlockDialogState extends State<_AdBlockDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _slotController;
  late final TextEditingController _minHeightController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _layoutController;
  late final TextEditingController _layoutKeyController;
  late String _placement;
  late String _format;
  late String _device;
  late bool _responsive;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    _slotController = TextEditingController(text: value['slot']?.toString());
    _minHeightController = TextEditingController(
      text: (value['minHeight'] ?? 250).toString(),
    );
    _widthController = TextEditingController(text: value['width']?.toString());
    _heightController = TextEditingController(
      text: value['height']?.toString(),
    );
    _layoutController = TextEditingController(
      text: value['layout']?.toString(),
    );
    _layoutKeyController = TextEditingController(
      text: value['layoutKey']?.toString(),
    );
    _placement = _choice(value['placement'], const [
      'content_top',
      'content_bottom',
      'sidebar',
    ], 'content_top');
    _format = _choice(value['format'], const [
      'auto',
      'rectangle',
      'horizontal',
      'vertical',
      'fluid',
      'fixed',
    ], 'auto');
    _device = _choice(value['device'], const [
      'all',
      'mobile',
      'desktop',
    ], 'all');
    _responsive = value['responsive'] != false;
    _enabled = value['enabled'] != false;
  }

  String _choice(dynamic value, List<String> options, String fallback) {
    final result = value?.toString();
    return options.contains(result) ? result! : fallback;
  }

  @override
  void dispose() {
    _slotController.dispose();
    _minHeightController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _layoutController.dispose();
    _layoutKeyController.dispose();
    super.dispose();
  }

  String? _boundedInteger(
    String? value, {
    required int minimum,
    required int maximum,
  }) {
    final number = int.tryParse(value ?? '');
    if (number == null || number < minimum || number > maximum) {
      return '请输入 $minimum–$maximum 之间的整数';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final result = Map<String, dynamic>.from(widget.initialValue)
      ..['slot'] = _slotController.text.trim()
      ..['placement'] = _placement
      ..['format'] = _format
      ..['responsive'] = _responsive
      ..['minHeight'] = int.parse(_minHeightController.text)
      ..['device'] = _device
      ..['enabled'] = _enabled;
    if (_format == 'fixed') {
      result['width'] = int.parse(_widthController.text);
      result['height'] = int.parse(_heightController.text);
    } else {
      result.remove('width');
      result.remove('height');
    }
    if (_format == 'fluid') {
      if (_layoutController.text.trim().isNotEmpty) {
        result['layout'] = _layoutController.text.trim();
      } else {
        result.remove('layout');
      }
      if (_layoutKeyController.text.trim().isNotEmpty) {
        result['layoutKey'] = _layoutKeyController.text.trim();
      } else {
        result.remove('layoutKey');
      }
    } else {
      result.remove('layout');
      result.remove('layoutKey');
    }
    Navigator.of(context).pop(result);
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map((item) => DropdownMenuItem(value: item.$1, child: Text(item.$2)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _integerField(
    TextEditingController controller,
    String label,
    int min,
    int max,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) => _boundedInteger(value, minimum: min, maximum: max),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialValue.isEmpty ? '添加广告块' : '编辑广告块'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _slotController,
                  decoration: const InputDecoration(
                    labelText: '广告位 ID（slot）',
                    helperText: '从 AdSense 广告单元代码中复制 data-ad-slot。',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '请输入广告位 ID'
                      : null,
                ),
                const SizedBox(height: 12),
                _dropdown(
                  label: '页面位置',
                  value: _placement,
                  options: const [
                    ('content_top', '文章内容顶部'),
                    ('content_bottom', '文章内容底部'),
                    ('sidebar', '侧栏'),
                  ],
                  onChanged: (value) =>
                      setState(() => _placement = value ?? _placement),
                ),
                const SizedBox(height: 12),
                _dropdown(
                  label: '广告格式',
                  value: _format,
                  options: const [
                    ('auto', '自适应（auto）'),
                    ('rectangle', '矩形'),
                    ('horizontal', '横幅'),
                    ('vertical', '竖幅'),
                    ('fluid', '原生流式（fluid）'),
                    ('fixed', '固定尺寸'),
                  ],
                  onChanged: (value) =>
                      setState(() => _format = value ?? _format),
                ),
                if (_format == 'fixed') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _integerField(
                          _widthController,
                          '宽度（px）',
                          1,
                          2000,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _integerField(
                          _heightController,
                          '高度（px）',
                          1,
                          2000,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_format == 'fluid') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _layoutController,
                    decoration: const InputDecoration(
                      labelText: 'layout（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _layoutKeyController,
                    decoration: const InputDecoration(
                      labelText: 'layoutKey（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _dropdown(
                  label: '显示设备',
                  value: _device,
                  options: const [
                    ('all', '所有设备'),
                    ('mobile', '仅手机'),
                    ('desktop', '仅桌面端'),
                  ],
                  onChanged: (value) =>
                      setState(() => _device = value ?? _device),
                ),
                const SizedBox(height: 12),
                _integerField(_minHeightController, '预留高度（px）', 0, 1200),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('响应式广告'),
                  value: _responsive,
                  onChanged: (value) => setState(() => _responsive = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用此广告块'),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }
}
