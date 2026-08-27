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
        AdminFeedback.showSnackBar(
          context,
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
        AdminFeedback.showSnackBar(
          context,
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
        AdminFeedback.showSnackBar(context, SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> createOrEdit({PostItem? item}) async {
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
        AdminFeedback.showSnackBar(
          context,
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
                try {
                  await widget.api.publishLatestDraftPost(it.id);
                  await load();
                } on UnauthorizedException {
                  widget.onAuthError();
                } catch (e) {
                  if (mounted) {
                    AdminFeedback.showSnackBar(
                      context,
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
                    AdminFeedback.showSnackBar(
                      context,
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
      child: AdminShortcutSearchField(
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
            label: AdminShortcutText(
              t(context, 'search'),
              AdminShortcutDefinitions.keyByAction['search']!,
            ),
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
