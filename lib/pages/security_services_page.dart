part of 'package:windblog_admin_flutter/main.dart';

class SecurityServicesPage extends StatefulWidget {
  const SecurityServicesPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<SecurityServicesPage> createState() => _SecurityServicesPageState();
}

class _SecurityServicesPageState extends State<SecurityServicesPage> {
  SystemMonitorInfo? _monitorInfo;
  ClamAvStatus? _clamAv;
  bool _loading = true;
  bool _testing = false;
  String? _error;

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
      final values = await Future.wait<dynamic>([
        widget.api.getSystemMonitor(),
        widget.api.getClamAvStatus(),
      ]);
      _monitorInfo = values[0] as SystemMonitorInfo;
      _clamAv = values[1] as ClamAvStatus;
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _testClamAv() async {
    setState(() => _testing = true);
    try {
      _clamAv = await widget.api.testClamAv();
      if (mounted) AdminFeedback.info(context, _clamAv!.message);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: '安全服务',
      actions: [
        OutlinedButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('刷新'),
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AdminStatusView.loading(title: '正在检查基础设施');
    }
    if (_error != null) {
      return AdminStatusView.error(
        title: '加载失败',
        message: _error,
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      );
    }
    if (_monitorInfo == null || _clamAv == null) {
      return const AdminStatusView.empty(title: '暂无安全服务状态');
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHealthCard(_monitorInfo!.health),
          const SizedBox(height: 16),
          _buildClamAvCard(_clamAv!),
          const SizedBox(height: 16),
          _buildReleaseNote(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHealthCard(HealthInfo health) {
    final healthy = health.isHealthy;
    return Card(
      color: healthy ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(healthy ? Icons.check_circle : Icons.error,
                    color: healthy ? Colors.green : Colors.red),
                const SizedBox(width: 10),
                Text('应用健康状态：${health.status}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
              ],
            ),
            if (health.components.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: health.components.entries.map((entry) {
                  final component = entry.value;
                  return Chip(
                    avatar: Icon(
                      component.isHealthy ? Icons.check : Icons.close,
                      size: 16,
                      color: component.isHealthy ? Colors.green : Colors.red,
                    ),
                    label: Text('${entry.key}: ${component.status}'),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClamAvCard(ClamAvStatus status) {
    final healthy = status.isHealthy;
    final color = healthy ? Colors.green : Colors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.policy_outlined, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('ClamAV 病毒扫描',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                ),
                Chip(
                  label: Text(status.available ? '可用' : '不可用'),
                  backgroundColor: color.shade100,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(status.message),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 640
                    ? constraints.maxWidth
                    : 260.0;
                return Wrap(
                  spacing: 22,
                  runSpacing: 12,
                  children: [
                    _securityValue('启用', status.enabled ? '是' : '否', width),
                    _securityValue('强制扫描', status.required ? '是' : '否', width),
                    _securityValue('地址', '${status.host}:${status.port}', width),
                    _securityValue('超时', status.timeout, width),
                    _securityValue('状态', status.status, width),
                    _securityValue('检查时间', _formatDate(status.checkedAt), width),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _testing ? null : _testClamAv,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check),
              label: const Text('重新测试连接'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _securityValue(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.grey.shade700,
                  )),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildReleaseNote() {
    return Card(
      color: Colors.blue.shade50,
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'ClamAV 的启用、强制策略、主机和端口来自服务端环境配置。修改后请重启后端，并在此页面重新测试；管理端不会保存或修改扫描服务凭据。',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return value.toLocal().toString().split('.').first;
  }
}
