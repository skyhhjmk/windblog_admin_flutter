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
    if (error != null) return Center(child: Text(error!));
    final map = data;
    if (map == null) return const Center(child: CircularProgressIndicator());

    Widget card(String label, Object value) {
      return SizedBox(
        width: 160,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 8),
                Text('$value'),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            card(t(context, 'users_count'), map['users'] ?? 0),
            card(t(context, 'posts_count'), map['posts'] ?? 0),
            card(t(context, 'comments_count'), map['comments'] ?? 0),
            card(t(context, 'tags_count'), map['tags'] ?? 0),
            card(t(context, 'categories_count'), map['categories'] ?? 0),
          ],
        ),
        const SizedBox(height: 12),
        Text('${t(context, 'api_docs')}${widget.api.baseUrl}/api/admin/docs'),
      ],
    );
  }
}

