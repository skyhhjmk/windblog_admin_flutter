part of 'package:windblog_admin_flutter/main.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<CategoryItem> categories = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => loading = true);
    try {
      categories = await widget.api.listCategories();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'load_failed')}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _createCategory() async {
    final result = await showDialog<CategoryCreateRequest>(
      context: context,
      builder: (context) =>
          _CategoryEditDialog(
            categories: categories,
          ),
    );
    if (result == null) return;

    try {
      await widget.api.createCategory(result);
      await _loadCategories();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'save_failed')}$e')),
      );
    }
  }

  Future<void> _editCategory(CategoryItem category) async {
    final result = await showDialog<CategoryUpdateRequest>(
      context: context,
      builder: (context) =>
          _CategoryEditDialog(
            category: category,
            categories: categories.where((c) => c.id != category.id).toList(),
          ),
    );
    if (result == null) return;

    try {
      await widget.api.updateCategory(category.id, result);
      await _loadCategories();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'save_failed')}$e')),
      );
    }
  }

  Future<void> _deleteCategory(CategoryItem category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(t(context, 'confirm_delete')),
            content: Text(t(context, 'confirm_delete_category').replaceAll(
                '%s', category.displayName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t(context, 'cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(t(context, 'delete')),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await widget.api.deleteCategory(category.id);
      await _loadCategories();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'delete_failed')}$e')),
      );
    }
  }

  List<CategoryItem> _buildTree(List<CategoryItem> flatList) {
    final Map<int, CategoryItem> map = {};
    final List<CategoryItem> roots = [];

    for (final cat in flatList) {
      map[cat.id] = cat;
    }

    for (final cat in flatList) {
      if (cat.parentId == null || !map.containsKey(cat.parentId)) {
        roots.add(cat);
      }
    }

    return roots;
  }

  List<CategoryItem> _getChildren(int parentId) {
    return categories.where((c) => c.parentId == parentId).toList();
  }

  Widget _buildCategoryTree(CategoryItem category, int depth) {
    final children = _getChildren(category.id);
    final indent = depth * 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(left: 16 + indent, right: 16),
          leading: Icon(
            children.isEmpty ? Icons.folder_outlined : Icons.folder,
            color: children.isEmpty ? Colors.grey : Colors.amber,
          ),
          title: Row(
            children: [
              Text(category.displayName),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${category.postCount}',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text('${category.slug} · ${category.path}'),
          trailing: Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _editCategory(category),
                child: Text(t(context, 'edit')),
              ),
              TextButton(
                onPressed: () => _deleteCategory(category),
                child: Text(t(context, 'delete')),
              ),
            ],
          ),
        ),
        ...children.map((child) => _buildCategoryTree(child, depth + 1)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootCategories = _buildTree(categories);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              FilledButton(
                onPressed: _createCategory,
                child: Text(t(context, 'create_category')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loadCategories,
                child: Text(t(context, 'refresh')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : rootCategories.isEmpty
                ? Center(child: Text(t(context, 'no_categories')))
                : Card(
              child: ListView(
                children: rootCategories
                    .map((cat) => _buildCategoryTree(cat, 0))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryEditDialog extends StatefulWidget {
  const _CategoryEditDialog({
    this.category,
    required this.categories,
  });

  final CategoryItem? category;
  final List<CategoryItem> categories;

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final TextEditingController slugCtrl;
  late final TextEditingController nameCtrl;
  late final TextEditingController descCtrl;
  int? parentId;

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    slugCtrl = TextEditingController(text: cat?.slug ?? '');
    nameCtrl = TextEditingController(text: cat?.zhName ?? '');
    descCtrl = TextEditingController(
      text: cat?.description?['zh-cn'] ?? '',
    );
    parentId = cat?.parentId;
  }

  @override
  void dispose() {
    slugCtrl.dispose();
    nameCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;

    return AlertDialog(
      title: Text(
          isEdit ? t(context, 'edit_category') : t(context, 'create_category')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: slugCtrl,
              decoration: InputDecoration(labelText: t(context, 'slug')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: t(context, 'name')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(labelText: t(context, 'description')),
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: parentId,
              decoration: InputDecoration(
                  labelText: t(context, 'parent_category')),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(t(context, 'no_parent')),
                ),
                ...widget.categories.map((cat) =>
                    DropdownMenuItem(
                      value: cat.id,
                      child: Text(cat.displayName),
                    )),
              ],
              onChanged: (v) => setState(() => parentId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t(context, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            final slug = slugCtrl.text.trim();
            final name = nameCtrl.text.trim();
            if (slug.isEmpty || name.isEmpty) return;

            final request = isEdit
                ? CategoryUpdateRequest(
              slug: slug,
              name: {'zh-cn': name},
              description: descCtrl.text
                  .trim()
                  .isEmpty
                  ? null
                  : {'zh-cn': descCtrl.text.trim()},
              parentId: parentId,
            )
                : CategoryCreateRequest(
              slug: slug,
              name: {'zh-cn': name},
              description: descCtrl.text
                  .trim()
                  .isEmpty
                  ? null
                  : {'zh-cn': descCtrl.text.trim()},
              parentId: parentId,
            );
            Navigator.pop(context, request);
          },
          child: Text(t(context, 'save')),
        ),
      ],
    );
  }
}
