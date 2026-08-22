part of 'package:windblog_admin_flutter/main.dart';

class ImportDataPage extends StatefulWidget {
  const ImportDataPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });
  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<ImportDataPage> createState() => _ImportDataPageState();
}

class _ImportDataPageState extends State<ImportDataPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController(
    text: 'jdbc:postgresql://localhost:5432/windblog',
  );
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _assetPrefixController = TextEditingController();
  final _urlSearchController = TextEditingController();
  final _embeddedSearchController = TextEditingController();
  final _logScrollController = ScrollController();
  final String _driver = 'org.postgresql.Driver';

  String _sourceType = 'DATABASE';
  PlatformFile? _sqlFile;
  String? _analysisId;
  Map<String, dynamic>? _analysisReport;
  List<StorageClassItem> _storageClasses = [];
  bool _isTesting = false;
  bool _isAnalyzing = false;
  bool _isImporting = false;
  String? _result;
  final List<String> _logs = [];
  final List<Map<String, dynamic>> _recentDownloads = [];
  StreamSubscription? _importSub;
  static const int _urlPageSize = 20;
  int _urlPage = 1;
  String _urlTypeFilter = 'ALL';
  double? _overallProgress;
  int _overallCompleted = 0;
  int _overallTotal = 0;
  int _successfulDownloads = 0;
  int _failedDownloads = 0;
  String _overallPhase = '等待开始';
  Map<String, dynamic>? _currentDownload;
  int _embeddedPage = 1;
  String _embeddedFilter = 'ALL';

  bool _importCategories = true;
  bool _importTags = true;
  bool _importPosts = true;
  bool _importLinks = true;
  bool _importMedia = true;

  @override
  void initState() {
    super.initState();
    _loadStorageClasses();
  }

  Future<void> _loadStorageClasses() async {
    final items = await AdminRequestRunner.run<List<StorageClassItem>>(
      context: context,
      mounted: mounted,
      onAuthError: widget.onAuthError,
      task: widget.api.listStorageClasses,
      errorMessageBuilder: (error) => '读取存储策略失败：$error',
    );
    if (mounted && items != null) setState(() => _storageClasses = items);
  }

  bool _validateDatabaseCredentials() {
    if (_sourceType != 'DATABASE') return true;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid && mounted) setState(() => _result = '请输入源数据库用户名和密码');
    return valid;
  }

  Future<String?> _getStepUpToken() => AdminStepUpAuthorization.obtain(
    context,
    widget.api,
    title: '确认旧系统数据导入操作',
  );

  Future<void> _pickSqlFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['sql'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (mounted) AdminFeedback.error(context, '无法读取 SQL 文件内容');
      return;
    }
    setState(() {
      _sqlFile = file;
      _analysisId = null;
      _analysisReport = null;
      _result = null;
    });
  }

  Map<String, dynamic> _databaseBody() => {
    'sourceType': 'DATABASE',
    'driver': _driver,
    'url': _urlController.text.trim(),
    'username': _usernameController.text.trim(),
    'password': _passwordController.text,
    'assetPrefix': _assetPrefixController.text.trim(),
  };

  Future<void> _analyze() async {
    if (!_validateDatabaseCredentials()) return;
    if (_sourceType == 'SQL_FILE' && _sqlFile?.bytes == null) {
      AdminFeedback.error(context, '请先选择 SQL 文件');
      return;
    }
    final stepUpToken = await _getStepUpToken();
    if (stepUpToken == null || !mounted) return;
    setState(() {
      _isAnalyzing = true;
      _result = null;
    });
    final report = await AdminRequestRunner.run<Map<String, dynamic>>(
      context: context,
      mounted: mounted,
      onAuthError: widget.onAuthError,
      task: () => _sourceType == 'DATABASE'
          ? widget.api.analyzeImportDatabase(
              _databaseBody(),
              stepUpToken: stepUpToken,
            )
          : widget.api.analyzeImportSqlFile(
              fileName: _sqlFile!.name,
              bytes: _sqlFile!.bytes!,
              stepUpToken: stepUpToken,
            ),
      errorMessageBuilder: (error) => '预分析失败：$error',
    );
    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _analysisId = report?['analysisId']?.toString();
        _analysisReport = report?['report'] as Map<String, dynamic>?;
        _urlPage = 1;
        _urlTypeFilter = 'ALL';
        _urlSearchController.clear();
        _result = report == null ? null : '预分析完成，可确认报告后执行导入';
      });
    }
  }

  Future<void> _testConnection() async {
    if (!_validateDatabaseCredentials()) return;
    final stepUpToken = await _getStepUpToken();
    if (stepUpToken == null || !mounted) return;
    setState(() {
      _isTesting = true;
      _result = null;
    });
    final result = await AdminRequestRunner.run<Map<String, dynamic>>(
      context: context,
      mounted: mounted,
      onAuthError: widget.onAuthError,
      task: () => widget.api.testImportConnection(
        _databaseBody(),
        stepUpToken: stepUpToken,
      ),
      errorMessageBuilder: (error) => '测试连接失败：$error',
    );
    if (mounted) {
      setState(() {
        _isTesting = false;
        _result = result?['message']?.toString();
      });
    }
  }

  List<String> _selectedTypes() => [
    if (_importCategories) 'categories',
    if (_importTags) 'tags',
    if (_importPosts) 'posts',
    if (_importLinks) 'links',
    if (_importMedia) 'media',
  ];

  bool get _hasBlockers {
    final blockers = _analysisReport?['blockers'];
    return blockers is List && blockers.isNotEmpty;
  }

  Future<void> _startImport() async {
    if (!_validateDatabaseCredentials()) return;
    if (_analysisId == null) {
      AdminFeedback.error(context, '请先完成预分析');
      return;
    }
    final types = _selectedTypes();
    if (types.isEmpty) {
      AdminFeedback.error(context, t(context, 'please_select_at_least_one'));
      return;
    }
    if (_hasBlockers) {
      AdminFeedback.error(context, '预分析报告存在阻断项，请修复后重新分析');
      return;
    }
    final stepUpToken = await _getStepUpToken();
    if (stepUpToken == null || !mounted) return;
    setState(() {
      _isImporting = true;
      _result = null;
      _logs
        ..clear()
        ..add('🚀 开始导入任务...');
      _recentDownloads.clear();
      _overallProgress = 0;
      _overallCompleted = 0;
      _overallTotal = 0;
      _successfulDownloads = 0;
      _failedDownloads = 0;
      _overallPhase = '准备导入';
      _currentDownload = null;
    });

    _importSub = widget.api.importStream().listen(
      (event) {
        if (!mounted) return;
        _handleImportEvent(event);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScrollController.hasClients) {
            _logScrollController.animateTo(
              _logScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          }
        });
      },
      onError: (error) {
        if (mounted) setState(() => _logs.add('❌ 连接流错误：$error'));
      },
    );

    final result = await AdminRequestRunner.run<Map<String, dynamic>>(
      context: context,
      mounted: mounted,
      onAuthError: widget.onAuthError,
      task: () => widget.api.executeImport({
        'analysisId': _analysisId,
        'sourceType': _sourceType,
        'driver': _driver,
        'url': _urlController.text.trim(),
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'types': types,
        'assetPrefix': _assetPrefixController.text.trim(),
        'conflictPolicy': 'SKIP_EXISTING',
      }, stepUpToken: stepUpToken),
      errorMessageBuilder: (error) => '导入失败：$error',
    );
    if (mounted) {
      setState(() {
        _isImporting = false;
        _result = result == null
            ? null
            : result['success'] == true
            ? '导入成功！分类 ${result['importedCategories']}，标签 ${result['importedTags']}，文章 ${result['importedPosts']}，链接 ${result['importedLinks']}'
            : result['message']?.toString() ?? '导入失败';
      });
    }
    await _importSub?.cancel();
  }

  void _handleImportEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    final rawData = event['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    final prefix = switch (type) {
      'info' => 'ℹ️ ',
      'error' => '❌ ',
      'progress' => '📈 ',
      'download' => '⬇️ ',
      'overall' => '📊 ',
      'end' => '✅ ',
      _ => '',
    };
    if (type == 'overall') {
      _overallCompleted = (data['completed'] as num?)?.toInt() ?? _overallCompleted;
      _overallTotal = (data['total'] as num?)?.toInt() ?? _overallTotal;
      final percent = (data['percent'] as num?)?.toDouble();
      _overallProgress = percent == null ? null : (percent / 100).clamp(0.0, 1.0);
      _overallPhase = data['phase']?.toString() ?? _overallPhase;
    } else if (type == 'download') {
      _currentDownload = data;
      _successfulDownloads =
          (data['successfulResources'] as num?)?.toInt() ?? _successfulDownloads;
      _failedDownloads =
          (data['failedResources'] as num?)?.toInt() ?? _failedDownloads;
      final phase = data['phase']?.toString();
      if (phase == 'completed' || phase == 'failed') {
        _recentDownloads.removeWhere(
          (item) => item['resourceUrl'] == data['resourceUrl'],
        );
        _recentDownloads.insert(0, data);
        if (_recentDownloads.length > 20) _recentDownloads.removeLast();
      }
    }
    final shouldLog = type != 'download' ||
        data['phase'] == 'started' ||
        data['phase'] == 'completed' ||
        data['phase'] == 'failed';
    setState(() {
      if (shouldLog) _logs.add('$prefix${event['message'] ?? ''}');
    });
  }

  @override
  void dispose() {
    _importSub?.cancel();
    _logScrollController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _assetPrefixController.dispose();
    _urlSearchController.dispose();
    _embeddedSearchController.dispose();
    super.dispose();
  }

  Widget _buildSourceCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(context, 'db_config'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'DATABASE',
                    label: Text('源数据库'),
                    icon: Icon(Icons.storage),
                  ),
                  ButtonSegment(
                    value: 'SQL_FILE',
                    label: Text('SQL 文件'),
                    icon: Icon(Icons.description),
                  ),
                ],
                selected: {_sourceType},
                onSelectionChanged: _isAnalyzing || _isImporting
                    ? null
                    : (values) => setState(() {
                        _sourceType = values.first;
                        _analysisId = null;
                        _analysisReport = null;
                      }),
              ),
              const SizedBox(height: 14),
              if (_sourceType == 'DATABASE') ...[
                TextFormField(
                  initialValue: 'PostgreSQL',
                  readOnly: true,
                  decoration: InputDecoration(labelText: t(context, 'db_type')),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: 'JDBC URL'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: t(context, 'username'),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '请输入源数据库用户名'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: t(context, 'password'),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? '请输入源数据库密码' : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isTesting || _isAnalyzing || _isImporting
                      ? null
                      : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cable),
                  label: Text(t(context, 'test_connection')),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _isAnalyzing || _isImporting ? null : _pickSqlFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_sqlFile?.name ?? '选择 PostgreSQL .sql 文件'),
                ),
                if (_sqlFile != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_sqlFile!.name} · ${(_sqlFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                  ),
                ],
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _assetPrefixController,
                decoration: const InputDecoration(
                  labelText: 'URL 补全前缀（仅相对资源使用）',
                  hintText: '例如 https://old.example.com',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '预分析会检测文章、评论、友情链接和媒体字段中的全部 URL；Data URL 图片会单独统计，导入时先转换为标准媒体文件，再替换 Markdown、HTML、CSS 中的原引用。只有相对 URL 和协议相对 URL 会使用此前缀补全；普通绝对 URL 和 mailto:/javascript:/tel: 等非媒体协议会保留原值。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _isAnalyzing || _isImporting ? null : _analyze,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.analytics_outlined),
                label: Text(_isAnalyzing ? '分析中...' : '预分析'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(BuildContext context) {
    if (_analysisReport == null) return const SizedBox.shrink();
    final report = _analysisReport!;
    final blockers = (report['blockers'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final warnings = (report['warnings'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final primary = _storageClasses
        .where((item) => item.isPrimary)
        .map((item) => item.displayName)
        .join(', ');
    final replicas = _storageClasses
        .where((item) => item.isEnabled && !item.isPrimary)
        .map((item) => item.displayName)
        .join(', ');
    return Card(
      color: blockers.isEmpty
          ? null
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  blockers.isEmpty
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                ),
                const SizedBox(width: 8),
                Text('预分析报告', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '类型：${report['dialect'] ?? _sourceType} · 语句：${report['statementCount'] ?? '-'}',
            ),
            if (report['tables'] is Map)
              Text(
                (report['tables'] as Map).entries
                    .map(
                      (entry) =>
                          '${entry.key}: ${(entry.value as Map)['rows'] ?? 0} 行',
                    )
                    .join('，'),
              ),
            if (primary.isNotEmpty) Text('媒体主存储：$primary'),
            if (replicas.isNotEmpty) Text('同步副本：$replicas'),
            for (final warning in warnings)
              Text(
                '提示：$warning',
                style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
              ),
            for (final blocker in blockers)
              Text(
                '阻断：$blocker',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard(BuildContext context) {
    Widget option(String title, bool value, ValueChanged<bool?> onChanged) =>
        CheckboxListTile(
          title: Text(title),
          value: value,
          onChanged: _isImporting ? null : onChanged,
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'select_import_content'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            option(
              t(context, 'categories'),
              _importCategories,
              (value) => setState(() => _importCategories = value ?? false),
            ),
            option(
              t(context, 'tags'),
              _importTags,
              (value) => setState(() => _importTags = value ?? false),
            ),
            option(
              t(context, 'posts'),
              _importPosts,
              (value) => setState(() => _importPosts = value ?? false),
            ),
            option(
              t(context, 'links'),
              _importLinks,
              (value) => setState(() => _importLinks = value ?? false),
            ),
            option(
              t(context, 'media_library_import'),
              _importMedia,
              (value) => setState(() => _importMedia = value ?? false),
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> _reportList(String key) {
    final value = _analysisReport?[key];
    return value is List<dynamic> ? value : const [];
  }

  Map<String, dynamic> _reportMap(String key) {
    final value = _analysisReport?[key];
    return value is Map<String, dynamic> ? value : const {};
  }

  String _reportValue(Object? value) {
    if (value == null) return '执行时判断';
    return value.toString();
  }

  Widget _buildMergePlanCard(BuildContext context) {
    final plans = _reportList('mergePlan');
    if (plans.isEmpty) return const SizedBox.shrink();
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.merge_type),
        title: const Text('导入与合并计划'),
        subtitle: const Text('明确哪些数据会新增、合并、跳过或在执行阶段判断'),
        children: plans.map((raw) {
          final plan = raw is Map ? raw : const <String, dynamic>{};
          final sourceRows = _reportValue(plan['sourceRows']);
          final newRecords = _reportValue(plan['newRecords']);
          final merge = _reportValue(plan['mergeCandidates']);
          return ListTile(
            dense: true,
            title: Text(
              '${plan['label'] ?? plan['entity']} · $sourceRows 条源数据',
            ),
            subtitle: Text(
              '新增：$newRecords  · 合并/跳过：$merge\n'
              '${plan['action'] ?? ''}；${plan['comparison'] ?? ''}',
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDirtyDataCard(BuildContext context) {
    final dirty = _reportList('dirtyData');
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: dirty.isNotEmpty,
        leading: Icon(
          dirty.isEmpty
              ? Icons.verified_outlined
              : Icons.warning_amber_outlined,
          color: dirty.isEmpty ? scheme.primary : scheme.error,
        ),
        title: Text(dirty.isEmpty ? '未检测到脏数据' : '检测到 ${dirty.length} 类脏数据'),
        subtitle: Text(
          dirty.isEmpty ? '已完成空值、重复键、孤儿关系和非法字符检查' : '请在执行前确认以下数据处理方式',
        ),
        children: dirty.isEmpty
            ? const []
            : dirty.map((raw) {
                final item = raw is Map ? raw : const <String, dynamic>{};
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.report_problem_outlined,
                    color: scheme.error,
                  ),
                  title: Text(
                    '${item['entity'] ?? ''}：${item['issue'] ?? ''}（${item['count'] ?? 0}）',
                  ),
                  subtitle: Text(item['action']?.toString() ?? ''),
                );
              }).toList(),
      ),
    );
  }

  Widget _buildRelativeUrlsCard(BuildContext context) {
    final urls = _reportMap('urls').isNotEmpty
        ? _reportMap('urls')
        : _reportMap('relativeUrls');
    final rawItems = urls['examples'] is List
        ? urls['examples'] as List
        : const [];
    final items = rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final query = _urlSearchController.text.trim().toLowerCase();
    final filtered = items.where((item) {
      final type = item['type']?.toString() ?? 'RELATIVE';
      final matchesType = _urlTypeFilter == 'ALL' || type == _urlTypeFilter;
      final matchesQuery =
          query.isEmpty ||
          (item['url']?.toString().toLowerCase().contains(query) ?? false);
      return matchesType && matchesQuery;
    }).toList();
    final totalPages = filtered.isEmpty
        ? 1
        : (filtered.length / _urlPageSize).ceil();
    final page = _urlPage.clamp(1, totalPages);
    final start = (page - 1) * _urlPageSize;
    final pageItems = filtered.skip(start).take(_urlPageSize).toList();
    final scheme = Theme.of(context).colorScheme;
    final typeLabels = <String, String>{
      'ALL': '全部',
      'RELATIVE': '相对 URL',
      'ABSOLUTE': '绝对 URL',
      'PROTOCOL_RELATIVE': '协议相对',
      'SPECIAL': '特殊协议',
      'FRAGMENT': '页面片段',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.link,
                  color: items.isEmpty ? scheme.primary : scheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'URL 检测（全部类型）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${urls['total'] ?? 0} 次引用',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '相对：${urls['relativeCount'] ?? 0} · 绝对：${urls['absoluteCount'] ?? 0} · 协议相对：${urls['protocolRelativeCount'] ?? 0} · 特殊协议：${urls['specialCount'] ?? 0} · 页面片段：${urls['fragmentCount'] ?? 0} · 媒体：${urls['mediaCount'] ?? 0}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _urlSearchController,
                    decoration: const InputDecoration(
                      labelText: '过滤 URL',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() => _urlPage = 1),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    initialValue: _urlTypeFilter,
                    decoration: const InputDecoration(
                      labelText: '类型过滤',
                      isDense: true,
                    ),
                    items: typeLabels.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _urlTypeFilter = value ?? 'ALL';
                      _urlPage = 1;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pageItems.isEmpty)
              Text(
                items.isEmpty ? '未检测到 URL' : '没有符合当前过滤条件的 URL',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pageItems.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final item = pageItems[index];
                  final details = item['examples'] is List
                      ? item['examples'] as List
                      : const [];
                  final source = details.isNotEmpty && details.first is Map
                      ? (details.first as Map)['source']?.toString() ?? ''
                      : '';
                  final kind = details.isNotEmpty && details.first is Map
                      ? (details.first as Map)['kind']?.toString() ?? ''
                      : '';
                  final type = item['type']?.toString() ?? 'RELATIVE';
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      type == 'ABSOLUTE' ? Icons.public : Icons.link,
                    ),
                    title: SelectableText(
                      '${item['url'] ?? ''} × ${item['count'] ?? 0}',
                      maxLines: 3,
                    ),
                    subtitle: Text(
                      '$type · $source${kind.isEmpty ? '' : ' · $kind'}',
                    ),
                  );
                },
              ),
            if (filtered.isNotEmpty) ...[
              const SizedBox(height: 8),
              PaginationBar(
                currentPage: page,
                totalPages: totalPages,
                totalItems: filtered.length,
                pageSize: _urlPageSize,
                onPageChanged: (value) => setState(() => _urlPage = value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedImagesCard(BuildContext context) {
    final report = _reportMap('embeddedImages');
    final rawItems = report['items'] is List ? report['items'] as List : const [];
    final items = rawItems.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    final query = _embeddedSearchController.text.trim().toLowerCase();
    final filtered = items.where((item) {
      final mime = item['mimeType']?.toString() ?? '';
      final status = item['status']?.toString() ?? 'CONVERTIBLE';
      return (_embeddedFilter == 'ALL' || status == _embeddedFilter) &&
          (query.isEmpty || mime.toLowerCase().contains(query) ||
              (item['sha256']?.toString().toLowerCase().contains(query) ?? false));
    }).toList();
    final totalPages = filtered.isEmpty ? 1 : (filtered.length / _urlPageSize).ceil();
    final page = _embeddedPage.clamp(1, totalPages);
    final pageItems = filtered.skip((page - 1) * _urlPageSize).take(_urlPageSize).toList();
    final failed = report['failed'] ?? 0;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(failed is num && failed > 0 ? Icons.error_outline : Icons.image_outlined,
                color: failed is num && failed > 0 ? scheme.error : scheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('内嵌图片 Data URL（独立迁移）', style: Theme.of(context).textTheme.titleMedium)),
            Text('${report['totalReferences'] ?? 0} 次引用', style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 6),
          Text('去重图片：${report['uniqueImages'] ?? 0} · 可转换：${report['convertible'] ?? 0} · 失败：$failed · 原始大小：${report['totalBytes'] ?? 0} B',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text('导入时会先转换为标准媒体文件，再替换 Markdown、HTML 和 CSS 中的原引用；失败项会阻止执行。',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 10, children: [
            SizedBox(width: 280, child: TextField(
              controller: _embeddedSearchController,
              decoration: const InputDecoration(labelText: '过滤 MIME / 摘要', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: (_) => setState(() => _embeddedPage = 1),
            )),
            SizedBox(width: 190, child: DropdownButtonFormField<String>(
              initialValue: _embeddedFilter,
              decoration: const InputDecoration(labelText: '状态过滤', isDense: true),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('全部')),
                DropdownMenuItem(value: 'CONVERTIBLE', child: Text('可转换')),
                DropdownMenuItem(value: 'FAILED', child: Text('失败')),
              ],
              onChanged: (value) => setState(() { _embeddedFilter = value ?? 'ALL'; _embeddedPage = 1; }),
            )),
          ]),
          const SizedBox(height: 10),
          if (pageItems.isEmpty)
            Text(items.isEmpty ? '未检测到内嵌图片 Data URL' : '没有符合当前过滤条件的内嵌图片')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pageItems.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = pageItems[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.image, color: scheme.primary),
                  title: Text(item['status'] == 'FAILED'
                      ? '转换失败 · ${item['reason'] ?? ''}'
                      : '${item['mimeType'] ?? ''} · ${item['bytes'] ?? 0} B × ${item['references'] ?? 0}'),
                  subtitle: Text(item['status'] == 'FAILED'
                      ? '${item['source'] ?? ''} · ${item['kind'] ?? ''}'
                      : '${item['status'] ?? ''} · ${item['sha256'] ?? ''}'),
                );
              },
            ),
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: 8),
            PaginationBar(currentPage: page, totalPages: totalPages, totalItems: filtered.length,
                pageSize: _urlPageSize, onPageChanged: (value) => setState(() => _embeddedPage = value)),
          ],
        ]),
      ),
    );
  }

  Widget _buildImportProgressCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final download = _currentDownload;
    final totalBytes = (download?['totalBytes'] as num?)?.toInt() ?? -1;
    final downloadedBytes = (download?['downloadedBytes'] as num?)?.toInt() ?? 0;
    final byteProgress = totalBytes > 0
        ? (downloadedBytes / totalBytes).clamp(0.0, 1.0)
        : null;
    final httpStatus = (download?['httpStatus'] as num?)?.toInt() ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.downloading, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('导入总进度', style: Theme.of(context).textTheme.titleMedium)),
            Text('$_overallCompleted / $_overallTotal', style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _overallProgress),
          const SizedBox(height: 6),
          Text('${_overallProgress == null ? '处理中' : '${((_overallProgress ?? 0) * 100).round()}%'} · $_overallPhase · 成功资源 $_successfulDownloads · 失败资源 $_failedDownloads'),
          if (download != null) ...[
            const Divider(height: 24),
            Text('当前资源', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            SelectableText(download['resourceUrl']?.toString() ?? '', maxLines: 2),
            const SizedBox(height: 6),
            Row(children: [
              Text('HTTP ${httpStatus > 0 ? httpStatus : '—'}'),
              const SizedBox(width: 12),
              Text('重定向 ${(download['redirectCount'] as num?)?.toInt() ?? 0} 次'),
              const SizedBox(width: 12),
              Text('${_formatBytes(downloadedBytes)} / ${totalBytes > 0 ? _formatBytes(totalBytes) : '未知大小'}'),
            ]),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: byteProgress),
            if (byteProgress != null)
              Text('${(byteProgress * 100).round()}%', style: Theme.of(context).textTheme.bodySmall),
            if (download['error'] != null)
              Text('失败：${download['error']}', style: TextStyle(color: scheme.error)),
          ],
          if (_recentDownloads.isNotEmpty) ...[
            const Divider(height: 24),
            Text('最近资源', style: Theme.of(context).textTheme.titleSmall),
            ..._recentDownloads.take(8).map((item) {
              final failed = item['phase'] == 'failed';
              final status = (item['httpStatus'] as num?)?.toInt() ?? 0;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(failed ? Icons.error_outline : Icons.check_circle_outline,
                    color: failed ? scheme.error : scheme.primary),
                title: Text(item['resourceUrl']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${failed ? '失败' : '完成'} · HTTP ${status > 0 ? status : '—'} · ${_formatBytes((item['downloadedBytes'] as num?)?.toInt() ?? 0)}'),
              );
            }),
          ],
        ]),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AdminPageScaffold(
        title: t(context, 'import_data'),
        actions: [
          OutlinedButton.icon(
            onPressed: Navigator.canPop(context)
                ? () => Navigator.of(context).pop()
                : null,
            icon: const Icon(Icons.arrow_back),
            label: Text(t(context, 'back')),
          ),
        ],
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSourceCard(context),
              const SizedBox(height: 12),
              _buildAnalysisCard(context),
              const SizedBox(height: 12),
              _buildMergePlanCard(context),
              const SizedBox(height: 12),
              _buildDirtyDataCard(context),
              const SizedBox(height: 12),
              _buildRelativeUrlsCard(context),
              const SizedBox(height: 12),
              _buildEmbeddedImagesCard(context),
              const SizedBox(height: 12),
              _buildSelectionCard(context),
              const SizedBox(height: 12),
              if (_isImporting || _overallProgress != null)
                _buildImportProgressCard(context),
              if (_isImporting || _overallProgress != null)
                const SizedBox(height: 12),
              if (_logs.isNotEmpty)
                Card(
                  child: SizedBox(
                    height: 260,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t(context, 'import_logs'),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const Divider(),
                          Expanded(
                            child: ListView.builder(
                              controller: _logScrollController,
                              itemCount: _logs.length,
                              itemBuilder: (_, index) => Text(
                                _logs[index],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_result != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(_result!),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isImporting || _isAnalyzing ? null : _startImport,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.input),
                label: Text(
                  _isImporting
                      ? t(context, 'importing')
                      : t(context, 'start_import'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
