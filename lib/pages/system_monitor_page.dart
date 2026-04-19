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
  bool loading = false;
  String? error;
  DateTime? lastUpdate;

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton(
                onPressed: _loadMonitorInfo,
                child: Text(t(context, 'refresh')),
              ),
              if (lastUpdate != null) ...[
                const SizedBox(width: 16),
                Text(
                  '${t(context, 'last_update')}: ${_formatTime(lastUpdate!)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            if (error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade300,
                          size: 48),
                      const SizedBox(height: 16),
                      Text(
                        '${t(context, 'load_failed')}$error',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                  ),
                ),
              )
            else
              if (monitorInfo == null)
                const Expanded(
                  child: Center(child: Text('No data')),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildHealthCard(),
                        const SizedBox(height: 16),
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
                      ],
                    ),
                  ),
                ),
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
        child: Row(
          children: [
            Icon(
              isHealthy ? Icons.check_circle : Icons.error,
              color: isHealthy ? Colors.green : Colors.red,
              size: 48,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t(context, 'health_status')}: ${health.status}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isHealthy ? Colors.green.shade700 : Colors.red
                          .shade700,
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
              ),
            ),
          ],
        ),
      ),
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
            Row(
              children: [
                const Icon(Icons.memory, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'JVM ${t(context, 'info')}',
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleMedium,
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
                  t(context, 'memory_committed'), jvm.memoryCommittedText),
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
            Row(
              children: [
                const Icon(Icons.computer, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  '${t(context, 'system')} ${t(context, 'info')}',
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleMedium,
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
            Row(
              children: [
                const Icon(Icons.apps, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '${t(context, 'application')} ${t(context, 'info')}',
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleMedium,
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

  Widget _buildProgressBar(String label, double percent, String sublabel) {
    final color = percent > 80
        ? Colors.red
        : (percent > 60 ? Colors.orange : Colors.green);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  item.label,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              Expanded(
                child: Text(
                  item.value,
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
