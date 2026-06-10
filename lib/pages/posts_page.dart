part of 'package:windblog_admin_flutter/main.dart';

Color _generateColorFromSlug(String slug) {
  int hash = 0;
  for (int i = 0; i < slug.length; i++) {
    hash = slug.codeUnitAt(i) + ((hash << 5) - hash);
  }
  final colors = [
    const Color(0xFF5C6BC0),
    const Color(0xFF26A69A),
    const Color(0xFFEF5350),
    const Color(0xFFFF7043),
    const Color(0xFF66BB6A),
    const Color(0xFFAB47BC),
    const Color(0xFF42A5F5),
    const Color(0xFFFFCA28),
    const Color(0xFFEC407A),
    const Color(0xFF7E57C2),
    const Color(0xFF29B6F6),
    const Color(0xFF9CCC65),
  ];
  return colors[hash.abs() % colors.length].withValues(alpha: 0.8);
}

class PostsPage extends StatefulWidget {
  const PostsPage({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  final keywordCtrl = TextEditingController();
  List<PostItem> items = [];
  int page = 1;
  int total = 0;

  bool _isTreeView = false;
  final Map<int, CategoryTreeNode> _categoryTreeCache = {};
  List<CategoryItem> _allCategories = [];
  bool _isTreeLoading = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loading = true;
    _loadAllCategories();
    load();
  }

  Future<void> _loadAllCategories() async {
    if (!mounted) return;
    setState(() => _isTreeLoading = true);
    try {
      final cats = await widget.api.listCategories();
      if (!mounted) return;
      setState(() {
        _allCategories = cats;
        _buildCategoryTree();
        _isTreeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTreeLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t(context, 'load_categories_failed')}: $e'),
          ),
        );
      }
    }
  }

  void _buildCategoryTree() {
    _categoryTreeCache.clear();

    for (final category in _allCategories) {
      if (!_categoryTreeCache.containsKey(category.id)) {
        _categoryTreeCache[category.id] = CategoryTreeNode.fromCategory(
          category,
        );
      }
    }

    for (final category in _allCategories) {
      if (category.parentId == null) {
        continue;
      }

      final parentNode = _categoryTreeCache[category.parentId];
      final childNode = _categoryTreeCache[category.id];

      if (parentNode != null && childNode != null) {
        final updatedChildren = List<CategoryTreeNode>.from(parentNode.children)
          ..add(childNode);
        _categoryTreeCache[category.parentId!] = parentNode.copyWith(
          children: updatedChildren,
        );
      }
    }
  }

  Future<void> _loadCategoryPosts(int categoryId) async {
    final node = _categoryTreeCache[categoryId];
    if (node == null) return;

    if (node.isLoading) return;

    setState(() {
      _categoryTreeCache[categoryId] = node.copyWith(isLoading: true);
    });

    try {
      final res = await widget.api.listPostsByCategory(
        categoryId: categoryId,
        page: 1,
        pageSize: 10,
        keyword: keywordCtrl.text.trim().isEmpty
            ? null
            : keywordCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          _categoryTreeCache[categoryId] = node.copyWith(
            posts: res.items,
            total: res.total,
            page: 1,
            isLoading: false,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categoryTreeCache[categoryId] = node.copyWith(isLoading: false);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'load_posts_failed')}: $e')),
        );
      }
    }
  }

  Future<void> _toggleCategory(int categoryId) async {
    final node = _categoryTreeCache[categoryId];
    if (node == null) return;

    final willExpand = !node.isExpanded;

    setState(() {
      _categoryTreeCache[categoryId] = node.copyWith(isExpanded: willExpand);
    });

    if (willExpand && node.posts.isEmpty && !node.isLoading) {
      await _loadCategoryPosts(categoryId);
    }
  }

  void _clearCategoryPostsCache() {
    final keys = _categoryTreeCache.keys.toList();
    for (final key in keys) {
      final node = _categoryTreeCache[key];
      if (node != null) {
        _categoryTreeCache[key] = node.copyWith(
          posts: [],
          page: 1,
          total: 0,
          isExpanded: false,
        );
      }
    }
  }

  @override
  void dispose() {
    keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.listPosts(
        page: page,
        pageSize: 10,
        keyword: keywordCtrl.text.trim().isEmpty
            ? null
            : keywordCtrl.text.trim(),
      );
      items = res.items;
      total = res.total;
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> createOrEdit({PostItem? item}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      PostDetail? detail;
      if (item != null) {
        detail = await widget.api.postDetail(item.id);
      }
      if (!mounted) return;

      await Navigator.push<PostEditRequest?>(
        context,
        MaterialPageRoute(
          builder: (_) => PostEditorPage(detail: detail, api: widget.api),
        ),
      );

      await load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('${t(context, 'operation_failed')}: $e')),
        );
      }
    }
  }

  Widget _buildListView() {
    if (items.isEmpty) {
      return AdminStatusView.empty(title: t(context, 'no_posts'));
    }

    return Card(
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, index) => const Divider(height: 1),
        itemBuilder: (_, i) => _buildPostTile(items[i]),
      ),
    );
  }

  Widget _buildPostTile(PostItem it, {double indent = 16}) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: ListTile(
        contentPadding: const EdgeInsets.only(right: 16),
        leading: Icon(
          Icons.description_outlined,
          color: Colors.grey.shade500,
          size: 20,
        ),
        title: Text(
          it.zhTitle.isEmpty ? it.slug : it.zhTitle,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'slug: ${it.slug} | ${t(context, 'author')}: ${it.userName ?? t(context, 'unknown')} | ${t(context, 'status_text')}: ${it.status == 0 ? t(context, 'draft') : (it.status == 1 ? t(context, 'published') : t(context, 'archived'))}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${t(context, 'visibility_label')}: ${it.visibility == 0 ? t(context, 'public_visibility') : (it.visibility == 1 ? t(context, 'private_visibility') : t(context, 'password_protected'))}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (it.aiSummaryStatus != 2)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0.5,
                      ),
                      decoration: BoxDecoration(
                        color: it.aiSummaryStatus == 0
                            ? Colors.blue.shade50
                            : Colors.green.shade50,
                        border: Border.all(
                          color: it.aiSummaryStatus == 0
                              ? Colors.blue.shade200
                              : Colors.green.shade200,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        it.aiSummaryStatus == 0
                            ? t(context, 'ai_status_auto')
                            : t(context, 'ai_status_manual_locked'),
                        style: TextStyle(
                          fontSize: 9,
                          color: it.aiSummaryStatus == 0
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: () => createOrEdit(item: it),
              child: Text(
                t(context, 'edit'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                try {
                  await widget.api.publishLatestDraftPost(it.id);
                  await load();
                } on UnauthorizedException {
                  widget.onAuthError();
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('${t(context, 'operation_failed')}: $e'),
                      ),
                    );
                  }
                }
              },
              child: Text(
                t(context, 'publish_latest_draft'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(t(context, 'confirm_delete')),
                    content: Text(t(context, 'confirm_delete_post_msg')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(t(context, 'cancel')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          t(context, 'delete'),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirmed != true) return;

                try {
                  await widget.api.deletePost(it.id);
                  await load();
                } on UnauthorizedException {
                  widget.onAuthError();
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('${t(context, 'operation_failed')}: $e'),
                      ),
                    );
                  }
                }
              },
              child: Text(
                t(context, 'delete'),
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<CategoryTreeNode> _getRootCategories() {
    return _categoryTreeCache.values
        .where((node) => node.category.parentId == null)
        .toList();
  }

  Widget _buildCategoryNode(
    int categoryId, {
    int depth = 0,
    required Color lineColor,
  }) {
    final node = _categoryTreeCache[categoryId];
    if (node == null) return const SizedBox.shrink();

    final hasChildren = node.children.isNotEmpty;
    final indent = depth * 24.0;
    final categoryColor = _generateColorFromSlug(node.category.slug);

    return Column(
      key: ValueKey('category_$categoryId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: categoryColor, width: 3)),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.only(left: 12 + indent, right: 16),
            leading: node.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    node.isExpanded ? Icons.folder_open : Icons.folder,
                    color: hasChildren ? categoryColor : Colors.grey,
                  ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    node.category.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${node.category.postCount}',
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              node.category.slug,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            onTap: () => _toggleCategory(categoryId),
            trailing: hasChildren
                ? IconButton(
                    icon: Icon(
                      node.isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                    ),
                    onPressed: () => _toggleCategory(categoryId),
                  )
                : null,
          ),
        ),
        if (node.isExpanded && hasChildren)
          SizedBox(
            key: ValueKey('children_$categoryId'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: node.children
                  .map(
                    (child) => _buildCategoryNode(
                      child.category.id,
                      depth: depth + 1,
                      lineColor: categoryColor,
                    ),
                  )
                  .toList(),
            ),
          ),
        if (node.isExpanded && node.posts.isNotEmpty)
          SizedBox(
            key: ValueKey('posts_$categoryId'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 24 + indent),
                  child: Row(
                    children: [
                      Container(
                        width: 1,
                        height: 20,
                        color: lineColor.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.article_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        t(context, 'articles'),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                ...node.posts.map(
                  (post) => _buildPostTileWithLine(
                    post,
                    indent: 24 + indent,
                    lineColor: lineColor,
                  ),
                ),
              ],
            ),
          ),
        if (node.isExpanded &&
            node.posts.isNotEmpty &&
            node.category.postCount > node.posts.length)
          Padding(
            padding: EdgeInsets.only(left: 48 + indent),
            child: TextButton(
              onPressed: () async {
                final nextPage = node.page + 1;
                final res = await widget.api.listPostsByCategory(
                  categoryId: categoryId,
                  page: nextPage,
                  pageSize: 10,
                  keyword: keywordCtrl.text.trim().isEmpty
                      ? null
                      : keywordCtrl.text.trim(),
                );
                if (mounted) {
                  setState(() {
                    _categoryTreeCache[categoryId] = node.copyWith(
                      posts: [...node.posts, ...res.items],
                      page: nextPage,
                    );
                  });
                }
              },
              child: Text(t(context, 'load_more')),
            ),
          ),
      ],
    );
  }

  Widget _buildPostTileWithLine(
    PostItem it, {
    required double indent,
    required Color lineColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.only(left: indent),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 12,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1,
                      color: lineColor.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Expanded(child: _buildPostTile(it, indent: 0)),
          ],
        ),
      ),
    );
  }

  Widget _buildTreeView() {
    if (_isTreeLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_categoryTreeCache.isEmpty) {
      return Center(child: Text(t(context, 'no_categories')));
    }

    final rootCategories = _getRootCategories();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.vertical,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rootCategories.map((root) {
                    final rootColor = _generateColorFromSlug(
                      root.category.slug,
                    );
                    return _buildCategoryNode(
                      root.category.id,
                      depth: 0,
                      lineColor: rootColor,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget searchField = SizedBox(
      width: AdminBreakpoints.isPhone(context) ? double.infinity : 260,
      child: TextField(
        controller: keywordCtrl,
        decoration: InputDecoration(
          hintText: t(context, 'search_hint'),
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.search),
          isDense: true,
        ),
        onSubmitted: (value) {
          page = 1;
          if (_isTreeView) {
            _clearCategoryPostsCache();
          }
          load();
        },
      ),
    );

    return AdminPageScaffold(
      title: t(context, 'posts'),
      actions: [
        AdminActionButton(
          label: t(context, 'create'),
          icon: Icons.add,
          onPressed: () => createOrEdit(),
        ),
      ],
      filters: AdminToolbar(
        children: [
          searchField,
          FilledButton.icon(
            onPressed: () {
              page = 1;
              if (_isTreeView) {
                _clearCategoryPostsCache();
              }
              load();
            },
            icon: const Icon(Icons.search, size: 18),
            label: Text(t(context, 'search')),
          ),
          OutlinedButton.icon(
            icon: Icon(_isTreeView ? Icons.view_list : Icons.account_tree),
            onPressed: () {
              setState(() {
                _isTreeView = !_isTreeView;
              });
              if (!_isTreeView) {
                load();
              }
            },
            label: Text(
              _isTreeView ? t(context, 'list_view') : t(context, 'tree_view'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && items.isEmpty
                ? const AdminStatusView.loading(title: '正在加载文章')
                : _isTreeView
                ? _buildTreeView()
                : _buildListView(),
          ),
        ],
      ),
      footer: PaginationBar(
        currentPage: page,
        totalPages: (total / 10).ceil().clamp(1, 999999),
        totalItems: total,
        onPageChanged: (newPage) {
          setState(() => page = newPage);
          load();
        },
      ),
    );
  }
}

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
  final ScrollController _contentScrollController = ScrollController();

  int status = 0;
  int visibility = 0;
  int renderType = 0;
  int editorType = 0;
  int aiSummaryStatus = 0;
  Map<String, String> aiSummary = {};

  int? categoryId;
  List<int> tagIds = [];
  List<String> visibilityRegions = [];
  List<CategoryItem> _categories = [];
  List<TagItem> _tags = [];
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
    aiSummaryStatus = d?.aiSummaryStatus ?? 0;
    pointsPriceCtrl = TextEditingController(
      text: d?.pointsPrice?.toString() ?? '',
    );
    freeLinesCtrl = TextEditingController(text: d?.freeLines?.toString() ?? '');
    passwordCtrl = TextEditingController();
    categoryId = d?.categoryId;
    tagIds = d?.tagIds ?? [];
    visibilityRegions = d?.visibilityRegions ?? [];

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

    _sidebarTabController = TabController(length: 3, vsync: this);

    _loadCategoriesAndTags();
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
          tagIds.isNotEmpty;
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
        !_listEqualsString(visibilityRegions, _initialVisibilityRegions);
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
          ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'load_failed')}: $e')),
        );
      }
    }
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

  Future<void> _uploadMedia() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      return;
    }
    final mimeType = _resolveMimeType(file);
    try {
      final media = await widget.api.uploadMedia(
        fileName: file.name,
        bytes: bytes,
        mimeType: mimeType,
      );
      _insertMedia(media.fileName, media.url);
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t(context, 'media_inserted')}${media.fileName}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'upload_failed')}$e')),
        );
      }
    }
  }

  void _insertMedia(String fileName, String url) {
    final insertText = '![$fileName]($url)\n';
    final currentText = contentCtrl.text;
    final selection = contentCtrl.selection;
    final newText = currentText.replaceRange(
      selection.baseOffset,
      selection.extentOffset,
      insertText,
    );
    contentCtrl.text = newText;
    contentCtrl.selection = TextSelection.collapsed(
      offset: selection.baseOffset + insertText.length,
    );
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

  Future<bool> _save() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final finalContent = contentCtrl.text.trim();

    if (titleCtrl.text.trim().isEmpty) {
      scaffoldMessenger.showSnackBar(
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
        title: {'zh-cn': titleCtrl.text.trim()},
        summary: {'zh-cn': summaryCtrl.text.trim()},
        aiSummary: const {},
        contentMarkdown: {'zh-cn': finalContent},
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
          _isSaving = false;
          _isDirty = false;
        });
        await _loadRevisions();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(draftSaveSuccessText),
            action: SnackBarAction(
              label: publishNowText,
              onPressed: () {
                _publishLatestDraft();
              },
            ),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('${t(context, 'save_failed')}: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _publishLatestDraft() async {
    if (_currentDetail == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final publishSuccessText = t(context, 'publish_success');
    final operationFailedText = t(context, 'operation_failed');
    try {
      await widget.api.publishLatestDraftPost(_currentDetail!.id);
      final latestDetail = await widget.api.postDetail(_currentDetail!.id);
      if (mounted) {
        setState(() {
          _currentDetail = latestDetail;
          status = latestDetail.status;
        });
        await _loadRevisions();
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(publishSuccessText)),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('$operationFailedText: $e')),
        );
      }
    }
  }

  Future<void> _publishRevision(int revisionNumber) async {
    if (_currentDetail == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final publishSuccessText = t(context, 'publish_success');
    final operationFailedText = t(context, 'operation_failed');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'publish_revision_title')),
        content: Text(
          t(
            context,
            'publish_revision_confirm',
          ).replaceAll('%d', revisionNumber.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t(context, 'publish_this_revision')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.api.publishPostRevision(_currentDetail!.id, revisionNumber);
      final latestDetail = await widget.api.postDetail(_currentDetail!.id);
      if (mounted) {
        setState(() {
          _currentDetail = latestDetail;
          status = latestDetail.status;
        });
        await _loadRevisions();
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(publishSuccessText)),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('$operationFailedText: $e')),
        );
      }
    }
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

          _isDirty = false;
        });

        await _loadRevisions();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t(context, 'set_current_draft_success'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
                            ),
                            const SizedBox(height: 24),
                            DiffViewer(
                              title: t(context, 'summary_diff'),
                              oldText: revSummary,
                              newText: currentSummary,
                            ),
                            const SizedBox(height: 24),
                            DiffViewer(
                              title: t(context, 'content_diff'),
                              oldText: revContent,
                              newText: currentContent,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'load_revision_failed')}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final isPhone = AdminBreakpoints.isPhone(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          navigator.pop();
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
                        final success = await _save();
                        if (success && mounted) {
                          navigator.pop(null);
                        }
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
                        final success = await _save();
                        if (success && mounted) {
                          navigator.pop(null);
                        }
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
    if (renderType == 1) {
      return HtmlSyntaxEditor(controller: contentCtrl, onChanged: _markDirty);
    }
    return MarkdownPlusEditor(
      controller: contentCtrl,
      api: widget.api,
      isBlockMode: renderType == 6,
      onChanged: _markDirty,
      scrollController: _contentScrollController,
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        TabBar(
          controller: _sidebarTabController,
          tabs: [
            Tab(text: t(context, 'basic_info')),
            Tab(text: t(context, 'revisions')),
            Tab(text: t(context, 'ai_summary')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _sidebarTabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildBasicInfoTab(),
              _buildRevisionsTab(),
              _buildAiSummaryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(context, 'ai_summary_settings'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(t(context, 'ai_auto')),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(t(context, 'ai_locked')),
                  icon: const Icon(Icons.lock_outline, size: 16),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text(t(context, 'ai_disabled')),
                  icon: const Icon(Icons.block, size: 16),
                ),
              ],
              selected: {aiSummaryStatus},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  aiSummaryStatus = newSelection.first;
                  _markDirty();
                });
              },
            ),
          ),
          const SizedBox(height: 24),
          if (aiSummaryStatus != 2) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  t(context, 'ai_summary_content'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    if (_currentDetail == null) return;
                    try {
                      await widget.api.triggerAiSummary(_currentDetail!.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t(context, 'trigger_ai_success')),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
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
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text(
                    t(context, 'trigger_ai_gen'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_currentDetail?.zhAiSummary != null &&
                _currentDetail!.zhAiSummary.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentDetail!.zhAiSummary,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    t(context, 'no_ai_summary'),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              t(context, 'ai_summary_desc'),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Icon(
                      Icons.visibility_off_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t(context, 'ai_summary_disabled_status'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    final d = _currentDetail;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d != null) ...[
            Text(
              '${t(context, 'author')}: ${d.userName ?? t(context, 'unknown')}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: slugCtrl,
            decoration: InputDecoration(
              labelText: 'Slug',
              suffixIcon: IconButton(
                icon: const Icon(Icons.autorenew),
                onPressed: () {
                  final text = titleCtrl.text
                      .toLowerCase()
                      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                      .replaceAll(RegExp(r'^-+|-+$'), '');
                  slugCtrl.text = text;
                },
                tooltip: t(context, 'auto_gen_from_title'),
              ),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: summaryCtrl,
            decoration: InputDecoration(labelText: t(context, 'summary')),
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            // ignore: deprecated_member_use
            initialValue: _categories.any((c) => c.id == categoryId)
                ? categoryId
                : null,
            decoration: InputDecoration(
              labelText: t(context, 'category'),
              isDense: true,
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(t(context, 'select_category')),
              ),
              ..._categories.map(
                (cat) => DropdownMenuItem<int?>(
                  value: cat.id,
                  child: Text(cat.displayName),
                ),
              ),
            ],
            onChanged: (v) => setState(() {
              categoryId = v;
              _markDirty();
            }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            // ignore: deprecated_member_use
            initialValue: null,
            decoration: InputDecoration(
              labelText: t(context, 'tags'),
              isDense: true,
            ),
            hint: Text(
              tagIds.isEmpty
                  ? t(context, 'select_tags')
                  : t(
                      context,
                      'tags_selected_count',
                    ).replaceFirst('%d', tagIds.length.toString()),
            ),
            items: [
              ..._tags.map(
                (tag) => DropdownMenuItem<int>(
                  value: tag.id,
                  child: Row(
                    children: [
                      Icon(
                        tagIds.contains(tag.id)
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tag.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  if (tagIds.contains(v)) {
                    tagIds.remove(v);
                  } else {
                    tagIds.add(v);
                  }
                  _markDirty();
                });
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: renderType,
            decoration: InputDecoration(
              labelText: t(context, 'editor_mode'),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(
                value: 6,
                child: Text(t(context, 'block_markdown')),
              ),
              const DropdownMenuItem(value: 1, child: Text('HTML')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  renderType = v;
                  editorType = v;
                  // 根据模式切换 Controller 类型以实现语法染色
                  final currentText = contentCtrl.text;
                  if (v == 1) {
                    contentCtrl = HtmlSyntaxController(text: currentText);
                  } else {
                    contentCtrl = MarkdownSyntaxController(text: currentText);
                  }
                  contentCtrl.addListener(_markDirty);
                  _markDirty();
                });
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: visibility,
            decoration: InputDecoration(
              labelText: t(context, 'visibility_label'),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(
                value: 0,
                child: Text(t(context, 'public_visibility')),
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
            onChanged: (v) => setState(() {
              visibility = v ?? 0;
              _markDirty();
            }),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibilityRegions
                .map(
                  (region) => Chip(
                    label: Text(region.toUpperCase()),
                    onDeleted: () => setState(() {
                      visibilityRegions.remove(region);
                      _markDirty();
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: null,
            decoration: const InputDecoration(
              labelText: "添加可见区域",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.add_location_alt_outlined),
            ),
            items: [
              if (visibilityRegions.isNotEmpty)
                const DropdownMenuItem(
                  value: "__clear__",
                  child: Text("清除所有区域限制", style: TextStyle(color: Colors.red)),
                ),
              ...BlogRegion.values.map((e) {
                final bool isSelected = visibilityRegions.contains(e.code);
                return DropdownMenuItem(
                  value: e.code,
                  enabled: !isSelected,
                  child: Text(
                    e.displayName + (isSelected ? " (已选)" : ""),
                    style: TextStyle(
                      color: isSelected ? Colors.grey : null,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                );
              }),
            ],
            onChanged: (val) {
              if (val == null) return;
              if (val == "__clear__") {
                setState(() {
                  visibilityRegions.clear();
                  _markDirty();
                });
                return;
              }
              if (!visibilityRegions.contains(val)) {
                setState(() {
                  visibilityRegions.add(val);
                  _markDirty();
                });
              }
            },
          ),
          if (visibility == 2) ...[
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              decoration: InputDecoration(
                labelText: t(context, 'access_password'),
                helperText: _currentDetail?.hasPassword == true
                    ? '已设置访问密码，留空表示不修改'
                    : null,
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _uploadMedia,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(t(context, 'upload_media')),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t(context, 'monetization'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pointsPriceCtrl,
            decoration: InputDecoration(
              labelText: t(context, 'points_price'),
              prefixIcon: const Icon(Icons.monetization_on_outlined, size: 18),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: freeLinesCtrl,
            decoration: InputDecoration(
              labelText: t(context, 'free_lines'),
              prefixIcon: const Icon(Icons.visibility_outlined, size: 18),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13),
          ),
          const Divider(height: 32),
          if (d != null) ...[
            MetadataItem(t(context, 'post_id'), '${d.id}'),
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
            const Divider(height: 24),
            if (d.createdAt != null)
              MetadataItem(t(context, 'created_at'), _formatDate(d.createdAt!)),
            if (d.updatedAt != null)
              MetadataItem(t(context, 'updated_at'), _formatDate(d.updatedAt!)),
            if (d.publishedAt != null)
              MetadataItem(
                t(context, 'published_at'),
                _formatDate(d.publishedAt!),
              ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(t(context, 'system_info_after_save')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRevisionsTab() {
    if (_currentDetail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t(context, 'history_after_save')),
        ),
      );
    }

    if (_isLoadingRevisions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_revisions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t(context, 'no_history')),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _revisions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final revision = _revisions[i];
        final isCurrent =
            revision.revisionNumber == _currentDetail!.currentRevisionNumber;
        final isPublished = revision.isPublishedRevision;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(
                  context,
                  'revision_text',
                ).replaceAll('%d', revision.revisionNumber.toString()),
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                revision.zhTitle.isEmpty
                    ? t(context, 'no_title')
                    : revision.zhTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${revision.createdByName} · ${_formatDate(revision.createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (isCurrent)
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
                  if (isPublished)
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
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    return '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')} ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
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
