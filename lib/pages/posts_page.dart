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
          SnackBar(content: Text('加载分类失败：$e')),
        );
      }
    }
  }

  void _buildCategoryTree() {
    _categoryTreeCache.clear();

    for (final category in _allCategories) {
      if (!_categoryTreeCache.containsKey(category.id)) {
        _categoryTreeCache[category.id] =
            CategoryTreeNode.fromCategory(category);
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
        _categoryTreeCache[category.parentId!] =
            parentNode.copyWith(children: updatedChildren);
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
        keyword: keywordCtrl.text
            .trim()
            .isEmpty ? null : keywordCtrl.text.trim(),
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
          SnackBar(content: Text('加载文章失败：$e')),
        );
      }
    }
  }

  Future<void> _toggleCategory(int categoryId) async {
    final node = _categoryTreeCache[categoryId];
    if (node == null) return;

    final willExpand = !node.isExpanded;

    setState(() {
      _categoryTreeCache[categoryId] = node.copyWith(
        isExpanded: willExpand,
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> createOrEdit({PostItem? item}) async {
    PostDetail? detail;
    if (item != null) {
      detail = await widget.api.postDetail(item.id);
    }
    if (!mounted) return;

    await Navigator.push<PostEditRequest?>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PostEditorPage(
              detail: detail,
              api: widget.api,
            ),
      ),
    );

    await load();
  }

  Widget _buildListView() {
    return Card(
      child: ListView.separated(
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
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'slug: ${it.slug} | ${t(context, 'status_text')}: ${it
                  .statusText}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
            if (it.aiSummaryStatus != 2)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: it.aiSummaryStatus == 0
                            ? Colors.blue.shade50
                            : Colors.green.shade50,
                        border: Border.all(
                            color: it.aiSummaryStatus == 0 ? Colors.blue
                                .shade200 : Colors.green.shade200),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        it.aiSummaryStatus == 0 ? 'AI: 自动' : 'AI: 手动/锁定',
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
                  t(context, 'edit'), style: const TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await widget.api.publishPost(it.id);
                  await load();
                } on UnauthorizedException {
                  widget.onAuthError();
                }
              },
              child: Text(
                  t(context, 'publish'), style: const TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await widget.api.deletePost(it.id);
                  await load();
                } on UnauthorizedException {
                  widget.onAuthError();
                }
              },
              child: Text(
                  t(context, 'delete'), style: const TextStyle(fontSize: 12)),
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

  Widget _buildCategoryNode(int categoryId,
      {int depth = 0, required Color lineColor}) {
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
            border: Border(
              left: BorderSide(
                color: categoryColor,
                width: 3,
              ),
            ),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.only(
              left: 12 + indent,
              right: 16,
            ),
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
                      horizontal: 6, vertical: 2),
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
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
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
              children: node.children.map((child) =>
                  _buildCategoryNode(child.category.id, depth: depth + 1,
                      lineColor: categoryColor)).toList(),
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
                      Icon(Icons.article_outlined, size: 16,
                          color: Colors.grey.shade600),
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
                ...node.posts.map((post) =>
                    _buildPostTileWithLine(
                        post, indent: 24 + indent, lineColor: lineColor)),
              ],
            ),
          ),
        if (node.isExpanded && node.posts.isNotEmpty &&
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
                  keyword: keywordCtrl.text
                      .trim()
                      .isEmpty
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

  Widget _buildPostTileWithLine(PostItem it,
      {required double indent, required Color lineColor}) {
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
            Expanded(
              child: _buildPostTile(it, indent: 0),
            ),
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
              scrollDirection: Axis.vertical,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rootCategories.map((root) {
                    final rootColor = _generateColorFromSlug(root.category
                        .slug);
                    return _buildCategoryNode(root.category.id, depth: 0,
                        lineColor: rootColor);
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: keywordCtrl,
                  decoration: InputDecoration(
                    hintText: t(context, 'search_hint'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  page = 1;
                  if (_isTreeView) {
                    _clearCategoryPostsCache();
                  }
                  load();
                },
                child: Text(t(context, 'search')),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: Icon(_isTreeView ? Icons.view_list : Icons.account_tree),
                onPressed: () {
                  setState(() {
                    _isTreeView = !_isTreeView;
                  });
                  if (!_isTreeView) {
                    load();
                  }
                },
                tooltip: _isTreeView ? t(context, 'list_view') : t(context, 'tree_view'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => createOrEdit(),
                child: Text(t(context, 'create')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading && items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _isTreeView
                    ? _buildTreeView()
                    : _buildListView(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${t(context, 'total')}: $total'),
              const Spacer(),
              IconButton(
                onPressed: page <= 1
                    ? null
                    : () {
                        setState(() => page--);
                        load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${t(context, 'page')} $page ${t(context, 'page')}'),
              IconButton(
                onPressed: page * 10 >= total
                    ? null
                    : () {
                        setState(() => page++);
                        load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
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
  late final TextEditingController contentCtrl;
  late final TabController _sidebarTabController;

  int status = 0;
  int visibility = 0;
  int renderType = 0;
  int editorType = 0;
  int aiSummaryStatus = 0;
  Map<String, String> aiSummary = {};

  int? categoryId;
  List<int> tagIds = [];
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

  PostDetail? _currentDetail;

  @override
  void initState() {
    super.initState();
    _currentDetail = widget.detail;
    final d = _currentDetail;
    slugCtrl = TextEditingController(text: d?.slug ?? '');
    titleCtrl = TextEditingController(text: d?.title['zh-cn'] ?? '');
    summaryCtrl = TextEditingController(text: d?.summary['zh-cn'] ?? '');
    contentCtrl = TextEditingController(
      text: d?.contentMarkdown['zh-cn'] ?? '',
    );

    status = d?.status ?? 0;
    visibility = d?.visibility ?? 0;
    renderType = d?.renderType ?? 0;
    editorType = d?.editorType ?? 0;
    aiSummaryStatus = d?.aiSummaryStatus ?? 0;
    categoryId = d?.categoryId;
    tagIds = d?.tagIds ?? [];

    _initialSlug = d?.slug;
    _initialTitle = d?.title['zh-cn'];
    _initialSummary = d?.summary['zh-cn'];
    _initialContent = d?.contentMarkdown['zh-cn'];
    _initialStatus = d?.status;
    _initialVisibility = d?.visibility;
    _initialRenderType = d?.renderType;
    _initialEditorType = d?.editorType;
    _initialAiSummaryStatus = d?.aiSummaryStatus;
    _initialCategoryId = d?.categoryId;
    _initialTagIds = d?.tagIds != null ? List<int>.from(d!.tagIds) : null;

    _sidebarTabController = TabController(length: 3, vsync: this);

    _loadCategoriesAndTags();
    if (_currentDetail != null) {
      _loadRevisions();
    }

    titleCtrl.addListener(_onTitleChanged);
    slugCtrl.addListener(_markDirty);
    summaryCtrl.addListener(_markDirty);
    contentCtrl.addListener(_markDirty);
  }

  void _onTitleChanged() {
    if (widget.detail == null || _initialSlug == null ||
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
    return title.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'), '-').replaceAll(
        RegExp(r'^-+|-+$'), '');
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
      return currentSlug.isNotEmpty || currentTitle.isNotEmpty ||
          currentSummary.isNotEmpty || currentContent.isNotEmpty ||
          status != 0 || visibility != 0 || categoryId != null ||
          tagIds.isNotEmpty;
    }

    return currentSlug != _initialSlug ||
        currentTitle != _initialTitle ||
        currentSummary != _initialSummary ||
        currentContent != _initialContent ||
        status != _initialStatus ||
        visibility != _initialVisibility ||
        renderType != _initialRenderType ||
        editorType != _initialEditorType ||
        aiSummaryStatus != _initialAiSummaryStatus ||
        categoryId != _initialCategoryId ||
        !_listEquals(tagIds, _initialTagIds);
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
            SnackBar(content: Text('加载版本列表失败：$e')),
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
          SnackBar(content: Text('加载分类和标签失败：$e')),
        );
      }
    }
  }

  @override
  void dispose() {
    slugCtrl.dispose();
    titleCtrl.dispose();
    summaryCtrl.dispose();
    contentCtrl.dispose();
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
          SnackBar(content: Text('${t(context, 'media_inserted')}${media.fileName}')),
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
      builder: (context) =>
          AlertDialog(
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

    if (slugCtrl.text.trim().isEmpty ||
        titleCtrl.text.trim().isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('请填写必填字段')),
      );
      return false;
    }

    setState(() => _isSaving = true);
    try {
      final request = PostEditRequest(
        slug: slugCtrl.text.trim(),
        title: {'zh-cn': titleCtrl.text.trim()},
        summary: {'zh-cn': summaryCtrl.text.trim()},
        aiSummary: const {},
        contentMarkdown: {'zh-cn': finalContent},
        status: status,
        visibility: visibility,
        renderType: renderType,
        editorType: editorType,
        aiSummaryStatus: aiSummaryStatus,
        version: _currentDetail?.version ?? 0,
        categoryId: categoryId,
        tagIds: tagIds,
      );

      if (_currentDetail == null) {
        await widget.api.createPost(request);
      } else {
        await widget.api.updatePost(
          _currentDetail!.id,
          request.copyWith(version: _currentDetail!.version),
        );
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isDirty = false;
        });
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(t(context, 'save_success'))),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
      return false;
    }
  }

  Future<void> _switchToRevision(int revisionNumber) async {
    if (_currentDetail == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('切换版本'),
            content: Text(
                '确定要切换到版本 $revisionNumber 吗？这将创建一个新版本。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定'),
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
          titleCtrl.text = newDetail.title['zh-cn'] ?? '';
          summaryCtrl.text = newDetail.summary['zh-cn'] ?? '';
          contentCtrl.text = newDetail.contentMarkdown['zh-cn'] ?? '';

          status = newDetail.status;
          visibility = newDetail.visibility;
          renderType = newDetail.renderType;
          editorType = newDetail.editorType;
          categoryId = newDetail.categoryId;
          tagIds = newDetail.tagIds;

          _initialSlug = newDetail.slug;
          _initialTitle = newDetail.title['zh-cn'];
          _initialSummary = newDetail.summary['zh-cn'];
          _initialContent = newDetail.contentMarkdown['zh-cn'];
          _initialStatus = newDetail.status;
          _initialVisibility = newDetail.visibility;
          _initialRenderType = newDetail.renderType;
          _initialEditorType = newDetail.editorType;
          _initialAiSummaryStatus = newDetail.aiSummaryStatus;
          _initialCategoryId = newDetail.categoryId;
          _initialTagIds = List<int>.from(newDetail.tagIds);

          _isDirty = false;
        });

        await _loadRevisions();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('版本切换成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('版本切换失败：$e')),
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

        final revTitle = revisionDetail.title['zh-cn'] ?? '';
        final revSummary = revisionDetail.summary['zh-cn'] ?? '';
        final revContent = revisionDetail.contentMarkdown['zh-cn'] ?? '';

        showDialog(
          context: context,
          builder: (context) {
            final screenSize = MediaQuery.of(context).size;
            return AlertDialog(
              title: Text('版本 $revisionNumber 对比'),
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
                          const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '提示：红色删除线部分来自版本 $revisionNumber，绿色背景部分为当前编辑器中的内容。',
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
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
                              title: '标题对比',
                              oldText: revTitle,
                              newText: currentTitle,
                            ),
                            const SizedBox(height: 24),
                            DiffViewer(
                              title: '摘要对比',
                              oldText: revSummary,
                              newText: currentSummary,
                            ),
                            const SizedBox(height: 24),
                            DiffViewer(
                              title: '正文对比',
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
                  child: const Text('关闭'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _switchToRevision(revisionNumber);
                  },
                  icon: const Icon(Icons.history_edu, size: 18),
                  label: const Text('切换到此版本'),
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
          SnackBar(content: Text('加载版本详情失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
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
          title: Text(_currentDetail == null ? t(context, 'new_post') : t(
              context, 'edit_post')),
          actions: [
            if (_isDirty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(t(context, 'unsaved'), style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.orange.shade100,
                  labelStyle: TextStyle(color: Colors.orange.shade800),
                ),
              ),
            TextButton(
              onPressed: _isSaving ? null : () async {
                final shouldPop = await _onWillPop();
                if (shouldPop && mounted) {
                  navigator.pop();
                }
              },
              child: Text(t(context, 'cancel')),
            ),
            FilledButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                final success = await _save();
                if (success) {
                  if (mounted) {
                    navigator.pop(null);
                  }
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
            const SizedBox(width: 8),
          ],
        ),
        body: Row(
          children: [
            Expanded(
              child: _buildEditorPane(),
            ),
            Container(
              width: 320,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey.shade300)),
              ),
              child: _buildSidebar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorPane() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: slugCtrl,
            decoration: InputDecoration(
              labelText: 'Slug',
              suffixIcon: IconButton(
                icon: const Icon(Icons.autorenew),
                onPressed: () {
                  slugCtrl.text = _generateSlug(titleCtrl.text);
                },
                tooltip: '根据标题自动生成',
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleCtrl,
            decoration: InputDecoration(
              labelText: t(context, 'title'),
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: summaryCtrl,
            decoration: InputDecoration(
              labelText: t(context, 'summary'),
            ),
            minLines: 2,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _uploadMedia,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(t(context, 'upload_media')),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
                        value: status,
                        decoration: InputDecoration(
                          labelText: t(context, 'status'),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(value: 0, child: Text(t(
                              context, 'draft'))),
                          DropdownMenuItem(value: 1, child: Text(t(
                              context, 'published'))),
                          DropdownMenuItem(value: 2, child: Text(t(
                              context, 'archived'))),
                        ],
                        onChanged: (v) =>
                            setState(() {
                              status = v ?? 0;
                              _markDirty();
                            }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
                        value: visibility,
                        decoration: InputDecoration(
                          labelText: t(context, 'visibility'),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(value: 0, child: Text(t(
                              context, 'public'))),
                          DropdownMenuItem(value: 1, child: Text(t(
                              context, 'private'))),
                          DropdownMenuItem(value: 2, child: Text(t(
                              context, 'protected'))),
                        ],
                        onChanged: (v) =>
                            setState(() {
                              visibility = v ?? 0;
                              _markDirty();
                            }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  // ignore: deprecated_member_use
                  value: _categories.any((c) => c.id == categoryId)
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
                    ..._categories.map((cat) =>
                        DropdownMenuItem<int?>(
                          value: cat.id,
                          child: Text(cat.displayName),
                        )),
                  ],
                  onChanged: (v) =>
                      setState(() {
                        categoryId = v;
                        _markDirty();
                      }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  // ignore: deprecated_member_use
                  value: null,
                  decoration: InputDecoration(
                    labelText: t(context, 'tags'),
                    isDense: true,
                  ),
                  hint: Text(tagIds.isEmpty
                      ? t(context, 'select_tags')
                      : '${tagIds.length} tags'),
                  items: [
                    ..._tags.map((tag) =>
                        DropdownMenuItem<int>(
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
                              Text(tag.displayName),
                            ],
                          ),
                        )),
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
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: renderType,
                  decoration: InputDecoration(
                    labelText: t(context, 'render_type'),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('Markdown')),
                    const DropdownMenuItem(value: 1, child: Text('HTML')),
                    const DropdownMenuItem(value: 6, child: Text('区块化 Markdown')),
                    if (renderType == 7)
                      const DropdownMenuItem(value: 7, child: Text('Tutorial Block (Deprecated)')),
                  ],
                  onChanged: (v) =>
                      setState(() {
                        renderType = v ?? 0;
                        _markDirty();
                      }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: editorType,
                  decoration: const InputDecoration(
                    labelText: 'Editor Type',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('Markdown')),
                    const DropdownMenuItem(value: 1, child: Text('HTML')),
                    const DropdownMenuItem(value: 6, child: Text('区块化 Markdown')),
                    if (editorType == 7)
                      const DropdownMenuItem(value: 7, child: Text('Tutorial Block (Deprecated)')),
                  ],
                  onChanged: (v) =>
                      setState(() {
                        editorType = v ?? 0;
                        _markDirty();
                      }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 500, maxHeight: 800),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _buildEditor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return _buildMarkdownEditor();
  }

  Widget _buildMarkdownEditor() {
    return MarkdownPlusEditor(
      controller: contentCtrl,
      api: widget.api,
      isBlockMode: renderType == 6,
      onChanged: _markDirty,
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        TabBar(
          controller: _sidebarTabController,
          tabs: const [
            Tab(text: '元数据'),
            Tab(text: '版本修订'),
            Tab(text: 'AI 摘要'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _sidebarTabController,
            children: [
              _buildMetadataTab(),
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
            'AI 摘要设置',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('自动'),
                icon: Icon(Icons.auto_awesome, size: 16),
              ),
              ButtonSegment(
                value: 1,
                label: Text('锁定'),
                icon: Icon(Icons.lock_outline, size: 16),
              ),
              ButtonSegment(
                value: 2,
                label: Text('禁用'),
                icon: Icon(Icons.block, size: 16),
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
          const SizedBox(height: 24),
          if (aiSummaryStatus != 2) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '摘要内容 (ZH-CN)',
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
                          const SnackBar(content: Text(
                              '已成功触发 AI 摘要任务'), backgroundColor: Colors
                              .green),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('触发失败: $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('触发生成', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_currentDetail?.aiSummary['zh-cn'] != null &&
                _currentDetail!.aiSummary['zh-cn']!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentDetail!.aiSummary['zh-cn']!,
                  style: const TextStyle(
                      fontSize: 13, height: 1.5, fontStyle: FontStyle.italic),
                ),
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('暂无摘要内容',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              '说明：自动模式下更新文章会重新生成摘要。手动锁定后将保留已有内容。禁用后在前台不显示摘要板块。',
              style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.5),
            ),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.visibility_off_outlined, size: 48,
                        color: Colors.grey),
                    SizedBox(height: 16),
                    Text('AI 摘要已禁用', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetadataTab() {
    final d = _currentDetail;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d != null) ...[
            MetadataItem('文章 ID', '${d.id}'),
            MetadataItem('当前版本', '${d.currentRevisionNumber}'),
            MetadataItem('数据版本', '${d.version}'),
            const Divider(height: 24),
            if (d.createdAt != null)
              MetadataItem('创建时间', _formatDate(d.createdAt!)),
            if (d.updatedAt != null)
              MetadataItem('更新时间', _formatDate(d.updatedAt!)),
            if (d.publishedAt != null)
              MetadataItem('发布时间', _formatDate(d.publishedAt!)),
          ] else
            ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('保存后显示元数据'),
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildRevisionsTab() {
    if (_currentDetail == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('保存后显示版本历史'),
        ),
      );
    }

    if (_isLoadingRevisions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_revisions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('暂无版本历史'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _revisions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final revision = _revisions[i];
        final isCurrent = revision.revisionNumber ==
            _currentDetail!.currentRevisionNumber;
        return ListTile(
          title: Text(
            '版本 ${revision.revisionNumber}',
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                revision.zhTitle.isEmpty ? '无标题' : revision.zhTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${revision.createdByName} · ${_formatDate(
                    revision.createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          trailing: isCurrent
              ? Chip(
            label: const Text('当前', style: TextStyle(fontSize: 10)),
            backgroundColor: Colors.green.shade100,
            labelStyle: TextStyle(color: Colors.green.shade800),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          )
              : Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: () => _showDiff(revision.revisionNumber),
                    child: const Text('对比'),
                  ),
                  TextButton(
                    onPressed: () => _switchToRevision(revision.revisionNumber),
                    child: const Text('切换'),
                  ),
                ],
              ),
          dense: true,
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day
        .toString().padLeft(2, '0')} ${date.hour.toString().padLeft(
        2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
