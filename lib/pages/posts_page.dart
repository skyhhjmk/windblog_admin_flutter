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

enum _PostAction { edit, quickEdit, comments, publish, delete }

class PostsPage extends StatefulWidget {
  const PostsPage({
    super.key,
    required this.api,
    required this.onAuthError,
    this.searchController,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;
  final TextEditingController? searchController;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  late final TextEditingController keywordCtrl;
  late final bool _ownsSearchController;
  List<PostItem> items = [];
  int page = 1;
  int total = 0;
  String _sortBy = 'id';

  bool _isTreeView = false;
  final Map<int, CategoryTreeNode> _categoryTreeCache = {};
  List<CategoryItem> _allCategories = [];
  bool _isTreeLoading = false;
  bool _loading = true;
  int? _statusFilter;
  final Set<int> _selected = {};
  bool _bulkRunning = false;

  @override
  void initState() {
    super.initState();
    keywordCtrl = widget.searchController ?? TextEditingController();
    _ownsSearchController = widget.searchController == null;
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

  Future<void> _refresh() async {
    await Future.wait([_loadAllCategories(), load()]);
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
    if (_ownsSearchController) keywordCtrl.dispose();
    super.dispose();
  }

  void applySearch() {
    page = 1;
    _selected.clear();
    if (_isTreeView) _clearCategoryPostsCache();
    load();
  }

  Future<void> load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.listPosts(
        page: page,
        pageSize: 10,
        sortBy: _sortBy,
        status: _statusFilter,
        keyword: keywordCtrl.text.trim().isEmpty
            ? null
            : keywordCtrl.text.trim(),
      );
      items = res.items;
      total = res.total;
      _selected.removeWhere((id) => !items.any((item) => item.id == id));
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
    final opened = await openPostEditor(
      context: context,
      api: widget.api,
      postId: item?.id,
      onAuthError: widget.onAuthError,
      onLoadError: (error) {
        if (mounted) {
          AdminFeedback.showSnackBar(
            context,
            SnackBar(
              content: Text('${t(context, 'operation_failed')}: $error'),
            ),
          );
        }
      },
    );
    if (opened) await load();
  }

  Future<void> _openQuickEdit(PostItem item) async {
    final updated = await showDialog<PostItem>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => QuickEditPostDialog(
        item: item,
        api: widget.api,
        categories: _allCategories,
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        final idx = items.indexWhere((it) => it.id == updated.id);
        if (idx != -1) {
          items[idx] = updated;
        }
      });
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text(t(context, 'quick_edit_success'))),
      );
    }
  }

  Future<void> _publishLatestDraft(PostItem item) async {
    try {
      await widget.api.publishLatestDraftPost(item.id);
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

  Future<void> _deletePost(PostItem item) async {
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

    if (confirmed != true || !mounted) return;

    try {
      await widget.api.deletePost(item.id);
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
      return AdminStatusView.empty(
        title: t(context, 'no_posts'),
        message: keywordCtrl.text.trim().isEmpty && _statusFilter == null
            ? null
            : '当前筛选条件下没有文章。',
      );
    }
    final isPhone = AdminBreakpoints.isPhone(context);
    if (isPhone) {
      return ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: items.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildMobilePostCard(items[i]),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildTableHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (_, i) => _buildDesktopPostRow(items[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final showAuthor = !AdminBreakpoints.isTablet(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      color: const Color(0xFFF1F5F9),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: _selected.isEmpty
                  ? false
                  : (_selected.length == items.length ? true : null),
              tristate: true,
              onChanged: (value) => _toggleSelectAll(value == true),
            ),
          ),
          const Expanded(
            flex: 5,
            child: Text('标题', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            flex: 2,
            child: Text('分类', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          if (showAuthor)
            const SizedBox(
              width: 110,
              child: Text('作者', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          const SizedBox(
            width: 96,
            child: Text('状态', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(
            width: 128,
            child: Text('更新时间', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(
            width: 96,
            child: Text(
              '操作',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPostRow(PostItem it) {
    final selected = _selected.contains(it.id);
    final showAuthor = !AdminBreakpoints.isTablet(context);
    return InkWell(
      onTap: () => createOrEdit(item: it),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                value: selected,
                onChanged: (value) => _toggleSelected(it, value == true),
              ),
            ),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          it.zhTitle.isEmpty ? it.slug : it.zhTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (it.articleMode == 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('教程', style: TextStyle(color: Colors.indigo, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ] else if (it.articleMode == 2) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('资源', style: TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      if (it.aiSummaryStatus != 0) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: it.aiSummaryStatus == 1
                              ? 'AI 摘要已锁定'
                              : 'AI 摘要已关闭',
                          child: Icon(
                            it.aiSummaryStatus == 1
                                ? Icons.lock_outline
                                : Icons.auto_awesome_outlined,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                      if (it.visibility != 0) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: it.visibility == 1 ? '私密文章' : '密码保护',
                          child: Icon(
                            it.visibility == 1 ? Icons.lock : Icons.key,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Text(
                _categoryNames(it),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            if (showAuthor)
              SizedBox(
                width: 110,
                child: Text(
                  it.userName ?? t(context, 'unknown'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            SizedBox(width: 96, child: _statusBadge(it.status)),
            SizedBox(
              width: 128,
              child: Text(
                _formatDate(it.updatedAt ?? it.createdAt),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
            SizedBox(
              width: 96,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.bolt, size: 18, color: Color(0xFFF59E0B)),
                    tooltip: t(context, 'quick_edit'),
                    onPressed: () => _openQuickEdit(it),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  _buildPostActions(it),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePostCard(PostItem it) {
    final selected = _selected.contains(it.id);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => createOrEdit(item: it),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: (value) => _toggleSelected(it, value == true),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            it.zhTitle.isEmpty ? it.slug : it.zhTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusBadge(it.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        it.userName ?? t(context, 'unknown'),
                        _categoryNames(it),
                        if (it.visibility != 0)
                          it.visibility == 1 ? '私密' : '密码保护',
                      ].where((value) => value.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '更新 ${_formatDate(it.updatedAt ?? it.createdAt)}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _buildPostActions(it),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSelected(PostItem item, bool value) {
    setState(() {
      if (value) {
        _selected.add(item.id);
      } else {
        _selected.remove(item.id);
      }
    });
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      if (value) {
        _selected.addAll(items.map((item) => item.id));
      } else {
        _selected.clear();
      }
    });
  }

  String _categoryNames(PostItem item) {
    if (item.categoryIds.isEmpty) {
      return item.categoryId == null ? '未分类' : '分类 #${item.categoryId}';
    }
    final names = <String>[];
    for (final id in item.categoryIds.take(2)) {
      CategoryItem? category;
      for (final entry in _allCategories) {
        if (entry.id == id) {
          category = entry;
          break;
        }
      }
      names.add(category?.displayName ?? '#$id');
    }
    if (item.categoryIds.length > 2) {
      names.add('+${item.categoryIds.length - 2}');
    }
    return names.join(' / ');
  }

  Widget _statusBadge(int status) {
    final (label, color) = switch (status) {
      1 => ('已发布', Colors.green),
      2 => ('已归档', Colors.blueGrey),
      _ => ('草稿', Colors.orange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _bulkActionBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '已选 ${_selected.length} 篇',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_bulkRunning)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            TextButton(
              onPressed: _bulkRunning ? null : () => setState(_selected.clear),
              child: const Text('取消选择'),
            ),
            OutlinedButton.icon(
              onPressed: _bulkRunning ? null : _bulkPublish,
              icon: const Icon(Icons.publish_outlined, size: 17),
              label: const Text('发布草稿'),
            ),
            TextButton.icon(
              onPressed: _bulkRunning ? null : _bulkDelete,
              icon: Icon(
                Icons.delete_outline,
                size: 17,
                color: Colors.red.shade600,
              ),
              label: Text('删除', style: TextStyle(color: Colors.red.shade600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkPublish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('批量发布'),
        content: Text('将发布所选 ${_selected.length} 篇文章的最新草稿，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('发布'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _bulkRunning = true);
    try {
      for (final id in _selected.toList()) {
        await widget.api.publishLatestDraftPost(id);
      }
      if (mounted) {
        AdminFeedback.success(context, '已发布 ${_selected.length} 篇文章');
      }
      _selected.clear();
      await load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, '批量发布失败：$error');
    } finally {
      if (mounted) setState(() => _bulkRunning = false);
    }
  }

  Future<void> _bulkDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('将删除所选 ${_selected.length} 篇文章，此操作不可撤销。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t(context, 'cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t(context, 'delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _bulkRunning = true);
    try {
      for (final id in _selected.toList()) {
        await widget.api.deletePost(id);
      }
      if (mounted) {
        AdminFeedback.success(context, '已删除 ${_selected.length} 篇文章');
      }
      _selected.clear();
      await load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, '批量删除失败：$error');
    } finally {
      if (mounted) setState(() => _bulkRunning = false);
    }
  }

  void _viewComments(PostItem item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(t(context, 'view_comments'))),
          body: CommentsPage(
            api: widget.api,
            onAuthError: widget.onAuthError,
            postId: item.id,
            postTitle: item.zhTitle.isEmpty ? item.slug : item.zhTitle,
          ),
        ),
      ),
    );
  }

  Widget _buildPostActions(PostItem item) {
    return PopupMenuButton<_PostAction>(
      tooltip: t(context, 'more_actions'),
      icon: const Icon(Icons.more_horiz, size: 20),
      onSelected: (action) {
        switch (action) {
          case _PostAction.edit:
            createOrEdit(item: item);
          case _PostAction.quickEdit:
            _openQuickEdit(item);
          case _PostAction.comments:
            _viewComments(item);
          case _PostAction.publish:
            _publishLatestDraft(item);
          case _PostAction.delete:
            _deletePost(item);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _PostAction.edit,
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 10),
              Text(t(context, 'edit')),
            ],
          ),
        ),
        PopupMenuItem(
          value: _PostAction.quickEdit,
          child: Row(
            children: [
              const Icon(Icons.bolt, size: 18, color: Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              Text(t(context, 'quick_edit')),
            ],
          ),
        ),
        PopupMenuItem(
          value: _PostAction.comments,
          child: Row(
            children: [
              const Icon(Icons.comment_outlined, size: 18),
              const SizedBox(width: 10),
              Text(t(context, 'view_comments')),
            ],
          ),
        ),
        PopupMenuItem(
          value: _PostAction.publish,
          child: Row(
            children: [
              const Icon(Icons.publish_outlined, size: 18),
              const SizedBox(width: 10),
              Text(t(context, 'publish_latest_draft')),
            ],
          ),
        ),
        PopupMenuItem(
          value: _PostAction.delete,
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              const SizedBox(width: 10),
              Text(
                t(context, 'delete'),
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostTile(PostItem it, {double indent = 0}) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 8, right: 8),
        leading: Icon(
          Icons.description_outlined,
          size: 18,
          color: Colors.grey.shade500,
        ),
        title: Text(
          it.zhTitle.isEmpty ? it.slug : it.zhTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        subtitle: Text(
          '${it.userName ?? t(context, 'unknown')} · ${_formatDate(it.updatedAt ?? it.createdAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusBadge(it.status),
            const SizedBox(width: 4),
            IconButton(
              tooltip: t(context, 'edit'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 17),
              onPressed: () => createOrEdit(item: it),
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

  void _changeStatusFilter(int? value) {
    if (_statusFilter == value) return;
    setState(() {
      _statusFilter = value;
      page = 1;
      _selected.clear();
    });
    if (!_isTreeView) load();
  }

  Widget _statusChips({bool compact = false}) {
    const options = <(int?, String)>[
      (null, '全部'),
      (1, '已发布'),
      (0, '草稿'),
      (2, '已归档'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((option) {
        final selected = _statusFilter == option.$1;
        return ChoiceChip(
          label: Text(option.$2, style: const TextStyle(fontSize: 12)),
          selected: selected,
          visualDensity: compact
              ? VisualDensity.compact
              : VisualDensity.standard,
          onSelected: (_) => _changeStatusFilter(option.$1),
        );
      }).toList(),
    );
  }

  Widget _listBody() {
    return Column(
      children: [
        if (_selected.isNotEmpty && !_isTreeView) ...[
          _bulkActionBar(),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: _loading && items.isEmpty
              ? const AdminStatusView.loading(title: '正在加载文章')
              : _isTreeView
              ? _buildTreeView()
              : _buildListView(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = AdminBreakpoints.isPhone(context);
    Widget searchField = AdminShortcutSearchField(
      controller: keywordCtrl,
      decoration: InputDecoration(
        hintText: t(context, 'search_hint'),
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onSubmitted: (value) {
        applySearch();
      },
    );

    final totalPages = (total / 10).ceil().clamp(1, 999999);
    final pagination = PaginationBar(
      currentPage: page,
      totalPages: totalPages,
      totalItems: total,
      onPageChanged: (newPage) {
        setState(() => page = newPage);
        load();
      },
    );

    void onSortChanged(String? value) {
      if (value == null || value == _sortBy) return;
      setState(() {
        _sortBy = value;
        page = 1;
      });
      load();
    }

    if (isPhone) {
      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => createOrEdit(),
          icon: const Icon(Icons.add),
          label: Text(t(context, 'create')),
        ),
        bottomNavigationBar: pagination,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _statusChips(compact: true),
                            ),
                          ),
                          IconButton(
                            tooltip: t(context, 'refresh'),
                            visualDensity: VisualDensity.compact,
                            onPressed: _loading ? null : _refresh,
                            icon: const Icon(Icons.refresh),
                          ),
                          PopupMenuButton<String>(
                            tooltip: t(context, 'sort_method'),
                            icon: const Icon(Icons.sort_rounded),
                            onSelected: onSortChanged,
                            itemBuilder: (context) => [
                              CheckedPopupMenuItem<String>(
                                value: 'id',
                                checked: _sortBy == 'id',
                                child: Text(t(context, 'sort_id_desc')),
                              ),
                              CheckedPopupMenuItem<String>(
                                value: 'updatedAt',
                                checked: _sortBy == 'updatedAt',
                                child: Text(t(context, 'sort_updated_desc')),
                              ),
                              CheckedPopupMenuItem<String>(
                                value: 'createdAt',
                                checked: _sortBy == 'createdAt',
                                child: Text(t(context, 'sort_created_desc')),
                              ),
                              CheckedPopupMenuItem<String>(
                                value: 'publishedAt',
                                checked: _sortBy == 'publishedAt',
                                child: Text(t(context, 'sort_published_desc')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _listBody()),
            ],
          ),
        ),
      );
    }

    return AdminPageScaffold(
      title: t(context, 'posts'),
      actions: [
        IconButton(
          tooltip: t(context, 'refresh'),
          onPressed: _loading ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
        AdminActionButton(
          label: t(context, 'create'),
          icon: Icons.add,
          onPressed: () => createOrEdit(),
        ),
      ],
      filters: AdminToolbar(
        children: [
          SizedBox(width: 280, child: searchField),
          _statusChips(),
          if (!_isTreeView)
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _sortBy,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: t(context, 'sort_method'),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'id',
                    child: Text(t(context, 'sort_id_desc')),
                  ),
                  DropdownMenuItem(
                    value: 'updatedAt',
                    child: Text(t(context, 'sort_updated_desc')),
                  ),
                  DropdownMenuItem(
                    value: 'createdAt',
                    child: Text(t(context, 'sort_created_desc')),
                  ),
                  DropdownMenuItem(
                    value: 'publishedAt',
                    child: Text(t(context, 'sort_published_desc')),
                  ),
                ],
                onChanged: onSortChanged,
              ),
            ),
          FilledButton.icon(
            onPressed: applySearch,
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
                _selected.clear();
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
      body: _listBody(),
      footer: pagination,
    );
  }
}

class QuickEditPostDialog extends StatefulWidget {
  const QuickEditPostDialog({
    super.key,
    required this.item,
    required this.api,
    required this.categories,
  });

  final PostItem item;
  final AdminApiClient api;
  final List<CategoryItem> categories;

  @override
  State<QuickEditPostDialog> createState() => _QuickEditPostDialogState();
}

class _QuickEditPostDialogState extends State<QuickEditPostDialog> {
  late final TextEditingController titleCtrl;
  late final TextEditingController slugCtrl;
  late final TextEditingController authorNameCtrl;
  late final TextEditingController passwordCtrl;
  late int status;
  late int visibility;
  late int articleMode;
  late bool allowComment;
  late DateTime? publishedAt;
  late int? selectedUserId;
  late Set<int> selectedCategoryIds;
  late Set<int> selectedTagIds;

  List<TagItem> allTags = [];
  List<UserListItem> allUsers = [];
  bool loadingData = true;
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    titleCtrl = TextEditingController(text: it.zhTitle);
    slugCtrl = TextEditingController(text: it.slug);
    authorNameCtrl = TextEditingController(text: it.authorName ?? '');
    passwordCtrl = TextEditingController();
    status = it.status;
    visibility = it.visibility;
    articleMode = it.articleMode;
    allowComment = it.allowComment;
    publishedAt = it.publishedAt ?? it.createdAt;
    selectedUserId = it.userId;
    selectedCategoryIds = it.categoryIds.isNotEmpty
        ? it.categoryIds.toSet()
        : (it.categoryId != null ? {it.categoryId!} : <int>{});
    selectedTagIds = it.tagIds.toSet();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        widget.api.listTags(),
        widget.api.listUsers(pageSize: 100),
      ]);
      if (mounted) {
        setState(() {
          allTags = results[0] as List<TagItem>;
          allUsers = (results[1] as PageResult<UserListItem>).items;
          loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loadingData = false);
      }
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    slugCtrl.dispose();
    authorNameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPublishedDate() async {
    final now = DateTime.now();
    final initial = publishedAt ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          publishedAt = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _save() async {
    final titleText = titleCtrl.text.trim();
    if (titleText.isEmpty) {
      setState(() => errorMessage = t(context, 'fill_required_fields'));
      return;
    }
    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      final req = PostQuickEditRequest(
        title: {'zh-cn': titleText},
        slug: slugCtrl.text.trim().isEmpty ? null : slugCtrl.text.trim(),
        authorName: authorNameCtrl.text.trim(),
        userId: selectedUserId,
        status: status,
        visibility: visibility,
        password: passwordCtrl.text.trim().isEmpty ? null : passwordCtrl.text.trim(),
        categoryIds: selectedCategoryIds.toList(),
        tagIds: selectedTagIds.toList(),
        publishedAt: publishedAt,
        articleMode: articleMode,
        allowComment: allowComment,
        version: widget.item.version,
      );

      final updated = await widget.api.quickEditPost(widget.item.id, req);
      if (mounted) {
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSaving = false;
          errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AdminBreakpoints.isPhone(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: isMobile ? double.infinity : 760,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(context, 'quick_edit'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '#${widget.item.id} · ${widget.item.slug}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  tooltip: t(context, 'close'),
                ),
              ],
            ),
            const Divider(height: 24),
            if (errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: '${t(context, 'title')} *',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: slugCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Slug (别名)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isMobile) ...[
                      _buildAuthorSection(),
                      const SizedBox(height: 12),
                      _buildStatusAndModeSection(),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildAuthorSection()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatusAndModeSection()),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickPublishedDate,
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: t(context, 'published_at'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: const Icon(Icons.calendar_today, size: 16),
                              ),
                              child: Text(
                                publishedAt != null
                                    ? _formatDateTime(publishedAt!)
                                    : t(context, 'please_select'),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: allowComment,
                              onChanged: (v) {
                                setState(() => allowComment = v ?? true);
                              },
                            ),
                            const Text('允许评论', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t(context, 'categories'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    if (widget.categories.isEmpty)
                      Text(
                        '暂无分类',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: widget.categories.map((c) {
                          final selected = selectedCategoryIds.contains(c.id);
                          return FilterChip(
                            label: Text(c.displayName, style: const TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  selectedCategoryIds.add(c.id);
                                } else {
                                  selectedCategoryIds.remove(c.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      t(context, 'tags'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    if (loadingData)
                      const SizedBox(height: 24, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                    else if (allTags.isEmpty)
                      Text(
                        '暂无标签',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: allTags.map((tag) {
                          final selected = selectedTagIds.contains(tag.id);
                          return FilterChip(
                            label: Text(tag.zhName, style: const TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  selectedTagIds.add(tag.id);
                                } else {
                                  selectedTagIds.remove(tag.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: Text(t(context, 'cancel')),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: isSaving ? null : _save,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(t(context, 'save')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorSection() {
    final hasSelectedUserInList =
        selectedUserId == null || allUsers.any((u) => u.id == selectedUserId);

    final userItems = <DropdownMenuItem<int?>>[
      DropdownMenuItem<int?>(
        value: null,
        child: Text(t(context, 'please_select')),
      ),
      if (selectedUserId != null && !hasSelectedUserInList)
        DropdownMenuItem<int?>(
          value: selectedUserId,
          child: Text(
            widget.item.userName?.isNotEmpty == true
                ? widget.item.userName!
                : '用户 #$selectedUserId',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ...allUsers.map(
        (u) => DropdownMenuItem<int?>(
          value: u.id,
          child: Text(u.username, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int?>(
          key: ValueKey('author_${selectedUserId}_${allUsers.length}'),
          initialValue: selectedUserId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: t(context, 'author_account'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: userItems,
          onChanged: (v) => setState(() => selectedUserId = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: authorNameCtrl,
          decoration: InputDecoration(
            labelText: t(context, 'custom_author_name'),
            helperText: t(context, 'custom_author_name_hint'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusAndModeSection() {
    final safeStatus = [0, 1, 2].contains(status) ? status : 0;
    final safeArticleMode = [0, 1, 2].contains(articleMode) ? articleMode : 0;
    final safeVisibility = [0, 1, 2].contains(visibility) ? visibility : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('status_$status'),
                initialValue: safeStatus,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: t(context, 'status'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(value: 0, child: Text(t(context, 'draft'))),
                  DropdownMenuItem(value: 1, child: Text(t(context, 'published'))),
                  DropdownMenuItem(value: 2, child: Text(t(context, 'archived'))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => status = v);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('mode_$articleMode'),
                initialValue: safeArticleMode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '文章模式',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('常规')),
                  DropdownMenuItem(value: 1, child: Text('教程')),
                  DropdownMenuItem(value: 2, child: Text('资源')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => articleMode = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          key: ValueKey('vis_$visibility'),
          initialValue: safeVisibility,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: t(context, 'visibility_label'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            DropdownMenuItem(value: 0, child: Text(t(context, 'public_visibility'))),
            DropdownMenuItem(value: 1, child: Text(t(context, 'private_visibility'))),
            DropdownMenuItem(value: 2, child: Text(t(context, 'password_protected'))),
          ],
          onChanged: (v) {
            if (v != null) setState(() => visibility = v);
          },
        ),
        if (visibility == 2) ...[
          const SizedBox(height: 10),
          TextField(
            controller: passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '访问密码',
              helperText: '留空保留原密码',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
