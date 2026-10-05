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
    if (mounted) setState(() => loading = true);
    try {
      pageResult = await widget.api.listUsers(
        page: page,
        pageSize: 20,
        keyword: keywordCtrl.text.trim(),
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('${t(context, 'load_failed')}$error')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadRoles() async {
    try {
      roles = await widget.api.listRoles();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _openUserManagement(UserListItem user) async {
    final result = await showDialog<_UserManagementDialogResult>(
      context: context,
      builder: (context) => _UserManagementDialog(
        user: user,
        roles: roles,
        api: widget.api,
        onAuthError: widget.onAuthError,
        isSuperAdmin: widget.isSuperAdmin,
      ),
    );
    if (result?.profile == null) return;
    await _updateUser(user, result!.profile!);
  }

  Future<void> _updateUser(UserListItem user, _UserEditResult result) async {
    try {
      await widget.api.updateUser(
        user.id,
        username: result.username,
        email: result.email,
        avatar: result.avatar,
        nickname: result.nickname,
        phone: result.phone,
        status: result.status,
        roleName: result.role,
        password: result.password,
      );
      await _loadUsers();
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text(t(context, 'update_success'))),
        );
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text('${t(context, 'update_failed')}$error')),
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
                child: AdminShortcutSearchField(
                  controller: keywordCtrl,
                  decoration: InputDecoration(
                    hintText: t(context, 'search_username_email'),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    page = 1;
                    _loadUsers();
                  },
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
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          child: Text(
                            user.username.isEmpty
                                ? '?'
                                : user.username[0].toUpperCase(),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(user.username),
                            if (user.nickname?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  '(${user.nickname})',
                                  style: TextStyle(
                                    color: Theme.of(context).hintColor,
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
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.status == 1
                                  ? t(context, 'active')
                                  : (user.status == 0
                                        ? t(context, 'disabled')
                                        : t(context, 'locked')),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _openUserManagement(user),
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

enum _UserManagementModule { profile, wallet, inventory }

class _UserManagementDialog extends StatefulWidget {
  const _UserManagementDialog({
    required this.user,
    required this.roles,
    required this.api,
    required this.onAuthError,
    required this.isSuperAdmin,
  });

  final UserListItem user;
  final List<PermissionRoleItem> roles;
  final AdminApiClient api;
  final VoidCallback onAuthError;
  final bool isSuperAdmin;

  @override
  State<_UserManagementDialog> createState() => _UserManagementDialogState();
}

class _UserManagementDialogState extends State<_UserManagementDialog> {
  late final TextEditingController emailCtrl;
  late final TextEditingController usernameCtrl;
  late final TextEditingController passwordCtrl;
  late final TextEditingController avatarCtrl;
  late final TextEditingController nicknameCtrl;
  late final TextEditingController phoneCtrl;
  late int status;
  late String roleName;
  _UserManagementModule selectedModule = _UserManagementModule.profile;

  List<PermissionRoleItem> get availableRoles {
    final values = [...widget.roles];
    if (!values.any((role) => role.name == roleName)) {
      values.add(
        PermissionRoleItem(
          name: roleName,
          displayName: roleName,
          description: '',
          canUpload: false,
          allowedMimeTypes: const [],
          createdAt: null,
          updatedAt: null,
        ),
      );
    }
    return values;
  }

  @override
  void initState() {
    super.initState();
    emailCtrl = TextEditingController(text: widget.user.email);
    usernameCtrl = TextEditingController(text: widget.user.username);
    passwordCtrl = TextEditingController();
    avatarCtrl = TextEditingController(text: widget.user.avatar);
    nicknameCtrl = TextEditingController(text: widget.user.nickname ?? '');
    phoneCtrl = TextEditingController(text: widget.user.phone ?? '');
    status = widget.user.status;
    roleName = widget.user.roleName;
    if (status != 0 && status != 1 && status != 2) status = 1;
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    avatarCtrl.dispose();
    nicknameCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    Navigator.pop(
      context,
      _UserManagementDialogResult(
        profile: _UserEditResult(
          usernameCtrl.text.trim(),
          emailCtrl.text.trim(),
          avatarCtrl.text.trim(),
          nicknameCtrl.text.trim(),
          phoneCtrl.text.trim(),
          status,
          roleName,
          passwordCtrl.text,
        ),
      ),
    );
  }

  String _moduleTitle(_UserManagementModule module) {
    switch (module) {
      case _UserManagementModule.profile:
        return '基本信息';
      case _UserManagementModule.wallet:
        return '钱包管理';
      case _UserManagementModule.inventory:
        return '仓库管理';
    }
  }

  IconData _moduleIcon(_UserManagementModule module) {
    switch (module) {
      case _UserManagementModule.profile:
        return Icons.person_outline;
      case _UserManagementModule.wallet:
        return Icons.account_balance_wallet_outlined;
      case _UserManagementModule.inventory:
        return Icons.inventory_2_outlined;
    }
  }

  Widget _buildProfile() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('编辑账号资料', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: '用户名'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '强制设置新密码（留空不修改）',
                    helperText: '设置后将立即替换该用户当前密码，长度 6-32 位',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(labelText: t(context, 'email')),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: avatarCtrl,
                  decoration: InputDecoration(labelText: t(context, 'avatar')),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nicknameCtrl,
                  decoration: InputDecoration(
                    labelText: t(context, 'nickname'),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  decoration: InputDecoration(labelText: t(context, 'phone')),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: status,
                  decoration: InputDecoration(labelText: t(context, 'status')),
                  items: [
                    DropdownMenuItem(
                      value: 1,
                      child: Text(t(context, 'active')),
                    ),
                    DropdownMenuItem(
                      value: 0,
                      child: Text(t(context, 'disabled')),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(t(context, 'locked')),
                    ),
                  ],
                  onChanged: (value) => setState(() => status = value ?? 1),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: roleName,
                  decoration: InputDecoration(
                    labelText: t(context, 'role_name'),
                  ),
                  items: availableRoles
                      .map(
                        (role) => DropdownMenuItem(
                          value: role.name,
                          child: Text(role.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: widget.isSuperAdmin
                      ? (value) => setState(() => roleName = value ?? roleName)
                      : null,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.save_outlined),
            label: Text(t(context, 'save')),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleContent() {
    switch (selectedModule) {
      case _UserManagementModule.profile:
        return _buildProfile();
      case _UserManagementModule.wallet:
        return UserWalletPanel(
          key: const ValueKey('wallet'),
          api: widget.api,
          userId: widget.user.id,
          onAuthError: widget.onAuthError,
          isSuperAdmin: widget.isSuperAdmin,
        );
      case _UserManagementModule.inventory:
        return _UserInventoryPanel(
          key: const ValueKey('inventory'),
          api: widget.api,
          userId: widget.user.id,
          username: widget.user.username,
          onAuthError: widget.onAuthError,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: min(1100.0, size.width * .92),
        height: min(720.0, size.height * .86),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer,
                    child: Text(
                      widget.user.username.isEmpty
                          ? '?'
                          : widget.user.username[0].toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '用户管理 · ${widget.user.username}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        widget.user.email,
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: t(context, 'cancel'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 218,
                    child: ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                            child: Text(
                              '管理模块',
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ..._UserManagementModule.values.map(
                            (module) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                selected: selectedModule == module,
                                selectedTileColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                leading: Icon(_moduleIcon(module)),
                                title: Text(_moduleTitle(module)),
                                onTap: () =>
                                    setState(() => selectedModule = module),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: KeyedSubtree(
                          key: ValueKey(selectedModule),
                          child: _buildModuleContent(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserInventoryPanel extends StatefulWidget {
  const _UserInventoryPanel({
    super.key,
    required this.api,
    required this.userId,
    required this.username,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final int userId;
  final String username;
  final VoidCallback onAuthError;

  @override
  State<_UserInventoryPanel> createState() => _UserInventoryPanelState();
}

class _UserInventoryPanelState extends State<_UserInventoryPanel> {
  InventorySnapshot? snapshot;
  List<StoreItem> storeItems = [];
  bool loading = true;
  bool granting = false;

  List<StoreItem> get activeItems =>
      storeItems.where((item) => item.status == 1 && !item.deprecated).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final inventory = await widget.api.getUserInventory(widget.userId);
      final items = await widget.api.getStoreItems(page: 1, pageSize: 200);
      if (!mounted) return;
      setState(() {
        snapshot = inventory;
        storeItems = items.items;
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      _showMessage('加载仓库失败：$error', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _grantItem() async {
    if (activeItems.isEmpty) {
      _showMessage('暂无可发放的上架物品', error: true);
      return;
    }
    final request = await showDialog<_GrantInventoryRequest>(
      context: context,
      builder: (context) => _GrantInventoryDialog(items: activeItems),
    );
    if (request == null || !mounted) return;

    final stepUpToken = await AdminStepUpAuthorization.obtain(
      context,
      widget.api,
      title: '确认向 ${widget.username} 发放仓库物品',
    );
    if (stepUpToken == null || !mounted) return;

    setState(() => granting = true);
    try {
      final updated = await widget.api.grantUserInventoryItem(
        widget.userId,
        storeItemId: request.storeItemId,
        quantity: request.quantity,
        reason: request.reason,
        stepUpToken: stepUpToken,
      );
      if (mounted) {
        setState(() => snapshot = updated);
        _showMessage('物品已发放');
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      _showMessage('发放失败：$error', error: true);
    } finally {
      if (mounted) setState(() => granting = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    AdminFeedback.showSnackBar(
      context,
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    return Column(
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('仓库内容', style: Theme.of(context).textTheme.titleMedium),
                if (current != null)
                  Text(
                    '版本 ${current.revision} · ${current.items.length} 个物品实例 · ${current.containers.length} 个容器',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: loading || granting ? null : _grantItem,
              icon: const Icon(Icons.card_giftcard_outlined),
              label: const Text('手动发放物品'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: loading || granting ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: t(context, 'refresh'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : current == null || current.items.isEmpty
              ? Center(
                  child: Text(
                    current == null ? '仓库加载失败' : '仓库暂无物品',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                )
              : _InventoryContainerList(snapshot: current),
        ),
      ],
    );
  }
}

class _InventoryContainerList extends StatelessWidget {
  const _InventoryContainerList({required this.snapshot});

  final InventorySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final containers = snapshot.containers.isEmpty
        ? [
            InventoryContainerSnapshot(
              id: null,
              userId: null,
              parentItemUuid: null,
              rows: 10,
              columns: 10,
              revision: snapshot.revision,
            ),
          ]
        : snapshot.containers;
    final itemByUuid = {
      for (final item in snapshot.items) item.instanceUuid: item,
    };

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: containers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final container = containers[index];
        final isRoot = container.parentItemUuid == null;
        final parentItem = itemByUuid[container.parentItemUuid];
        final items = snapshot.items.where((item) {
          if (container.id == null) return item.containerId == null;
          return item.containerId == container.id;
        }).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    isRoot ? Icons.inventory_2_outlined : Icons.inbox_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRoot
                        ? '主仓库'
                        : '${parentItem?.displayName ?? '容器'} · 内部空间',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Text(
                    '${items.length} 件 · ${container.columns}×${container.rows} 格',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
            _InventoryGridBoard(container: container, items: items),
          ],
        );
      },
    );
  }
}

class _InventoryGridBoard extends StatelessWidget {
  const _InventoryGridBoard({required this.container, required this.items});

  static const double cellSize = 52;

  final InventoryContainerSnapshot container;
  final List<InventoryItemSnapshot> items;

  Color _rarityColor(InventoryItemSnapshot item, Color fallback) {
    final raw = item.metadata['rarity']?.toString() ?? '';
    final value = raw.startsWith('#') ? raw.substring(1) : raw;
    if (value.length == 6) {
      final parsed = int.tryParse(value, radix: 16);
      if (parsed != null) return Color(0xff000000 | parsed);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final columns = container.columns.clamp(1, 40);
    final rows = container.rows.clamp(1, 40);
    final scheme = Theme.of(context).colorScheme;
    final boardSize = Size(columns * cellSize, rows * cellSize);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: boardSize.width,
        height: boardSize.height,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withAlpha(75),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _InventoryGridPainter(
                  rows: rows,
                  columns: columns,
                  lineColor: scheme.outlineVariant.withAlpha(150),
                ),
              ),
            ),
            for (final item in items)
              _buildItem(context, item, columns: columns, rows: rows),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    InventoryItemSnapshot item, {
    required int columns,
    required int rows,
  }) {
    final widthInCells = (item.rotation ? item.height : item.width).clamp(
      1,
      columns,
    );
    final heightInCells = (item.rotation ? item.width : item.height).clamp(
      1,
      rows,
    );
    final x = item.x.clamp(0, columns - widthInCells);
    final y = item.y.clamp(0, rows - heightInCells);
    final color = _rarityColor(item, Theme.of(context).colorScheme.primary);
    final width = widthInCells * cellSize;
    final height = heightInCells * cellSize;

    return Positioned(
      left: x * cellSize,
      top: y * cellSize,
      width: width,
      height: height,
      child: Tooltip(
        message:
            '${item.displayName}\n${item.width}×${item.height} 格 · ×${item.quantity}${item.deprecated ? '\n已弃用' : ''}',
        child: Material(
          color: color.withAlpha(52),
          child: InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(item.displayName),
                content: Text(
                  '${item.itemCode}\n占用 ${item.width}×${item.height} 格 · 数量 ${item.quantity}\n位置 (${item.x}, ${item.y})${item.deprecated ? '\n此物品定义已弃用' : ''}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: color.withAlpha(230), width: 2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withAlpha(55), color.withAlpha(24)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          item.displayName,
                          maxLines: heightInCells > 1 ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 1,
                      top: 1,
                      child: Text(
                        '${item.width}×${item.height}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withAlpha(225),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Text(
                            '×${item.quantity}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryGridPainter extends CustomPainter {
  const _InventoryGridPainter({
    required this.rows,
    required this.columns,
    required this.lineColor,
  });

  final int rows;
  final int columns;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (var column = 1; column < columns; column++) {
      final x = column * _InventoryGridBoard.cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var row = 1; row < rows; row++) {
      final y = row * _InventoryGridBoard.cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InventoryGridPainter oldDelegate) =>
      rows != oldDelegate.rows ||
      columns != oldDelegate.columns ||
      lineColor != oldDelegate.lineColor;
}

class _GrantInventoryDialog extends StatefulWidget {
  const _GrantInventoryDialog({required this.items});

  final List<StoreItem> items;

  @override
  State<_GrantInventoryDialog> createState() => _GrantInventoryDialogState();
}

class _GrantInventoryDialogState extends State<_GrantInventoryDialog> {
  late int selectedItemId;
  late final TextEditingController quantityCtrl;
  late final TextEditingController reasonCtrl;

  @override
  void initState() {
    super.initState();
    selectedItemId = widget.items.first.id;
    quantityCtrl = TextEditingController(text: '1');
    reasonCtrl = TextEditingController(text: '后台手动发放');
  }

  @override
  void dispose() {
    quantityCtrl.dispose();
    reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手动发放仓库物品'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: selectedItemId,
              decoration: const InputDecoration(labelText: '物品'),
              items: widget.items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text('${item.name} · ${item.itemCode ?? '未设置编码'}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => selectedItemId = value);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: quantityCtrl,
              decoration: const InputDecoration(labelText: '数量'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: '发放原因'),
              maxLines: 2,
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
          onPressed: () {
            final quantity = int.tryParse(quantityCtrl.text.trim());
            if (quantity == null || quantity < 1) {
              AdminFeedback.showSnackBar(
                context,
                const SnackBar(content: Text('数量必须是大于 0 的整数')),
              );
              return;
            }
            Navigator.pop(
              context,
              _GrantInventoryRequest(
                selectedItemId,
                quantity,
                reasonCtrl.text.trim().isEmpty
                    ? 'ADMIN'
                    : reasonCtrl.text.trim(),
              ),
            );
          },
          child: Text(t(context, 'confirm')),
        ),
      ],
    );
  }
}

class _GrantInventoryRequest {
  _GrantInventoryRequest(this.storeItemId, this.quantity, this.reason);

  final int storeItemId;
  final int quantity;
  final String reason;
}

class _UserManagementDialogResult {
  const _UserManagementDialogResult({this.profile});

  final _UserEditResult? profile;
}

class _UserEditResult {
  _UserEditResult(
    this.username,
    this.email,
    this.avatar,
    this.nickname,
    this.phone,
    this.status,
    this.role,
    this.password,
  );

  final String username;
  final String email;
  final String avatar;
  final String nickname;
  final String phone;
  final int status;
  final String role;
  final String password;
}
