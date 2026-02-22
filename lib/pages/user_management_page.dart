part of 'package:windblog_admin_flutter/main.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({
    super.key,
    required this.api,
    required this.onAuthError,
    required this.isSuperAdmin,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;
  final bool isSuperAdmin;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final keywordCtrl = TextEditingController();
  PageResult<UserListItem>? pageResult;
  bool loading = false;
  bool loadingRoles = true;
  List<PermissionRoleItem> roles = [];
  int page = 1;

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _loadUsers();
  }

  @override
  void dispose() {
    keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => loading = true);
    try {
      pageResult = await widget.api.listUsers(
        page: page,
        pageSize: 20,
        keyword: keywordCtrl.text.trim(),
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u52a0\u8f7d\u7528\u6237\u5217\u8868\u5931\u8d25: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadRoles() async {
    setState(() => loadingRoles = true);
    try {
      roles = await widget.api.listRoles();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (_) {}
    if (mounted) setState(() => loadingRoles = false);
  }

  Future<void> _editUser(UserListItem user) async {
    final result = await showDialog<_UserEditResult>(
      context: context,
      builder: (context) => _UserEditDialog(
        user: user,
        roles: roles,
        isSuperAdmin: widget.isSuperAdmin,
      ),
    );
    if (result == null) return;
    try {
      await widget.api.updateUser(
        user.id,
        email: result.email,
        status: result.status,
        roleName: result.role,
      );
      await _loadUsers();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\u66f4\u65b0\u7528\u6237\u5931\u8d25: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = pageResult?.items ?? [];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: keywordCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search username/email',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  page = 1;
                  _loadUsers();
                },
                child: const Text('Search'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loadUsers,
                child: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? const Center(child: Text('No users'))
                    : ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(user.username.isEmpty
                                  ? '?'
                                  : user.username[0].toUpperCase()),
                            ),
                            title: Text(user.username),
                            subtitle: Text('${user.email} \u00b7 ${user.roleName}'),
                            trailing: Text(user.statusText),
                            onTap: () => _editUser(user),
                          );
                        },
                      ),
          ),
          if (pageResult != null)
            Row(
              children: [
                Text('Page: $page / Total: ${pageResult!.total}'),
                const Spacer(),
                IconButton(
                  onPressed: page <= 1 ? null : () => setState(() => page--),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: page * pageResult!.pageSize >= pageResult!.total
                      ? null
                      : () => setState(() => page++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _UserEditDialog extends StatefulWidget {
  const _UserEditDialog({
    required this.user,
    required this.roles,
    required this.isSuperAdmin,
  });

  final UserListItem user;
  final List<PermissionRoleItem> roles;
  final bool isSuperAdmin;

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late final TextEditingController emailCtrl;
  late int status;
  late String roleName;

  List<PermissionRoleItem> get _availableRoles {
    if (widget.roles.isNotEmpty) return widget.roles;
    return [
      PermissionRoleItem(
        name: widget.user.roleName,
        displayName: widget.user.roleName,
        description: '',
        canUpload: false,
        allowedMimeTypes: const [],
        createdAt: null,
        updatedAt: null,
      )
    ];
  }

  @override
  void initState() {
    super.initState();
    emailCtrl = TextEditingController(text: widget.user.email);
    status = widget.user.status;
    roleName = widget.user.roleName;
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Email'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Active')),
                DropdownMenuItem(value: 1, child: Text('Disabled')),
                DropdownMenuItem(value: 2, child: Text('Locked')),
              ],
              onChanged: (v) => setState(() => status = v ?? 0),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: roleName,
              decoration: const InputDecoration(labelText: 'Email'),
              items: _availableRoles
                  .map((role) => DropdownMenuItem(
                        value: role.name,
                        child: Text(role.displayName),
                      ))
                  .toList(),
              onChanged: widget.isSuperAdmin
                  ? (v) => setState(() => roleName = v ?? roleName)
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Search'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _UserEditResult(
              emailCtrl.text.trim(),
              status,
              roleName,
            ),
          ),
          child: const Text('Search'),
        ),
      ],
    );
  }
}

class _UserEditResult {
  _UserEditResult(this.email, this.status, this.role);

  final String email;
  final int status;
  final String role;
}

