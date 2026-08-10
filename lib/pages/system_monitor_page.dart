part of 'package:windblog_admin_flutter/main.dart';

class SystemMonitorPage extends StatefulWidget {
  const SystemMonitorPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<SystemMonitorPage> createState() => _SystemMonitorPageState();
}

class _SystemMonitorPageState extends State<SystemMonitorPage> {
  SystemMonitorInfo? monitorInfo;
  bool loading = true;
  String? error;
  DateTime? lastUpdate;
  final TextEditingController _trackingTextController = TextEditingController();
  String? _decryptedText;
  bool _decrypting = false;

  @override
  void initState() {
    super.initState();
    _loadMonitorInfo();
  }

  Future<void> _loadMonitorInfo() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      monitorInfo = await widget.api.getSystemMonitor();
      lastUpdate = DateTime.now();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _decryptTrackingText() async {
    final text = _trackingTextController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _decrypting = true;
      _decryptedText = null;
    });

    try {
      final result = await widget.api.decryptError(text);
      setState(() {
        _decryptedText = result;
      });
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(context, SnackBar(content: Text('解密失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _decrypting = false);
    }
  }

  @override
  void dispose() {
    _trackingTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actionWidgets = [
      OutlinedButton.icon(
        onPressed: _loadMonitorInfo,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(t(context, 'refresh')),
      ),
    ];
    if (lastUpdate != null) {
      actionWidgets.add(
        Chip(
          label: Text(
            '${t(context, 'last_update')}: ${_formatTime(lastUpdate!)}',
          ),
        ),
      );
    }

    return AdminPageScaffold(
      title: t(context, 'system_monitoring'),
      actions: actionWidgets,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const AdminStatusView.loading(title: '正在加载系统监控');
    }

    if (error != null) {
      return AdminStatusView.error(
        title: t(context, 'load_failed'),
        message: error,
        action: FilledButton.icon(
          onPressed: _loadMonitorInfo,
          icon: const Icon(Icons.refresh),
          label: Text(t(context, 'refresh')),
        ),
      );
    }

    if (monitorInfo == null) {
      return AdminStatusView.empty(title: t(context, 'no_data'));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildHealthCard(),
          const SizedBox(height: 16),
          if (AdminBreakpoints.isPhone(context)) ...[
            _buildJvmCard(),
            const SizedBox(height: 16),
            _buildSystemCard(),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildJvmCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildSystemCard()),
              ],
            ),
          const SizedBox(height: 16),
          _buildApplicationCard(),
          const SizedBox(height: 16),
          _buildDecryptionTool(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHealthCard() {
    final health = monitorInfo!.health;
    final isHealthy = health.isHealthy;

    return Card(
      color: isHealthy ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AdminBreakpoints.isPhone(context)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isHealthy ? Icons.check_circle : Icons.error,
                    color: isHealthy ? Colors.green : Colors.red,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  _buildHealthText(health, isHealthy),
                ],
              )
            : Row(
                children: [
                  Icon(
                    isHealthy ? Icons.check_circle : Icons.error,
                    color: isHealthy ? Colors.green : Colors.red,
                    size: 48,
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildHealthText(health, isHealthy)),
                ],
              ),
      ),
    );
  }

  Widget _buildHealthText(HealthInfo health, bool isHealthy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${t(context, 'health_status')}: ${health.status}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isHealthy ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: health.components.entries.map((entry) {
            final component = entry.value;
            final isComponentHealthy = component.isHealthy;
            return Chip(
              avatar: Icon(
                isComponentHealthy ? Icons.check : Icons.close,
                size: 16,
                color: isComponentHealthy ? Colors.green : Colors.red,
              ),
              label: Text(entry.key),
              backgroundColor: isComponentHealthy
                  ? Colors.green.shade100
                  : Colors.red.shade100,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildJvmCard() {
    final jvm = monitorInfo!.jvm;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.memory, color: Colors.blue),
                Text(
                  'JVM ${t(context, 'info')}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildProgressBar(
              t(context, 'memory_usage'),
              jvm.memoryUsagePercent,
              '${jvm.memoryUsedText} / ${jvm.memoryMaxText}',
            ),
            const SizedBox(height: 16),
            _buildInfoGrid([
              _InfoItem(
                t(context, 'memory_committed'),
                jvm.memoryCommittedText,
              ),
              _InfoItem(t(context, 'thread_count'), '${jvm.threadCount}'),
              _InfoItem(t(context, 'peak_threads'), '${jvm.peakThreadCount}'),
              _InfoItem(t(context, 'uptime'), jvm.uptimeText),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemCard() {
    final system = monitorInfo!.system;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.computer, color: Colors.purple),
                Text(
                  '${t(context, 'system')} ${t(context, 'info')}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoGrid([
              _InfoItem(t(context, 'os_name'), system.osName),
              _InfoItem(t(context, 'os_version'), system.osVersion),
              _InfoItem(t(context, 'os_arch'), system.osArch),
              _InfoItem(t(context, 'cpu_count'), '${system.cpuCount}'),
              _InfoItem(t(context, 'system_load'), system.loadText),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationCard() {
    final app = monitorInfo!.application;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.apps, color: Colors.orange),
                Text(
                  '${t(context, 'application')} ${t(context, 'info')}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoGrid([
              _InfoItem(t(context, 'app_name'), app.name),
              _InfoItem(t(context, 'app_version'), app.version),
              _InfoItem(t(context, 'start_time'), app.startTime),
              _InfoItem(t(context, 'app_uptime'), app.uptimeText),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildDecryptionTool() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.security, color: Colors.teal),
                Text(
                  '错误追踪解密工具',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _trackingTextController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '在此粘贴加密的追踪文本...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _decrypting ? null : _decryptTrackingText,
                icon: _decrypting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.vpn_key),
                label: const Text('解密追踪文本'),
              ),
            ),
            if (_decryptedText != null) ...[
              const SizedBox(height: 16),
              const Text(
                '解密结果:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  _decryptedText!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String label, double percent, String sublabel) {
    final color = percent > 80
        ? Colors.red
        : (percent > 60 ? Colors.orange : Colors.green);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              '${percent.toStringAsFixed(1)}% ($sublabel)',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(List<_InfoItem> items) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  item.label,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AdminBreakpoints.isPhone(context) ? 220 : 360,
                ),
                child: Text(
                  item.value,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

class _InfoItem {
  _InfoItem(this.label, this.value);

  final String label;
  final String value;
}
