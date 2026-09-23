part of 'package:windblog_admin_flutter/main.dart';

class VaultUnlockPage extends StatefulWidget {
  const VaultUnlockPage({required this.onUnlock, super.key});

  final Future<void> Function(String password) onUnlock;

  @override
  State<VaultUnlockPage> createState() => _VaultUnlockPageState();
}

class _VaultUnlockPageState extends State<VaultUnlockPage> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onUnlock(_password.text);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_outline, size: 44),
                const SizedBox(height: 12),
                Text(
                  '解锁 WindBlog 实例库',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('主密码只在本次应用运行期间有效。', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofocus: true,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: '主密码'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('解锁并自动登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class InstanceManagerDialog extends StatefulWidget {
  const InstanceManagerDialog({super.key});

  @override
  State<InstanceManagerDialog> createState() => _InstanceManagerDialogState();
}

class _InstanceManagerDialogState extends State<InstanceManagerDialog> {
  String? _selectedId;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedId = prefs.getString('admin_active_instance_id');
        _ready = true;
      });
    }
  }

  Future<bool> _ensureUnlocked() async {
    if (InstanceVault.isUnlocked) return true;
    if (await InstanceVault.exists) return false;
    if (!mounted) return false;
    final master = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateMasterPasswordDialog(),
    );
    if (master == null) return false;
    await InstanceVault.create(master);
    return true;
  }

  Future<void> _edit([AdminInstance? existing]) async {
    if (!await _ensureUnlocked()) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先解锁实例库后再管理账号。')));
      }
      return;
    }
    if (!mounted) return;
    final draft = await showDialog<_InstanceDraft>(
      context: context,
      builder: (_) => _InstanceEditorDialog(existing: existing),
    );
    if (draft == null) return;
    final instance = AdminInstance(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: draft.name,
      baseUrl: draft.baseUrl,
      account: draft.account,
      password: draft.password,
    );
    final updated = [...InstanceVault.instances];
    final index = updated.indexWhere((item) => item.id == instance.id);
    if (index < 0) {
      updated.add(instance);
    } else {
      updated[index] = instance;
    }
    await InstanceVault.save(updated);
    if (mounted) setState(() => _selectedId ??= instance.id);
  }

  Future<void> _delete(AdminInstance instance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除实例'),
        content: Text('删除“${instance.name}”保存的登录方式？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = InstanceVault.instances
        .where((item) => item.id != instance.id)
        .toList();
    await InstanceVault.save(updated);
    if (_selectedId == instance.id) {
      _selectedId = updated.isEmpty ? null : updated.first.id;
    }
    if (mounted) setState(() {});
  }

  Future<void> _connect(AdminInstance instance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_active_instance_id', instance.id);
    if (mounted) Navigator.pop(context, instance);
  }

  @override
  Widget build(BuildContext context) {
    final instances = InstanceVault.isUnlocked
        ? InstanceVault.instances
        : const <AdminInstance>[];
    return AlertDialog(
      title: const Text('WindBlog 实例管理'),
      content: SizedBox(
        width: 500,
        child: !_ready
            ? const Center(child: CircularProgressIndicator())
            : instances.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('还没有保存的实例。添加实例后，启动时会自动登录上次选择的实例。'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: instances.length,
                itemBuilder: (context, index) {
                  final instance = instances[index];
                  return ListTile(
                    selected: instance.id == _selectedId,
                    leading: const Icon(Icons.dns_outlined),
                    title: Text(instance.name),
                    subtitle: Text('${instance.baseUrl}\n${instance.account}'),
                    isThreeLine: true,
                    onTap: () => setState(() => _selectedId = instance.id),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _edit(instance);
                        if (value == 'delete') _delete(instance);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('编辑')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _edit,
          icon: const Icon(Icons.add),
          label: const Text('添加实例'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        if (instances.isNotEmpty)
          FilledButton(
            onPressed: instances.where((item) => item.id == _selectedId).isEmpty
                ? null
                : () => _connect(
                    instances.firstWhere((item) => item.id == _selectedId),
                  ),
            child: const Text('连接并登录'),
          ),
      ],
    );
  }
}

class _CreateMasterPasswordDialog extends StatefulWidget {
  const _CreateMasterPasswordDialog();

  @override
  State<_CreateMasterPasswordDialog> createState() =>
      _CreateMasterPasswordDialogState();
}

class _CreateMasterPasswordDialogState
    extends State<_CreateMasterPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.length < 8) {
      setState(() => _error = '主密码至少需要 8 个字符。');
    } else if (_password.text != _confirm.text) {
      setState(() => _error = '两次输入的主密码不一致。');
    } else {
      Navigator.pop(context, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('设置实例库主密码'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('主密码用于加密保存的账号密码；忘记后无法恢复，请妥善保管。'),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: '主密码'),
          ),
          TextField(
            controller: _confirm,
            obscureText: true,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: '确认主密码'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('创建实例库')),
    ],
  );
}

class _InstanceDraft {
  const _InstanceDraft(this.name, this.baseUrl, this.account, this.password);
  final String name;
  final String baseUrl;
  final String account;
  final String password;
}

class _InstanceEditorDialog extends StatefulWidget {
  const _InstanceEditorDialog({this.existing});
  final AdminInstance? existing;

  @override
  State<_InstanceEditorDialog> createState() => _InstanceEditorDialogState();
}

class _InstanceEditorDialogState extends State<_InstanceEditorDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _url = TextEditingController(text: widget.existing?.baseUrl ?? '');
  late final _account = TextEditingController(
    text: widget.existing?.account ?? '',
  );
  late final _password = TextEditingController(
    text: widget.existing?.password ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? '添加实例' : '编辑实例'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '实例名称'),
            ),
            TextField(
              controller: _url,
              decoration: const InputDecoration(labelText: '服务器地址'),
            ),
            TextField(
              controller: _account,
              decoration: const InputDecoration(labelText: '管理员账号'),
            ),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: '管理员密码'),
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
          if (_name.text.trim().isEmpty ||
              _url.text.trim().isEmpty ||
              _account.text.trim().isEmpty ||
              _password.text.isEmpty) {
            return;
          }
          Navigator.pop(
            context,
            _InstanceDraft(
              _name.text.trim(),
              _url.text.trim(),
              _account.text.trim(),
              _password.text,
            ),
          );
        },
        child: const Text('保存'),
      ),
    ],
  );
}
