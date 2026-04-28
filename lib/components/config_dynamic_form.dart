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
          onChanged: widget.isFrozen ? null : (val) =>
              setState(() => _values[field.key] = val),
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
      case 'input':
      default:
        return TextFormField(
          initialValue: _values[field.key]?.toString(),
          decoration: InputDecoration(
            labelText: field.label,
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
            ..._tags.map((tag) =>
                Chip(
                  label: Text(tag),
                  onDeleted: widget.readOnly ? null : () => _remove(tag),
                )),
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
