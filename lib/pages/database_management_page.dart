part of 'package:windblog_admin_flutter/main.dart';

class DatabaseManagementPage extends StatefulWidget {
  const DatabaseManagementPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<DatabaseManagementPage> createState() => _DatabaseManagementPageState();
}

class _DatabaseManagementPageState extends State<DatabaseManagementPage> {
  bool isMigrating = false;
  bool isSeeding = false;
  String? lastMigrateResult;
  String? lastSeedResult;
  DateTime? lastMigrateTime;
  DateTime? lastSeedTime;

  Future<void> _handleMigrate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'migrate_database')),
        content: Text(t(context, 'migrate_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t(context, 'migrate_database')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      isMigrating = true;
      lastMigrateResult = null;
    });

    try {
      final result = await widget.api.databaseMigrate();
      final success = result['success'] as bool? ?? false;
      final message = result['message']?.toString() ?? '';
      
      setState(() {
        lastMigrateResult = success ? t(context, 'migrate_success') : message;
        lastMigrateTime = DateTime.now();
      });

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lastMigrateResult!)),
        );
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      setState(() {
        lastMigrateResult = t(context, 'migrate_failed').replaceAll('%s', '$e');
        lastMigrateTime = DateTime.now();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lastMigrateResult!)),
        );
      }
    } finally {
      if (mounted) setState(() => isMigrating = false);
    }
  }

  Future<void> _handleSeed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'seed_database')),
        content: Text(t(context, 'seed_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t(context, 'seed_database')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      isSeeding = true;
      lastSeedResult = null;
    });

    try {
      final result = await widget.api.databaseSeed();
      final success = result['success'] as bool? ?? false;
      final message = result['message']?.toString() ?? '';
      
      setState(() {
        lastSeedResult = success ? t(context, 'seed_success') : message;
        lastSeedTime = DateTime.now();
      });

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lastSeedResult!)),
        );
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      setState(() {
        lastSeedResult = t(context, 'seed_failed').replaceAll('%s', '$e');
        lastSeedTime = DateTime.now();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lastSeedResult!)),
        );
      }
    } finally {
      if (mounted) setState(() => isSeeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(context, 'database_operations'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  t(context, 'database_description'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(context, 'migrate_database'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  t(context, 'migrate_confirm'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: isMigrating ? null : _handleMigrate,
                  icon: isMigrating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(isMigrating ? t(context, 'migrating') : t(context, 'migrate_database')),
                ),
                if (lastMigrateResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lastMigrateResult!.contains('成功') || 
                             lastMigrateResult!.contains('successfully')
                          ? Colors.green[50]
                          : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastMigrateResult!,
                          style: TextStyle(
                            color: lastMigrateResult!.contains('成功') || 
                                   lastMigrateResult!.contains('successfully')
                                ? Colors.green[800]
                                : Colors.red[800],
                          ),
                        ),
                        if (lastMigrateTime != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '🕐 ${_formatTime(lastMigrateTime!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(context, 'seed_database'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  t(context, 'seed_confirm'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: isSeeding ? null : _handleSeed,
                  icon: isSeeding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline),
                  label: Text(isSeeding ? t(context, 'seeding') : t(context, 'seed_database')),
                ),
                if (lastSeedResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lastSeedResult!.contains('成功') || 
                           lastSeedResult!.contains('successfully')
                          ? Colors.green[50]
                          : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastSeedResult!,
                          style: TextStyle(
                            color: lastSeedResult!.contains('成功') || 
                                   lastSeedResult!.contains('successfully')
                                ? Colors.green[800]
                                : Colors.red[800],
                          ),
                        ),
                        if (lastSeedTime != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '🕐 ${_formatTime(lastSeedTime!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(context, 'data_import'),
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  t(context, 'data_import_desc'),
                  style: Theme
                      .of(context)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            ImportDataPage(
                              api: widget.api,
                              onAuthError: widget.onAuthError,
                            ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.input),
                  label: Text(t(context, 'go_to_import')),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange[800]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
