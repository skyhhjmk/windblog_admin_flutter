part of 'package:windblog_admin_flutter/main.dart';

class GrafanaEmbed extends StatefulWidget {
  const GrafanaEmbed({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<GrafanaEmbed> createState() => _GrafanaEmbedState();
}

class _GrafanaEmbedState extends State<GrafanaEmbed> {
  static const _refreshLeadTime = Duration(minutes: 13);

  String? _url;
  String? _error;
  bool _loading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await widget.api.grafanaEmbedUrl();
      final path = payload['url']?.toString() ?? '';
      if (path.isEmpty) throw Exception('Grafana 未返回嵌入地址');
      final url = Uri.parse(path).isAbsolute
          ? path
          : '${widget.api.baseUrl}${path.startsWith('/') ? '' : '/'}$path';
      if (mounted) {
        setState(() => _url = url);
        _refreshTimer?.cancel();
        // Grafana is authenticated by the short-lived, HttpOnly edge cookie.
        // Refresh before it expires so an open dashboard keeps working without
        // exposing a long-lived token in the iframe URL.
        _refreshTimer = Timer(_refreshLeadTime, _load);
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _url == null) {
      return const SizedBox(
        height: 420,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insights_outlined, size: 36),
              const SizedBox(height: 8),
              const Text('Grafana 观测面板暂不可用'),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    final url = _url;
    if (url == null) return const SizedBox.shrink();
    if (!kIsWeb) {
      return SizedBox(
        height: 180,
        child: Center(
          child: FilledButton.icon(
            onPressed: () => web_helper.openUrl(url),
            icon: const Icon(Icons.open_in_new),
            label: const Text('在浏览器中打开 Grafana Dashboard'),
          ),
        ),
      );
    }
    return SizedBox(height: 620, child: web_helper.buildIFrame(url));
  }
}
