part of 'package:windblog_admin_flutter/main.dart';

class PermissionManagementPage extends StatefulWidget {
  const PermissionManagementPage({
    super.key,
    required this.api,
    required this.isSuperAdmin,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final bool isSuperAdmin;
  final VoidCallback onAuthError;

  @override
  State<PermissionManagementPage> createState() => _PermissionManagementPageState();
}

class _PermissionManagementPageState extends State<PermissionManagementPage> {
  List<PermissionRoleItem> roles = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() => loading = true);
    try {
      roles = await widget.api.listRoles();
    } on UnauthorizedException {
      widget.onAuthError();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openRoleDialog([PermissionRoleItem? role]) async {
    final result = await showDialog<PermissionRoleRequest>(
      context: context,
      builder: (_) => _RoleFormDialog(
        role: role,
      ),
    );
    if (result == null) return;
    try {
      if (role == null) {
        await widget.api.createRole(result);
      } else {
        await widget.api.updateRole(role.name, result);
      }
      await _loadRoles();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\u4fdd\u5b58\u89d2\u8272\u5931\u8d25: $e')),
      );
    }
  }

  Future<void> _deleteRole(String name) async {
    try {
      await widget.api.deleteRole(name);
      await _loadRoles();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\u5220\u9664\u89d2\u8272\u5931\u8d25: $e')),
      );
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
              const Text('Permission Roles'),
              const Spacer(),
              ElevatedButton(
                onPressed: widget.isSuperAdmin ? () => _openRoleDialog() : null,
                child: const Text('Create Role'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : roles.isEmpty
                    ? const Center(child: Text('No roles'))
                    : ListView.separated(
                        itemCount: roles.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final role = roles[index];
                          return ListTile(
                            title: Text(role.displayName),
                            subtitle: Text(
                              role.allowedMimeTypes.join(', '),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: widget.isSuperAdmin
                                      ? () => _openRoleDialog(role)
                                      : null,
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  onPressed: widget.isSuperAdmin &&
                                          !_defaultRoles.contains(role.name)
                                      ? () => _deleteRole(role.name)
                                      : null,
                                  icon: const Icon(Icons.delete),
                                ),
                              ],
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

const List<String> _defaultRoles = ['SUPER_ADMIN', 'ADMIN', 'USER', 'GUEST'];

class _RoleFormDialog extends StatefulWidget {
  const _RoleFormDialog({this.role});

  final PermissionRoleItem? role;

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController displayCtrl;
  late final TextEditingController descriptionCtrl;
  late final TextEditingController mimeCtrl;
  late final TextEditingController singleCtrl;
  late final TextEditingController totalCtrl;
  bool canUpload = false;

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    nameCtrl = TextEditingController(text: role?.name ?? '');
    displayCtrl = TextEditingController(text: role?.displayName ?? '');
    descriptionCtrl = TextEditingController(text: role?.description ?? '');
    mimeCtrl = TextEditingController(
      text: role?.allowedMimeTypes.join(', ') ?? '',
    );
    singleCtrl = TextEditingController(
      text: role?.maxSingleUploadBytes?.toString() ?? '',
    );
    totalCtrl = TextEditingController(
      text: role?.maxTotalUploadBytes?.toString() ?? '',
    );
    canUpload = role?.canUpload ?? false;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    displayCtrl.dispose();
    descriptionCtrl.dispose();
    mimeCtrl.dispose();
    singleCtrl.dispose();
    totalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.role == null ? '\u521b\u5efa\u89d2\u8272' : '\u7f16\u8f91\u89d2\u8272'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Role Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: displayCtrl,
                decoration: const InputDecoration(labelText: 'Role Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionCtrl,
                decoration: const InputDecoration(labelText: 'Role Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: mimeCtrl,
                decoration: const InputDecoration(labelText: 'Role Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: singleCtrl,
                decoration: const InputDecoration(labelText: 'Role Name'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: totalCtrl,
                decoration: const InputDecoration(labelText: 'Role Name'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: canUpload,
                onChanged: (value) => setState(() => canUpload = value ?? false),
                title: const Text('Upload Permission'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Create Role'),
        ),
        FilledButton(
          onPressed: () {
            final request = PermissionRoleRequest(
              name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
              displayName: displayCtrl.text.trim(),
              description: descriptionCtrl.text.trim(),
              canUpload: canUpload,
              allowedMimeTypes: mimeCtrl.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
              maxSingleUploadBytes: int.tryParse(singleCtrl.text.trim()),
              maxTotalUploadBytes: int.tryParse(totalCtrl.text.trim()),
            );
            Navigator.pop(context, request);
          },
          child: const Text('Create Role'),
        ),
      ],
    );
  }
}
