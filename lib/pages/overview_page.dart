part of 'package:windblog_admin_flutter/main.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      data = await widget.api.overview();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return AdminPageScaffold(
        title: t(context, 'overview'),
        body: AdminStatusView.error(
          title: t(context, 'load_failed'),
          message: error,
          action: FilledButton.icon(
            onPressed: load,
            icon: const Icon(Icons.refresh),
            label: Text(t(context, 'refresh')),
          ),
        ),
      );
    }
    final map = data;
    if (map == null) {
      return AdminPageScaffold(
        title: t(context, 'overview'),
        body: const AdminStatusView.loading(title: '正在加载概览'),
      );
    }

    final primaryColor = Theme.of(context).colorScheme.primary;

    Widget card(String label, Object value, IconData icon) {
      return SizedBox(
        width: AdminBreakpoints.isPhone(context) ? double.infinity : 200,
        child: Card(
          elevation: 3,
          shadowColor: primaryColor.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: primaryColor.withValues(alpha: 0.15), width: 1.5),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withValues(alpha: 0.06), primaryColor.withValues(alpha: 0.01)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$value',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: primaryColor, size: 24),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AdminPageScaffold(
      title: t(context, 'overview'),
      actions: [
        OutlinedButton.icon(
          onPressed: load,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(t(context, 'refresh')),
        ),
      ],
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              card(t(context, 'users_count'), map['users'] ?? 0, Icons.people_alt),
              card(t(context, 'posts_count'), map['posts'] ?? 0, Icons.article),
              card(t(context, 'comments_count'), map['comments'] ?? 0, Icons.comment),
              card(t(context, 'tags_count'), map['tags'] ?? 0, Icons.local_offer),
              card(t(context, 'categories_count'), map['categories'] ?? 0, Icons.folder),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.code, color: primaryColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'API Documentation / 接口文档',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          '${widget.api.baseUrl}/api/admin/docs',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
