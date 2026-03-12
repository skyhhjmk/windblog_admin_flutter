part of 'package:windblog_admin_flutter/main.dart';

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

  @override
  void initState() {
    super.initState();
    load();
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
                  load();
                },
                child: Text(t(context, 'search')),
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
            child: Card(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = items[i];
                  return ListTile(
                    title: Text(it.zhTitle.isEmpty ? it.slug : it.zhTitle),
                    subtitle: Text(
                      'slug: ${it.slug} | ${t(context, 'status_text')}: ${it.statusText} | ${t(context, 'render_text')}: ${it.renderTypeText} | ${t(context, 'version_text')}${it.version}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => createOrEdit(item: it),
                          child: Text(t(context, 'edit')),
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
                          child: Text(t(context, 'publish')),
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
                          child: Text(t(context, 'delete')),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
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
          _categories = cats;
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
                      initialValue: categoryId,
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
                      decoration: InputDecoration(labelText: t(context, 'status')),
                      items: [
                        DropdownMenuItem(value: 0, child: Text(t(context, 'draft'))),
                        DropdownMenuItem(value: 1, child: Text(t(context, 'published'))),
                        DropdownMenuItem(value: 2, child: Text(t(context, 'archived'))),
                      ],
                      onChanged: (v) => setState(() => status = v ?? 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: visibility,
                      decoration: InputDecoration(labelText: t(context, 'visibility')),
                      items: [
                        DropdownMenuItem(value: 0, child: Text(t(context, 'public'))),
                        DropdownMenuItem(value: 1, child: Text(t(context, 'private'))),
                        DropdownMenuItem(value: 2, child: Text(t(context, 'protected'))),
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
                      decoration: InputDecoration(labelText: t(context, 'render_type')),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Markdown')),
                        DropdownMenuItem(value: 1, child: Text('HTML')),
                        DropdownMenuItem(value: 2, child: Text('Vditor')),
                        DropdownMenuItem(value: 3, child: Text('V Builder')),
                        DropdownMenuItem(value: 4, child: Text('Gutenberg')),
                        DropdownMenuItem(value: 5, child: Text('Flutter Quill')),
                        DropdownMenuItem(value: 6, child: Text('Flutter Markdown Plus')),
                      ],
                      onChanged: (v) => setState(() => renderType = v ?? 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: editorType,
                      decoration: const InputDecoration(labelText: 'Editor Type'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Markdown')),
                        DropdownMenuItem(value: 5, child: Text('Flutter Quill')),
                        DropdownMenuItem(value: 6, child: Text('Flutter Markdown Plus')),
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
