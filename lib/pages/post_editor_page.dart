part of 'package:windblog_admin_flutter/main.dart';

class PostEditorPage extends StatefulWidget {
  const PostEditorPage({super.key, PostDetail? detail, required this.api})
    : _detail = detail;

  final PostDetail? _detail;
  final AdminApiClient api;

  PostDetail? get detail => _detail;

  @override
  State<PostEditorPage> createState() => _PostEditorPageState();
}

class _PostEditorPageState extends State<PostEditorPage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController slugCtrl;
  late final TextEditingController titleCtrl;
  late final TextEditingController summaryCtrl;
  late TextEditingController contentCtrl;
  late final TextEditingController pointsPriceCtrl;
  late final TextEditingController freeLinesCtrl;
  late final TextEditingController passwordCtrl;
  late final TabController _sidebarTabController;
  final ScrollController _contentScrollController = SmoothScrollController();

  int status = 0;
  int visibility = 0;
  int renderType = 0;
  int editorType = 0;
  int aiSummaryStatus = 0;
  Map<String, String> aiSummary = {};
  Map<String, String> _titles = {};
  Map<String, String> _summaries = {};
  Map<String, String> _contents = {};

  int? categoryId;
  List<int> tagIds = [];
  List<String> visibilityRegions = [];
  List<String> contentDeclarations = [];
  String repostPolicyCode = RepostPolicyItem.defaultCode;
  List<CategoryItem> _categories = [];
  List<TagItem> _tags = [];
  List<RepostPolicyItem> _repostPolicies = [];
  bool _isLoadingRepostPolicies = false;
  List<PostRevisionItem> _revisions = [];
  bool _isLoadingRevisions = false;

  bool _isDirty = false;
  bool _isSaving = false;

  String? _initialSlug;
  String? _initialTitle;
  String? _initialSummary;
  String? _initialContent;
  int? _initialStatus;
  int? _initialVisibility;
  int? _initialRenderType;
  int? _initialEditorType;
  int? _initialAiSummaryStatus;
  int? _initialCategoryId;
  List<int>? _initialTagIds;
  List<String>? _initialVisibilityRegions;
  List<String>? _initialContentDeclarations;
  String? _initialRepostPolicyCode;

  PostDetail? _currentDetail;

  @override
  void initState() {
    super.initState();
    _contentScrollController.addListener(_onScroll);
    _currentDetail = widget.detail;
    final d = _currentDetail;
    slugCtrl = TextEditingController(text: d?.slug ?? '');
    titleCtrl = TextEditingController(text: d?.zhTitle ?? '');
    summaryCtrl = TextEditingController(text: d?.zhSummary ?? '');
    _titles = Map<String, String>.from(d?.title ?? {});
    _summaries = Map<String, String>.from(d?.summary ?? {});
    _contents = Map<String, String>.from(d?.contentMarkdown ?? {});
    _titles['zh-cn'] = d?.zhTitle ?? '';
    _summaries['zh-cn'] = d?.zhSummary ?? '';
    status = d?.status ?? 0;
    visibility = d?.visibility ?? 0;
    renderType = d?.renderType ?? 6;
    editorType = d?.editorType ?? 6;

    // 升级旧版 Markdown 为区块化 Markdown
    if (renderType == 0) {
      renderType = 6;
    }
    if (editorType == 0) {
      editorType = 6;
    }

    if (renderType == 1) {
      contentCtrl = HtmlSyntaxController(text: d?.zhContent ?? '');
    } else {
      contentCtrl = MarkdownSyntaxController(text: d?.zhContent ?? '');
    }
    _contents['zh-cn'] = d?.zhContent ?? '';
    aiSummaryStatus = d?.aiSummaryStatus ?? 0;
    pointsPriceCtrl = TextEditingController(
      text: d?.pointsPrice?.toString() ?? '',
    );
    freeLinesCtrl = TextEditingController(text: d?.freeLines?.toString() ?? '');
    passwordCtrl = TextEditingController();
    categoryId = d?.categoryId;
    tagIds = d?.tagIds ?? [];
    visibilityRegions = d?.visibilityRegions ?? [];
    contentDeclarations = List<String>.from(d?.contentDeclarations ?? []);
    repostPolicyCode = d?.repostPolicyCode ?? RepostPolicyItem.defaultCode;

    _initialSlug = d?.slug;
    _initialTitle = d?.zhTitle;
    _initialSummary = d?.zhSummary;
    _initialContent = d?.zhContent;
    _initialStatus = d?.status;
    _initialVisibility = d?.visibility;
    _initialRenderType = d?.renderType;
    _initialEditorType = d?.editorType;
    _initialAiSummaryStatus = d?.aiSummaryStatus;
    _initialCategoryId = d?.categoryId;
    _initialTagIds = d?.tagIds != null ? List<int>.from(d!.tagIds) : null;
    _initialVisibilityRegions = d?.visibilityRegions != null
        ? List<String>.from(d!.visibilityRegions)
        : null;
    _initialContentDeclarations = d?.contentDeclarations != null
        ? List<String>.from(d!.contentDeclarations)
        : null;
    _initialRepostPolicyCode =
        d?.repostPolicyCode ??
        (d == null ? RepostPolicyItem.defaultCode : null);

    _sidebarTabController = TabController(length: 3, vsync: this);

    _loadCategoriesAndTags();
    _loadRepostPolicies();
    if (_currentDetail != null) {
      _loadRevisions();
    }

    titleCtrl.addListener(_onTitleChanged);
    contentCtrl.addListener(_markDirty);
    pointsPriceCtrl.addListener(_markDirty);
    freeLinesCtrl.addListener(_markDirty);
    passwordCtrl.addListener(_markDirty);
  }

  void _onScroll() {
    // No longer hiding title on scroll
  }

  void _onTitleChanged() {
    if (widget.detail == null ||
        _initialSlug == null ||
        _initialSlug!.isEmpty) {
      final newSlug = _generateSlug(titleCtrl.text);
      if (slugCtrl.text != newSlug) {
        slugCtrl.text = newSlug;
      }
    }
    _markDirty();
  }

  String _generateSlug(String title) {
    if (title.isEmpty) return '';
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  bool _checkIfDirty() {
    final d = _currentDetail;
    final currentSlug = slugCtrl.text.trim();
    final currentTitle = titleCtrl.text.trim();
    final currentSummary = summaryCtrl.text.trim();
    final currentContent = contentCtrl.text.trim();

    if (d == null) {
      return currentSlug.isNotEmpty ||
          currentTitle.isNotEmpty ||
          currentSummary.isNotEmpty ||
          currentContent.isNotEmpty ||
          status != 0 ||
          visibility != 0 ||
          passwordCtrl.text.trim().isNotEmpty ||
          categoryId != null ||
          tagIds.isNotEmpty ||
          contentDeclarations.isNotEmpty ||
          repostPolicyCode != RepostPolicyItem.defaultCode;
    }

    return currentSlug != _initialSlug ||
        currentTitle != _initialTitle ||
        currentSummary != _initialSummary ||
        currentContent != _initialContent ||
        status != _initialStatus ||
        visibility != _initialVisibility ||
        passwordCtrl.text.trim().isNotEmpty ||
        renderType != _initialRenderType ||
        editorType != _initialEditorType ||
        aiSummaryStatus != _initialAiSummaryStatus ||
        categoryId != _initialCategoryId ||
        !_listEquals(tagIds, _initialTagIds) ||
        !_listEqualsString(visibilityRegions, _initialVisibilityRegions) ||
        !_listEqualsString(contentDeclarations, _initialContentDeclarations) ||
        repostPolicyCode != _initialRepostPolicyCode;
  }

  bool _listEqualsString(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _listEquals(List<int>? a, List<int>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _loadRevisions() async {
    if (_currentDetail == null) return;
    setState(() => _isLoadingRevisions = true);
    try {
      final revisions = await widget.api.listPostRevisions(_currentDetail!.id);
      if (mounted) {
        setState(() {
          _revisions = revisions;
          _isLoadingRevisions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRevisions = false);
        if (mounted) {
          AdminFeedback.showSnackBar(
            context,
            SnackBar(
              content: Text('${t(context, 'load_revisions_failed')}: $e'),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadCategoriesAndTags() async {
    try {
      final cats = await widget.api.listCategories();
      final tags = await widget.api.listTags();
      if (mounted) {
        setState(() {
          final uniqueCatsMap = <int, CategoryItem>{};
          for (final cat in cats) {
            uniqueCatsMap[cat.id] = cat;
          }
          _categories = uniqueCatsMap.values.toList();
          _tags = tags;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('${t(context, 'load_failed')}: $e')),
        );
      }
    }
  }

  Future<void> _loadRepostPolicies() async {
    _isLoadingRepostPolicies = true;
    try {
      final policies = await widget.api.listRepostPolicies();
      if (!mounted) return;
      setState(() {
        _repostPolicies = policies;
        _isLoadingRepostPolicies = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _repostPolicies = [_fallbackRepostPolicy()];
        _isLoadingRepostPolicies = false;
      });
      AdminFeedback.showSnackBar(
        context,
        SnackBar(
          content: Text('${t(context, 'repost_policy_load_failed')}: $e'),
        ),
      );
    }
  }

  RepostPolicyItem _fallbackRepostPolicy() {
    return const RepostPolicyItem(
      code: RepostPolicyItem.defaultCode,
      name: '转载需申请授权',
      nameEn: 'Repost requires authorization',
      requiresApplication: true,
      summary: '转载需先申请授权，并保留授权码、原文地址和文中 go/affiliate 链接。',
      summaryEn:
          'Request authorization before reposting and retain the authorization code, original URL, and go/affiliate links.',
      conditions: ['转载前需要申请授权', '转载页需保留授权码、原文地址和文中 go/affiliate 链接'],
      conditionsEn: [
        'Authorization is required before reposting',
        'Keep the authorization code, original URL, and go/affiliate links on the reposted page',
      ],
    );
  }

  List<RepostPolicyItem> _policyOptions() {
    final options = List<RepostPolicyItem>.from(_repostPolicies);
    if (options.isEmpty) {
      options.add(_fallbackRepostPolicy());
    }
    if (!options.any((policy) => policy.code == repostPolicyCode)) {
      options.add(
        RepostPolicyItem(
          code: repostPolicyCode,
          name: repostPolicyCode,
          nameEn: repostPolicyCode,
          requiresApplication: true,
          summary: t(context, 'repost_policy_unknown'),
          summaryEn: t(context, 'repost_policy_unknown'),
          conditions: const [],
          conditionsEn: const [],
        ),
      );
    }
    return options;
  }

  String _policyName(RepostPolicyItem policy) {
    return Localizations.localeOf(context).languageCode == 'en'
        ? policy.nameEn
        : policy.name;
  }

  String _policySummary(RepostPolicyItem policy) {
    return Localizations.localeOf(context).languageCode == 'en'
        ? policy.summaryEn
        : policy.summary;
  }

  List<String> _policyConditions(RepostPolicyItem policy) {
    return Localizations.localeOf(context).languageCode == 'en'
        ? policy.conditionsEn
        : policy.conditions;
  }

  @override
  void dispose() {
    _contentScrollController.removeListener(_onScroll);
    _contentScrollController.dispose();
    slugCtrl.dispose();
    titleCtrl.dispose();
    summaryCtrl.dispose();
    contentCtrl.dispose();
    passwordCtrl.dispose();
    pointsPriceCtrl.dispose();
    freeLinesCtrl.dispose();
    _sidebarTabController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_isSaving) return false;
    final isDirty = _checkIfDirty();
    if (!isDirty) return true;

    final navigator = Navigator.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'unsaved_changes')),
        content: Text(t(context, 'unsaved_changes_desc')),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => navigator.pop(true),
            child: Text(t(context, 'dont_save')),
          ),
          FilledButton(
            onPressed: () async {
              final success = await _save();
              if (success) {
                navigator.pop(true);
              }
            },
            child: Text(t(context, 'save')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openTranslationManager() async {
    final detail = _currentDetail;
    if (detail == null) return;

    _titles['zh-cn'] = titleCtrl.text.trim();
    _summaries['zh-cn'] = summaryCtrl.text.trim();
    _contents['zh-cn'] = contentCtrl.text.trim();

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PostTranslationDialog(
        api: widget.api,
        postId: detail.id,
        titles: Map<String, String>.from(_titles),
        summaries: Map<String, String>.from(_summaries),
        contents: Map<String, String>.from(_contents),
      ),
    );
    if (result == null || !mounted) return;

    final language = result['targetLanguage'];
    if (language == null || language.isEmpty) return;
    setState(() {
      _titles[language] = result['title'] ?? '';
      _summaries[language] = result['summary'] ?? '';
      _contents[language] = result['contentMarkdown'] ?? '';
      _isDirty = true;
    });
  }

  Future<bool> _save() async {
    final finalContent = contentCtrl.text.trim();
    _titles['zh-cn'] = titleCtrl.text.trim();
    _summaries['zh-cn'] = summaryCtrl.text.trim();
    _contents['zh-cn'] = finalContent;

    if (titleCtrl.text.trim().isEmpty) {
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text(t(context, 'fill_required_fields'))),
      );
      return false;
    }

    setState(() => _isSaving = true);
    final draftSaveSuccessText = t(context, 'draft_save_success');
    final publishNowText = t(context, 'publish_now');
    try {
      final request = PostEditRequest(
        slug: slugCtrl.text.trim(),
        title: Map<String, String>.from(_titles),
        summary: Map<String, String>.from(_summaries),
        aiSummary: Map<String, String>.from(_currentDetail?.aiSummary ?? {}),
        contentMarkdown: Map<String, String>.from(_contents),
        status: status,
        visibility: visibility,
        password: passwordCtrl.text.trim().isEmpty
            ? null
            : passwordCtrl.text.trim(),
        renderType: renderType,
        editorType: editorType,
        aiSummaryStatus: aiSummaryStatus,
        version: _currentDetail?.version ?? 0,
        pointsPrice: int.tryParse(pointsPriceCtrl.text.trim()),
        freeLines: int.tryParse(freeLinesCtrl.text.trim()),
        categoryId: categoryId,
        tagIds: tagIds,
        visibilityRegions: visibilityRegions,
        contentDeclarations: contentDeclarations,
        repostPolicyCode: repostPolicyCode,
      );

      PostDetail savedDetail;
      if (_currentDetail == null) {
        savedDetail = await widget.api.createPost(request);
      } else {
        savedDetail = await widget.api.updatePost(
          _currentDetail!.id,
          request.copyWith(version: _currentDetail!.version),
        );
      }

      if (mounted) {
        setState(() {
          _currentDetail = savedDetail;
          _titles = Map<String, String>.from(savedDetail.title);
          _summaries = Map<String, String>.from(savedDetail.summary);
          _contents = Map<String, String>.from(savedDetail.contentMarkdown);
          repostPolicyCode = savedDetail.repostPolicyCode;
          _initialRepostPolicyCode = savedDetail.repostPolicyCode;
          _isSaving = false;
          _isDirty = false;
        });
        await _loadRevisions();
        if (!mounted) return false;
        AdminFeedback.showTransient(
          context,
          message: draftSaveSuccessText,
          severity: AdminNotificationSeverity.success,
          actionLabel: publishNowText,
          onAction: () {
            _publishLatestDraft();
          },
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('${t(context, 'save_failed')}: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _publishLatestDraft() async {
    if (_currentDetail == null) return;

    final sendArticleUpdate = await _askWhetherToSendArticleUpdate();
    if (sendArticleUpdate == null) return;
    if (!mounted) return;
    final publishSuccessText = t(context, 'publish_success');
    final operationFailedText = t(context, 'operation_failed');
    try {
      await widget.api.publishLatestDraftPost(
        _currentDetail!.id,
        sendArticleUpdate: sendArticleUpdate,
      );
      final latestDetail = await widget.api.postDetail(_currentDetail!.id);
      if (mounted) {
        setState(() {
          _currentDetail = latestDetail;
          status = latestDetail.status;
        });
        await _loadRevisions();
        if (!mounted) return;
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text(publishSuccessText)),
        );
      }
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('$operationFailedText: $e')),
        );
      }
    }
  }

  Future<void> _publishRevision(int revisionNumber) async {
    if (_currentDetail == null) return;
    final publishSuccessText = t(context, 'publish_success');
    final operationFailedText = t(context, 'operation_failed');
    bool sendArticleUpdate = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(t(context, 'publish_revision_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t(
                  context,
                  'publish_revision_confirm',
                ).replaceAll('%d', revisionNumber.toString()),
              ),
              CheckboxListTile(
                value: sendArticleUpdate,
                onChanged: (value) =>
                    setDialogState(() => sendArticleUpdate = value ?? false),
                title: const Text('向订阅者发送新文章更新邮件'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t(context, 'publish_this_revision')),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await widget.api.publishPostRevision(
        _currentDetail!.id,
        revisionNumber,
        sendArticleUpdate: sendArticleUpdate,
      );
      final latestDetail = await widget.api.postDetail(_currentDetail!.id);
      if (mounted) {
        setState(() {
          _currentDetail = latestDetail;
          status = latestDetail.status;
        });
        await _loadRevisions();
        if (!mounted) return;
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text(publishSuccessText)),
        );
      }
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('$operationFailedText: $e')),
        );
      }
    }
  }

  Future<bool?> _askWhetherToSendArticleUpdate() {
    bool sendArticleUpdate = false;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('发布文章'),
          content: CheckboxListTile(
            value: sendArticleUpdate,
            onChanged: (value) =>
                setDialogState(() => sendArticleUpdate = value ?? false),
            title: const Text('向订阅者发送新文章更新邮件'),
            contentPadding: EdgeInsets.zero,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, sendArticleUpdate),
              child: const Text('发布'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchToRevision(int revisionNumber) async {
    if (_currentDetail == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'set_current_draft_title')),
        content: Text(
          t(
            context,
            'set_current_draft_confirm',
          ).replaceAll('%d', revisionNumber.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t(context, 'set_current_draft')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final newDetail = await widget.api.activatePostRevision(
        _currentDetail!.id,
        revisionNumber,
      );

      if (mounted) {
        setState(() {
          _currentDetail = newDetail;
          _titles = Map<String, String>.from(newDetail.title);
          _summaries = Map<String, String>.from(newDetail.summary);
          _contents = Map<String, String>.from(newDetail.contentMarkdown);

          slugCtrl.text = newDetail.slug;
          titleCtrl.text = newDetail.zhTitle;
          summaryCtrl.text = newDetail.zhSummary;
          contentCtrl.text = newDetail.zhContent;
          pointsPriceCtrl.text = newDetail.pointsPrice?.toString() ?? '';
          freeLinesCtrl.text = newDetail.freeLines?.toString() ?? '';
          passwordCtrl.clear();

          status = newDetail.status;
          visibility = newDetail.visibility;
          renderType = newDetail.renderType;
          editorType = newDetail.editorType;
          categoryId = newDetail.categoryId;
          tagIds = newDetail.tagIds;
          visibilityRegions = newDetail.visibilityRegions;
          contentDeclarations = List<String>.from(
            newDetail.contentDeclarations,
          );
          repostPolicyCode = newDetail.repostPolicyCode;

          _initialSlug = newDetail.slug;
          _initialTitle = newDetail.zhTitle;
          _initialSummary = newDetail.zhSummary;
          _initialContent = newDetail.zhContent;
          _initialStatus = newDetail.status;
          _initialVisibility = newDetail.visibility;
          _initialRenderType = newDetail.renderType;
          _initialEditorType = newDetail.editorType;
          _initialAiSummaryStatus = newDetail.aiSummaryStatus;
          _initialCategoryId = newDetail.categoryId;
          _initialTagIds = List<int>.from(newDetail.tagIds);
          _initialVisibilityRegions = List<String>.from(
            newDetail.visibilityRegions,
          );
          _initialContentDeclarations = List<String>.from(
            newDetail.contentDeclarations,
          );
          _initialRepostPolicyCode = newDetail.repostPolicyCode;

          _isDirty = false;
        });

        await _loadRevisions();

        if (mounted) {
          AdminFeedback.showSnackBar(
            context,
            SnackBar(content: Text(t(context, 'set_current_draft_success'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(
            content: Text('${t(context, 'set_current_draft_failed')}: $e'),
          ),
        );
      }
    }
  }

  Future<void> _showDiff(int revisionNumber) async {
    if (_currentDetail == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final revisionDetail = await widget.api.getPostRevision(
        _currentDetail!.id,
        revisionNumber,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        final currentTitle = titleCtrl.text;
        final currentSummary = summaryCtrl.text;
        final currentContent = contentCtrl.text;

        final revTitle = revisionDetail.zhTitle;
        final revSummary = revisionDetail.zhSummary;
        final revContent = revisionDetail.zhContent;

        showDialog(
          context: context,
          builder: (context) {
            final screenSize = MediaQuery.of(context).size;
            return AlertDialog(
              title: Text(
                t(
                  context,
                  'diff_with_version',
                ).replaceAll('%d', revisionNumber.toString()),
              ),
              content: SizedBox(
                width: screenSize.width * 0.8,
                height: screenSize.height * 0.8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t(
                                context,
                                'diff_tip',
                              ).replaceAll('%d', revisionNumber.toString()),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DiffViewer(
                              title: t(context, 'title_diff'),
                              oldText: revTitle,
                              newText: currentTitle,
                              key: UniqueKey(),
                            ),
                            const SizedBox(height: 24),
                            DiffViewer(
                              title: t(context, 'summary_diff'),
                              oldText: revSummary,
                              newText: currentSummary,
                              key: UniqueKey(),
                            ),
                            const SizedBox(height: 24),
                            DiffViewer(
                              title: t(context, 'content_diff'),
                              oldText: revContent,
                              newText: currentContent,
                              key: UniqueKey(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t(context, 'close')),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _switchToRevision(revisionNumber);
                  },
                  icon: const Icon(Icons.history_edu, size: 18),
                  label: Text(t(context, 'switch_to_this_version')),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('${t(context, 'load_revision_failed')}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final bool isPhone = AdminBreakpoints.isPhone(context);
    final bool isDirty = _checkIfDirty();
    final bool canPopVal = !isDirty;

    return PopScope(
      canPop: canPopVal,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool shouldPop = await _onWillPop();
        if (shouldPop) {
          if (mounted) {
            navigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            _currentDetail == null
                ? t(context, 'new_post')
                : t(context, 'edit_post'),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_isDirty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: isPhone
                    ? Icon(
                        Icons.circle,
                        size: 10,
                        color: Colors.orange.shade600,
                      )
                    : Chip(
                        label: Text(
                          t(context, 'unsaved'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.orange.shade100,
                        labelStyle: TextStyle(color: Colors.orange.shade800),
                      ),
              ),
            if (isPhone)
              IconButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        final shouldPop = await _onWillPop();
                        if (shouldPop && mounted) {
                          navigator.pop();
                        }
                      },
                icon: const Icon(Icons.close),
                tooltip: t(context, 'cancel'),
              )
            else
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        final shouldPop = await _onWillPop();
                        if (mounted) {
                          if (shouldPop) {
                            navigator.pop();
                          }
                        }
                      },
                child: Text(t(context, 'cancel')),
              ),
            if (isPhone)
              IconButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        await _save();
                      },
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                tooltip: t(context, 'save'),
              )
            else
              FilledButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        await _save();
                      },
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t(context, 'save')),
              ),
            if (isPhone)
              IconButton(
                onPressed: _openMobileSidebar,
                icon: const Icon(Icons.tune),
                tooltip: t(context, 'basic_info'),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: isPhone ? _buildEditorPane() : _buildWideEditorLayout(),
        floatingActionButton: isPhone
            ? FloatingActionButton.extended(
                onPressed: _openMobileSidebar,
                icon: const Icon(Icons.tune),
                label: Text(t(context, 'basic_info')),
              )
            : null,
      ),
    );
  }

  Widget _buildWideEditorLayout() {
    return Row(
      children: [
        Expanded(child: _buildEditorPane()),
        Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Colors.grey.shade300)),
          ),
          child: _buildSidebar(),
        ),
      ],
    );
  }

  void _openMobileSidebar() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (bottomSheetContext) {
        return SizedBox(
          height: MediaQuery.sizeOf(bottomSheetContext).height * 0.9,
          child: _buildSidebar(),
        );
      },
    );
  }

  Widget _buildEditorPane() {
    final isPhone = AdminBreakpoints.isPhone(context);
    final horizontalPadding = isPhone ? 12.0 : 24.0;
    final bottomPadding = isPhone ? 92.0 : 24.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        hintText: t(context, 'title'),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      style: TextStyle(
                        fontSize: isPhone ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
              if (_currentDetail != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: OutlinedButton.icon(
                    onPressed: _openTranslationManager,
                    icon: const Icon(Icons.translate),
                    label: Text(t(context, 'multilingual_management')),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              bottomPadding,
            ),
            child: _buildEditor(),
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    final theme = Theme.of(context);
    final selectionTheme = theme.textSelectionTheme.copyWith(
      selectionColor: theme.colorScheme.primary.withValues(alpha: 0.28),
      selectionHandleColor: theme.colorScheme.primary,
      cursorColor: theme.colorScheme.primary,
    );
    final editor = renderType == 1
        ? HtmlSyntaxEditor(controller: contentCtrl, onChanged: _markDirty)
        : MarkdownPlusEditor(
            controller: contentCtrl,
            api: widget.api,
            isBlockMode: renderType == 6,
            onChanged: _markDirty,
            scrollController: _contentScrollController,
          );
    return TextSelectionTheme(data: selectionTheme, child: editor);
  }

  Widget _buildSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _sidebarTabController,
          tabs: [
            Tab(text: t(context, 'publish_settings')),
            Tab(text: t(context, 'ai_summary')),
            Tab(text: t(context, 'revisions')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _sidebarTabController,
            children: [
              _buildPublishSettingsContent(),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildAiSummaryCard(),
              ),
              _buildRevisionsContent(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPublishSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContentStatsCard(),
          const SizedBox(height: 16),
          _buildPublishSettingsCard(),
          const SizedBox(height: 16),
          _buildRepostPolicyCard(),
          const SizedBox(height: 16),
          _buildCategoryCard(),
          const SizedBox(height: 16),
          _buildTagsCard(),
          const SizedBox(height: 16),
          _buildMetadataCard(),
        ],
      ),
    );
  }

  Widget _buildRevisionsContent() {
    return _buildRevisionsCard();
  }

  Widget _buildContentStatsCard() {
    return _ContentStatsCard(
      contentCtrl: contentCtrl,
      lastSavedText: _formatLastSaved(),
    );
  }

  String _formatLastSaved() {
    final d = _currentDetail;
    if (d == null || d.updatedAt == null) return '—';
    return _formatDate(d.updatedAt!);
  }

  Widget _buildMetadataCard() {
    final d = _currentDetail;
    if (d == null) {
      return SectionCard(
        icon: Icons.info_outline,
        title: t(context, 'system_info_after_save'),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              t(context, 'system_info_after_save'),
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ),
      );
    }
    return SectionCard(
      icon: Icons.info_outline,
      title: t(context, 'article_metadata'),
      child: Column(
        children: [
          MetadataItem(t(context, 'post_id'), '${d.id}'),
          MetadataItem(
            t(context, 'author'),
            d.userName ?? t(context, 'unknown'),
          ),
          MetadataItem(
            t(context, 'current_revision'),
            '${d.currentRevisionNumber}',
          ),
          MetadataItem(
            t(context, 'published_revision'),
            d.hasPublishedRevision
                ? '${d.publishedRevisionNumber}'
                : t(context, 'not_published'),
          ),
          MetadataItem(t(context, 'data_version'), '${d.version}'),
          if (d.createdAt != null)
            MetadataItem(t(context, 'created_at'), _formatDate(d.createdAt!)),
          if (d.updatedAt != null)
            MetadataItem(t(context, 'updated_at'), _formatDate(d.updatedAt!)),
          if (d.publishedAt != null)
            MetadataItem(
              t(context, 'published_at'),
              _formatDate(d.publishedAt!),
            ),
        ],
      ),
    );
  }

  Widget _buildRevisionsCard() {
    if (_currentDetail == null) {
      return SectionCard(
        icon: Icons.history,
        title: t(context, 'revisions'),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              t(context, 'history_after_save'),
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ),
      );
    }

    if (_isLoadingRevisions) {
      return SectionCard(
        icon: Icons.history,
        title: t(context, 'revisions'),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_revisions.isEmpty) {
      return SectionCard(
        icon: Icons.history,
        title: t(context, 'revisions'),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              t(context, 'no_history'),
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ),
      );
    }

    return SectionCard(
      icon: Icons.history,
      title: t(context, 'revisions'),
      child: SizedBox(
        height: 400,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _revisions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final revision = _revisions[i];
            final isCurrent =
                revision.revisionNumber ==
                _currentDetail!.currentRevisionNumber;
            final isPublished = revision.isPublishedRevision;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrent ? Colors.green.shade50 : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCurrent
                      ? Colors.green.shade200
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        t(
                          context,
                          'revision_text',
                        ).replaceAll('%d', revision.revisionNumber.toString()),
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            t(context, 'current_draft'),
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.green.shade100,
                          labelStyle: TextStyle(color: Colors.green.shade800),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                        ),
                      ],
                      if (isPublished) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            t(context, 'published_revision_badge'),
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.blue.shade100,
                          labelStyle: TextStyle(color: Colors.blue.shade800),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    revision.zhTitle.isEmpty
                        ? t(context, 'no_title')
                        : revision.zhTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${revision.createdByName} · ${_formatDate(revision.createdAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => _showDiff(revision.revisionNumber),
                        child: Text(t(context, 'compare')),
                      ),
                      if (!isCurrent)
                        TextButton(
                          onPressed: () =>
                              _switchToRevision(revision.revisionNumber),
                          child: Text(t(context, 'set_current_draft')),
                        ),
                      if (!isPublished)
                        TextButton(
                          onPressed: () =>
                              _publishRevision(revision.revisionNumber),
                          child: Text(t(context, 'publish_this_revision')),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPublishSettingsCard() {
    return SectionCard(
      icon: Icons.settings,
      title: t(context, 'publish_settings'),
      child: Column(
        children: [
          _buildDropdownRow(
            label: t(context, 'status'),
            value: status,
            items: [
              DropdownMenuItem(value: 0, child: Text(t(context, 'draft'))),
              DropdownMenuItem(value: 1, child: Text(t(context, 'published'))),
              DropdownMenuItem(value: 2, child: Text(t(context, 'archived'))),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  status = v;
                  _markDirty();
                });
              }
            },
          ),
          const SizedBox(height: 12),
          _buildDropdownRow(
            label: t(context, 'visibility_label'),
            value: visibility,
            items: [
              DropdownMenuItem(
                value: 0,
                child: Row(
                  children: [
                    const Icon(Icons.public, size: 16),
                    const SizedBox(width: 8),
                    Text(t(context, 'public_visibility')),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 1,
                child: Text(t(context, 'private_visibility')),
              ),
              DropdownMenuItem(
                value: 2,
                child: Text(t(context, 'password_protected')),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  visibility = v;
                  _markDirty();
                });
              }
            },
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            '内容声明',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          _buildContentDeclarationDropdown(
            code: 'EXPLICIT_AND_EMBEDDED_ADVERTISING',
            label: '包含显式广告和植入式广告',
          ),
          const SizedBox(height: 12),
          _buildContentDeclarationDropdown(
            code: 'AI_GENERATED_CONTENT',
            label: '存在 AI 生成内容',
          ),
          const SizedBox(height: 12),
          _buildContentDeclarationDropdown(
            code: 'SUBJECTIVE_VIEWPOINTS',
            label: '存在主观观点',
          ),
          const SizedBox(height: 12),
          _buildContentDeclarationDropdown(
            code: 'AUTOMATION_USE_ALLOWED',
            label: '可用于自动化程序',
            helpText: '选择后表示允许自动化程序使用内容，不将爬虫排除在外。',
          ),
        ],
      ),
    );
  }

  Widget _buildRepostPolicyCard() {
    final options = _policyOptions();
    final selectedPolicy = options.firstWhere(
      (policy) => policy.code == repostPolicyCode,
      orElse: () => options.first,
    );
    final conditions = _policyConditions(selectedPolicy);

    return SectionCard(
      icon: Icons.copyright_outlined,
      title: t(context, 'repost_policy_card_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingRepostPolicies)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                t(context, 'repost_policy_loading'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          KeyedSubtree(
            key: const Key('repostPolicyDropdown'),
            child: _buildDropdownRow<String>(
              label: t(context, 'repost_policy'),
              value: selectedPolicy.code,
              items: options
                  .map(
                    (policy) => DropdownMenuItem<String>(
                      value: policy.code,
                      child: Text(_policyName(policy)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null || value == repostPolicyCode) return;
                setState(() {
                  repostPolicyCode = value;
                  _isDirty = true;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selectedPolicy.requiresApplication
                  ? Colors.orange.withValues(alpha: 0.08)
                  : Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selectedPolicy.requiresApplication
                    ? Colors.orange.withValues(alpha: 0.3)
                    : Colors.green.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedPolicy.requiresApplication
                      ? t(context, 'repost_policy_requires_application')
                      : t(context, 'repost_policy_no_application'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  _policySummary(selectedPolicy),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (conditions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...conditions.map(
                    (condition) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '• $condition',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
                if (selectedPolicy.licenseUrl != null &&
                    selectedPolicy.licenseUrl!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    '${t(context, 'repost_policy_link')}: ${selectedPolicy.licenseUrl}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentDeclarationDropdown({
    required String code,
    required String label,
    String? helpText,
  }) {
    final selected = contentDeclarations.contains(code);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdownRow<bool>(
          label: label,
          value: selected,
          items: const [
            DropdownMenuItem(value: false, child: Text('不声明')),
            DropdownMenuItem(value: true, child: Text('声明')),
          ],
          onChanged: (value) {
            if (value == null || value == selected) {
              return;
            }
            setState(() {
              if (value) {
                contentDeclarations.add(code);
              } else {
                contentDeclarations.remove(code);
              }
              _markDirty();
            });
          },
        ),
        if (helpText != null) ...[
          const SizedBox(height: 4),
          Text(
            helpText,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownRow<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiSummaryCard() {
    return SectionCard(
      icon: Icons.auto_awesome,
      title: t(context, 'ai_summary'),
      headerColor: Colors.orange.shade700,
      headerBgColor: Colors.orange.shade50,
      trailing: Switch(
        value: aiSummaryStatus != 2,
        onChanged: (v) {
          setState(() {
            aiSummaryStatus = v ? 0 : 2;
            _markDirty();
          });
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (aiSummaryStatus != 2) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    aiSummaryStatus == 1
                        ? t(context, 'ai_locked')
                        : t(context, 'ai_auto'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  t(context, 'persistent_summary'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Switch(
                  value: aiSummaryStatus == 1,
                  onChanged: (v) {
                    setState(() {
                      aiSummaryStatus = v ? 1 : 0;
                      _markDirty();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              t(context, 'ai_summary_content'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _currentDetail?.zhAiSummary != null
                    ? TextEditingController(text: _currentDetail!.zhAiSummary)
                    : TextEditingController(),
                maxLines: null,
                minLines: 4,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _currentDetail == null
                        ? null
                        : () async {
                            if (_currentDetail == null) return;
                            try {
                              await widget.api.triggerAiSummary(
                                _currentDetail!.id,
                              );
                              if (mounted) {
                                AdminFeedback.showSnackBar(
                                  context,
                                  SnackBar(
                                    content: Text(
                                      t(context, 'trigger_ai_success'),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                AdminFeedback.showSnackBar(
                                  context,
                                  SnackBar(
                                    content: Text(
                                      '${t(context, 'trigger_ai_failed')}: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(
                      t(context, 'generate_summary'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _currentDetail == null
                        ? null
                        : () async {
                            // 保存摘要逻辑
                          },
                    icon: const Icon(Icons.save, size: 16),
                    label: Text(
                      t(context, 'save_summary'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 36,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t(context, 'ai_summary_disabled_status'),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    return SectionCard(
      icon: Icons.category,
      title: t(context, 'category'),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: _categories.any((c) => c.id == categoryId)
                ? categoryId
                : null,
            isExpanded: true,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            hint: Text(t(context, 'select_category')),
            items: [
              ..._categories.map(
                (cat) => DropdownMenuItem<int?>(
                  value: cat.id,
                  child: Text(cat.displayName),
                ),
              ),
            ],
            onChanged: (v) {
              setState(() {
                categoryId = v;
                _markDirty();
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTagsCard() {
    return SectionCard(
      icon: Icons.label,
      title: t(context, 'tags'),
      child: Column(
        children: [
          if (tagIds.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tagIds.map((tagId) {
                final tag = _tags.firstWhere(
                  (t) => t.id == tagId,
                  orElse: () => TagItem(
                    id: 0,
                    slug: '',
                    name: const {},
                    createdAt: DateTime.now(),
                  ),
                );
                return Chip(
                  label: Text(tag.zhName, style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    setState(() {
                      tagIds.remove(tagId);
                      _markDirty();
                    });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: null,
                isExpanded: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                hint: Text(t(context, 'add_tags')),
                items: _tags
                    .where((tag) => !tagIds.contains(tag.id))
                    .map(
                      (tag) => DropdownMenuItem<int>(
                        value: tag.id,
                        child: Text(tag.zhName),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      tagIds.add(v);
                      _markDirty();
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    return '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')} ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.headerColor,
    this.headerBgColor,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? headerColor;
  final Color? headerBgColor;

  @override
  Widget build(BuildContext context) {
    final effectiveHeaderColor = headerColor ?? Colors.grey.shade700;
    final effectiveHeaderBgColor = headerBgColor ?? Colors.grey.shade50;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: effectiveHeaderBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: effectiveHeaderColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: effectiveHeaderColor,
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _ContentStatsCard extends StatefulWidget {
  const _ContentStatsCard({
    required this.contentCtrl,
    required this.lastSavedText,
  });

  final TextEditingController contentCtrl;
  final String lastSavedText;

  @override
  State<_ContentStatsCard> createState() => _ContentStatsCardState();
}

class _ContentStatsCardState extends State<_ContentStatsCard> {
  late BuildContext _localContext;

  @override
  void initState() {
    super.initState();
    widget.contentCtrl.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    widget.contentCtrl.removeListener(_onContentChanged);
    super.dispose();
  }

  void _onContentChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    _localContext = context;
    final contentText = widget.contentCtrl.text;
    final characterCount = contentText.length;
    final wordCount = _countWords(contentText);
    final readingTimeMinutes = _estimateReadingTime(wordCount);

    return SectionCard(
      icon: Icons.bar_chart,
      title: t(_localContext, 'content_stats'),
      child: Column(
        children: [
          _buildStatRow(t(_localContext, 'word_count'), wordCount.toString()),
          _buildStatRow(
            t(_localContext, 'character_count'),
            characterCount.toString(),
          ),
          _buildStatRow(
            t(_localContext, 'estimated_reading_time'),
            '$readingTimeMinutes分钟',
          ),
          const Divider(height: 24),
          _buildStatRow(
            t(_localContext, 'last_saved'),
            widget.lastSavedText,
            showBorder: false,
          ),
        ],
      ),
    );
  }

  int _countWords(String text) {
    if (text.isEmpty) return 0;
    final words = text.trim().split(RegExp(r'\s+'));
    return words.where((word) => word.isNotEmpty).length;
  }

  int _estimateReadingTime(int wordCount) {
    if (wordCount == 0) return 0;
    const wordsPerMinute = 200;
    final minutes = wordCount ~/ wordsPerMinute;
    if (minutes < 1 && wordCount > 0) return 1;
    return minutes;
  }

  Widget _buildStatRow(String label, String value, {bool showBorder = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class MetadataItem extends StatelessWidget {
  const MetadataItem(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _PostTranslationDialog extends StatefulWidget {
  const _PostTranslationDialog({
    required this.api,
    required this.postId,
    required this.titles,
    required this.summaries,
    required this.contents,
  });

  final AdminApiClient api;
  final int postId;
  final Map<String, String> titles;
  final Map<String, String> summaries;
  final Map<String, String> contents;

  @override
  State<_PostTranslationDialog> createState() => _PostTranslationDialogState();
}

class _PostTranslationDialogState extends State<_PostTranslationDialog> {
  static const _customLanguage = '__custom__';
  static const _languagePresets = <String>[
    'zh-cn',
    'en-us',
    'ja-jp',
    'ko-kr',
    'fr-fr',
    'de-de',
    _customLanguage,
  ];

  late final TextEditingController _customTargetController;
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _contentController;
  late final TextEditingController _translatedTitleController;
  late final TextEditingController _translatedSummaryController;
  late final TextEditingController _translatedContentController;
  late String _sourceLanguage;
  late String _targetLanguage;
  PostTranslationResult? _translation;
  bool _isTranslating = false;

  List<String> get _sourceLanguages {
    final languages = <String>{
      ...widget.titles.keys,
      ...widget.summaries.keys,
      ...widget.contents.keys,
    };
    languages.add('zh-cn');
    return languages.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _sourceLanguage = _sourceLanguages.contains('zh-cn')
        ? 'zh-cn'
        : _sourceLanguages.first;
    final existingTargets = _sourceLanguages
        .where((language) => language != _sourceLanguage)
        .toList();
    _targetLanguage = existingTargets.isNotEmpty
        ? existingTargets.first
        : 'en-us';
    if (!_languagePresets.contains(_targetLanguage)) {
      _targetLanguage = _customLanguage;
    }
    _customTargetController = TextEditingController(
      text: _targetLanguage == _customLanguage && existingTargets.isNotEmpty
          ? existingTargets.first
          : '',
    );
    _titleController = TextEditingController();
    _summaryController = TextEditingController();
    _contentController = TextEditingController();
    _translatedTitleController = TextEditingController();
    _translatedSummaryController = TextEditingController();
    _translatedContentController = TextEditingController();
    _loadSourceFields();
  }

  @override
  void dispose() {
    _customTargetController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _translatedTitleController.dispose();
    _translatedSummaryController.dispose();
    _translatedContentController.dispose();
    super.dispose();
  }

  void _loadSourceFields() {
    _titleController.text = widget.titles[_sourceLanguage] ?? '';
    _summaryController.text = widget.summaries[_sourceLanguage] ?? '';
    _contentController.text = widget.contents[_sourceLanguage] ?? '';
    _translation = null;
  }

  String get _effectiveTargetLanguage {
    if (_targetLanguage == _customLanguage) {
      return _customTargetController.text.trim().toLowerCase().replaceAll(
        '_',
        '-',
      );
    }
    return _targetLanguage;
  }

  Future<void> _translate() async {
    final targetLanguage = _effectiveTargetLanguage;
    if (targetLanguage.isEmpty || targetLanguage == _sourceLanguage) {
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text(t(context, 'translation_invalid_language'))),
      );
      return;
    }
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text(t(context, 'fill_required_fields'))),
      );
      return;
    }

    setState(() => _isTranslating = true);
    try {
      final result = await widget.api.translatePost(
        widget.postId,
        sourceLanguage: _sourceLanguage,
        targetLanguage: targetLanguage,
        title: _titleController.text,
        summary: _summaryController.text,
        contentMarkdown: _contentController.text,
      );
      if (!mounted) return;
      setState(() {
        _translation = result;
        _translatedTitleController.text = result.title;
        _translatedSummaryController.text = result.summary;
        _translatedContentController.text = result.contentMarkdown;
        _isTranslating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isTranslating = false);
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text('${t(context, 'translation_failed')}: $error')),
      );
    }
  }

  Future<bool> _confirmOverwrite(PostTranslationResult result) async {
    final oldTitle = widget.titles[result.targetLanguage] ?? '';
    final oldSummary = widget.summaries[result.targetLanguage] ?? '';
    final oldContent = widget.contents[result.targetLanguage] ?? '';
    if (oldTitle.isEmpty && oldSummary.isEmpty && oldContent.isEmpty) {
      return true;
    }

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(t(dialogContext, 'translation_overwrite_title')),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t(dialogContext, 'translation_overwrite_desc')),
                    const SizedBox(height: 16),
                    _buildDiff(
                      dialogContext,
                      t(dialogContext, 'title'),
                      oldTitle,
                      result.title,
                    ),
                    _buildDiff(
                      dialogContext,
                      t(dialogContext, 'summary'),
                      oldSummary,
                      result.summary,
                    ),
                    _buildDiff(
                      dialogContext,
                      t(dialogContext, 'content'),
                      oldContent,
                      result.contentMarkdown,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(t(dialogContext, 'cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(t(dialogContext, 'translation_overwrite')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildDiff(
    BuildContext context,
    String label,
    String oldValue,
    String newValue,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _diffPanel(
                  context,
                  t(context, 'translation_existing'),
                  oldValue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _diffPanel(
                  context,
                  t(context, 'translation_new'),
                  newValue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _diffPanel(BuildContext context, String label, String value) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        child: Text('$label\n$value', style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Future<void> _apply() async {
    if (_translation == null) return;
    final result = PostTranslationResult(
      sourceLanguage: _translation!.sourceLanguage,
      targetLanguage: _translation!.targetLanguage,
      title: _translatedTitleController.text,
      summary: _translatedSummaryController.text,
      contentMarkdown: _translatedContentController.text,
    );
    if (!await _confirmOverwrite(result) || !mounted) return;
    Navigator.pop(context, {
      'targetLanguage': result.targetLanguage,
      'title': result.title,
      'summary': result.summary,
      'contentMarkdown': result.contentMarkdown,
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetHasExisting =
        _effectiveTargetLanguage.isNotEmpty &&
        ((_titlesForTarget[_effectiveTargetLanguage] ?? '').isNotEmpty ||
            (_summariesForTarget[_effectiveTargetLanguage] ?? '').isNotEmpty ||
            (_contentsForTarget[_effectiveTargetLanguage] ?? '').isNotEmpty);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.translate),
          const SizedBox(width: 8),
          Expanded(child: Text(t(context, 'multilingual_management'))),
        ],
      ),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey<String>('source-$_sourceLanguage'),
                      initialValue: _sourceLanguage,
                      decoration: InputDecoration(
                        labelText: t(context, 'translation_source_language'),
                      ),
                      items: _sourceLanguages
                          .map(
                            (language) => DropdownMenuItem(
                              value: language,
                              child: Text(language),
                            ),
                          )
                          .toList(),
                      onChanged: _isTranslating
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _sourceLanguage = value;
                                _loadSourceFields();
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey<String>('target-$_targetLanguage'),
                      initialValue: _targetLanguage,
                      decoration: InputDecoration(
                        labelText: t(context, 'translation_target_language'),
                      ),
                      items: _languagePresets
                          .map(
                            (language) => DropdownMenuItem(
                              value: language,
                              child: Text(
                                language == _customLanguage
                                    ? t(context, 'translation_custom_language')
                                    : language,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isTranslating
                          ? null
                          : (value) => setState(() {
                              _targetLanguage = value ?? 'en-us';
                              _translation = null;
                            }),
                    ),
                  ),
                ],
              ),
              if (_targetLanguage == _customLanguage)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _customTargetController,
                    decoration: InputDecoration(
                      labelText: t(context, 'translation_custom_language_code'),
                      hintText: 'es-ES',
                    ),
                    onChanged: (_) => setState(() => _translation = null),
                  ),
                ),
              if (targetHasExisting)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    t(context, 'translation_existing_warning'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _buildTextField(
                t(context, 'title'),
                _titleController,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                t(context, 'summary'),
                _summaryController,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                t(context, 'content'),
                _contentController,
                maxLines: 12,
              ),
              if (_translation != null) ...[
                const SizedBox(height: 16),
                Text(
                  t(context, 'translation_preview'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildPreviewField(
                  t(context, 'title'),
                  _translatedTitleController,
                ),
                _buildPreviewField(
                  t(context, 'summary'),
                  _translatedSummaryController,
                ),
                _buildPreviewField(
                  t(context, 'content'),
                  _translatedContentController,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTranslating ? null : () => Navigator.pop(context),
          child: Text(t(context, 'cancel')),
        ),
        OutlinedButton.icon(
          onPressed: _isTranslating ? null : _translate,
          icon: _isTranslating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(t(context, 'translate_with_ai')),
        ),
        FilledButton(
          onPressed: _translation == null || _isTranslating ? null : _apply,
          child: Text(t(context, 'translation_apply')),
        ),
      ],
    );
  }

  Map<String, String> get _titlesForTarget => widget.titles;
  Map<String, String> get _summariesForTarget => widget.summaries;
  Map<String, String> get _contentsForTarget => widget.contents;

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildPreviewField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: controller,
              maxLines: label == t(context, 'content') ? 12 : 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}
