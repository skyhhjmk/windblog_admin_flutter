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

  Future<String> _resolveKibanaUrl() async {
    try {
      final payload = await widget.api.kibanaUrl();
      final path = payload['url']?.toString().trim() ?? '';
      if (path.isNotEmpty) {
        if (Uri.parse(path).isAbsolute) return path;
        return '${widget.api.baseUrl}${path.startsWith('/') ? '' : '/'}$path';
      }
    } catch (_) {
      // Ignored: fallback below
    }
    final baseUri = Uri.tryParse(widget.api.baseUrl);
    if (baseUri != null && baseUri.hasAuthority) {
      final host = baseUri.host;
      final scheme = baseUri.scheme.isNotEmpty ? baseUri.scheme : 'http';
      return '$scheme://$host:5601';
    }
    return 'http://localhost:5601';
  }

  Future<void> _openKibana() async {
    try {
      final kibanaUrl = await _resolveKibanaUrl();
      web_helper.openUrl(kibanaUrl);
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('打开 Kibana 失败: $e')),
        );
      }
    }
  }

  Widget _buildHeader(BuildContext context) {
    final isPhone = AdminBreakpoints.isPhone(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final titleWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.insights_outlined, color: primaryColor, size: 20),
        const SizedBox(width: 8),
        const Text(
          '系统监控与日志 / Observability',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: _openKibana,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('快捷打开 Kibana'),
        ),
        if (kIsWeb && _url != null)
          OutlinedButton.icon(
            onPressed: () => web_helper.openUrl(_url!),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('在浏览器中打开 Grafana'),
          ),
      ],
    );

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          if (kIsWeb) ...[const SizedBox(height: 10), actions],
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [titleWidget, if (kIsWeb) actions],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading && _url == null) {
      return const SizedBox(
        height: 380,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insights_outlined,
                size: 36,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 8),
              const Text('Grafana 观测面板暂不可用'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                  if (!kIsWeb)
                    FilledButton.tonalIcon(
                      onPressed: _openKibana,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('快捷打开 Kibana'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    final url = _url;
    if (url == null) return const SizedBox.shrink();
    if (!kIsWeb) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.dashboard_customize_outlined,
                size: 36,
                color: Color(0xFF64748B),
              ),
              const SizedBox(height: 10),
              const Text(
                '桌面端及移动端支持在外部默认浏览器中访问 Grafana 与 Kibana 面板',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => web_helper.openUrl(url),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('在浏览器中打开 Grafana Dashboard'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _openKibana,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('快捷打开 Kibana 控制台'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(height: 620, child: web_helper.buildIFrame(url));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        _buildContent(context),
      ],
    );
  }
}
