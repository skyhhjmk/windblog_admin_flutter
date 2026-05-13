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

class _HomePageState extends State<HomePage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = widget.user?.roleName == 'SUPER_ADMIN';
    return Scaffold(
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      extended: true,
                      selectedIndex: tab,
                      onDestinationSelected: (v) => setState(() => tab = v),
                      destinations: [
                        NavigationRailDestination(
                          icon: const Icon(Icons.dashboard_outlined),
                          selectedIcon: const Icon(Icons.dashboard),
                          label: Text(t(context, 'overview')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.article_outlined),
                          selectedIcon: const Icon(Icons.article),
                          label: Text(t(context, 'posts')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.folder_outlined),
                          selectedIcon: const Icon(Icons.folder),
                          label: Text(t(context, 'categories')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.label_outlined),
                          selectedIcon: const Icon(Icons.label),
                          label: Text(t(context, 'tags')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.storefront_outlined),
                          selectedIcon: const Icon(Icons.storefront),
                          label: Text(t(context, 'store_items')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.photo_library_outlined),
                          selectedIcon: const Icon(Icons.photo_library),
                          label: Text(t(context, 'media')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.cloud_outlined),
                          selectedIcon: const Icon(Icons.cloud),
                          label: const Text('存储节点'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.sync_outlined),
                          selectedIcon: const Icon(Icons.sync),
                          label: const Text('同步监控'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.warning_outlined),
                          selectedIcon: const Icon(Icons.warning),
                          label: const Text('死信队列'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.image_outlined),
                          selectedIcon: const Icon(Icons.image),
                          label: const Text('图片处理'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.public_outlined),
                          selectedIcon: const Icon(Icons.public),
                          label: const Text('边缘监控'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.link_outlined),
                          selectedIcon: const Icon(Icons.link),
                          label: Text(t(context, 'links_management')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.people_outlined),
                          selectedIcon: const Icon(Icons.people),
                          label: Text(t(context, 'users')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.security_outlined),
                          selectedIcon: const Icon(Icons.security),
                          label: Text(t(context, 'permissions')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.memory_outlined),
                          selectedIcon: const Icon(Icons.memory),
                          label: Text(t(context, 'ai_providers')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.storage_outlined),
                          selectedIcon: const Icon(Icons.storage),
                          label: Text(t(context, 'database')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.comment_outlined),
                          selectedIcon: const Icon(Icons.comment),
                          label: Text(t(context, 'comments')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.queue_outlined),
                          selectedIcon: const Icon(Icons.queue),
                          label: Text(t(context, 'queue_monitoring')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.monitor_heart_outlined),
                          selectedIcon: const Icon(Icons.monitor_heart),
                          label: Text(t(context, 'system_monitoring')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.history_outlined),
                          selectedIcon: const Icon(Icons.history),
                          label: Text(t(context, 'system_logs')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.settings_outlined),
                          selectedIcon: const Icon(Icons.settings),
                          label: Text(t(context, 'system_settings')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.hub_outlined),
                          selectedIcon: const Icon(Icons.hub),
                          label: const Text('边缘节点'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.language_outlined),
                          selectedIcon: const Icon(Icons.language),
                          label: const Text('区域规则'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        switch (tab) {
                          0 => t(context, 'overview'),
                          1 => t(context, 'posts'),
                          2 => t(context, 'categories'),
                          3 => t(context, 'tags'),
                          4 => t(context, 'store_items'),
                          5 => t(context, 'media'),
                          6 => '存储节点',
                          7 => '同步监控',
                          8 => '死信队列',
                          9 => '图片处理',
                          10 => '边缘监控',
                          11 => t(context, 'links_management'),
                          12 => t(context, 'users'),
                          13 => t(context, 'permissions'),
                          14 => t(context, 'ai_providers'),
                          15 => t(context, 'database'),
                          16 => t(context, 'comments'),
                          17 => t(context, 'queue_monitoring'),
                          18 => t(context, 'system_monitoring'),
                          19 => t(context, 'system_logs'),
                          20 => t(context, 'system_settings'),
                          21 => '边缘节点',
                          22 => '区域规则',
                          _ => t(context, 'unknown'),
                        },
                      ),
                      const Spacer(),
                      if (widget.user != null) Text(widget.user!.username),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: widget.onLogout,
                        child: Text(t(context, 'logout')),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _pageForIndex(tab, isSuperAdmin),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageForIndex(int index, bool isSuperAdmin) {
    return switch (index) {
      0 => OverviewPage(api: widget.api, onAuthError: widget.onLogout),
      1 => PostsPage(api: widget.api, onAuthError: widget.onLogout),
      2 => CategoriesPage(api: widget.api, onAuthError: widget.onLogout),
      3 => TagsPage(api: widget.api, onAuthError: widget.onLogout),
      4 => StoreItemsPage(api: widget.api, onAuthError: widget.onLogout),
      5 => MediaLibraryPage(api: widget.api, onAuthError: widget.onLogout),
      6 => StorageProvidersPage(api: widget.api, onAuthError: widget.onLogout),
      7 => StorageSyncPanel(api: widget.api, onAuthError: widget.onLogout),
      8 => DeadLetterPage(api: widget.api, onAuthError: widget.onLogout),
      9 =>
          ImageProcessingConfigPage(
              api: widget.api, onAuthError: widget.onLogout),
      10 => EdgeMonitorPage(api: widget.api, onAuthError: widget.onLogout),
      11 => LinksPage(api: widget.api, onAuthError: widget.onLogout),
      12 =>
          UserManagementPage(
          api: widget.api,
          onAuthError: widget.onLogout,
          isSuperAdmin: isSuperAdmin,
        ),
      13 =>
          PermissionManagementPage(
          api: widget.api,
          isSuperAdmin: isSuperAdmin,
          onAuthError: widget.onLogout,
        ),
      14 => AiProvidersPage(api: widget.api, onAuthError: widget.onLogout),
      15 =>
          DatabaseManagementPage(api: widget.api, onAuthError: widget.onLogout),
      16 => CommentsPage(api: widget.api, onAuthError: widget.onLogout),
      17 => QueuesPage(api: widget.api, onAuthError: widget.onLogout),
      18 => SystemMonitorPage(api: widget.api, onAuthError: widget.onLogout),
      19 => AuditLogsPage(api: widget.api, onAuthError: widget.onLogout),
      20 => SystemSettingsPage(api: widget.api, onAuthError: widget.onLogout),
      21 => EdgeNodesPage(api: widget.api, onAuthError: widget.onLogout),
      _ => RegionManagementPage(api: widget.api, onAuthError: widget.onLogout),
    };
  }
}
