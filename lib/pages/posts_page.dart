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
                  decoration: const InputDecoration(
                    hintText: 'Search by title or slug',
                    border: OutlineInputBorder(),
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
                child: const Text('Search'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => createOrEdit(),
                child: const Text('Search'),
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
                      'slug: ${it.slug} | \u72b6\u6001: ${it.statusText} | \u6e32\u67d3: ${it.renderTypeText} | v${it.version}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => createOrEdit(item: it),
                          child: const Text('Search'),
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
                          child: const Text('Search'),
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
                          child: const Text('Search'),
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
              Text('\u603b\u6570: $total'),
              const Spacer(),
              IconButton(
                onPressed: page <= 1
                    ? null
                    : () {
                        page--;
                        load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text('\u7b2c $page \u9875'),
              IconButton(
                onPressed: page * 10 >= total
                    ? null
                    : () {
                        page++;
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

  int status = 0;
  int visibility = 0;
  int renderType = 0;

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
    status = d?.status ?? 0;
    visibility = d?.visibility ?? 0;
    renderType = d?.renderType ?? 0;
  }

  @override
  void dispose() {
    slugCtrl.dispose();
    titleCtrl.dispose();
    summaryCtrl.dispose();
    contentCtrl.dispose();
    super.dispose();
  }

  Widget _buildEditorPane() {
    return SizedBox(
      height: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: _uploadMedia,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Upload Media'),
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
              child: _buildMarkdownEditor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownEditor() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: TextField(
            controller: contentCtrl,
            decoration: const InputDecoration(
              labelText: 'Markdown Content',
              border: OutlineInputBorder(),
            ),
            minLines: 12,
            maxLines: null,
            expands: true,
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
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: contentCtrl,
                builder: (context, value, child) {
                  return MarkdownBody(data: value.text);
                },
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
      final currentText = contentCtrl.text;
      final selection = contentCtrl.selection;
      final insertText = '![${media.fileName}](${media.url})\n';
      final newText = currentText.replaceRange(
        selection.baseOffset,
        selection.extentOffset,
        insertText,
      );
      contentCtrl.text = newText;
      contentCtrl.selection = TextSelection.collapsed(
        offset: selection.baseOffset + insertText.length,
      );
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u5df2\u63d2\u5165\u5a92\u4f53: ${media.fileName}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u4e0a\u4f20\u5a92\u4f53\u5931\u8d25: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.detail == null ? '\u65b0\u5efa\u6587\u7ae0' : '\u7f16\u8f91\u6587\u7ae0'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: slugCtrl,
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: summaryCtrl,
                decoration: const InputDecoration(labelText: 'Status'),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              _buildEditorPane(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Draft')),
                        DropdownMenuItem(value: 1, child: Text('Published')),
                        DropdownMenuItem(value: 2, child: Text('Archived')),
                      ],
                      onChanged: (v) => status = v ?? 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: visibility,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Public')),
                        DropdownMenuItem(value: 1, child: Text('Private')),
                        DropdownMenuItem(value: 2, child: Text('Protected')),
                      ],
                      onChanged: (v) => visibility = v ?? 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: renderType,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Markdown')),
                  DropdownMenuItem(value: 1, child: Text('HTML')),
                  DropdownMenuItem(value: 2, child: Text('Vditor')),
                  DropdownMenuItem(value: 3, child: Text('V Builder')),
                  DropdownMenuItem(value: 4, child: Text('Gutenberg')),
                  DropdownMenuItem(value: 5, child: Text('Flutter Quill')),
                  DropdownMenuItem(value: 6, child: Text('Flutter Markdown Plus')),
                ],
                onChanged: (v) => renderType = v ?? 0,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Search'),
        ),
        FilledButton(
          onPressed: () {
            final finalContent = contentCtrl.text.trim();
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
                editorType: 0,
                version: 0,
              ),
            );
          },
          child: const Text('Search'),
        ),
      ],
    );
  }
}

