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
          NavigationRail(
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
                icon: const Icon(Icons.photo_library_outlined),
                selectedIcon: const Icon(Icons.photo_library),
                label: Text(t(context, 'media')),
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
            ],
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
                          4 => t(context, 'media'),
                          5 => t(context, 'users'),
                          6 => t(context, 'permissions'),
                          7 => t(context, 'ai_providers'),
                          8 => t(context, 'database'),
                          9 => t(context, 'comments'),
                          10 => t(context, 'queue_monitoring'),
                          11 => t(context, 'system_monitoring'),
                          _ => t(context, 'system_logs'),
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
      4 => MediaLibraryPage(api: widget.api, onAuthError: widget.onLogout),
      5 =>
          UserManagementPage(
          api: widget.api,
          onAuthError: widget.onLogout,
          isSuperAdmin: isSuperAdmin,
        ),
      6 =>
          PermissionManagementPage(
          api: widget.api,
          isSuperAdmin: isSuperAdmin,
          onAuthError: widget.onLogout,
        ),
      7 => AiProvidersPage(api: widget.api, onAuthError: widget.onLogout),
      8 =>
          DatabaseManagementPage(api: widget.api, onAuthError: widget.onLogout),
      9 => CommentsPage(api: widget.api, onAuthError: widget.onLogout),
      10 => QueuesPage(api: widget.api, onAuthError: widget.onLogout),
      11 => SystemMonitorPage(api: widget.api, onAuthError: widget.onLogout),
      _ => AuditLogsPage(api: widget.api, onAuthError: widget.onLogout),
    };
  }
}

