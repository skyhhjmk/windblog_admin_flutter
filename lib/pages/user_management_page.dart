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
  bool loading = true;
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
          SnackBar(content: Text('${t(context, 'load_failed')}$e')),
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

  void _openWallet(UserListItem user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserWalletPage(
              api: widget.api,
              userId: user.id,
              username: user.username,
              onAuthError: widget.onAuthError,
              isSuperAdmin: widget.isSuperAdmin,
            ),
      ),
    );
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
        avatar: result.avatar,
        nickname: result.nickname,
        phone: result.phone,
        status: result.status,
        roleName: result.role,
      );
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'update_success'))),
        );
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'update_failed')}$e')),
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
                  decoration: InputDecoration(
                    hintText: t(context, 'search_username_email'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  page = 1;
                  _loadUsers();
                },
                child: Text(t(context, 'search')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loadUsers,
                child: Text(t(context, 'refresh')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? Center(child: Text(t(context, 'no_users')))
                    : ListView.separated(
              physics: const BouncingScrollPhysics(),
                        itemCount: users.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme
                                  .of(context)
                                  .colorScheme
                                  .primaryContainer,
                              foregroundColor: Theme
                                  .of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              child: Text(
                                user.username.isEmpty
                                    ? '?'
                                    : user.username[0].toUpperCase(),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(user.username),
                                if (user.nickname != null &&
                                    user.nickname!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      '(${user.nickname})',
                                      style: TextStyle(
                                        color: Theme
                                            .of(context)
                                            .hintColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${user.email} · ${user.roleName}'),
                                if (user.pointsBalance != null)
                                  Text(
                                    '${t(context, 'points')}：${user.pointsBalance}',
                                    style: TextStyle(
                                      color: Theme
                                          .of(context)
                                          .colorScheme
                                          .primary,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(user.status == 1
                                    ? t(context, 'active')
                                    : (user.status == 0
                                    ? t(context, 'disabled')
                                    : t(context, 'locked'))),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons
                                      .account_balance_wallet),
                                  onPressed: () => _openWallet(user),
                                  tooltip: t(context, 'wallet'),
                                ),
                              ],
                            ),
                            onTap: () => _editUser(user),
                          );
                        },
                      ),
          ),
          if (pageResult != null)
            PaginationBar(
              currentPage: page,
              totalPages: (pageResult!.total / pageResult!.pageSize)
                  .ceil()
                  .clamp(1, 999999),
              totalItems: pageResult!.total,
              onPageChanged: (newPage) {
                setState(() => page = newPage);
                _loadUsers();
              },
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
  late final TextEditingController avatarCtrl;
  late final TextEditingController nicknameCtrl;
  late final TextEditingController phoneCtrl;
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
    avatarCtrl = TextEditingController(text: widget.user.avatar);
    nicknameCtrl = TextEditingController(text: widget.user.nickname ?? '');
    phoneCtrl = TextEditingController(text: widget.user.phone ?? '');
    status = widget.user.status;
    roleName = widget.user.roleName;
    // 确保 status 值在有效范围内
    if (status != 0 && status != 1 && status != 2) {
      status = 1; // 默认为正常状态
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    avatarCtrl.dispose();
    nicknameCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t(context, 'edit_user')),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(labelText: t(context, 'email')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: avatarCtrl,
              decoration: InputDecoration(labelText: t(context, 'avatar')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nicknameCtrl,
              decoration: InputDecoration(labelText: t(context, 'nickname')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(labelText: t(context, 'phone')),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: status,
              decoration: InputDecoration(labelText: t(context, 'status')),
              items: [
                DropdownMenuItem(value: 1, child: Text(t(context, 'active'))),
                DropdownMenuItem(value: 0, child: Text(t(context, 'disabled'))),
                DropdownMenuItem(value: 2, child: Text(t(context, 'locked'))),
              ],
              onChanged: (v) => setState(() => status = v ?? 1),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: roleName,
              decoration: InputDecoration(labelText: t(context, 'role_name')),
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
          child: Text(t(context, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _UserEditResult(
              emailCtrl.text.trim(),
              avatarCtrl.text.trim(),
              nicknameCtrl.text.trim(),
              phoneCtrl.text.trim(),
              status,
              roleName,
            ),
          ),
          child: Text(t(context, 'save')),
        ),
      ],
    );
  }
}

class _UserEditResult {
  _UserEditResult(this.email, this.avatar, this.nickname, this.phone,
      this.status, this.role);

  final String email;
  final String avatar;
  final String nickname;
  final String phone;
  final int status;
  final String role;
}
