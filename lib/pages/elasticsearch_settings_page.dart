part of 'package:windblog_admin_flutter/main.dart';

class ElasticsearchSettingsPage extends StatefulWidget {
  const ElasticsearchSettingsPage({
    super.key,
    required this.api,
    required this.onAuthError,
    required this.onOpenSynonymRules,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;
  final VoidCallback onOpenSynonymRules;

  @override
  State<ElasticsearchSettingsPage> createState() {
    return _ElasticsearchSettingsPageState();
  }
}

class _ElasticsearchSettingsPageState extends State<ElasticsearchSettingsPage> {
  static const String settingKey = 'elasticsearch';

  bool loading = true;
  bool actionRunning = false;
  String? errorMessage;
  SystemSetting? setting;
  Map<String, dynamic> status = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      errorMessage = null;
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
        setting = loadedSetting;
        status = loadedStatus;
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (exception) {
      if (mounted) {
        setState(() {
          errorMessage = exception.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && setting == null) {
      return const AdminPageScaffold(
        title: 'Elasticsearch',
        body: AdminStatusView.loading(title: '正在加载 Elasticsearch 设置'),
      );
    }

    if (errorMessage != null && setting == null) {
      return AdminPageScaffold(
        title: 'Elasticsearch',
        body: AdminStatusView.error(
          title: '加载 Elasticsearch 设置失败',
          message: errorMessage,
          action: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('重新加载'),
          ),
        ),
      );
    }

    return AdminPageScaffold(
      title: 'Elasticsearch',
      actions: [
        TextButton.icon(
          onPressed: widget.onOpenSynonymRules,
          icon: const Icon(Icons.account_tree_outlined),
          label: const Text('同义词规则'),
        ),
        OutlinedButton.icon(
          onPressed: actionRunning ? null : _load,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新状态'),
        ),
      ],
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 12),
            _buildConfigurationCard(),
            const SizedBox(height: 12),
            _buildSynonymRulesCard(),
            const SizedBox(height: 12),
            _buildOperationCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Map<String, dynamic> connection = {};
    dynamic rawConnection = status['elasticsearch'];
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 20,
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
      ),
    );
  }

  Widget _buildConfigurationCard() {
    SystemSetting? currentSetting = setting;
    if (currentSetting == null) {
      return const AdminStatusView.empty(title: '暂无配置');
    }

    List<UISchemaField> sectionFields = [];
    for (UISchemaField field in currentSetting.uiSchema.fields) {
      if (field.key != 'synonyms') {
        sectionFields.add(field);
      }
    }
    UISchema sectionSchema = UISchema(
      type: currentSetting.uiSchema.type,
      fields: sectionFields,
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '基础连接配置',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '这里维护 Elasticsearch 的连接、认证和分词器。同义词规则已拆到单独页面，避免一张表单里混在一起。',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.tune, size: 18),
                  label: Text(
                    '${t(context, 'config_version')}: ${currentSetting.version}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ConfigDynamicForm(
              key: ValueKey('${currentSetting.version}-basic'),
              schema: sectionSchema,
              initialValues: currentValues,
              isFrozen: currentSetting.isFrozen,
              onSave: _saveSetting,
            ),
            if (currentSetting.isFrozen) ...[
              const SizedBox(height: 12),
              const AlertBanner(
                message: '当前基础配置已冻结，确认后才会正式生效。',
                type: AlertType.warning,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSynonymRulesCard() {
    SystemSetting? currentSetting = setting;
    if (currentSetting == null) {
      return const AdminStatusView.empty(title: '暂无同义词配置');
    }

    int synonymRuleCount = 0;
    if (currentSetting.configValue is Map) {
      dynamic rawSynonyms = (currentSetting.configValue as Map)['synonyms'];
      if (rawSynonyms is List) {
        synonymRuleCount = rawSynonyms.length;
      }
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AdminBreakpoints.isPhone(context) ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.account_tree,
                    color: Color(0xFF14B8A6),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '同义词规则',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '独立维护词条关系，适合集中编辑、批量调整和检查归一效果。',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.rule, size: 18),
                  label: Text('当前 $synonymRuleCount 条规则'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSynonymFeatureTile(
                  icon: Icons.sync_alt,
                  title: '等价组',
                  description: '一组词条互相等价，搜索会自动合并理解。',
                  color: Colors.indigo,
                ),
                _buildSynonymFeatureTile(
                  icon: Icons.arrow_right_alt,
                  title: '单向映射',
                  description: '把多个词统一映射到一个目标词，便于归一。',
                  color: Colors.deepOrange,
                ),
                _buildSynonymFeatureTile(
                  icon: Icons.layers_outlined,
                  title: '可视化卡片',
                  description: '每条规则独立成卡，关系和修改动作更清楚。',
                  color: const Color(0xFF14B8A6),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: widget.onOpenSynonymRules,
                icon: const Icon(Icons.open_in_new),
                label: const Text('打开同义词规则页面'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSynonymFeatureTile({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 330),
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
          const SizedBox(width: 12),
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
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
              ],
            ),
          ),
        ],
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
              '索引管理',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('修改连接参数或分词器后，先保存设置，再应用配置。同义词规则已经拆到单独页面，保存并确认后再回到这里执行索引操作。已有文章索引需要重建后才会使用新规则。'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: actionRunning ? null : _testConnection,
                  icon: const Icon(Icons.cable),
                  label: const Text('测试连接'),
                ),
                OutlinedButton.icon(
                  onPressed: actionRunning ? null : _rollbackSetting,
                  icon: const Icon(Icons.history),
                  label: const Text('回滚设置'),
                ),
                FilledButton.icon(
                  onPressed: actionRunning ? null : _confirmSetting,
                  icon: const Icon(Icons.check),
                  label: const Text('确认设置'),
                ),
                FilledButton.icon(
                  onPressed: actionRunning ? null : _applyIndexConfiguration,
                  icon: const Icon(Icons.build_outlined),
                  label: const Text('应用索引配置'),
                ),
                FilledButton.icon(
                  onPressed: actionRunning ? null : _confirmRebuild,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('重建索引'),
                ),
                OutlinedButton.icon(
                  onPressed: actionRunning ? null : _syncIndex,
                  icon: const Icon(Icons.sync),
                  label: const Text('同步全部文章'),
                ),
                OutlinedButton.icon(
                  onPressed: actionRunning ? null : _showAnalyzeDialog,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('预览分词'),
                ),
              ],
            ),
            if (actionRunning) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveSetting(Map<String, dynamic> values) async {
    await _runAction(() async {
      await widget.api.updateSystemSetting(
        settingKey,
        values,
        reason: '管理员修改 Elasticsearch 设置',
      );
      return '设置已保存，正在等待配置确认';
    }, reloadAfterSuccess: true);
  }

  Future<void> _testConnection() async {
    await _runAction(() async {
      Map<String, dynamic> response = await widget.api
          .testElasticsearchConnection();
      return response['message']?.toString() ?? '连接测试完成';
    }, reloadAfterSuccess: true);
  }

  Future<void> _confirmSetting() async {
    await _runAction(() async {
      await widget.api.confirmSystemSetting(settingKey);
      return '设置已确认';
    }, reloadAfterSuccess: true);
  }

  Future<void> _rollbackSetting() async {
    await _runAction(() async {
      await widget.api.rollbackSystemSetting(settingKey);
      return '设置已回滚';
    }, reloadAfterSuccess: true);
  }

  Future<void> _applyIndexConfiguration() async {
    await _runAction(() async {
      Map<String, dynamic> response = await widget.api
          .applyElasticsearchIndexConfiguration();
      return response['message']?.toString() ?? '索引配置已应用';
    }, reloadAfterSuccess: true);
  }

  Future<void> _confirmRebuild() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认重建索引'),
          content: const Text('该操作会删除现有文章索引并重新写入全部已发布文章。执行期间搜索结果可能暂时不完整。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认重建'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _runAction(() async {
      Map<String, dynamic> response = await widget.api
          .rebuildElasticsearchIndex();
      return response['message']?.toString() ?? '索引重建完成';
    }, reloadAfterSuccess: true);
  }

  Future<void> _syncIndex() async {
    await _runAction(() async {
      Map<String, dynamic> response = await widget.api.syncElasticsearchIndex();
      int totalCount = response['totalCount'] as int? ?? 0;
      return '文章索引同步完成，共处理 $totalCount 篇文章';
    }, reloadAfterSuccess: true);
  }

  Future<void> _showAnalyzeDialog() async {
    TextEditingController textController = TextEditingController();
    List<String> tokens = [];
    bool analyzing = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('预览分词'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: textController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '待分析文本',
                        hintText: '输入一段中文或英文内容',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (analyzing)
                      const LinearProgressIndicator()
                    else if (tokens.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tokens.map((token) {
                          return Chip(label: Text(token));
                        }).toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: analyzing
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('关闭'),
                ),
                FilledButton(
                  onPressed: analyzing
                      ? null
                      : () async {
                          String text = textController.text.trim();
                          if (text.isEmpty) {
                            return;
                          }
                          setDialogState(() {
                            analyzing = true;
                          });
                          try {
                            List<String> analyzedTokens = await widget.api
                                .analyzeElasticsearchText(text);
                            setDialogState(() {
                              tokens = analyzedTokens;
                            });
                          } catch (exception) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('分词预览失败：$exception'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                analyzing = false;
                              });
                            }
                          }
                        },
                  child: const Text('开始分析'),
                ),
              ],
            );
          },
        );
      },
    );
    textController.dispose();
  }

  Future<void> _runAction(
    Future<String> Function() action, {
    bool reloadAfterSuccess = false,
  }) async {
    setState(() {
      actionRunning = true;
    });
    try {
      String message = await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
      if (reloadAfterSuccess) {
        await _load();
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败：$exception'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          actionRunning = false;
        });
      }
    }
  }
}
