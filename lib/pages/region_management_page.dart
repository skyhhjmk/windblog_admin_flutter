part of 'package:windblog_admin_flutter/main.dart';

class RegionManagementPage extends StatefulWidget {
  const RegionManagementPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<RegionManagementPage> createState() => _RegionManagementPageState();
}

class _RegionManagementPageState extends State<RegionManagementPage> {
  bool _loading = true;
  String? _error;
  List<RegionRule> _rules = [];

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
      final list = await widget.api.listRegionRules();
      if (mounted) {
        setState(() {
          _rules = list;
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

  Future<void> _saveRule(RegionRule rule) async {
    try {
      if (rule.id == null || rule.id == 0) {
        await widget.api.createRegionRule(rule);
      } else {
        await widget.api.updateRegionRule(rule.id!, rule);
      }
      if (!mounted) return;
      AdminFeedback.showSnackBar(
        context,
        const SnackBar(content: Text('保存成功'), backgroundColor: Colors.green),
      );
      _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteRule(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个区域规则吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.api.deleteRegionRule(id);
        _load();
      } catch (e) {
        if (!mounted) return;
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRuleDialog([RegionRule? existing]) {
    var name = existing?.name ?? '';
    var ruleType = (existing?.ruleType ?? 'DOMAIN').toUpperCase();
    var pattern = existing?.pattern ?? '';
    var region = existing?.region ?? 'global';
    var priority = existing?.priority ?? 0;
    var isEnabled = existing?.isEnabled ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existing == null ? '添加规则' : '编辑规则'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        decoration: const InputDecoration(labelText: '名称'),
                        controller: TextEditingController(text: name)
                          ..selection = TextSelection.collapsed(
                            offset: name.length,
                          ),
                        onChanged: (v) => name = v,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: '规则类型'),
                        initialValue: ruleType,
                        items: const [
                          DropdownMenuItem(
                            value: 'DOMAIN',
                            child: Text('域名 (Domain)'),
                          ),
                          DropdownMenuItem(
                            value: 'LANGUAGE',
                            child: Text('语言 (Language)'),
                          ),
                        ],
                        onChanged: (v) => setState(() => ruleType = v!),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: '匹配模式',
                          hintText: ruleType.toUpperCase() == 'DOMAIN'
                              ? '例如: cn.biliwind.com'
                              : '例如: zh-CN',
                          helperText: ruleType.toUpperCase() == 'DOMAIN'
                              ? '按完整域名精确匹配，忽略大小写、端口和末尾的点；不支持通配符。'
                              : '按语言标记包含匹配，忽略大小写，例如 zh-CN 可匹配 zh-cn。',
                        ),
                        controller: TextEditingController(text: pattern)
                          ..selection = TextSelection.collapsed(
                            offset: pattern.length,
                          ),
                        onChanged: (v) => pattern = v,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: '目标区域'),
                        initialValue: region,
                        items: BlogRegion.values
                            .map(
                              (r) => DropdownMenuItem(
                                value: r.code,
                                child: Text(r.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => region = v!),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: '优先级 (越大越优先)',
                        ),
                        keyboardType: TextInputType.number,
                        controller:
                            TextEditingController(text: priority.toString())
                              ..selection = TextSelection.collapsed(
                                offset: priority.toString().length,
                              ),
                        onChanged: (v) => priority = int.tryParse(v) ?? 0,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('是否启用'),
                        value: isEnabled,
                        onChanged: (v) => setState(() => isEnabled = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    if (name.isEmpty || pattern.isEmpty) {
                      AdminFeedback.showSnackBar(
                        context,
                        const SnackBar(
                          content: Text('名称和模式不能为空'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    _saveRule(
                      RegionRule(
                        id: existing?.id,
                        name: name,
                        ruleType: ruleType,
                        pattern: pattern,
                        region: region,
                        priority: priority,
                        isEnabled: isEnabled,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _showRuleDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加规则'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _load, child: const Text('刷新')),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '规则类型与匹配模式中的英文字母均不区分大小写。域名规则按完整 Host 精确匹配；语言规则按语言标记包含匹配。',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text('错误: $_error'))
                : _rules.isEmpty
                ? const Center(child: Text('暂无规则'))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _rules.length,
                    itemBuilder: (context, index) {
                      final rule = _rules[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: rule.isEnabled
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                            child: Text(
                              rule.region.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(rule.name),
                          subtitle: Text(
                            '类型: ${rule.ruleType} | 模式: ${rule.pattern} | 优先级: ${rule.priority}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showRuleDialog(rule),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteRule(rule.id!),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
