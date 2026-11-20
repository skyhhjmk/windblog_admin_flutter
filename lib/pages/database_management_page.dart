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

  DatabaseStorageReport? storageReport;
  bool storageLoading = true;
  String? storageError;
  String storageSearch = '';
  String storageSortField = 'totalBytes';
  bool storageSortDesc = true;
  final TextEditingController _storageSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStorageReport();
  }

  @override
  void dispose() {
    _storageSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadStorageReport() async {
    setState(() {
      storageLoading = true;
      storageError = null;
    });
    try {
      final report = await widget.api.getDatabaseStorage();
      if (!mounted) return;
      setState(() {
        storageReport = report;
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        storageError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => storageLoading = false);
      }
    }
  }

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
        AdminFeedback.showSnackBar(
          context,
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
        AdminFeedback.showSnackBar(
          context,
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
        AdminFeedback.showSnackBar(
          context,
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
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text(lastSeedResult!)),
        );
      }
    } finally {
      if (mounted) setState(() => isSeeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = AdminBreakpoints.isPhone(context);
    final filteredTables = _filteredAndSortedTables(
      storageReport?.tables ?? const [],
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Card(
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
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _buildStorageMonitorHeaderCard(
              context,
              filteredTables,
              isPhone: isPhone,
            ),
          ),
        ),
        if (storageReport != null && filteredTables.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverFixedExtentList(
              itemExtent: isPhone ? 88.0 : 48.0,
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildStorageTableRow(
                  context,
                  filteredTables[index],
                  isLast: index == filteredTables.length - 1,
                  isPhone: isPhone,
                ),
                childCount: filteredTables.length,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync),
                          label: Text(
                            isMigrating
                                ? t(context, 'migrating')
                                : t(context, 'migrate_database'),
                          ),
                        ),
                        if (lastMigrateResult != null) ...[
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final isDark =
                                  Theme.of(context).brightness ==
                                  Brightness.dark;
                              final isSuccess =
                                  lastMigrateResult!.contains('成功') ||
                                  lastMigrateResult!.contains('successfully');
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSuccess
                                      ? (isDark
                                            ? const Color(
                                                0xFF14532D,
                                              ).withValues(alpha: 0.35)
                                            : Colors.green[50])
                                      : (isDark
                                            ? const Color(
                                                0xFF7F1D1D,
                                              ).withValues(alpha: 0.35)
                                            : Colors.red[50]),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSuccess
                                        ? (isDark
                                              ? Colors.green.shade800
                                                    .withValues(alpha: 0.5)
                                              : Colors.green.shade200)
                                        : (isDark
                                              ? Colors.red.shade800.withValues(
                                                  alpha: 0.5,
                                                )
                                              : Colors.red.shade200),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lastMigrateResult!,
                                      style: TextStyle(
                                        color: isSuccess
                                            ? (isDark
                                                  ? Colors.green.shade300
                                                  : Colors.green[800])
                                            : (isDark
                                                  ? Colors.red.shade300
                                                  : Colors.red[800]),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (lastMigrateTime != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '🕐 ${_formatTime(lastMigrateTime!)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_circle_outline),
                          label: Text(
                            isSeeding
                                ? t(context, 'seeding')
                                : t(context, 'seed_database'),
                          ),
                        ),
                        if (lastSeedResult != null) ...[
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final isDark =
                                  Theme.of(context).brightness ==
                                  Brightness.dark;
                              final isSuccess =
                                  lastSeedResult!.contains('成功') ||
                                  lastSeedResult!.contains('successfully');
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSuccess
                                      ? (isDark
                                            ? const Color(
                                                0xFF14532D,
                                              ).withValues(alpha: 0.35)
                                            : Colors.green[50])
                                      : (isDark
                                            ? const Color(
                                                0xFF7F1D1D,
                                              ).withValues(alpha: 0.35)
                                            : Colors.red[50]),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSuccess
                                        ? (isDark
                                              ? Colors.green.shade800
                                                    .withValues(alpha: 0.5)
                                              : Colors.green.shade200)
                                        : (isDark
                                              ? Colors.red.shade800.withValues(
                                                  alpha: 0.5,
                                                )
                                              : Colors.red.shade200),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lastSeedResult!,
                                      style: TextStyle(
                                        color: isSuccess
                                            ? (isDark
                                                  ? Colors.green.shade300
                                                  : Colors.green[800])
                                            : (isDark
                                                  ? Colors.red.shade300
                                                  : Colors.red[800]),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (lastSeedTime != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '🕐 ${_formatTime(lastSeedTime!)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
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
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t(context, 'data_import_desc'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ImportDataPage(
                                  api: widget.api,
                                  onAuthError: widget.onAuthError,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.input),
                          label: Text(t(context, 'go_to_import')),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStorageMonitorHeaderCard(
    BuildContext context,
    List<DatabaseTableStorageItem> filteredTables, {
    required bool isPhone,
  }) {
    final theme = Theme.of(context);
    final report = storageReport;
    final hasRows = report != null && filteredTables.isNotEmpty;

    return Material(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: hasRows
            ? const BorderRadius.vertical(top: Radius.circular(12))
            : BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, hasRows ? 0 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storage_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t(
                        context,
                        'database_table_storage',
                        fallback: '表级磁盘存储监控',
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (report != null && report.databaseName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(report.databaseName),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (report?.collectedAt != null) ...[
                      Text(
                        '${t(context, 'last_update', fallback: '最近更新')}: ${_formatTime(report!.collectedAt!.toLocal())}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: storageLoading ? null : _loadStorageReport,
                      icon: storageLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(t(context, 'refresh', fallback: '刷新')),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (storageLoading && report == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (storageError != null && report == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '加载表级存储信息失败: $storageError',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              )
            else if (report != null) ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildStorageStatChip(
                    context,
                    '数据库总占用',
                    _formatBytes(report.databaseTotalBytes),
                    Icons.dns_outlined,
                  ),
                  _buildStorageStatChip(
                    context,
                    '表总占用',
                    _formatBytes(report.tableTotalBytes),
                    Icons.table_chart_outlined,
                  ),
                  _buildStorageStatChip(
                    context,
                    '表数据',
                    _formatBytes(report.tableDataBytes),
                    Icons.dataset_outlined,
                  ),
                  _buildStorageStatChip(
                    context,
                    '索引占用',
                    _formatBytes(report.tableIndexBytes),
                    Icons.bolt_outlined,
                  ),
                  _buildStorageStatChip(
                    context,
                    'TOAST 占用',
                    _formatBytes(report.tableToastBytes),
                    Icons.layers_outlined,
                  ),
                  _buildStorageStatChip(
                    context,
                    '数据表数量',
                    '${report.tableCount}',
                    Icons.format_list_numbered,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _storageSearchController,
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        hintText: '搜索表名或 schema...',
                        border: const OutlineInputBorder(),
                        suffixIcon: storageSearch.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _storageSearchController.clear();
                                  setState(() => storageSearch = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(
                          () => storageSearch = value.trim().toLowerCase(),
                        );
                      },
                    ),
                  ),
                  DropdownButton<String>(
                    value: storageSortField,
                    items: const [
                      DropdownMenuItem(
                        value: 'totalBytes',
                        child: Text('按总占用排序'),
                      ),
                      DropdownMenuItem(
                        value: 'dataBytes',
                        child: Text('按表数据排序'),
                      ),
                      DropdownMenuItem(
                        value: 'indexBytes',
                        child: Text('按索引占用排序'),
                      ),
                      DropdownMenuItem(
                        value: 'toastBytes',
                        child: Text('按 TOAST 排序'),
                      ),
                      DropdownMenuItem(
                        value: 'estimatedRows',
                        child: Text('按预估行数排序'),
                      ),
                      DropdownMenuItem(
                        value: 'tableName',
                        child: Text('按表名排序'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        if (storageSortField == value) {
                          storageSortDesc = !storageSortDesc;
                        } else {
                          storageSortField = value;
                          storageSortDesc = value != 'tableName';
                        }
                      });
                    },
                  ),
                  IconButton(
                    tooltip: storageSortDesc ? '降序' : '升序',
                    icon: Icon(
                      storageSortDesc
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() => storageSortDesc = !storageSortDesc);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredTables.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('没有匹配的数据表', style: theme.textTheme.bodyMedium),
                )
              else if (!isPhone)
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: theme.dividerColor),
                      bottom: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          '表名',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 88,
                        child: Text(
                          '预估行数',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 88,
                        child: Text(
                          '表数据',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 88,
                        child: Text(
                          '索引',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 84,
                        child: Text(
                          'TOAST',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 92,
                        child: Text(
                          '总占用',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 112,
                        child: Text(
                          '占比',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStorageTableRow(
    BuildContext context,
    DatabaseTableStorageItem table, {
    required bool isLast,
    required bool isPhone,
  }) {
    final theme = Theme.of(context);
    final ratio = (table.sharePercent / 100).clamp(0.0, 1.0);
    final borderColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.45,
    );

    return Material(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : BorderRadius.zero,
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        child: isPhone
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          table.qualifiedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatBytes(table.totalBytes),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '行 ${_formatCount(table.estimatedRows)} · 数据 ${_formatBytes(table.dataBytes)} · 索引 ${_formatBytes(table.indexBytes)} · TOAST ${_formatBytes(table.toastBytes)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${table.sharePercent.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      table.qualifiedName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: Text(
                      _formatCount(table.estimatedRows),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: Text(
                      _formatBytes(table.dataBytes),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: Text(
                      _formatBytes(table.indexBytes),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      _formatBytes(table.toastBytes),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(
                    width: 92,
                    child: Text(
                      _formatBytes(table.totalBytes),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 112,
                    child: Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${table.sharePercent.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStorageStatChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<DatabaseTableStorageItem> _filteredAndSortedTables(
    List<DatabaseTableStorageItem> tables,
  ) {
    final filtered = tables.where((item) {
      if (storageSearch.isEmpty) return true;
      return item.tableName.toLowerCase().contains(storageSearch) ||
          item.schema.toLowerCase().contains(storageSearch);
    }).toList();

    filtered.sort((a, b) {
      int cmp;
      switch (storageSortField) {
        case 'dataBytes':
          cmp = a.dataBytes.compareTo(b.dataBytes);
          break;
        case 'indexBytes':
          cmp = a.indexBytes.compareTo(b.indexBytes);
          break;
        case 'toastBytes':
          cmp = a.toastBytes.compareTo(b.toastBytes);
          break;
        case 'estimatedRows':
          cmp = a.estimatedRows.compareTo(b.estimatedRows);
          break;
        case 'tableName':
          cmp = a.qualifiedName.compareTo(b.qualifiedName);
          break;
        case 'totalBytes':
        default:
          cmp = a.totalBytes.compareTo(b.totalBytes);
          break;
      }
      return storageSortDesc ? -cmp : cmp;
    });
    return filtered;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    double value = bytes / 1024.0;
    int unitIdx = 0;
    while (value >= 1024.0 && unitIdx < units.length - 1) {
      value /= 1024.0;
      unitIdx++;
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : (value >= 10 ? 1 : 2))} ${units[unitIdx]}';
  }

  String _formatCount(int count) {
    if (count < 1000) return '$count';
    final s = count.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write(',');
      }
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatTime(DateTime time) {
    return DateTimeFormatter.formatTimeOnly(context, time);
  }
}
