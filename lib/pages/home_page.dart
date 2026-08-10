part of 'package:windblog_admin_flutter/main.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final AdminUser? user;
  final VoidCallback onLogout;
  final VoidCallback onAuthError;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _AdminNavigationItem {
  const _AdminNavigationItem({
    required this.labelKey,
    required this.fallbackLabel,
    required this.icon,
    required this.selectedIcon,
    this.submenuParent,
  });

  final String? labelKey;
  final String fallbackLabel;
  final IconData icon;
  final IconData selectedIcon;
  final String? submenuParent;
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  int slideDirection = 1;
  final Map<String, bool> submenuExpandedStates = {
    '内容管理': false,
    '运营管理': false,
    '媒体与存储': false,
    '边缘集群': false,
    '系统运维': false,
    '系统设置': false,
  };

  List<_AdminNavigationItem> get _navigationItems {
    return const [
      _AdminNavigationItem(
        labelKey: 'overview',
        fallbackLabel: '概览',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
      ),
      // 内容管理
      _AdminNavigationItem(
        labelKey: 'posts',
        fallbackLabel: '文章',
        icon: Icons.article_outlined,
        selectedIcon: Icons.article,
        submenuParent: '内容管理',
      ),
      _AdminNavigationItem(
        labelKey: 'categories',
        fallbackLabel: '分类',
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder,
        submenuParent: '内容管理',
      ),
      _AdminNavigationItem(
        labelKey: 'tags',
        fallbackLabel: '标签',
        icon: Icons.label_outlined,
        selectedIcon: Icons.label,
        submenuParent: '内容管理',
      ),
      _AdminNavigationItem(
        labelKey: 'comments',
        fallbackLabel: '评论',
        icon: Icons.comment_outlined,
        selectedIcon: Icons.comment,
        submenuParent: '内容管理',
      ),
      // 运营管理
      _AdminNavigationItem(
        labelKey: 'links_management',
        fallbackLabel: '链接管理',
        icon: Icons.link_outlined,
        selectedIcon: Icons.link,
        submenuParent: '运营管理',
      ),
      _AdminNavigationItem(
        labelKey: 'users',
        fallbackLabel: '用户',
        icon: Icons.people_outlined,
        selectedIcon: Icons.people,
        submenuParent: '运营管理',
      ),
      _AdminNavigationItem(
        labelKey: 'store_items',
        fallbackLabel: '商店',
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront,
        submenuParent: '运营管理',
      ),
      // 媒体与存储
      _AdminNavigationItem(
        labelKey: 'media',
        fallbackLabel: '媒体',
        icon: Icons.photo_library_outlined,
        selectedIcon: Icons.photo_library,
        submenuParent: '媒体与存储',
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '存储类',
        icon: Icons.cloud_outlined,
        selectedIcon: Icons.cloud,
        submenuParent: '媒体与存储',
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '图片处理',
        icon: Icons.image_outlined,
        selectedIcon: Icons.image,
        submenuParent: '媒体与存储',
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '同步监控',
        icon: Icons.sync_outlined,
        selectedIcon: Icons.sync,
        submenuParent: '媒体与存储',
      ),
      // 边缘集群
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '边缘节点',
        icon: Icons.hub_outlined,
        selectedIcon: Icons.hub,
        submenuParent: '边缘集群',
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '区域规则',
        icon: Icons.language_outlined,
        selectedIcon: Icons.language,
        submenuParent: '边缘集群',
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '边缘监控',
        icon: Icons.public_outlined,
        selectedIcon: Icons.public,
        submenuParent: '边缘集群',
      ),
      // 系统运维
      _AdminNavigationItem(
        labelKey: 'queue_monitoring',
        fallbackLabel: '队列监控',
        icon: Icons.queue_outlined,
        selectedIcon: Icons.queue,
        submenuParent: '系统运维',
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '死信队列',
        icon: Icons.warning_outlined,
        selectedIcon: Icons.warning,
        submenuParent: '系统运维',
      ),
      _AdminNavigationItem(
        labelKey: 'system_monitoring',
        fallbackLabel: '系统监控',
        icon: Icons.monitor_heart_outlined,
        selectedIcon: Icons.monitor_heart,
        submenuParent: '系统运维',
      ),
      _AdminNavigationItem(
        labelKey: 'database',
        fallbackLabel: '数据库',
        icon: Icons.storage_outlined,
        selectedIcon: Icons.storage,
        submenuParent: '系统运维',
      ),
      _AdminNavigationItem(
        labelKey: 'system_logs',
        fallbackLabel: '系统日志',
        icon: Icons.history_outlined,
        selectedIcon: Icons.history,
        submenuParent: '系统运维',
      ),
      // 系统设置
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '功能设置',
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune,
        submenuParent: '系统设置',
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: 'Elasticsearch',
        icon: Icons.manage_search_outlined,
        selectedIcon: Icons.manage_search,
        submenuParent: '系统设置',
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '同义词规则',
        icon: Icons.account_tree_outlined,
        selectedIcon: Icons.account_tree,
        submenuParent: '系统设置',
      ),
      _AdminNavigationItem(
        labelKey: 'ai_providers',
        fallbackLabel: 'AI 供应商',
        icon: Icons.memory_outlined,
        selectedIcon: Icons.memory,
        submenuParent: '系统设置',
      ),
      _AdminNavigationItem(
        labelKey: 'permissions',
        fallbackLabel: '权限',
        icon: Icons.security_outlined,
        selectedIcon: Icons.security,
        submenuParent: '系统设置',
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '邮件中心',
        icon: Icons.mail_outline,
        selectedIcon: Icons.mail,
        submenuParent: '系统设置',
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: 'Outbox 审计',
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
        submenuParent: '系统运维',
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: '安全服务',
        icon: Icons.policy_outlined,
        selectedIcon: Icons.policy,
        submenuParent: '系统运维',
      ),
      _AdminNavigationItem(
        labelKey: null,
        fallbackLabel: 'AMP / SEO',
        icon: Icons.speed_outlined,
        selectedIcon: Icons.speed,
        submenuParent: '系统设置',
      ),
    ];
  }

  static const Map<int, Color> tabColors = {
    0: Color(0xFFF43F5E), // Overview: Rose
    1: Color(0xFFF97316), // Posts: Orange
    2: Color(0xFFF59E0B), // Categories: Amber
    3: Color(0xFF84CC16), // Tags: Lime
    4: Color(0xFFEC4899), // Comments: Pink
    5: Color(0xFFEF4444), // Links: Red
    6: Color(0xFF059669), // Users: Green
    7: Color(0xFF10B981), // Store: Emerald
    8: Color(0xFF06B6D4), // Media: Cyan
    9: Color(0xFF3B82F6), // Storage Classes: Blue
    10: Color(0xFF8B5CF6), // Image Processing: Violet
    11: Color(0xFF6366F1), // Sync Panel: Indigo
    12: Color(0xFF10B981), // Edge Nodes: Emerald
    13: Color(0xFFF59E0B), // Region Rules: Amber
    14: Color(0xFFD946EF), // Edge Monitor: Fuchsia
    15: Color(0xFF06B6D4), // Queues: Cyan
    16: Color(0xFFEF4444), // Dead Letter: Red
    17: Color(0xFFEF4444), // System Monitor: Red
    18: Color(0xFF2563EB), // Database: Blue
    19: Color(0xFFF97316), // System Logs: Orange
    20: Color(0xFF8B5CF6), // Feature Settings: Violet
    21: Color(0xFF0EA5E9), // Elasticsearch: Sky
    22: Color(0xFF14B8A6), // Synonym Rules: Teal
    23: Color(0xFF6366F1), // AI Providers: Indigo
    24: Color(0xFF14B8A6), // Permissions: Teal
    25: Color(0xFF0F766E), // Email Center: Teal
    26: Color(0xFF7C3AED), // Outbox Audit: Violet
    27: Color(0xFFDC2626), // Security Services: Red
    28: Color(0xFF0EA5E9), // AMP / SEO: Sky
  };

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
          const VerticalDivider(width: 1, color: Color(0xFF1E293B)),
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
    final themeColor = tabColors[tab] ?? const Color(0xFF2563EB);
    return AppBar(
      title: Text(
        pageTitle,
        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(color: themeColor, height: 2),
      ),
      actions: [
        if (widget.user != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(widget.user!.username),
              backgroundColor: themeColor.withValues(alpha: 0.1),
              side: BorderSide.none,
              labelStyle: TextStyle(
                color: themeColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
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
    final themeColor = tabColors[tab] ?? const Color(0xFF2563EB);
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: themeColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              pageTitle,
              style: TextStyle(
                color: themeColor,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Spacer(),
          if (widget.user != null) ...[
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: themeColor, width: 2),
              ),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: themeColor.withValues(alpha: 0.2),
                child: Text(
                  widget.user!.username
                      .substring(0, min(2, widget.user!.username.length))
                      .toUpperCase(),
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.user!.username,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, size: 16),
            label: Text(t(context, 'logout')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context, bool extended) {
    List<Widget> navigationChildren = [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: _buildBrand(extended),
      ),
    ];
    List<_AdminNavigationItem> items = _navigationItems;
    Set<String> renderedSubmenus = <String>{};
    for (int index = 0; index < items.length; index++) {
      _AdminNavigationItem item = items[index];
      if (item.submenuParent == null) {
        navigationChildren.add(
          _buildDesktopNavigationTile(context, index, item, extended, false),
        );
        continue;
      }
      String submenuName = item.submenuParent!;
      if (!renderedSubmenus.add(submenuName)) {
        continue;
      }
      navigationChildren.add(_buildDesktopSubmenu(context, index, extended));
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: extended ? 210 : 72,
      color: const Color(0xFF0F172A),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: navigationChildren,
        ),
      ),
    );
  }

  Widget _buildDesktopSubmenu(
    BuildContext context,
    int firstChildIndex,
    bool extended,
  ) {
    List<_AdminNavigationItem> items = _navigationItems;
    List<Widget> children = [];
    List<int> childIndices = <int>[];
    String submenuName = items[firstChildIndex].submenuParent ?? '设置';
    for (int index = 0; index < items.length; index++) {
      _AdminNavigationItem item = items[index];
      if (item.submenuParent == submenuName) {
        childIndices.add(index);
        children.add(
          _buildDesktopNavigationTile(context, index, item, extended, true),
        );
      }
    }

    bool childSelected = false;
    for (int index in childIndices) {
      if (tab == index) {
        childSelected = true;
      }
    }
    Color parentColor = childSelected
        ? tabColors[tab] ?? const Color(0xFF8B5CF6)
        : const Color(0xFF94A3B8);

    bool expanded = submenuExpandedStates[submenuName] == true;

    IconData submenuIcon = Icons.settings_outlined;
    if (submenuName == '内容管理') {
      submenuIcon = Icons.edit_note_outlined;
    } else if (submenuName == '运营管理') {
      submenuIcon = Icons.business_center_outlined;
    } else if (submenuName == '媒体与存储') {
      submenuIcon = Icons.cloud_queue_outlined;
    } else if (submenuName == '边缘集群') {
      submenuIcon = Icons.hub_outlined;
    } else if (submenuName == '系统运维') {
      submenuIcon = Icons.analytics_outlined;
    }

    double rotationTurns = 0;
    if (expanded) {
      rotationTurns = 0.5;
    }

    CrossFadeState fadeState = CrossFadeState.showFirst;
    if (expanded) {
      fadeState = CrossFadeState.showSecond;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: submenuName,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                final currentVal = submenuExpandedStates[submenuName] == true;
                submenuExpandedStates[submenuName] = !currentVal;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(submenuIcon, color: parentColor, size: 22),
                  if (extended) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        submenuName,
                        style: TextStyle(
                          color: parentColor,
                          fontWeight: childSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: rotationTurns,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: parentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(children: children),
          crossFadeState: fadeState,
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }

  Widget _buildDesktopNavigationTile(
    BuildContext context,
    int index,
    _AdminNavigationItem item,
    bool extended,
    bool isSubmenu,
  ) {
    bool selected = index == tab;
    Color itemColor = tabColors[index] ?? const Color(0xFF2563EB);
    Color contentColor = selected ? itemColor : const Color(0xFF94A3B8);
    return Padding(
      padding: EdgeInsets.only(left: extended && isSubmenu ? 14 : 0, bottom: 2),
      child: Tooltip(
        message: _itemLabel(context, item),
        child: Material(
          color: selected
              ? itemColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _selectTab(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: contentColor,
                    size: 22,
                  ),
                  if (extended) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _itemLabel(context, item),
                        style: TextStyle(
                          color: contentColor,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    List<Widget> children = [
      DrawerHeader(
        decoration: const BoxDecoration(color: Color(0xFF0F172A)),
        margin: EdgeInsets.zero,
        child: Align(alignment: Alignment.bottomLeft, child: _buildBrand(true)),
      ),
    ];

    List<_AdminNavigationItem> items = _navigationItems;
    Set<String> renderedSubmenus = <String>{};
    for (int index = 0; index < items.length; index++) {
      _AdminNavigationItem item = items[index];
      if (item.submenuParent != null) {
        String submenuName = item.submenuParent!;
        if (!renderedSubmenus.add(submenuName)) {
          continue;
        }
        children.add(_buildDrawerSubmenu(context, index));
        continue;
      }
      bool selected = index == tab;
      final itemColor = tabColors[index] ?? const Color(0xFF2563EB);
      children.add(
        ListTile(
          selected: selected,
          selectedColor: itemColor,
          selectedTileColor: itemColor.withValues(alpha: 0.08),
          leading: Icon(
            selected ? item.selectedIcon : item.icon,
            color: selected ? itemColor : const Color(0xFF64748B),
          ),
          title: Text(
            _itemLabel(context, item),
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
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

  Widget _buildDrawerSubmenu(BuildContext context, int firstChildIndex) {
    List<_AdminNavigationItem> items = _navigationItems;
    List<Widget> children = [];
    bool childSelected = false;
    String submenuName = items[firstChildIndex].submenuParent ?? '设置';
    for (int index = 0; index < items.length; index++) {
      _AdminNavigationItem item = items[index];
      if (item.submenuParent != submenuName) {
        continue;
      }
      bool selected = index == tab;
      if (selected) {
        childSelected = true;
      }
      Color itemColor = tabColors[index] ?? const Color(0xFF2563EB);
      children.add(
        ListTile(
          selected: selected,
          selectedColor: itemColor,
          selectedTileColor: itemColor.withValues(alpha: 0.08),
          leading: Icon(selected ? item.selectedIcon : item.icon),
          title: Text(
            _itemLabel(context, item),
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            _selectTab(index);
          },
        ),
      );
    }

    bool initiallyExpanded = submenuExpandedStates[submenuName] == true;

    IconData submenuIcon = Icons.settings_outlined;
    if (submenuName == '内容管理') {
      submenuIcon = Icons.edit_note_outlined;
    } else if (submenuName == '运营管理') {
      submenuIcon = Icons.business_center_outlined;
    } else if (submenuName == '媒体与存储') {
      submenuIcon = Icons.cloud_queue_outlined;
    } else if (submenuName == '边缘集群') {
      submenuIcon = Icons.hub_outlined;
    } else if (submenuName == '系统运维') {
      submenuIcon = Icons.analytics_outlined;
    }

    return ExpansionTile(
      initiallyExpanded: initiallyExpanded || childSelected,
      leading: Icon(submenuIcon),
      title: Text(submenuName),
      onExpansionChanged: (expanded) {
        submenuExpandedStates[submenuName] = expanded;
      },
      childrenPadding: const EdgeInsets.only(left: 16),
      children: children,
    );
  }

  Widget _buildBrand(bool showText) {
    final themeColor = tabColors[tab] ?? const Color(0xFF2563EB);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [themeColor, themeColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.air, color: Colors.white, size: 20),
          ),
          if (showText) ...[
            const SizedBox(width: 10),
            const Text(
              'WindBlog',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimatedPage(Widget page) {
    final themeColor = tabColors[tab] ?? const Color(0xFF2563EB);

    final pageTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: themeColor,
        primary: themeColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardTheme: CardThemeData(
        elevation: 3,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shadowColor: themeColor.withValues(alpha: 0.08),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: themeColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: themeColor.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: themeColor.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: themeColor, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: themeColor,
          side: BorderSide(color: themeColor, width: 1.5),
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: themeColor,
        ),
        headingRowColor: WidgetStateProperty.all(
          themeColor.withValues(alpha: 0.05),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: themeColor.withValues(alpha: 0.15),
        thickness: 1,
      ),
    );

    return Theme(
      data: pageTheme,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final bool isCurrent = child.key == ValueKey<int>(tab);
          Offset beginOffset = Offset.zero;

          if (slideDirection == 1) {
            if (isCurrent) {
              beginOffset = const Offset(0, 0.04);
            } else {
              beginOffset = const Offset(0, -0.04);
            }
          } else {
            if (isCurrent) {
              beginOffset = const Offset(0, -0.04);
            } else {
              beginOffset = const Offset(0, 0.04);
            }
          }

          final fade = FadeTransition(opacity: animation, child: child);
          final slide = SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(animation),
            child: fade,
          );
          return slide;
        },
        child: KeyedSubtree(key: ValueKey<int>(tab), child: page),
      ),
    );
  }

  void _selectTab(int index) {
    if (index == tab) {
      return;
    }

    AdminNotificationScope.maybeOf(context)?.recordNavigation();

    int direction = 1;
    if (index < tab) {
      direction = -1;
    }

    List<_AdminNavigationItem> items = _navigationItems;
    String? activeSubmenu;
    if (index >= 0 && index < items.length) {
      activeSubmenu = items[index].submenuParent;
    }
    setState(() {
      slideDirection = direction;
      tab = index;
      List<String> keys = submenuExpandedStates.keys.toList();
      for (int i = 0; i < keys.length; i++) {
        String key = keys[i];
        if (key == activeSubmenu) {
          submenuExpandedStates[key] = true;
        } else {
          submenuExpandedStates[key] = false;
        }
      }
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
        return OverviewPage(api: widget.api, onAuthError: widget.onAuthError);
      case 1:
        return PostsPage(api: widget.api, onAuthError: widget.onAuthError);
      case 2:
        return CategoriesPage(api: widget.api, onAuthError: widget.onAuthError);
      case 3:
        return TagsPage(api: widget.api, onAuthError: widget.onAuthError);
      case 4:
        return CommentsPage(api: widget.api, onAuthError: widget.onAuthError);
      case 5:
        return LinksPage(api: widget.api, onAuthError: widget.onAuthError);
      case 6:
        return UserManagementPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
          isSuperAdmin: isSuperAdmin,
        );
      case 7:
        return StoreItemsPage(api: widget.api, onAuthError: widget.onAuthError);
      case 8:
        return MediaLibraryPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      case 9:
        return StorageClassesPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      case 10:
        return ImageProcessingConfigPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      case 11:
        return StorageSyncPanel(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      case 12:
        return EdgeNodesPage(api: widget.api, onAuthError: widget.onAuthError);
      case 13:
        return RegionManagementPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      case 14:
        return EdgeMonitorPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      case 15:
        return QueuesPage(api: widget.api, onAuthError: widget.onAuthError);
      case 16:
        return DeadLetterPage(api: widget.api, onAuthError: widget.onAuthError);
      case 17:
        return SystemMonitorPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      case 18:
        return DatabaseManagementPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      case 19:
        return AuditLogsPage(api: widget.api, onAuthError: widget.onAuthError);
      case 20:
        return SystemSettingsPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      case 21:
        return ElasticsearchSettingsPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
          onOpenSynonymRules: () => _selectTab(22),
        );
      case 22:
        return ElasticsearchSynonymsPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
          onOpenElasticSettings: () => _selectTab(21),
        );
      case 23:
        return AiProvidersPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      case 24:
        return PermissionManagementPage(
          api: widget.api,
          isSuperAdmin: isSuperAdmin,
          onAuthError: widget.onAuthError,
        );
      case 25:
        return EmailCenterPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      case 26:
        return OutboxPage(api: widget.api, onAuthError: widget.onAuthError);
      case 27:
        return SecurityServicesPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      case 28:
        return AmpSettingsPage(
          api: widget.api,
          onAuthError: widget.onAuthError,
        );
      default:
        return OverviewPage(api: widget.api, onAuthError: widget.onAuthError);
    }
  }
}
