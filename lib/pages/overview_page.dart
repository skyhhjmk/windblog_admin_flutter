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

    Widget card(String label, Object value) {
      return SizedBox(
        width: AdminBreakpoints.isPhone(context) ? double.infinity : 180,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 10),
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
              card(t(context, 'users_count'), map['users'] ?? 0),
              card(t(context, 'posts_count'), map['posts'] ?? 0),
              card(t(context, 'comments_count'), map['comments'] ?? 0),
              card(t(context, 'tags_count'), map['tags'] ?? 0),
              card(t(context, 'categories_count'), map['categories'] ?? 0),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${t(context, 'api_docs')}${widget.api.baseUrl}/api/admin/docs',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
