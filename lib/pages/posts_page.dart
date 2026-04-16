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

  @override
  void initState() {
    super.initState();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载分类失败：$e')),
      );
    }
  }

  void _buildCategoryTree() {
    _categoryTreeCache.clear();

    // 首先创建所有节点
    for (final category in _allCategories) {
      if (!_categoryTreeCache.containsKey(category.id)) {
        _categoryTreeCache[category.id] =
            CategoryTreeNode.fromCategory(category);
      }
    }

    // 然后构建父子关系
    for (final category in _allCategories) {
      if (category.parentId == null) {
        continue; // 根节点已创建
      }

      final parentNode = _categoryTreeCache[category.parentId];
      final childNode = _categoryTreeCache[category.id];

      if (parentNode != null && childNode != null) {
        // 将子节点添加到父节点的 children 列表中
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
        page: 1, // 总是从第一页开始
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载文章失败：$e')));
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

    // 展开时如果还没有加载过文章，则加载
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
      if (mounted) setState(() {});
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> createOrEdit({PostItem? item}) async {
    PostDetail? detail;
    if (item != null) {
      detail = await widget.api.postDetail(item.id);
    }
    if (!mounted) return;
    final req = await showDialog<PostEditRequest>(
      context: context,
      builder: (_) => PostDialog(detail: detail, api: widget.api),
    );
    if (req == null) return;

    try {
      if (item == null) {
        await widget.api.createPost(req);
      } else {
        await widget.api.updatePost(
          item.id,
          req.copyWith(version: detail!.version),
        );
      }
      await load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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
        subtitle: Text(
          'slug: ${it.slug} | ${t(context, 'status_text')}: ${it.statusText}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
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
        // 只在当前分类展开时显示子分类
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
        // 只在当前分类展开时显示文章
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
        // 显示加载更多按钮（仅当有更多文章时）
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
                tooltip: _isTreeView ? '列表视图' : '树状视图',
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
            child: _isTreeView ? _buildTreeView() : _buildListView(),
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

class PostDialog extends StatefulWidget {
  const PostDialog({super.key, this.detail, required this.api});

  final PostDetail? detail;
  final AdminApiClient api;

  @override
  State<PostDialog> createState() => _PostDialogState();
}

class _PostDialogState extends State<PostDialog> {
  late final TextEditingController slugCtrl;
  late final TextEditingController titleCtrl;
  late final TextEditingController summaryCtrl;
  late final TextEditingController contentCtrl;
  late final QuillController quillController;

  int status = 0;
  int visibility = 0;
  int renderType = 0;
  int editorType = 0;

  int? categoryId;
  List<int> tagIds = [];
  List<CategoryItem> _categories = [];
  List<TagItem> _tags = [];

  @override
  void initState() {
    super.initState();
    final d = widget.detail;
    slugCtrl = TextEditingController(text: d?.slug ?? '');
    titleCtrl = TextEditingController(text: d?.title['zh-cn'] ?? '');
    summaryCtrl = TextEditingController(text: d?.summary['zh-cn'] ?? '');
    contentCtrl = TextEditingController(
      text: d?.contentMarkdown['zh-cn'] ?? '',
    );

    Document document;
    final quillContent = d?.contentMarkdown['zh-cn'] ?? '';
    if (quillContent.isNotEmpty) {
      try {
        final decoded = jsonDecode(quillContent);
        document = Document.fromJson(decoded);
      } catch (_) {
        document = Document()..insert(0, quillContent);
      }
    } else {
      document = Document();
    }
    quillController = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    status = d?.status ?? 0;
    visibility = d?.visibility ?? 0;
    renderType = d?.renderType ?? 0;
    editorType = d?.editorType ?? 0;
    categoryId = d?.categoryId;
    tagIds = d?.tagIds ?? [];

    _loadCategoriesAndTags();
  }

  Future<void> _loadCategoriesAndTags() async {
    try {
      final cats = await widget.api.listCategories();
      final tags = await widget.api.listTags();
      if (mounted) {
        setState(() {
          // 去重：确保每个 ID 只有一个分类
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载分类和标签失败：$e')),
      );
    }
  }

  @override
  void dispose() {
    slugCtrl.dispose();
    titleCtrl.dispose();
    summaryCtrl.dispose();
    contentCtrl.dispose();
    quillController.dispose();
    super.dispose();
  }

  Widget _buildEditorPane() {
    return SizedBox(
      height: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: _uploadMedia,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(t(context, 'upload_media')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
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
    if (editorType == 5) {
      return _buildQuillEditor();
    } else if (editorType == 6) {
      return _buildMarkdownPlusEditor();
    }
    return _buildMarkdownEditor();
  }

  Widget _buildQuillEditor() {
    return Column(
      children: [
        QuillSimpleToolbar(
          controller: quillController,
          config: const QuillSimpleToolbarConfig(),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.text,
            child: Container(
              color: Colors.white,
              child: QuillEditor.basic(
                controller: quillController,
                config: const QuillEditorConfig(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarkdownPlusEditor() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.code, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Flutter Markdown Plus Editor',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownEditor() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
          child: TextField(
            controller: contentCtrl,
            decoration: InputDecoration(
              labelText: t(context, 'markdown_content'),
              border: const OutlineInputBorder(),
            ),
            minLines: 12,
            maxLines: null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: contentCtrl,
                      builder: (context, value, child) {
                        if (value.text.trim().isEmpty) {
                          return Center(
                            child: Text(
                              t(context, 'markdown_content'),
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          );
                        }
                        return SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: MarkdownBody(data: value.text),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _uploadMedia() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
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
    if (editorType == 5) {
      final index = quillController.selection.baseOffset;
      quillController.document.insert(index, BlockEmbed.image(url));
      quillController.moveCursorToPosition(index + 1);
    } else if (editorType == 0 || editorType == 6) {
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
  }

  String _getContent() {
    if (editorType == 5) {
      final content = jsonEncode(quillController.document.toDelta().toJson());
      return content;
    } else if (editorType == 0 || editorType == 6) {
      return contentCtrl.text;
    }
    return contentCtrl.text;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.detail == null ? t(context, 'new_post') : t(context, 'edit_post')),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: slugCtrl,
                decoration: InputDecoration(labelText: t(context, 'slug')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(labelText: t(context, 'title')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: summaryCtrl,
                decoration: InputDecoration(labelText: t(context, 'summary')),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              _buildEditorPane(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _categories.any((c) => c.id == categoryId)
                          ? categoryId
                          : null,
                      decoration: InputDecoration(
                          labelText: t(context, 'category')),
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
                      onChanged: (v) => setState(() => categoryId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: null,
                      decoration: InputDecoration(
                          labelText: t(context, 'tags')),
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
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: status,
                      decoration: InputDecoration(
                          labelText: t(context, 'status')),
                      items: [
                        DropdownMenuItem(value: 0, child: Text(t(
                            context, 'draft'))),
                        DropdownMenuItem(value: 1, child: Text(t(
                            context, 'published'))),
                        DropdownMenuItem(value: 2, child: Text(t(
                            context, 'archived'))),
                      ],
                      onChanged: (v) => setState(() => status = v ?? 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: visibility,
                      decoration: InputDecoration(
                          labelText: t(context, 'visibility')),
                      items: [
                        DropdownMenuItem(value: 0, child: Text(t(
                            context, 'public'))),
                        DropdownMenuItem(value: 1, child: Text(t(
                            context, 'private'))),
                        DropdownMenuItem(value: 2, child: Text(t(
                            context, 'protected'))),
                      ],
                      onChanged: (v) => setState(() => visibility = v ?? 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: renderType,
                      decoration: InputDecoration(
                          labelText: t(context, 'render_type')),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Markdown')),
                        DropdownMenuItem(value: 1, child: Text('HTML')),
                        DropdownMenuItem(value: 2, child: Text('Vditor')),
                        DropdownMenuItem(value: 3, child: Text('V Builder')),
                        DropdownMenuItem(value: 4, child: Text('Gutenberg')),
                        DropdownMenuItem(
                            value: 5, child: Text('Flutter Quill')),
                        DropdownMenuItem(
                            value: 6, child: Text('Flutter Markdown Plus')),
                      ],
                      onChanged: (v) => setState(() => renderType = v ?? 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: editorType,
                      decoration: const InputDecoration(
                          labelText: 'Editor Type'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Markdown')),
                        DropdownMenuItem(
                            value: 5, child: Text('Flutter Quill')),
                        DropdownMenuItem(
                            value: 6, child: Text('Flutter Markdown Plus')),
                      ],
                      onChanged: (v) => setState(() => editorType = v ?? 0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t(context, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            final finalContent = _getContent().trim();
            if (slugCtrl.text.trim().isEmpty ||
                titleCtrl.text.trim().isEmpty ||
                finalContent.isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              PostEditRequest(
                slug: slugCtrl.text.trim(),
                title: {'zh-cn': titleCtrl.text.trim()},
                summary: {'zh-cn': summaryCtrl.text.trim()},
                aiSummary: const {},
                contentMarkdown: {'zh-cn': finalContent},
                status: status,
                visibility: visibility,
                renderType: renderType,
                editorType: editorType,
                version: 0,
                categoryId: categoryId,
                tagIds: tagIds,
              ),
            );
          },
          child: Text(t(context, 'save')),
        ),
      ],
    );
  }
}
