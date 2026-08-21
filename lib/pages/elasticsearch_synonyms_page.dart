part of 'package:windblog_admin_flutter/main.dart';

class ElasticsearchSynonymsPage extends StatefulWidget {
  const ElasticsearchSynonymsPage({
    super.key,
    required this.api,
    required this.onAuthError,
    required this.onOpenElasticSettings,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;
  final VoidCallback onOpenElasticSettings;

  @override
  State<ElasticsearchSynonymsPage> createState() {
    return _ElasticsearchSynonymsPageState();
  }
}

class _ElasticsearchSynonymsPageState extends State<ElasticsearchSynonymsPage> {
  static const String settingKey = 'elasticsearch';

  bool _loading = true;
  bool _actionRunning = false;
  String? _errorMessage;
  SystemSetting? _setting;
  Map<String, dynamic> _status = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      SystemSetting loadedSetting = await widget.api.getSystemSetting(
        settingKey,
      );
      Map<String, dynamic> loadedStatus = {};
      try {
        loadedStatus = await widget.api.getElasticsearchStatus();
      } catch (_) {
        loadedStatus = {};
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _setting = loadedSetting;
        _status = loadedStatus;
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (exception) {
      if (mounted) {
        setState(() {
          _errorMessage = exception.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _setting == null) {
      return const AdminPageScaffold(
        title: '同义词规则',
        body: AdminStatusView.loading(title: '正在加载同义词规则'),
      );
    }

    if (_errorMessage != null && _setting == null) {
      return AdminPageScaffold(
        title: '同义词规则',
        body: AdminStatusView.error(
          title: '加载同义词规则失败',
          message: _errorMessage,
          action: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('重新加载'),
          ),
        ),
      );
    }

    return AdminPageScaffold(
      title: '同义词规则',
      actions: [
        TextButton.icon(
          onPressed: widget.onOpenElasticSettings,
          icon: const Icon(Icons.tune),
          label: const Text('返回 Elasticsearch'),
        ),
        OutlinedButton.icon(
          onPressed: _actionRunning ? null : _load,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新状态'),
        ),
      ],
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 12),
            _buildRelationLegendCard(),
            const SizedBox(height: 12),
            _buildEditorCard(),
            const SizedBox(height: 12),
            _buildOperationCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    SystemSetting? currentSetting = _setting;
    List<Map<String, dynamic>> synonymRules = _readSynonymRules(currentSetting);
    int equivalentRuleCount = 0;
    int mappingRuleCount = 0;
    int termCount = 0;

    for (Map<String, dynamic> rule in synonymRules) {
      String mode = rule['mode']?.toString() ?? 'equivalent';
      List<String> terms = _readTerms(rule['terms']);
      termCount += terms.length;
      if (mode == 'mapping') {
        mappingRuleCount += 1;
      } else {
        equivalentRuleCount += 1;
      }
    }

    Color accentColor = const Color(0xFF14B8A6);
    if (currentSetting != null && currentSetting.isFrozen) {
      accentColor = Colors.orange;
    }

    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accentColor.withValues(alpha: 0.16),
              accentColor.withValues(alpha: 0.05),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(AdminBreakpoints.isPhone(context) ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.account_tree, color: accentColor, size: 30),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '同义词规则单独管理',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    const Text('在这里维护词条关系，保存后仍然沿用 Elasticsearch 主配置的确认和回滚流程。'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMetricChip(
                  icon: Icons.rule,
                  label: '规则总数',
                  value: synonymRules.length.toString(),
                  color: accentColor,
                ),
                _buildMetricChip(
                  icon: Icons.sync_alt,
                  label: '等价组',
                  value: equivalentRuleCount.toString(),
                  color: Colors.indigo,
                ),
                _buildMetricChip(
                  icon: Icons.arrow_right_alt,
                  label: '单向映射',
                  value: mappingRuleCount.toString(),
                  color: Colors.deepOrange,
                ),
                _buildMetricChip(
                  icon: Icons.style,
                  label: '词条总数',
                  value: termCount.toString(),
                  color: Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildConnectionSummary(),
            if (currentSetting != null && currentSetting.isFrozen) ...[
              const SizedBox(height: 16),
              const AlertBanner(
                message: '当前同义词配置已冻结，先解除冻结后才能修改。',
                type: AlertType.warning,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSummary() {
    Map<String, dynamic> connection = {};
    dynamic rawConnection = _status['elasticsearch'];
    if (rawConnection is Map) {
      connection = Map<String, dynamic>.from(rawConnection);
    }

    bool enabled = connection['enabled'] == true;
    bool available = connection['available'] == true;
    String connectionText = connection['status']?.toString() ?? '未知';
    String hosts = connection['hosts']?.toString() ?? '-';
    String lastError = connection['lastError']?.toString() ?? '';

    Color stateColor = Colors.grey;
    IconData stateIcon = Icons.help_outline;
    String stateLabel = '状态未知';
    if (!enabled) {
      stateColor = Colors.orange;
      stateIcon = Icons.pause_circle_outline;
      stateLabel = '已停用';
    } else if (available) {
      stateColor = Colors.green;
      stateIcon = Icons.check_circle_outline;
      stateLabel = '连接正常';
    } else {
      stateColor = Colors.red;
      stateIcon = Icons.error_outline;
      stateLabel = '连接不可用';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stateColor.withValues(alpha: 0.16)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(
            avatar: Icon(stateIcon, color: stateColor, size: 18),
            label: Text(stateLabel),
            side: BorderSide(color: stateColor.withValues(alpha: 0.4)),
          ),
          Text('地址：$hosts'),
          Text('连接状态：$connectionText'),
          if (lastError.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(
                '最近错误：$lastError',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRelationLegendCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AdminBreakpoints.isPhone(context) ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '关系图例',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 14,
              children: [
                _buildLegendItem(
                  color: Colors.indigo,
                  icon: Icons.sync_alt,
                  title: '等价组',
                  description: '多个词条互相替换，搜索会视为同一概念。',
                ),
                _buildLegendItem(
                  color: Colors.deepOrange,
                  icon: Icons.arrow_right_alt,
                  title: '单向映射',
                  description: '左侧词条统一映射到右侧目标词。',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCard() {
    SystemSetting? currentSetting = _setting;
    if (currentSetting == null) {
      return const AdminStatusView.empty(title: '暂无配置');
    }

    List<UISchemaField> synonymFields = [];
    for (UISchemaField field in currentSetting.uiSchema.fields) {
      if (field.key == 'synonyms') {
        synonymFields.add(field);
      }
    }

    if (synonymFields.isEmpty) {
      synonymFields.add(
        UISchemaField(key: 'synonyms', label: '同义词规则', widget: 'synonym_cards'),
      );
    }

    UISchema synonymSchema = UISchema(
      type: currentSetting.uiSchema.type,
      fields: synonymFields,
    );

    Map<String, dynamic> currentValues = {};
    if (currentSetting.configValue is Map) {
      currentValues = Map<String, dynamic>.from(
        currentSetting.configValue as Map,
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AdminBreakpoints.isPhone(context) ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '规则编辑器',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '等价组适合“相互替换”的词，映射规则适合“归一到目标词”的词。',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    '${t(context, 'config_version')}: ${currentSetting.version}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ConfigDynamicForm(
              key: ValueKey('${currentSetting.version}-synonyms'),
              schema: synonymSchema,
              initialValues: currentValues,
              isFrozen: currentSetting.isFrozen,
              onSave: _saveSynonymRules,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '配置操作',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('同义词改动保存后，仍需回到 Elasticsearch 主配置完成确认，必要时也可以直接回滚。'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _actionRunning ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新状态'),
                ),
                OutlinedButton.icon(
                  onPressed: _actionRunning ? null : _rollbackSetting,
                  icon: const Icon(Icons.history),
                  label: const Text('回滚设置'),
                ),
                FilledButton.icon(
                  onPressed: _actionRunning ? null : _confirmSetting,
                  icon: const Icon(Icons.check),
                  label: const Text('确认生效'),
                ),
              ],
            ),
            if (_actionRunning) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveSynonymRules(Map<String, dynamic> values) async {
    final stepUpToken = await _obtainStepUp();
    if (stepUpToken == null) return;
    await _runAction(() async {
      await widget.api.updateSystemSetting(
        settingKey,
        values,
        reason: '管理员修改 Elasticsearch 同义词规则',
        stepUpToken: stepUpToken,
      );
      return '同义词规则已保存，等待确认后生效';
    }, reloadAfterSuccess: true);
  }

  Future<void> _confirmSetting() async {
    final stepUpToken = await _obtainStepUp();
    if (stepUpToken == null) return;
    await _runAction(() async {
      await widget.api.confirmSystemSetting(
        settingKey,
        stepUpToken: stepUpToken,
      );
      return '同义词规则已确认';
    }, reloadAfterSuccess: true);
  }

  Future<void> _rollbackSetting() async {
    final stepUpToken = await _obtainStepUp();
    if (stepUpToken == null) return;
    await _runAction(() async {
      await widget.api.rollbackSystemSetting(
        settingKey,
        stepUpToken: stepUpToken,
      );
      return '同义词规则已回滚';
    }, reloadAfterSuccess: true);
  }

  Future<String?> _obtainStepUp() => AdminStepUpAuthorization.obtain(
    context,
    widget.api,
    title: '确认 Elasticsearch 同义词设置操作',
  );

  Future<void> _runAction(
    Future<String> Function() action, {
    bool reloadAfterSuccess = false,
  }) async {
    setState(() {
      _actionRunning = true;
    });
    try {
      String message = await action();
      if (!mounted) {
        return;
      }
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
      if (reloadAfterSuccess) {
        await _load();
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (exception) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(
            content: Text('操作失败：$exception'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionRunning = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _readSynonymRules(SystemSetting? setting) {
    List<Map<String, dynamic>> rules = [];
    if (setting == null || setting.configValue is! Map) {
      return rules;
    }

    dynamic rawSynonyms = (setting.configValue as Map)['synonyms'];
    if (rawSynonyms is! List) {
      return rules;
    }

    for (dynamic item in rawSynonyms) {
      if (item is Map) {
        rules.add(Map<String, dynamic>.from(item));
      }
    }
    return rules;
  }

  List<String> _readTerms(dynamic rawTerms) {
    List<String> terms = [];
    if (rawTerms is! List) {
      return terms;
    }

    for (dynamic item in rawTerms) {
      String term = item?.toString().trim() ?? '';
      if (term.isNotEmpty) {
        terms.add(term);
      }
    }
    return terms;
  }
}
