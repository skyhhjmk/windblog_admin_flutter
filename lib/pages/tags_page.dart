part of 'package:windblog_admin_flutter/main.dart';

class TagsPage extends StatefulWidget {
  const TagsPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  List<TagItem> tags = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() => loading = true);
    try {
      tags = await widget.api.listTags();
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

  Future<void> _createTag() async {
    final result = await showDialog<TagCreateRequest>(
      context: context,
      builder: (context) => const _TagEditDialog(),
    );
    if (result == null) return;

    try {
      await widget.api.createTag(result);
      await _loadTags();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'save_failed')}$e')),
      );
    }
  }

  Future<void> _editTag(TagItem tag) async {
    final result = await showDialog<TagUpdateRequest>(
      context: context,
      builder: (context) => _TagEditDialog(tag: tag),
    );
    if (result == null) return;

    try {
      await widget.api.updateTag(tag.id, result);
      await _loadTags();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'save_failed')}$e')),
      );
    }
  }

  Future<void> _deleteTag(TagItem tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(t(context, 'confirm_delete')),
            content: Text(t(context, 'confirm_delete_tag').replaceAll(
                '%s', tag.displayName)),
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
      await widget.api.deleteTag(tag.id);
      await _loadTags();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'delete_failed')}$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              FilledButton(
                onPressed: _createTag,
                child: Text(t(context, 'create_tag')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loadTags,
                child: Text(t(context, 'refresh')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : tags.isEmpty
                ? Center(child: Text(t(context, 'no_tags')))
                : Card(
              child: ListView.separated(
                itemCount: tags.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  return ListTile(
                    leading: const Icon(Icons.label, color: Colors.blue),
                    title: Text(tag.displayName),
                    subtitle: Text(tag.slug),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _editTag(tag),
                          child: Text(t(context, 'edit')),
                        ),
                        TextButton(
                          onPressed: () => _deleteTag(tag),
                          child: Text(t(context, 'delete')),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagEditDialog extends StatefulWidget {
  const _TagEditDialog({
    this.tag,
  });

  final TagItem? tag;

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  late final TextEditingController slugCtrl;
  late final TextEditingController nameCtrl;
  late final TextEditingController descCtrl;

  @override
  void initState() {
    super.initState();
    final tag = widget.tag;
    slugCtrl = TextEditingController(text: tag?.slug ?? '');
    nameCtrl = TextEditingController(text: tag?.zhName ?? '');
    descCtrl = TextEditingController(
      text: tag?.description?['zh-cn'] ?? '',
    );
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
    final isEdit = widget.tag != null;

    return AlertDialog(
      title: Text(isEdit ? t(context, 'edit_tag') : t(context, 'create_tag')),
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
                ? TagUpdateRequest(
              slug: slug,
              name: {'zh-cn': name},
              description: descCtrl.text
                  .trim()
                  .isEmpty
                  ? null
                  : {'zh-cn': descCtrl.text.trim()},
            )
                : TagCreateRequest(
              slug: slug,
              name: {'zh-cn': name},
              description: descCtrl.text
                  .trim()
                  .isEmpty
                  ? null
                  : {'zh-cn': descCtrl.text.trim()},
            );
            Navigator.pop(context, request);
          },
          child: Text(t(context, 'save')),
        ),
      ],
    );
  }
}
