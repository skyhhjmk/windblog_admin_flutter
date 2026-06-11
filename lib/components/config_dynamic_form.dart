part of 'package:windblog_admin_flutter/main.dart';

class ConfigDynamicForm extends StatefulWidget {
  const ConfigDynamicForm({
    super.key,
    required this.schema,
    required this.initialValues,
    required this.onSave,
    this.isFrozen = false,
  });

  final UISchema schema;
  final Map<String, dynamic> initialValues;
  final Function(Map<String, dynamic> values) onSave;
  final bool isFrozen;

  @override
  State<ConfigDynamicForm> createState() => _ConfigDynamicFormState();
}

class _ConfigDynamicFormState extends State<ConfigDynamicForm> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _values;

  @override
  void initState() {
    super.initState();
    _values = Map<String, dynamic>.from(widget.initialValues);
  }

  @override
  void didUpdateWidget(ConfigDynamicForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValues != oldWidget.initialValues) {
      _values = Map<String, dynamic>.from(widget.initialValues);
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      widget.onSave(_values);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...widget.schema.fields.map((field) => _buildField(field)),
          const SizedBox(height: 24),
          if (!widget.isFrozen)
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save),
              label: Text(t(context, 'save_config')),
            )
          else
            AlertBanner(
              message: t(context, 'config_frozen_msg'),
              type: AlertType.warning,
            ),
        ],
      ),
    );
  }

  Widget _buildField(UISchemaField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildWidget(field),
    );
  }

  Widget _buildWidget(UISchemaField field) {
    switch (field.widget) {
      case 'switch':
        return SwitchListTile(
          title: Text(field.label),
          value: _values[field.key] ?? false,
          onChanged: widget.isFrozen
              ? null
              : (val) => setState(() => _values[field.key] = val),
        );
      case 'tag_input':
        final rawVal = _values[field.key];
        List<String> tags = [];
        if (rawVal is List) {
          tags = List<String>.from(rawVal);
        } else if (rawVal is String && rawVal.isNotEmpty) {
          tags = rawVal
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        return _TagInput(
          label: field.label,
          initialValue: tags,
          onChanged: (val) => _values[field.key] = val,
          readOnly: widget.isFrozen,
        );
      case 'password':
        return TextFormField(
          initialValue: _values[field.key]?.toString(),
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.hint,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
          readOnly: widget.isFrozen,
          onSaved: (value) => _values[field.key] = value ?? '',
        );
      case 'number':
        return TextFormField(
          initialValue: _values[field.key]?.toString(),
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.hint,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          readOnly: widget.isFrozen,
          onSaved: (value) {
            _values[field.key] = int.tryParse(value ?? '') ?? 0;
          },
          validator: (value) {
            if (field.required && (value == null || value.isEmpty)) {
              return '该项必填';
            }
            if (value != null &&
                value.isNotEmpty &&
                int.tryParse(value) == null) {
              return '请输入整数';
            }
            return null;
          },
        );
      case 'select':
        final options = field.options ?? const <Map<String, dynamic>>[];
        String? selectedValue = _values[field.key]?.toString();
        bool valueExists = false;
        for (Map<String, dynamic> option in options) {
          if (option['value']?.toString() == selectedValue) {
            valueExists = true;
          }
        }
        if (!valueExists) {
          selectedValue = null;
        }
        return DropdownButtonFormField<String>(
          initialValue: selectedValue,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.hint,
            border: const OutlineInputBorder(),
          ),
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option['value']?.toString() ?? '',
              child: Text(option['label']?.toString() ?? ''),
            );
          }).toList(),
          onChanged: widget.isFrozen
              ? null
              : (value) {
                  setState(() {
                    _values[field.key] = value;
                  });
                },
        );
      case 'synonym_cards':
        return SynonymRuleEditor(
          initialValue: _values[field.key],
          readOnly: widget.isFrozen,
          onChanged: (rules) {
            _values[field.key] = rules;
          },
        );
      case 'input':
      default:
        return TextFormField(
          initialValue: _values[field.key]?.toString(),
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.hint,
            border: const OutlineInputBorder(),
          ),
          readOnly: widget.isFrozen,
          onSaved: (val) => _values[field.key] = val,
          validator: field.required
              ? (val) => (val == null || val.isEmpty) ? '该项必填' : null
              : null,
        );
    }
  }
}

class SynonymRuleEditor extends StatefulWidget {
  const SynonymRuleEditor({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.readOnly = false,
  });

  final dynamic initialValue;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final bool readOnly;

  @override
  State<SynonymRuleEditor> createState() => _SynonymRuleEditorState();
}

class _SynonymRuleEditorState extends State<SynonymRuleEditor> {
  late List<Map<String, dynamic>> rules;

  @override
  void initState() {
    super.initState();
    rules = [];
    if (widget.initialValue is List) {
      for (dynamic item in widget.initialValue as List) {
        if (item is Map) {
          rules.add(Map<String, dynamic>.from(item));
        }
      }
    }
  }

  void _addRule() {
    setState(() {
      rules.add({'mode': 'equivalent', 'terms': <String>[], 'target': ''});
      widget.onChanged(rules);
    });
  }

  void _removeRule(int index) {
    setState(() {
      rules.removeAt(index);
      widget.onChanged(rules);
    });
  }

  void _moveRule(int index, int direction) {
    int targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= rules.length) {
      return;
    }
    setState(() {
      Map<String, dynamic> rule = rules.removeAt(index);
      rules.insert(targetIndex, rule);
      widget.onChanged(rules);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '同义词规则',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (rules.isEmpty) const AdminStatusView.empty(title: '暂无同义词规则'),
        for (int index = 0; index < rules.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SynonymRuleCard(
              index: index,
              rule: rules[index],
              readOnly: widget.readOnly,
              onChanged: (rule) {
                rules[index] = rule;
                widget.onChanged(rules);
              },
              onMoveUp: () => _moveRule(index, -1),
              onMoveDown: () => _moveRule(index, 1),
              onDelete: () => _removeRule(index),
            ),
          ),
        if (!widget.readOnly)
          OutlinedButton.icon(
            onPressed: _addRule,
            icon: const Icon(Icons.add),
            label: const Text('新增规则卡片'),
          ),
      ],
    );
  }
}

class _SynonymRuleCard extends StatefulWidget {
  const _SynonymRuleCard({
    required this.index,
    required this.rule,
    required this.readOnly,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final int index;
  final Map<String, dynamic> rule;
  final bool readOnly;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  @override
  State<_SynonymRuleCard> createState() => _SynonymRuleCardState();
}

class _SynonymRuleCardState extends State<_SynonymRuleCard> {
  late String mode;
  late List<String> terms;
  late TextEditingController termController;
  late TextEditingController targetController;

  @override
  void initState() {
    super.initState();
    mode = widget.rule['mode']?.toString() ?? 'equivalent';
    terms = [];
    dynamic rawTerms = widget.rule['terms'];
    if (rawTerms is List) {
      terms = rawTerms.map((item) => item.toString()).toList();
    }
    termController = TextEditingController();
    targetController = TextEditingController(
      text: widget.rule['target']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    termController.dispose();
    targetController.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged({
      'mode': mode,
      'terms': List<String>.from(terms),
      'target': targetController.text.trim(),
    });
  }

  void _addTerm(String value) {
    String term = value.trim();
    if (term.isEmpty || terms.contains(term)) {
      return;
    }
    setState(() {
      terms.add(term);
      termController.clear();
      _notifyChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '规则卡片 ${widget.index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: mode,
                  items: const [
                    DropdownMenuItem(value: 'equivalent', child: Text('等价组')),
                    DropdownMenuItem(value: 'mapping', child: Text('单向映射')),
                  ],
                  onChanged: widget.readOnly
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            mode = value;
                            _notifyChanged();
                          });
                        },
                ),
                IconButton(
                  onPressed: widget.readOnly ? null : widget.onMoveUp,
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: '上移',
                ),
                IconButton(
                  onPressed: widget.readOnly ? null : widget.onMoveDown,
                  icon: const Icon(Icons.arrow_downward),
                  tooltip: '下移',
                ),
                IconButton(
                  onPressed: widget.readOnly ? null : widget.onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '删除',
                ),
              ],
            ),
            if (mode == 'mapping') ...[
              const SizedBox(height: 8),
              TextField(
                controller: targetController,
                readOnly: widget.readOnly,
                decoration: const InputDecoration(
                  labelText: '映射到',
                  hintText: '目标词',
                ),
                onChanged: (value) => _notifyChanged(),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: terms.map((term) {
                return InputChip(
                  label: Text(term),
                  onDeleted: widget.readOnly
                      ? null
                      : () {
                          setState(() {
                            terms.remove(term);
                            _notifyChanged();
                          });
                        },
                );
              }).toList(),
            ),
            if (!widget.readOnly) ...[
              const SizedBox(height: 12),
              TextField(
                controller: termController,
                decoration: const InputDecoration(
                  hintText: '输入词条后按回车添加',
                  suffixIcon: Icon(Icons.add),
                ),
                onSubmitted: _addTerm,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagInput extends StatefulWidget {
  const _TagInput({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.readOnly = false,
  });

  final String label;
  final List<String> initialValue;
  final ValueChanged<List<String>> onChanged;
  final bool readOnly;

  @override
  State<_TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<_TagInput> {
  late List<String> _tags;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = List<String>.from(widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(String val) {
    val = val.trim();
    if (val.isNotEmpty && !_tags.contains(val)) {
      setState(() {
        _tags.add(val);
        widget.onChanged(_tags);
        _ctrl.clear();
      });
    }
  }

  void _remove(String val) {
    setState(() {
      _tags.remove(val);
      widget.onChanged(_tags);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._tags.map(
              (tag) => Chip(
                label: Text(tag),
                onDeleted: widget.readOnly ? null : () => _remove(tag),
              ),
            ),
            if (!widget.readOnly)
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: '${t(context, 'add_tag')}...',
                    isDense: true,
                  ),
                  onSubmitted: _add,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

enum AlertType { info, warning, error, success }

class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key, required this.message, required this.type});

  final String message;
  final AlertType type;

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (type) {
      case AlertType.warning:
        color = Colors.orange.shade100;
        icon = Icons.warning_amber_rounded;
        break;
      case AlertType.error:
        color = Colors.red.shade100;
        icon = Icons.error_outline;
        break;
      case AlertType.success:
        color = Colors.green.shade100;
        icon = Icons.check_circle_outline;
        break;
      case AlertType.info:
        color = Colors.blue.shade100;
        icon = Icons.info_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
