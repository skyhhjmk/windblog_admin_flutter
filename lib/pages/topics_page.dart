part of 'package:windblog_admin_flutter/main.dart';

class TopicsPage extends StatefulWidget {
  const TopicsPage({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage>
    with SingleTickerProviderStateMixin {
  static const int _topicPageSize = 20;
  static const int _assignedPageSize = 20;
  static const int _runPageSize = 20;

  late final TabController _tabController;

  bool _loading = true;
  bool _assignedLoading = false;
  bool _saving = false;
  String? _error;
  String? _pollingMessage;
  String _topicStatus = 'ALL';
  int _topicPage = 1;
  int _topicTotal = 0;
  int _assignedPage = 1;
  int _assignedTotal = 0;
  int _runPage = 1;
  int _runTotal = 0;
  int _activeTabIndex = 0;

  Map<String, dynamic>? _automation;
  List<Map<String, dynamic>> _seeds = [];
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _assignedTopics = [];
  List<Map<String, dynamic>> _runs = [];
  Map<String, dynamic> _models = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!mounted) return;
    final index = _tabController.index;
    if (_activeTabIndex == index) return;
    setState(() => _activeTabIndex = index);
    if (index == 1) unawaited(_loadAssignedTopics());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final automation = await widget.api.codexCreatorTopicAutomation();
      final models = await widget.api.codexCreatorModels();
      final topics = await widget.api.codexCreatorTopics(
        status: _topicStatus == 'ALL' ? null : _topicStatus,
        page: _topicPage,
        pageSize: _topicPageSize,
      );
      final runs = await widget.api.codexCreatorTopicRuns(
        page: _runPage,
        pageSize: _runPageSize,
      );
      if (!mounted) return;

      final topicPage = _intValue(topics['page']);
      final topicTotal = _intValue(topics['total']);
      final runTotal = _intValue(runs['total']);
      setState(() {
        _automation = automation;
        _models = models;
        _seeds = _mapList(automation['seeds']);
        _topics = _mapList(topics['items']);
        _runs = _mapList(runs['items']);
        _topicPage = topicPage ?? _topicPage;
        _topicTotal = topicTotal ?? 0;
        _runTotal = runTotal ?? 0;
      });
      final notifications = AdminNotificationScope.maybeOf(context);
      for (final run in _runs) {
        final status = run['status']?.toString() ?? '';
        if (status == 'QUEUED' || status == 'RUNNING') {
          notifications?.trackTopicDiscovery(
            api: widget.api,
            run: run,
            onCompleted: () {
              if (mounted) unawaited(_load());
            },
          );
        }
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) setState(() => _error = '读取话题数据失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAssignedTopics() async {
    if (mounted) {
      setState(() {
        _assignedLoading = true;
        _error = null;
      });
    }

    try {
      final result = await widget.api.codexCreatorTopics(
        status: 'ASSIGNED',
        page: _assignedPage,
        pageSize: _assignedPageSize,
      );
      if (!mounted) return;
      setState(() {
        _assignedTopics = _mapList(result['items']);
        _assignedTotal = _intValue(result['total']) ?? 0;
        _assignedPage = _intValue(result['page']) ?? _assignedPage;
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) setState(() => _error = '读取已指派任务失败：$error');
    } finally {
      if (mounted) setState(() => _assignedLoading = false);
    }
  }

  Future<void> _refresh() async {
    await _load();
    if (mounted && _activeTabIndex == 1) await _loadAssignedTopics();
  }

  Future<void> _changeTopicPage(int page) async {
    if (page == _topicPage || page < 1) return;
    setState(() => _topicPage = page);
    await _load();
  }

  Future<void> _changeAssignedPage(int page) async {
    if (page == _assignedPage || page < 1) return;
    setState(() => _assignedPage = page);
    await _loadAssignedTopics();
  }

  Future<void> _saveAutomation() async {
    final settings = _mapValue(_automation?['settings']);
    if (mounted) setState(() => _saving = true);
    try {
      final saved = await widget.api.updateCodexCreatorTopicAutomation({
        'enabled': settings['enabled'] == true,
        'intervalMinutes': _intValue(settings['intervalMinutes']) ?? 360,
        'maxSeedsPerRun': _intValue(settings['maxSeedsPerRun']) ?? 5,
        'maxTopicsPerRun': _intValue(settings['maxTopicsPerRun']) ?? 20,
        'promotionEnabled': settings['promotionEnabled'] == true,
        'promotionMarkdown': settings['promotionMarkdown']?.toString() ?? '',
      });
      if (!mounted) return;
      setState(() => _automation = {...?_automation, 'settings': saved});
      // Confirm against the read endpoint instead of relying solely on the
      // mutation response. This keeps the promotion state aligned with what a
      // browser refresh will display.
      await _load();
      if (!mounted) return;
      AdminFeedback.showSnackBar(
        context,
        const SnackBar(
          content: Text('主题自动化设置已保存'),
          backgroundColor: Colors.green,
        ),
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('保存主题自动化设置失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runNow() async {
    final profileId = await _chooseModel(
      title: '选择话题生成模型',
      description: '本次选择只影响这一次立即运行；定时任务继续使用默认模型。',
      operation: 'topic',
    );
    if (profileId == null || !mounted) return;
    if (mounted) setState(() => _saving = true);
    try {
      final run = await widget.api.startCodexCreatorTopicRun(
        profileId: profileId,
      );
      if (!mounted) return;
      final notifications = AdminNotificationScope.maybeOf(context);
      notifications?.trackTopicDiscovery(
        api: widget.api,
        run: run,
        onCompleted: () {
          if (mounted) unawaited(_load());
        },
      );
      if (notifications == null) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('话题生成已提交：${run['status'] ?? 'QUEUED'}')),
        );
      }
      await _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('立即运行失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editSeed([Map<String, dynamic>? seed]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TopicSeedDialog(seed: seed),
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final id = _intValue(seed?['id']);
      if (id == null) {
        await widget.api.createCodexCreatorTopicSeed(result);
      } else {
        await widget.api.updateCodexCreatorTopicSeed(id, result);
      }
      await _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('保存主题查询种子失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSeed(Map<String, dynamic> seed) async {
    final id = _intValue(seed['id']);
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除主题查询种子'),
        content: Text('确定删除“${seed['name'] ?? seed['query'] ?? ''}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.api.deleteCodexCreatorTopicSeed(id);
      await _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('删除主题查询种子失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reviewTopic(Map<String, dynamic> topic, String decision) async {
    final id = _intValue(topic['id']);
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await widget.api.reviewCodexCreatorTopic(id, decision);
      await _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('更新主题审核状态失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _assignDraft(Map<String, dynamic> topic) async {
    final topicId = _intValue(topic['id']);
    if (topicId == null) return;
    List<Map<String, dynamic>> servers = const [];
    List<RepostPolicyItem> policies = const [];
    try {
      final results = await Future.wait<Object>([
        widget.api.codexCreatorTestServers(),
        widget.api.listRepostPolicies(),
      ]);
      servers = results[0] as List<Map<String, dynamic>>;
      policies = results[1] as List<RepostPolicyItem>;
    } catch (_) {}
    if (policies.isEmpty) {
      policies = [_fallbackRepostPolicy()];
    }
    if (!mounted) return;

    final request = await showDialog<_DraftRequest>(
      context: context,
      builder: (_) => _DraftRequestDialog(
        models: _modelOptions('article'),
        servers: servers,
        policies: policies,
      ),
    );
    if (request == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final job = await widget.api.startCodexCreatorDraft(
        topicId,
        language: request.language,
        instructions: request.instructions,
        profileId: request.profileId,
        reasoningEffort: request.reasoningEffort,
        repostPolicyCode: request.repostPolicyCode,
        requiresPracticalVerification: request.practicalVerification,
        testServerIds: request.testServerIds,
      );
      final jobId = _intValue(job['id']);
      if (jobId == null) throw Exception('服务器没有返回草稿任务编号');
      if (!mounted) return;
      final notifications = AdminNotificationScope.maybeOf(context);
      notifications?.trackDraftGeneration(
        api: widget.api,
        job: job,
        onCompleted: () {
          if (mounted) unawaited(_loadAssignedTopics());
        },
      );
      if (notifications == null) await _pollDraft(jobId);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('提交草稿任务失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _pollingMessage = null;
        });
      }
    }
  }

  RepostPolicyItem _fallbackRepostPolicy() => const RepostPolicyItem(
    code: RepostPolicyItem.defaultCode,
    name: '转载前需申请授权',
    nameEn: 'Request authorization before reposting',
    licenseUrl: null,
    requiresApplication: true,
    summary: '转载前需要申请授权，并保留授权码、原文地址和转载链路。',
    summaryEn:
        'Request authorization before reposting and retain attribution details.',
    conditions: ['转载前申请授权', '保留授权码和原文地址'],
    conditionsEn: [
      'Authorization is required before reposting',
      'Keep the original URL',
    ],
  );

  Future<void> _regenerateDraft(Map<String, dynamic> topic) async {
    final topicId = _intValue(topic['id']);
    if (topicId == null) return;
    final choice = await _chooseArticleGeneration(
      title: '重新生成文章草稿',
      description: '选择本次重新生成使用的模型和思考级别。新内容会写入同一篇草稿的新修订，旧修订仍保留。',
    );
    if (choice == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final job = await widget.api.regenerateCodexCreatorDraft(
        topicId,
        profileId: choice.profileId,
        reasoningEffort: choice.reasoningEffort,
      );
      final jobId = _intValue(job['id']);
      if (jobId == null) throw Exception('服务器没有返回草稿任务编号');
      if (!mounted) return;
      final notifications = AdminNotificationScope.maybeOf(context);
      notifications?.trackDraftGeneration(
        api: widget.api,
        job: job,
        regeneration: true,
        onCompleted: () {
          if (mounted) unawaited(_loadAssignedTopics());
        },
      );
      if (notifications == null) await _pollDraft(jobId);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('重新生成草稿失败：$error')),
        );
        await _loadAssignedTopics();
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _pollingMessage = null;
        });
      }
    }
  }

  List<Map<String, dynamic>> _modelOptions(String operation) {
    final values = _models[operation];
    return _mapList(values);
  }

  Future<String?> _chooseModel({
    required String title,
    required String description,
    required String operation,
  }) async {
    final models = _modelOptions(operation);
    if (models.isEmpty) {
      if (mounted) AdminFeedback.error(context, '没有可用于本操作的模型');
      return null;
    }
    var selected = models
        .firstWhere(
          (model) => model['isDefault'] == true,
          orElse: () => models.first,
        )['profileId']
        ?.toString();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(description),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: '模型',
                    prefixIcon: Icon(Icons.model_training),
                  ),
                  items: models
                      .map(
                        (model) => DropdownMenuItem<String>(
                          value: model['profileId']?.toString(),
                          child: Text(
                            model['displayName']?.toString() ??
                                model['modelId']?.toString() ??
                                '未命名模型',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => selected = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: const Text('继续'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_ArticleGenerationChoice?> _chooseArticleGeneration({
    required String title,
    required String description,
  }) async {
    final models = _modelOptions('article');
    if (models.isEmpty) {
      if (mounted) AdminFeedback.error(context, '没有可用于文章生成的模型');
      return null;
    }
    final saved = await StorageService.getLastArticleGenerationChoice();
    if (!mounted) return null;
    var profileId =
        models.any(
          (model) => model['profileId']?.toString() == saved['profileId'],
        )
        ? saved['profileId']
        : models
              .firstWhere(
                (model) => model['isDefault'] == true,
                orElse: () => models.first,
              )['profileId']
              ?.toString();
    var reasoningEffort =
        const {
          'low',
          'medium',
          'high',
          'xhigh',
        }.contains(saved['reasoningEffort'])
        ? saved['reasoningEffort']!
        : 'high';
    return showDialog<_ArticleGenerationChoice>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(description),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: profileId,
                  decoration: const InputDecoration(
                    labelText: '模型',
                    prefixIcon: Icon(Icons.model_training),
                  ),
                  items: models
                      .map(
                        (model) => DropdownMenuItem<String>(
                          value: model['profileId']?.toString(),
                          child: Text(
                            model['displayName']?.toString() ??
                                model['modelId']?.toString() ??
                                '',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => profileId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reasoningEffort,
                  decoration: const InputDecoration(
                    labelText: '思考级别',
                    prefixIcon: Icon(Icons.psychology_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('低')),
                    DropdownMenuItem(value: 'medium', child: Text('中')),
                    DropdownMenuItem(value: 'high', child: Text('高')),
                    DropdownMenuItem(value: 'xhigh', child: Text('极高')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => reasoningEffort = value ?? 'high'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: profileId == null
                  ? null
                  : () async {
                      await StorageService.saveLastArticleGenerationChoice(
                        profileId!,
                        reasoningEffort,
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(
                          dialogContext,
                          _ArticleGenerationChoice(profileId!, reasoningEffort),
                        );
                      }
                    },
              child: const Text('继续'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pollDraft(int jobId) async {
    try {
      for (var attempt = 0; attempt < 60; attempt++) {
        final job = await widget.api.codexCreatorDraftJob(jobId);
        final status = job['status']?.toString() ?? '';
        if (status == 'DRAFT_CREATED') {
          await _showDraftCompleted(job);
          return;
        }
        if (status == 'FAILED') {
          throw Exception(job['error']?.toString() ?? '草稿生成失败');
        }
        if (attempt < 59) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      throw Exception('草稿生成等待超时，可稍后在任务状态中继续查询');
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('草稿任务未完成：$error')),
        );
      }
    }
  }

  Future<void> _showDraftCompleted(Map<String, dynamic> job) async {
    final postId = _intValue(job['postId']);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('草稿已生成'),
        content: Text(
          postId == null
              ? 'Codex Creator 已完成文章生成，WindBlog 草稿正在同步。'
              : '草稿已保存为文章 #$postId，状态仍为草稿，可以继续编辑。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('稍后查看'),
          ),
          if (postId != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_openPostEditor(postId));
              },
              icon: const Icon(Icons.edit),
              label: const Text('进入文章编辑器'),
            ),
        ],
      ),
    );
    await Future.wait([_load(), _loadAssignedTopics()]);
  }

  Future<void> _openPostEditor(int postId) async {
    try {
      final detail = await widget.api.postDetail(postId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostEditorPage(detail: detail, api: widget.api),
        ),
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('打开文章编辑器失败：$error')),
        );
      }
    }
  }

  Future<void> _showSources(Map<String, dynamic> topic) async {
    final source = _mapValue(topic['source']);
    final sources = _mapList(source['sources']);
    final queries = (source['queries'] as List<dynamic>? ?? [])
        .map((value) => value.toString())
        .toList();
    final webSearchItems = source['webSearchItems'];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('来源与检索证据'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (queries.isNotEmpty) ...[
                  const Text(
                    '检索查询',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(queries.join('\n')),
                  const SizedBox(height: 16),
                ],
                const Text(
                  '来源 URL',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                if (sources.isEmpty)
                  const Text('没有保存有效来源 URL')
                else
                  ...sources.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SelectableText(
                        '${item['title'] ?? ''}\n${item['url'] ?? ''}',
                      ),
                    ),
                  ),
                if (webSearchItems != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'webSearch 事件',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(_compactJson(webSearchItems)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topicPages = _topicTotal == 0
        ? 1
        : ((_topicTotal + _topicPageSize - 1) ~/ _topicPageSize);
    final assignedPages = _assignedTotal == 0
        ? 1
        : ((_assignedTotal + _assignedPageSize - 1) ~/ _assignedPageSize);
    Widget? footer;
    if (_activeTabIndex == 0) {
      footer = PaginationBar(
        currentPage: _topicPage.clamp(1, topicPages),
        totalPages: topicPages,
        totalItems: _topicTotal,
        pageSize: _topicPageSize,
        onPageChanged: _changeTopicPage,
      );
    } else if (_activeTabIndex == 1) {
      footer = PaginationBar(
        currentPage: _assignedPage.clamp(1, assignedPages),
        totalPages: assignedPages,
        totalItems: _assignedTotal,
        pageSize: _assignedPageSize,
        onPageChanged: _changeAssignedPage,
      );
    }

    return AdminPageScaffold(
      title: '话题',
      actions: [
        IconButton(
          onPressed: _loading || _assignedLoading ? null : _refresh,
          icon: const Icon(Icons.refresh),
          tooltip: '刷新话题',
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                const Tab(icon: Icon(Icons.lightbulb_outline), text: '话题列表'),
                Tab(
                  icon: const Icon(Icons.assignment_outlined),
                  text: _assignedTotal == 0
                      ? '已指派任务'
                      : '已指派任务（$_assignedTotal）',
                ),
                const Tab(icon: Icon(Icons.settings_outlined), text: '设置与记录'),
              ],
            ),
          ),
          if (_loading || _assignedLoading)
            const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabScroll([_buildTopicsCard()]),
                _buildAssignedTab(),
                _buildTabScroll([
                  _buildAutomationCard(),
                  const SizedBox(height: 16),
                  _buildPromotionCard(),
                  const SizedBox(height: 16),
                  _buildSeedsCard(),
                  const SizedBox(height: 16),
                  _buildRunsCard(),
                  const SizedBox(height: 16),
                  _buildBoundaryCard(),
                ]),
              ],
            ),
          ),
        ],
      ),
      footer: footer,
    );
  }

  Widget _buildTabScroll(List<Widget> children) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: AdminBreakpoints.pagePadding(context)),
        children: [
          if (_error != null) ...[
            AlertBanner(message: _error!, type: AlertType.error),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _buildAssignedTab() {
    return _buildTabScroll([
      Card(
        child: Padding(
          padding: EdgeInsets.all(AdminBreakpoints.isPhone(context) ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader(
                '已指派任务',
                '这里集中显示正在写作和已经生成草稿的主题任务。生成后的文章仍需人工编辑和发布。',
                icon: Icons.assignment_outlined,
                action: OutlinedButton.icon(
                  onPressed: _assignedLoading ? null : _loadAssignedTopics,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新任务'),
                ),
              ),
              const SizedBox(height: 12),
              if (_assignedTopics.isEmpty && !_assignedLoading)
                const Text('暂无已指派任务。请在“话题列表”中指派一个主题。')
              else
                ..._assignedTopics.map(_assignedTopicCard),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _assignedTopicCard(Map<String, dynamic> topic) {
    final status = topic['status']?.toString() ?? 'WRITING';
    final source = _mapValue(topic['source']);
    final sourceCount = _mapList(source['sources']).length;
    final error = topic['articleError']?.toString().trim() ?? '';
    final execution = _mapValue(topic['execution']);
    final message = switch (status) {
      'DRAFT_CREATED' => '草稿已生成并保存，可在文章管理中继续编辑。',
      'FAILED' => error.isEmpty ? '草稿生成失败，可调整模型后重新生成。' : '草稿生成失败：$error',
      _ => 'Codex 正在生成草稿，请稍后刷新任务。',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    topic['title']?.toString() ?? '-',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            Text(message),
            if (execution.isNotEmpty) ...[
              const SizedBox(height: 8),
              _executionTimeline(execution),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('来源 $sourceCount 个'),
                Text('出现 ${topic['occurrenceCount'] ?? 1} 次'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSources(topic),
                  icon: const Icon(Icons.source_outlined),
                  label: const Text('来源详情'),
                ),
                if (status == 'DRAFT_CREATED')
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : () => _regenerateDraft(topic),
                    icon: const Icon(Icons.autorenew),
                    label: const Text('重新生成'),
                  ),
                if (status == 'FAILED')
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : () => _assignDraft(topic),
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试生成'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationCard() {
    final settings = _mapValue(_automation?['settings']);
    final enabled = settings['enabled'] == true;
    final interval = _intValue(settings['intervalMinutes']) ?? 360;
    final maxSeeds = _intValue(settings['maxSeedsPerRun']) ?? 5;
    final maxTopics = _intValue(settings['maxTopicsPerRun']) ?? 20;
    final nextRun = settings['nextRunAt']?.toString() ?? '';
    final lastError = settings['lastError']?.toString() ?? '';
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AdminBreakpoints.isPhone(context) ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              '主题自动化',
              '默认关闭。手动立即运行不会改变定时开关；每次运行只使用启用的主题查询种子。',
              icon: Icons.schedule,
              action: FilledButton.icon(
                onPressed: _saving ? null : _runNow,
                icon: const Icon(Icons.play_arrow),
                label: const Text('立即运行'),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用固定周期自动搜索'),
              subtitle: const Text('调度器会在服务端使用 Redis 锁和数据库幂等键避免多实例重复执行。'),
              value: enabled,
              onChanged: _saving
                  ? null
                  : (value) => _updateAutomationValue(
                      enabled: value,
                      intervalMinutes: interval,
                      maxSeedsPerRun: maxSeeds,
                      maxTopicsPerRun: maxTopics,
                    ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int>(
                    initialValue: interval,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '搜索周期',
                      prefixIcon: Icon(Icons.timelapse),
                    ),
                    items: const [60, 360, 720, 1440]
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text(_intervalLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => _updateAutomationValue(
                            enabled: enabled,
                            intervalMinutes: value ?? interval,
                            maxSeedsPerRun: maxSeeds,
                            maxTopicsPerRun: maxTopics,
                          ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int>(
                    initialValue: maxSeeds,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '每次查询种子数',
                      prefixIcon: Icon(Icons.search),
                    ),
                    items: const [1, 3, 5, 10, 20]
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value 个'),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => _updateAutomationValue(
                            enabled: enabled,
                            intervalMinutes: interval,
                            maxSeedsPerRun: value ?? maxSeeds,
                            maxTopicsPerRun: maxTopics,
                          ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int>(
                    initialValue: maxTopics,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '每次主题数上限',
                      prefixIcon: Icon(Icons.topic),
                    ),
                    items: const [5, 10, 20, 30, 50]
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value 个'),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => _updateAutomationValue(
                            enabled: enabled,
                            intervalMinutes: interval,
                            maxSeedsPerRun: maxSeeds,
                            maxTopicsPerRun: value ?? maxTopics,
                          ),
                  ),
                ),
              ],
            ),
            if (nextRun.isNotEmpty || lastError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${nextRun.isEmpty ? '' : '下次运行：$nextRun'}${lastError.isEmpty ? '' : '\n最近错误：$lastError'}',
                style: TextStyle(
                  color: lastError.isEmpty ? Colors.grey.shade700 : Colors.red,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveAutomation,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('保存自动化设置'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateAutomationValue({
    required bool enabled,
    required int intervalMinutes,
    required int maxSeedsPerRun,
    required int maxTopicsPerRun,
  }) {
    setState(() {
      _automation = {
        ...?_automation,
        'settings': {
          ..._mapValue(_automation?['settings']),
          'enabled': enabled,
          'intervalMinutes': intervalMinutes,
          'maxSeedsPerRun': maxSeedsPerRun,
          'maxTopicsPerRun': maxTopicsPerRun,
        },
      };
    });
  }

  Future<void> _editPromotion() async {
    final settings = _mapValue(_automation?['settings']);
    final controller = TextEditingController(
      text: settings['promotionMarkdown']?.toString() ?? '',
    );
    var enabled = settings['promotionEnabled'] == true;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('营销推广内容'),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('在 AI 草稿中启用软植入'),
                  subtitle: const Text('文章仍须以真实信息、出处和读者价值为先。'),
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 7,
                  maxLines: 14,
                  maxLength: 8000,
                  decoration: const InputDecoration(
                    labelText: '推广内容（支持 Markdown）',
                    alignLabelWithHint: true,
                    hintText: '说明产品/服务适用场景、真实能力、限制与链接。AI 会仅在确有帮助的位置自然嵌入一次。',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'promotionEnabled': enabled,
                'promotionMarkdown': controller.text.trim(),
              }),
              child: const Text('保存并应用'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _automation = {
        ...?_automation,
        'settings': {...settings, ...result},
      };
    });
    // The dialog action is presented as applying the promotion settings. Save
    // them immediately so a refresh or navigation cannot discard the in-memory
    // edit before the separate automation-settings button is pressed.
    await _saveAutomation();
  }

  Widget _buildPromotionCard() {
    final settings = _mapValue(_automation?['settings']);
    final enabled = settings['promotionEnabled'] == true;
    final content = settings['promotionMarkdown']?.toString().trim() ?? '';
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AdminBreakpoints.isPhone(context) ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              '营销推广',
              '为新生成的草稿提供可复用的推广背景。系统要求正文围绕真实读者问题展开，保留限制、替代方案和可核验依据，避免硬广；编辑后请点击上方“保存自动化设置”。',
              icon: Icons.campaign_outlined,
              action: OutlinedButton.icon(
                onPressed: _saving ? null : _editPromotion,
                icon: const Icon(Icons.edit_outlined),
                label: Text(enabled ? '编辑推广内容' : '设置推广内容'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              enabled
                  ? (content.isEmpty
                        ? '已启用，但尚未填写推广内容。保存时会被拒绝。'
                        : '已启用：每篇新草稿会在合适位置自然嵌入一次。')
                  : '未启用；生成文章不会加入推广内容。',
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                content.length > 240
                    ? '${content.substring(0, 240)}…'
                    : content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeedsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AdminBreakpoints.isPhone(context) ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              '主题查询池',
              '每个种子包含名称、检索语句、语言和地区；服务端会保存本次运行使用的快照。',
              icon: Icons.manage_search,
              action: FilledButton.icon(
                onPressed: _saving ? null : () => _editSeed(),
                icon: const Icon(Icons.add),
                label: const Text('新增种子'),
              ),
            ),
            const SizedBox(height: 12),
            if (_seeds.isEmpty)
              const Text('还没有主题查询种子，请先新增一个。')
            else
              ..._seeds.map(
                (seed) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      seed['enabled'] == true
                          ? Icons.check_circle
                          : Icons.pause_circle,
                      color: seed['enabled'] == true
                          ? Colors.green
                          : Colors.grey,
                    ),
                    title: Text(seed['name']?.toString() ?? '-'),
                    subtitle: Text(
                      '${seed['query'] ?? '-'}\n'
                      '${seed['language'] ?? 'zh-CN'}${seed['region'] == null ? '' : ' · ${seed['region']}'}',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 2,
                      children: [
                        IconButton(
                          onPressed: _saving ? null : () => _editSeed(seed),
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: '编辑',
                        ),
                        IconButton(
                          onPressed: _saving ? null : () => _deleteSeed(seed),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: '删除',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicsCard() {
    final topicGroups = _groupedTopics();
    final seedTabs = topicGroups.entries
        .map((entry) => (name: entry.key, topics: entry.value))
        .toList();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AdminBreakpoints.isPhone(context) ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              '主题池',
              '重复标题只合并来源和出现次数，不覆盖人工审核状态。来源详情包含保存的 URL 与 webSearch 证据。',
              icon: Icons.lightbulb_outline,
              action: SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  initialValue: _topicStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '状态'),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('全部')),
                    DropdownMenuItem(value: 'SUGGESTED', child: Text('待审核')),
                    DropdownMenuItem(value: 'APPROVED', child: Text('已批准')),
                    DropdownMenuItem(value: 'WRITING', child: Text('写作中')),
                    DropdownMenuItem(
                      value: 'DRAFT_CREATED',
                      child: Text('已生成草稿'),
                    ),
                    DropdownMenuItem(value: 'FAILED', child: Text('生成失败')),
                    DropdownMenuItem(value: 'DISMISSED', child: Text('已忽略')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _topicStatus = value;
                            _topicPage = 1;
                          });
                          unawaited(_load());
                        },
                ),
              ),
            ),
            if (_pollingMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _pollingMessage!,
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
            const SizedBox(height: 12),
            if (_topics.isEmpty && !_loading && topicGroups.isEmpty)
              const Text('还没有主题。可以先配置查询种子，再手动运行一次全网搜索。')
            else if (seedTabs.isEmpty)
              const Text('正在刷新主题分组，请稍后重试。')
            else
              _TopicHorizontalTabs(
                items: seedTabs,
                labelBuilder: (item) => item.name,
                childBuilder: (item) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.travel_explore, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...item.topics.map(_topicCard),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupedTopics() {
    final seedById = <int, Map<String, dynamic>>{
      for (final seed in _seeds)
        if (_intValue(seed['id']) case final int id) id: seed,
    };
    final seedIdByQuery = <String, int>{
      for (final entry in seedById.entries)
        if ((entry.value['query']?.toString().trim() ?? '').isNotEmpty)
          entry.value['query'].toString().trim(): entry.key,
    };
    final groupedById = <int, List<Map<String, dynamic>>>{};
    final ungrouped = <Map<String, dynamic>>[];
    for (final topic in _topics) {
      final source = _mapValue(topic['source']);
      final ids = <int>{};
      for (final seed in _mapList(source['seeds'])) {
        final id = _intValue(seed['id']);
        if (id != null && seedById.containsKey(id)) ids.add(id);
      }
      final primaryId = _intValue(_mapValue(source['primarySeed'])['id']);
      if (primaryId != null && seedById.containsKey(primaryId)) {
        ids.add(primaryId);
      }
      if (ids.isEmpty) {
        for (final query in (source['queries'] as List<dynamic>? ?? const [])) {
          final id = seedIdByQuery[query.toString().trim()];
          if (id != null) ids.add(id);
        }
      }
      if (ids.isEmpty) {
        ungrouped.add(topic);
      } else {
        for (final id in ids) {
          groupedById.putIfAbsent(id, () => []).add(topic);
        }
      }
    }
    final result = <String, List<Map<String, dynamic>>>{};
    for (final seed in _seeds) {
      final id = _intValue(seed['id']);
      final topics = id == null ? null : groupedById[id];
      result[seed['name']?.toString() ??
              seed['query']?.toString() ??
              '种子 #$id'] =
          topics ?? <Map<String, dynamic>>[];
    }
    if (ungrouped.isNotEmpty) result['历史或未归类'] = ungrouped;
    return result;
  }

  Widget _topicCard(Map<String, dynamic> topic) {
    final status = topic['status']?.toString() ?? 'SUGGESTED';
    final articleJobStatus = topic['articleJobStatus']?.toString() ?? '';
    final generationFailed = status == 'FAILED' || articleJobStatus == 'FAILED';
    final source = _mapValue(topic['source']);
    final sourceCount = _mapList(source['sources']).length;
    final keywords = (source['keywords'] as List<dynamic>? ?? [])
        .map((value) => value.toString())
        .take(12)
        .toList();
    final canReview = status == 'SUGGESTED' || status == 'APPROVED';
    final execution = _mapValue(topic['execution']);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    topic['title']?.toString() ?? '-',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            Text(topic['rationale']?.toString() ?? '暂无理由'),
            if (execution.isNotEmpty) ...[
              const SizedBox(height: 8),
              _executionTimeline(execution),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('推荐：${topic['recommendation'] ?? '-'}'),
                Text('出现 ${topic['occurrenceCount'] ?? 1} 次'),
                Text('来源 $sourceCount 个'),
                if (keywords.isNotEmpty) Text('关键词：${keywords.join('、')}'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSources(topic),
                  icon: const Icon(Icons.source_outlined),
                  label: const Text('来源详情'),
                ),
                if (generationFailed)
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : () => _assignDraft(topic),
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新生成'),
                  ),
                if (canReview)
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _reviewTopic(topic, 'APPROVE'),
                    icon: const Icon(Icons.check),
                    label: const Text('批准'),
                  ),
                if (canReview)
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _reviewTopic(topic, 'DISMISS'),
                    icon: const Icon(Icons.close),
                    label: const Text('忽略'),
                  ),
                if (canReview)
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _assignDraft(topic),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('指派并生成草稿'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _executionTimeline(Map<String, dynamic> execution) {
    final events = _mapList(execution['events']);
    final attempts = _mapList(execution['attempts']);
    final latestEvents = events.reversed.take(5).toList().reversed;
    final attemptCount =
        _intValue(execution['attemptCount']) ?? attempts.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '执行过程${attemptCount == 0 ? '' : ' · 第 $attemptCount 次尝试'}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 5),
            if (latestEvents.isEmpty)
              const Text('任务已排队，等待 Codex 开始执行。')
            else
              ...latestEvents.map((event) {
                final message = event['message']?.toString() ?? '正在执行';
                final query = event['query']?.toString().trim() ?? '';
                final at = event['at']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '• $message${query.isEmpty ? '' : '：$query'}${at.isEmpty ? '' : '（$at）'}',
                  ),
                );
              }),
            if ((execution['error']?.toString().trim() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  '最近错误：${execution['error']}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunsCard() {
    final runPages = _runTotal == 0
        ? 1
        : ((_runTotal + _runPageSize - 1) ~/ _runPageSize);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AdminBreakpoints.isPhone(context) ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              '运行记录',
              '记录手动/定时触发、任务编号、来源统计和失败原因。共 $_runTotal 条，当前第 $_runPage / $runPages 页。',
              icon: Icons.history,
              action: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    onPressed: _runPage <= 1 || _loading
                        ? null
                        : () {
                            setState(() => _runPage--);
                            unawaited(_load());
                          },
                    icon: const Icon(Icons.chevron_left),
                    tooltip: '上一页运行记录',
                  ),
                  IconButton(
                    onPressed: _runPage >= runPages || _loading
                        ? null
                        : () {
                            setState(() => _runPage++);
                            unawaited(_load());
                          },
                    icon: const Icon(Icons.chevron_right),
                    tooltip: '下一页运行记录',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_runs.isEmpty)
              const Text('暂无运行记录。')
            else
              ..._runs.map(
                (run) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _runIcon(run['status']?.toString() ?? ''),
                  title: Text(
                    '${run['trigger'] ?? '-'} · ${run['status'] ?? '-'}',
                  ),
                  subtitle: Text(
                    '主题 ${run['topicCount'] ?? 0} 个 · 种子 ${run['seedCount'] ?? 0} 个'
                    '${run['taskId'] == null ? '' : ' · 任务 #${run['taskId']}'}\n'
                    '${run['error']?.toString().isNotEmpty == true ? run['error'] : (run['createdAt'] ?? '')}',
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoundaryCard() {
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.secondaryContainer.withValues(alpha: 0.35),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          '说明：主题搜索只保存标题、理由、关键词、来源 URL 和检索证据，不保存整页网页内容；文章只有管理员在本页确认后才会生成，生成结果始终是 DRAFT。浏览器不会接触 Codex Creator 管理 token，父子服务之间继续使用签名内部请求。',
        ),
      ),
    );
  }

  Widget _sectionHeader(
    String title,
    String description, {
    required IconData icon,
    Widget? action,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (action != null) ...[
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: action),
        ],
      ],
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'APPROVED' => Colors.blue,
      'DISMISSED' => Colors.grey,
      'WRITING' => Colors.orange,
      'DRAFT_CREATED' => Colors.green,
      'FAILED' => Colors.red,
      _ => Colors.deepPurple,
    };
    return Chip(
      label: Text(_statusLabel(status)),
      labelStyle: TextStyle(color: color, fontSize: 12),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _runIcon(String status) {
    final color = switch (status) {
      'SUCCEEDED' => Colors.green,
      'FAILED' => Colors.red,
      'RUNNING' => Colors.blue,
      _ => Colors.orange,
    };
    return Icon(Icons.circle, color: color, size: 14);
  }

  static String _statusLabel(String status) => switch (status) {
    'SUGGESTED' => '待审核',
    'APPROVED' => '已批准',
    'DISMISSED' => '已忽略',
    'WRITING' => '写作中',
    'DRAFT_CREATED' => '已生成草稿',
    'SUCCEEDED' => '成功',
    'FAILED' => '失败',
    'RUNNING' => '运行中',
    'QUEUED' => '排队中',
    _ => status,
  };

  static String _intervalLabel(int minutes) {
    if (minutes >= 1440) return '每天（24 小时）';
    if (minutes >= 60) return '每 ${minutes ~/ 60} 小时';
    return '每 $minutes 分钟';
  }

  static Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map(_mapValue).toList();
  }

  static int? _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _compactJson(Object value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }
}

/// Displays one seed at a time while keeping all seed choices in a compact
/// horizontal strip; topics within the selected seed remain vertically listed.
class _TopicHorizontalTabs<T> extends StatefulWidget {
  const _TopicHorizontalTabs({
    required this.items,
    required this.labelBuilder,
    required this.childBuilder,
  });

  final List<T> items;
  final String Function(T item) labelBuilder;
  final Widget Function(T item) childBuilder;

  @override
  State<_TopicHorizontalTabs<T>> createState() =>
      _TopicHorizontalTabsState<T>();
}

class _TopicHorizontalTabsState<T> extends State<_TopicHorizontalTabs<T>>
    with TickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: widget.items.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _TopicHorizontalTabs<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      final oldIndex = _controller.index;
      _controller.dispose();
      _controller = TabController(
        length: widget.items.length,
        vsync: this,
        initialIndex: oldIndex.clamp(0, widget.items.length - 1),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          tabs: [
            for (final item in widget.items)
              Tab(text: widget.labelBuilder(item)),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final selectedIndex = _controller.index.clamp(
              0,
              widget.items.length - 1,
            );
            return widget.childBuilder(widget.items[selectedIndex]);
          },
        ),
      ],
    );
  }
}

class _TopicSeedDialog extends StatefulWidget {
  const _TopicSeedDialog({this.seed});

  final Map<String, dynamic>? seed;

  @override
  State<_TopicSeedDialog> createState() => _TopicSeedDialogState();
}

class _TopicSeedDialogState extends State<_TopicSeedDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _queryController;
  late final TextEditingController _languageController;
  late final TextEditingController _regionController;
  late final TextEditingController _sortOrderController;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final seed = widget.seed ?? const <String, dynamic>{};
    _nameController = TextEditingController(
      text: seed['name']?.toString() ?? '',
    );
    _queryController = TextEditingController(
      text: seed['query']?.toString() ?? '',
    );
    _languageController = TextEditingController(
      text: seed['language']?.toString() ?? 'zh-CN',
    );
    _regionController = TextEditingController(
      text: seed['region']?.toString() ?? '',
    );
    _sortOrderController = TextEditingController(
      text: seed['sortOrder']?.toString() ?? '0',
    );
    _enabled = seed['enabled'] != false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _queryController.dispose();
    _languageController.dispose();
    _regionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final query = _queryController.text.trim();
    if (name.isEmpty || query.isEmpty) {
      setState(() {});
      return;
    }
    Navigator.pop(context, {
      'name': name,
      'query': query,
      'language': _languageController.text.trim().isEmpty
          ? 'zh-CN'
          : _languageController.text.trim(),
      'region': _regionController.text.trim().isEmpty
          ? null
          : _regionController.text.trim(),
      'enabled': _enabled,
      'sortOrder': int.tryParse(_sortOrderController.text.trim()) ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.seed == null ? '新增主题查询种子' : '编辑主题查询种子'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _queryController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '搜索查询',
                  hintText: '例如：AI 编程工具 最新进展',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _languageController,
                      decoration: const InputDecoration(labelText: '语言'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _regionController,
                      decoration: const InputDecoration(labelText: '地区（可选）'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sortOrderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '排序'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用'),
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
                  ),
                ],
              ),
              if (_nameController.text.trim().isEmpty ||
                  _queryController.text.trim().isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '名称和搜索查询不能为空',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

class _DraftRequest {
  const _DraftRequest({
    required this.language,
    required this.instructions,
    required this.profileId,
    required this.reasoningEffort,
    required this.repostPolicyCode,
    required this.practicalVerification,
    required this.testServerIds,
  });

  final String language;
  final String instructions;
  final String profileId;
  final String reasoningEffort;
  final String repostPolicyCode;
  final bool practicalVerification;
  final List<int> testServerIds;
}

class _ArticleGenerationChoice {
  const _ArticleGenerationChoice(this.profileId, this.reasoningEffort);

  final String profileId;
  final String reasoningEffort;
}

class _DraftRequestDialog extends StatefulWidget {
  const _DraftRequestDialog({
    required this.models,
    required this.servers,
    required this.policies,
  });

  final List<Map<String, dynamic>> models;
  final List<Map<String, dynamic>> servers;
  final List<RepostPolicyItem> policies;

  @override
  State<_DraftRequestDialog> createState() => _DraftRequestDialogState();
}

class _DraftRequestDialogState extends State<_DraftRequestDialog> {
  late final TextEditingController _languageController;
  late final TextEditingController _instructionsController;
  String? _profileId;
  String _reasoningEffort = 'high';
  String _repostPolicyCode = RepostPolicyItem.defaultCode;
  String? _error;
  bool _practicalVerification = false;
  final Set<int> _testServerIds = {};

  @override
  void initState() {
    super.initState();
    _languageController = TextEditingController(text: 'zh-CN');
    _instructionsController = TextEditingController();
    if (widget.models.isNotEmpty) {
      _profileId = widget.models
          .firstWhere(
            (model) => model['isDefault'] == true,
            orElse: () => widget.models.first,
          )['profileId']
          ?.toString();
    }
    _restoreLastGenerationChoice();
  }

  Future<void> _restoreLastGenerationChoice() async {
    final saved = await StorageService.getLastArticleGenerationChoice();
    if (!mounted) return;
    final savedProfileId = saved['profileId'];
    final exists = widget.models.any(
      (model) => model['profileId']?.toString() == savedProfileId,
    );
    setState(() {
      if (exists) _profileId = savedProfileId;
      final savedEffort = saved['reasoningEffort'];
      if (const {'low', 'medium', 'high', 'xhigh'}.contains(savedEffort)) {
        _reasoningEffort = savedEffort!;
      }
      final savedPolicy = saved['repostPolicyCode'];
      if (widget.policies.any((policy) => policy.code == savedPolicy)) {
        _repostPolicyCode = savedPolicy!;
      } else if (widget.policies.any(
        (policy) => policy.code == RepostPolicyItem.defaultCode,
      )) {
        _repostPolicyCode = RepostPolicyItem.defaultCode;
      }
    });
  }

  @override
  void dispose() {
    _languageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _submit() {
    final language = _languageController.text.trim();
    if (language.isEmpty) {
      setState(() => _error = '请填写文章语言');
      return;
    }
    if (_profileId == null) {
      setState(() => _error = '请选择生成模型');
      return;
    }
    if (_practicalVerification && _testServerIds.isEmpty) {
      setState(() => _error = '请选择至少一台验证用服务器');
      return;
    }
    StorageService.saveLastArticleGenerationChoice(
      _profileId!,
      _reasoningEffort,
      _repostPolicyCode,
    );
    Navigator.pop(
      context,
      _DraftRequest(
        language: language,
        instructions: _instructionsController.text.trim(),
        profileId: _profileId!,
        reasoningEffort: _reasoningEffort,
        repostPolicyCode: _repostPolicyCode,
        practicalVerification: _practicalVerification,
        testServerIds: _testServerIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('指派并生成文章草稿'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('分类由 Codex 自动选择或创建；如果没有合适分类，将归入“未分类”。'),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('需要实操验证'),
                subtitle: const Text('让 Codex 在验证用服务器执行命令，并将脱敏的真实结果自然写入文章。'),
                value: _practicalVerification,
                onChanged: (value) =>
                    setState(() => _practicalVerification = value),
              ),
              if (_practicalVerification) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('验证用服务器（可多选）'),
                ),
                if (widget.servers
                    .where((server) => server['enabled'] == true)
                    .isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '暂无可用服务器，请先到 Codex Creator 添加。',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ...widget.servers.where((server) => server['enabled'] == true).map((
                  server,
                ) {
                  final id = int.tryParse(server['id']?.toString() ?? '');
                  if (id == null) return const SizedBox.shrink();
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _testServerIds.contains(id),
                    title: Text(server['name']?.toString() ?? '未命名服务器'),
                    subtitle: Text(
                      '${server['sshUser'] ?? 'root'}@${server['host']}:${server['sshPort'] ?? 22}',
                    ),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _testServerIds.add(id);
                      } else {
                        _testServerIds.remove(id);
                      }
                    }),
                  );
                }),
              ],
              TextField(
                controller: _languageController,
                decoration: const InputDecoration(
                  labelText: '文章语言',
                  hintText: 'zh-CN',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('article-repost-policy-$_repostPolicyCode'),
                initialValue: _repostPolicyCode,
                decoration: const InputDecoration(
                  labelText: '转载协议',
                  prefixIcon: Icon(Icons.copyright_outlined),
                ),
                items: widget.policies
                    .map(
                      (policy) => DropdownMenuItem<String>(
                        value: policy.code,
                        child: Text(policy.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _repostPolicyCode = value ?? RepostPolicyItem.defaultCode;
                }),
              ),
              Builder(
                builder: (context) {
                  final policy = widget.policies.firstWhere(
                    (item) => item.code == _repostPolicyCode,
                    orElse: () => widget.policies.first,
                  );
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        policy.summary,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('article-model-$_profileId'),
                initialValue: _profileId,
                decoration: const InputDecoration(
                  labelText: '生成模型',
                  prefixIcon: Icon(Icons.model_training),
                ),
                items: widget.models
                    .map(
                      (model) => DropdownMenuItem<String>(
                        value: model['profileId']?.toString(),
                        child: Text(
                          model['displayName']?.toString() ??
                              model['modelId']?.toString() ??
                              '未命名模型',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _profileId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('article-effort-$_reasoningEffort'),
                initialValue: _reasoningEffort,
                decoration: const InputDecoration(
                  labelText: '思考级别',
                  prefixIcon: Icon(Icons.psychology_alt_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('低：更快')),
                  DropdownMenuItem(value: 'medium', child: Text('中：平衡')),
                  DropdownMenuItem(value: 'high', child: Text('高：更深入')),
                  DropdownMenuItem(value: 'xhigh', child: Text('极高：最深入')),
                ],
                onChanged: (value) =>
                    setState(() => _reasoningEffort = value ?? 'high'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instructionsController,
                maxLines: 5,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: '写作要求（可选）',
                  hintText: '例如：面向开发者，保留引用来源，使用小标题。',
                ),
              ),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('开始生成'),
        ),
      ],
    );
  }
}
