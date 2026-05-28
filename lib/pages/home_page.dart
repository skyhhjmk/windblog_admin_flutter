part of 'package:windblog_admin_flutter/main.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
  });

  final AdminApiClient api;
  final AdminUser? user;
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _AdminNavigationItem {
  const _AdminNavigationItem({
    required this.labelKey,
    required this.fallbackLabel,
    required this.icon,
    required this.selectedIcon,
  });

  final String? labelKey;
  final String fallbackLabel;
  final IconData icon;
  final IconData selectedIcon;
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  List<_AdminNavigationItem> get _navigationItems {
    return const [
      _AdminNavigationItem(
        labelKey: 'overview',
        fallbackLabel: '概览',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
      ),
      _AdminNavigationItem(
        labelKey: 'posts',
        fallbackLabel: '文章',
        icon: Icons.article_outlined,
        selectedIcon: Icons.article,
      ),
      _AdminNavigationItem(
        labelKey: 'categories',
        fallbackLabel: '分类',
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder,
      ),
      _AdminNavigationItem(
        labelKey: 'tags',
        fallbackLabel: '标签',
        icon: Icons.label_outlined,
        selectedIcon: Icons.label,
      ),
      _AdminNavigationItem(
        labelKey: 'store_items',
        fallbackLabel: '商店',
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront,
      ),
      _AdminNavigationItem(
        labelKey: 'media',
        fallbackLabel: '媒体',
        icon: Icons.photo_library_outlined,
        selectedIcon: Icons.photo_library,
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '存储类',
        icon: Icons.cloud_outlined,
        selectedIcon: Icons.cloud,
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '同步监控',
        icon: Icons.sync_outlined,
        selectedIcon: Icons.sync,
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '死信队列',
        icon: Icons.warning_outlined,
        selectedIcon: Icons.warning,
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '图片处理',
        icon: Icons.image_outlined,
        selectedIcon: Icons.image,
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '边缘监控',
        icon: Icons.public_outlined,
        selectedIcon: Icons.public,
      ),
      _AdminNavigationItem(
        labelKey: 'links_management',
        fallbackLabel: '链接管理',
        icon: Icons.link_outlined,
        selectedIcon: Icons.link,
      ),
      _AdminNavigationItem(
        labelKey: 'users',
        fallbackLabel: '用户',
        icon: Icons.people_outlined,
        selectedIcon: Icons.people,
      ),
      _AdminNavigationItem(
        labelKey: 'permissions',
        fallbackLabel: '权限',
        icon: Icons.security_outlined,
        selectedIcon: Icons.security,
      ),
      _AdminNavigationItem(
        labelKey: 'ai_providers',
        fallbackLabel: 'AI 供应商',
        icon: Icons.memory_outlined,
        selectedIcon: Icons.memory,
      ),
      _AdminNavigationItem(
        labelKey: 'database',
        fallbackLabel: '数据库',
        icon: Icons.storage_outlined,
        selectedIcon: Icons.storage,
      ),
      _AdminNavigationItem(
        labelKey: 'comments',
        fallbackLabel: '评论',
        icon: Icons.comment_outlined,
        selectedIcon: Icons.comment,
      ),
      _AdminNavigationItem(
        labelKey: 'queue_monitoring',
        fallbackLabel: '队列监控',
        icon: Icons.queue_outlined,
        selectedIcon: Icons.queue,
      ),
      _AdminNavigationItem(
        labelKey: 'system_monitoring',
        fallbackLabel: '系统监控',
        icon: Icons.monitor_heart_outlined,
        selectedIcon: Icons.monitor_heart,
      ),
      _AdminNavigationItem(
        labelKey: 'system_logs',
        fallbackLabel: '系统日志',
        icon: Icons.history_outlined,
        selectedIcon: Icons.history,
      ),
      _AdminNavigationItem(
        labelKey: 'system_settings',
        fallbackLabel: '系统设置',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '边缘节点',
        icon: Icons.hub_outlined,
        selectedIcon: Icons.hub,
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '区域规则',
        icon: Icons.language_outlined,
        selectedIcon: Icons.language,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    bool isSuperAdmin = widget.user?.roleName == 'SUPER_ADMIN';
    bool isPhone = AdminBreakpoints.isPhone(context);
    bool isDesktop = AdminBreakpoints.isDesktop(context);
    String pageTitle = _titleForIndex(context, tab);
    Widget page = _pageForIndex(tab, isSuperAdmin);

    if (isPhone) {
      return Scaffold(
        appBar: _buildAppBar(context, pageTitle, true),
        drawer: _buildDrawer(context),
        body: _buildAnimatedPage(page),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _buildNavigationRail(context, isDesktop),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, pageTitle),
                Expanded(child: _buildAnimatedPage(page)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, String pageTitle, bool showMenu) {
    return AppBar(
      title: Text(pageTitle),
      actions: [
        if (widget.user != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: Text(widget.user!.username)),
          ),
        IconButton(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout),
          tooltip: t(context, 'logout'),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, String pageTitle) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            pageTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (widget.user != null)
            Text(
              widget.user!.username,
              style: const TextStyle(color: Color(0xFF4B5563)),
            ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, size: 18),
            label: Text(t(context, 'logout')),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context, bool extended) {
    List<NavigationRailDestination> destinations = [];
    List<_AdminNavigationItem> items = _navigationItems;
    for (int index = 0; index < items.length; index++) {
      _AdminNavigationItem item = items[index];
      destinations.add(
        NavigationRailDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.selectedIcon),
          label: Text(_itemLabel(context, item)),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height,
          ),
          child: IntrinsicHeight(
            child: NavigationRail(
              extended: extended,
              minExtendedWidth: 188,
              selectedIndex: tab,
              onDestinationSelected: _selectTab,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _buildBrand(extended),
              ),
              destinations: destinations,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    List<Widget> children = [
      DrawerHeader(
        margin: EdgeInsets.zero,
        child: Align(alignment: Alignment.bottomLeft, child: _buildBrand(true)),
      ),
    ];

    List<_AdminNavigationItem> items = _navigationItems;
    for (int index = 0; index < items.length; index++) {
      _AdminNavigationItem item = items[index];
      bool selected = index == tab;
      children.add(
        ListTile(
          selected: selected,
          leading: Icon(selected ? item.selectedIcon : item.icon),
          title: Text(_itemLabel(context, item)),
          onTap: () {
            Navigator.pop(context);
            _selectTab(index);
          },
        ),
      );
    }

    return Drawer(
      child: SafeArea(child: ListView(children: children)),
    );
  }

  Widget _buildBrand(bool showText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.air, color: Colors.white, size: 20),
          ),
          if (showText) ...[
            const SizedBox(width: 10),
            const Text(
              'WindBlog',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimatedPage(Widget page) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(key: ValueKey<int>(tab), child: page),
    );
  }

  void _selectTab(int index) {
    setState(() {
      tab = index;
    });
  }

  String _itemLabel(BuildContext context, _AdminNavigationItem item) {
    if (item.labelKey == null) {
      return item.fallbackLabel;
    }

    String label = t(context, item.labelKey!);
    if (label == item.labelKey) {
      return item.fallbackLabel;
    }
    return label;
  }

  String _titleForIndex(BuildContext context, int index) {
    List<_AdminNavigationItem> items = _navigationItems;
    if (index < 0 || index >= items.length) {
      return t(context, 'unknown');
    }
    return _itemLabel(context, items[index]);
  }

  Widget _pageForIndex(int index, bool isSuperAdmin) {
    switch (index) {
      case 0:
        return OverviewPage(api: widget.api, onAuthError: widget.onLogout);
      case 1:
        return PostsPage(api: widget.api, onAuthError: widget.onLogout);
      case 2:
        return CategoriesPage(api: widget.api, onAuthError: widget.onLogout);
      case 3:
        return TagsPage(api: widget.api, onAuthError: widget.onLogout);
      case 4:
        return StoreItemsPage(api: widget.api, onAuthError: widget.onLogout);
      case 5:
        return MediaLibraryPage(api: widget.api, onAuthError: widget.onLogout);
      case 6:
        return StorageClassesPage(
          api: widget.api,
          onAuthError: widget.onLogout,
        );
      case 7:
        return StorageSyncPanel(api: widget.api, onAuthError: widget.onLogout);
      case 8:
        return DeadLetterPage(api: widget.api, onAuthError: widget.onLogout);
      case 9:
        return ImageProcessingConfigPage(
          api: widget.api,
          onAuthError: widget.onLogout,
        );
      case 10:
        return EdgeMonitorPage(api: widget.api, onAuthError: widget.onLogout);
      case 11:
        return LinksPage(api: widget.api, onAuthError: widget.onLogout);
      case 12:
        return UserManagementPage(
          api: widget.api,
          onAuthError: widget.onLogout,
          isSuperAdmin: isSuperAdmin,
        );
      case 13:
        return PermissionManagementPage(
          api: widget.api,
          isSuperAdmin: isSuperAdmin,
          onAuthError: widget.onLogout,
        );
      case 14:
        return AiProvidersPage(api: widget.api, onAuthError: widget.onLogout);
      case 15:
        return DatabaseManagementPage(
          api: widget.api,
          onAuthError: widget.onLogout,
        );
      case 16:
        return CommentsPage(api: widget.api, onAuthError: widget.onLogout);
      case 17:
        return QueuesPage(api: widget.api, onAuthError: widget.onLogout);
      case 18:
        return SystemMonitorPage(api: widget.api, onAuthError: widget.onLogout);
      case 19:
        return AuditLogsPage(api: widget.api, onAuthError: widget.onLogout);
      case 20:
        return SystemSettingsPage(
          api: widget.api,
          onAuthError: widget.onLogout,
        );
      case 21:
        return EdgeNodesPage(api: widget.api, onAuthError: widget.onLogout);
      default:
        return RegionManagementPage(
          api: widget.api,
          onAuthError: widget.onLogout,
        );
    }
  }
}
