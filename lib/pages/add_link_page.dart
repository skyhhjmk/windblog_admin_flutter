part of 'package:windblog_admin_flutter/main.dart';

class AddLinkPage extends StatefulWidget {
  const AddLinkPage({
    super.key,
    required this.api,
    required this.onAuthError,
    this.initialLink,
    this.defaultLinkType,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;
  final AdminLinkItem? initialLink;
  final int? defaultLinkType;

  @override
  State<AddLinkPage> createState() => _AddLinkPageState();
}

class _AddLinkPageState extends State<AddLinkPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _iconController = TextEditingController();
  final _imageController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');

  final _noteController = TextEditingController();
  final _seoTitleController = TextEditingController();
  final _seoKeywordsController = TextEditingController();
  final _seoDescriptionController = TextEditingController();

  String _target = '_blank';
  int _redirectType = 1;
  int _linkType = 0;
  bool _showUrl = true;
  bool _status = true;

  bool _isFetching = false;
  bool _isSaving = false;
  bool _isUploadingIcon = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    if (widget.defaultLinkType != null) {
      _linkType = widget.defaultLinkType!;
    }

    if (widget.initialLink != null) {
      final link = widget.initialLink!;
      _nameController.text = link.name;
      _urlController.text = link.url;
      _descriptionController.text = link.description ?? '';
      _emailController.text = link.email ?? '';
      _iconController.text = link.icon ?? '';
      _imageController.text = link.image ?? '';
      _sortOrderController.text = link.sortOrder.toString();
      _noteController.text = link.note ?? '';
      _seoTitleController.text = link.seoTitle ?? '';
      _seoKeywordsController.text = link.seoKeywords ?? '';
      _seoDescriptionController.text = link.seoDescription ?? '';

      _target = link.target;
      _redirectType = link.redirectType;
      _linkType = link.type ?? 0;
      _showUrl = link.showUrl;
      _status = link.status == 1;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _iconController.dispose();
    _imageController.dispose();
    _sortOrderController.dispose();
    _noteController.dispose();
    _seoTitleController.dispose();
    _seoKeywordsController.dispose();
    _seoDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchMeta() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !Uri.parse(url).isAbsolute) {
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text(t(context, 'invalid_url'))),
      );
      return;
    }

    setState(() => _isFetching = true);
    try {
      final meta = await widget.api.parseLinkMeta(url);
      if (mounted) {
        if (meta.title.isNotEmpty && _nameController.text.isEmpty) {
          _nameController.text = meta.title;
        }
        if (meta.description.isNotEmpty &&
            _descriptionController.text.isEmpty) {
          _descriptionController.text = meta.description;
        }
        if (meta.icon.isNotEmpty && _iconController.text.isEmpty) {
          _iconController.text = meta.icon;
        }
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text(t(context, 'link_fetch_success'))),
        );
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('${t(context, 'link_fetch_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _uploadFile(
    TextEditingController controller,
    bool isIcon,
  ) async {
    if (isIcon) {
      setState(() => _isUploadingIcon = true);
    } else {
      setState(() => _isUploadingImage = true);
    }

    try {
      final result = await FilePicker.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      if (!mounted) return;
      final mimeType = _resolveMimeType(file);
      final notifications = AdminNotificationScope.of(context);
      final media = await notifications.uploadMediaWithNotification(
        api: widget.api,
        fileName: file.name,
        bytes: bytes,
        mimeType: mimeType,
      );

      if (mounted) {
        controller.text = media.url;
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (_) {
      // 上传失败已经由持久通知显示。
    } finally {
      if (mounted) {
        if (isIcon) {
          setState(() => _isUploadingIcon = false);
        } else {
          setState(() => _isUploadingImage = false);
        }
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final req = LinkCreateRequest(
        name: _nameController.text.trim(),
        url: _urlController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        icon: _iconController.text.trim().isEmpty
            ? null
            : _iconController.text.trim(),
        image: _imageController.text.trim().isEmpty
            ? null
            : _imageController.text.trim(),
        sortOrder: int.tryParse(_sortOrderController.text) ?? 0,
        status: _status ? 1 : 2,
        target: _target,
        redirectType: _redirectType,
        showUrl: _showUrl,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        seoTitle: _seoTitleController.text.trim().isEmpty
            ? null
            : _seoTitleController.text.trim(),
        seoKeywords: _seoKeywordsController.text.trim().isEmpty
            ? null
            : _seoKeywordsController.text.trim(),
        seoDescription: _seoDescriptionController.text.trim().isEmpty
            ? null
            : _seoDescriptionController.text.trim(),
        type: _linkType,
      );

      if (widget.initialLink != null) {
        await widget.api.updateLink(widget.initialLink!.id, req);
      } else {
        await widget.api.createLink(req);
      }

      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text(t(context, 'save_success'))),
        );
        Navigator.of(context).pop(true);
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(content: Text('${t(context, 'save_failed')}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialLink != null
              ? t(context, 'edit_link')
              : t(context, 'add_link'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(t(context, 'link_basic_info')),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: '${t(context, 'link_name')} *',
                                  hintText: '如: 风之博客',
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? t(context, 'required')
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _urlController,
                                decoration: InputDecoration(
                                  labelText: '${t(context, 'link_url')} *',
                                  hintText: '如: https://example.com',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: _isFetching
                                      ? const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : IconButton(
                                          tooltip: t(
                                            context,
                                            'link_auto_fetch',
                                          ),
                                          icon: const Icon(Icons.auto_awesome),
                                          onPressed: _fetchMeta,
                                        ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return t(context, 'required');
                                  }
                                  if (!Uri.parse(v).isAbsolute) {
                                    return t(context, 'invalid_url');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: t(context, 'link_description'),
                                  hintText: '一句话简介',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: t(context, 'link_email'),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                initialValue: _linkType,
                                decoration: InputDecoration(
                                  labelText: t(context, 'link_type'),
                                  border: const OutlineInputBorder(),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 0,
                                    child: Text(
                                      t(context, 'link_type_friendly'),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 5,
                                    child: Text(t(context, 'link_type_tool')),
                                  ),
                                  const DropdownMenuItem(
                                    value: 3,
                                    child: Text('文章外链'),
                                  ),
                                  DropdownMenuItem(
                                    value: 99,
                                    child: Text(t(context, 'link_type_other')),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _linkType = v ?? 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('媒体与图文'),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _iconController,
                                      decoration: InputDecoration(
                                        labelText: t(context, 'link_icon'),
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isUploadingIcon
                                        ? null
                                        : () => _uploadFile(
                                            _iconController,
                                            true,
                                          ),
                                    icon: _isUploadingIcon
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.upload),
                                    label: Text(t(context, 'upload')),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _imageController,
                                      decoration: InputDecoration(
                                        labelText: t(context, 'link_image'),
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isUploadingImage
                                        ? null
                                        : () => _uploadFile(
                                            _imageController,
                                            false,
                                          ),
                                    icon: _isUploadingImage
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.upload),
                                    label: Text(t(context, 'upload')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle(t(context, 'link_display_settings')),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _sortOrderController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: t(
                                          context,
                                          'link_sort_order',
                                        ),
                                        hintText: t(
                                          context,
                                          'link_sort_order_hint',
                                        ),
                                        border: const OutlineInputBorder(),
                                        helperText: t(
                                          context,
                                          'link_sort_order_hint',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _target,
                                      decoration: InputDecoration(
                                        labelText: t(context, 'link_target'),
                                        border: const OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: '_blank',
                                          child: Text('新标签页 (_blank)'),
                                        ),
                                        DropdownMenuItem(
                                          value: '_self',
                                          child: Text('当前页 (_self)'),
                                        ),
                                      ],
                                      onChanged: (v) => setState(
                                        () => _target = v ?? '_blank',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _redirectType,
                                      decoration: InputDecoration(
                                        labelText: t(
                                          context,
                                          'link_redirect_type',
                                        ),
                                        border: const OutlineInputBorder(),
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: 1,
                                          child: Text(
                                            t(context, 'link_redirect_direct'),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 2,
                                          child: Text(
                                            t(context, 'link_redirect_goto'),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 4,
                                          child: Text(
                                            t(context, 'link_redirect_info'),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) => setState(
                                        () => _redirectType = v ?? 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: SwitchListTile(
                                      title: Text(t(context, 'link_show_url')),
                                      subtitle: const Text('在前台是否展示具体地址'),
                                      value: _showUrl,
                                      onChanged: (v) =>
                                          setState(() => _showUrl = v),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  Expanded(
                                    child: SwitchListTile(
                                      title: Text(t(context, 'link_status')),
                                      subtitle: const Text('是否审核通过并在前台可见'),
                                      value: _status,
                                      onChanged: (v) =>
                                          setState(() => _status = v),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          title: Text(
                            t(context, 'link_advanced_seo'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          childrenPadding: const EdgeInsets.all(16.0),
                          children: [
                            TextFormField(
                              controller: _noteController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: t(context, 'link_note'),
                                hintText: '仅管理员可见',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _seoTitleController,
                              decoration: const InputDecoration(
                                labelText: 'SEO Title',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _seoKeywordsController,
                              decoration: const InputDecoration(
                                labelText: 'SEO Keywords',
                                hintText: '逗号分隔',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _seoDescriptionController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'SEO Description',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(t(context, 'cancel')),
                          ),
                          const SizedBox(width: 16),
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(t(context, 'save')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
