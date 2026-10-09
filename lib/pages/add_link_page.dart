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
  final _monitoringIntervalMinutesController = TextEditingController(
    text: '60',
  );
  final _monitoringKeywordsController = TextEditingController();
  final _backlinkGraceDaysController = TextEditingController(text: '7');
  final _offlineGraceDaysController = TextEditingController(text: '7');
  final _fraudGraceDaysController = TextEditingController(text: '7');

  final _noteController = TextEditingController();
  final _seoTitleController = TextEditingController();
  final _seoKeywordsController = TextEditingController();
  final _seoDescriptionController = TextEditingController();

  String _target = '_blank';
  int _redirectType = 1;
  int _linkType = 0;
  bool _showUrl = true;
  bool _status = true;
  bool _monitoringEnabled = true;
  bool _hideWhenBacklinkMissing = false;
  bool _hideWhenOffline = false;
  bool _hideWhenKeywordFraudDetected = false;
  String _displayRegion = 'global';
  List<String> _backlinkCheckUrls = [];
  bool _notifyOnBacklinkMissing = false;
  bool _notifyOnOffline = false;
  bool _notifyOnKeywordFraud = false;

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
      _monitoringIntervalMinutesController.text = link.monitoringIntervalMinutes
          .toString();
      _monitoringKeywordsController.text = link.monitoringKeywords;
      _noteController.text = link.note ?? '';
      _seoTitleController.text = link.seoTitle ?? '';
      _seoKeywordsController.text = link.seoKeywords ?? '';
      _seoDescriptionController.text = link.seoDescription ?? '';

      _target = link.target;
      _redirectType = link.redirectType;
      _linkType = link.type ?? 0;
      _showUrl = link.showUrl;
      _status = link.status == 1;
      _monitoringEnabled = link.monitoringEnabled;
      _hideWhenBacklinkMissing = link.hideWhenBacklinkMissing;
      _hideWhenOffline = link.hideWhenOffline;
      _hideWhenKeywordFraudDetected = link.hideWhenKeywordFraudDetected;
      _displayRegion = link.displayRegion;
      _backlinkCheckUrls = List<String>.from(link.backlinkCheckUrls);
      _notifyOnBacklinkMissing = link.notifyOnBacklinkMissing;
      _backlinkGraceDaysController.text = link.backlinkMissingGraceDays
          .toString();
      _notifyOnOffline = link.notifyOnOffline;
      _offlineGraceDaysController.text = link.offlineGraceDays.toString();
      _notifyOnKeywordFraud = link.notifyOnKeywordFraud;
      _fraudGraceDaysController.text = link.keywordFraudGraceDays.toString();
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
    _monitoringIntervalMinutesController.dispose();
    _monitoringKeywordsController.dispose();
    _backlinkGraceDaysController.dispose();
    _offlineGraceDaysController.dispose();
    _fraudGraceDaysController.dispose();
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
        monitoringEnabled: _monitoringEnabled,
        monitoringIntervalMinutes:
            int.tryParse(_monitoringIntervalMinutesController.text.trim()) ??
            60,
        hideWhenBacklinkMissing: _hideWhenBacklinkMissing,
        hideWhenOffline: _hideWhenOffline,
        monitoringKeywords: _monitoringKeywordsController.text.trim(),
        hideWhenKeywordFraudDetected: _hideWhenKeywordFraudDetected,
        displayRegion: _displayRegion,
        backlinkCheckUrls: _backlinkCheckUrls,
        notifyOnBacklinkMissing: _notifyOnBacklinkMissing,
        backlinkMissingGraceDays:
            int.tryParse(_backlinkGraceDaysController.text.trim()) ?? 7,
        notifyOnOffline: _notifyOnOffline,
        offlineGraceDays:
            int.tryParse(_offlineGraceDaysController.text.trim()) ?? 7,
        notifyOnKeywordFraud: _notifyOnKeywordFraud,
        keywordFraudGraceDays:
            int.tryParse(_fraudGraceDaysController.text.trim()) ?? 7,
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

  Future<void> _showAutoHideSettings({
    required String title,
    required bool notify,
    required ValueChanged<bool> onNotifyChanged,
    required TextEditingController graceDaysController,
    bool configureBacklinkUrls = false,
  }) async {
    var dialogNotify = notify;
    var urlText = _backlinkCheckUrls.join('\n');
    String? errorText;
    final urlsController = TextEditingController(text: urlText);
    final daysController = TextEditingController(
      text: graceDaysController.text,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('$title设置'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (configureBacklinkUrls) ...[
                    TextField(
                      controller: urlsController,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: '检测的本站链接',
                        helperText:
                            '每行一个。留空时优先检查展示区域的 DOMAIN 规则；没有可用域名规则时使用本站 URL。',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        urlText = value;
                        setDialogState(() => errorText = null);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('通知对方站长'),
                    subtitle: Text(
                      _emailController.text.trim().isEmpty
                          ? '通知将发送到友链邮箱；请先填写邮箱。'
                          : '通知将发送到 ${_emailController.text.trim()}。',
                    ),
                    value: dialogNotify,
                    onChanged: (value) =>
                        setDialogState(() => dialogNotify = value ?? false),
                  ),
                  TextField(
                    controller: daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '缓冲期（天）',
                      helperText: '连续 3 次检测异常后开始计时，默认 7 天，允许 0 至 365 天。',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final days = int.tryParse(daysController.text.trim());
                if (days == null || days < 0 || days > 365) {
                  setDialogState(() => errorText = '缓冲期必须填写 0 到 365 之间的整数。');
                  return;
                }
                if (dialogNotify && _emailController.text.trim().isEmpty) {
                  setDialogState(() => errorText = '请先填写友链邮箱，再开启站长通知。');
                  return;
                }
                final parsedUrls = urlText
                    .split(RegExp(r'[,，;；\r\n]+'))
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .toList();
                if (configureBacklinkUrls && parsedUrls.length > 20) {
                  setDialogState(() => errorText = '检测链接最多设置 20 个。');
                  return;
                }
                setState(() {
                  onNotifyChanged(dialogNotify);
                  graceDaysController.text = daysController.text.trim();
                  if (configureBacklinkUrls) {
                    _backlinkCheckUrls = parsedUrls;
                  }
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('保存设置'),
            ),
          ],
        ),
      ),
    );
    urlsController.dispose();
    daysController.dispose();
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
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _displayRegion,
                                decoration: const InputDecoration(
                                  labelText: '友链展示区域',
                                  helperText: '全球友链会在所有区域显示；选择具体区域后仅在该区域显示。',
                                  border: OutlineInputBorder(),
                                ),
                                items: BlogRegion.values
                                    .map(
                                      (region) => DropdownMenuItem<String>(
                                        value: region.code,
                                        child: Text(region.displayName),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => setState(
                                  () => _displayRegion = value ?? 'global',
                                ),
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
                      if (_linkType == 0) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          t(context, 'link_monitoring_settings'),
                        ),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller:
                                      _monitoringIntervalMinutesController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: t(
                                      context,
                                      'link_monitoring_interval',
                                    ),
                                    helperText: t(
                                      context,
                                      'link_monitoring_interval_hint',
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    final minutes = int.tryParse(
                                      value?.trim() ?? '',
                                    );
                                    if (minutes == null ||
                                        minutes < 1 ||
                                        minutes > 10080) {
                                      return t(
                                        context,
                                        'link_monitoring_interval_invalid',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                SwitchListTile(
                                  title: Text(
                                    t(context, 'link_monitoring_enabled'),
                                  ),
                                  subtitle: Text(
                                    t(context, 'link_monitoring_enabled_hint'),
                                  ),
                                  value: _monitoringEnabled,
                                  onChanged: (value) => setState(
                                    () => _monitoringEnabled = value,
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                SwitchListTile(
                                  secondary: IconButton(
                                    tooltip: '返链检测与通知设置',
                                    icon: const Icon(Icons.settings_outlined),
                                    onPressed: () => _showAutoHideSettings(
                                      title: '缺少返链时隐藏',
                                      notify: _notifyOnBacklinkMissing,
                                      onNotifyChanged: (value) =>
                                          _notifyOnBacklinkMissing = value,
                                      graceDaysController:
                                          _backlinkGraceDaysController,
                                      configureBacklinkUrls: true,
                                    ),
                                  ),
                                  title: Text(
                                    t(
                                      context,
                                      'link_hide_when_backlink_missing',
                                    ),
                                  ),
                                  subtitle: Text(
                                    t(
                                      context,
                                      'link_hide_when_backlink_missing_hint',
                                    ),
                                  ),
                                  value: _hideWhenBacklinkMissing,
                                  onChanged: (value) => setState(
                                    () => _hideWhenBacklinkMissing = value,
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                SwitchListTile(
                                  secondary: IconButton(
                                    tooltip: '离线通知与缓冲期设置',
                                    icon: const Icon(Icons.settings_outlined),
                                    onPressed: () => _showAutoHideSettings(
                                      title: '离线时隐藏',
                                      notify: _notifyOnOffline,
                                      onNotifyChanged: (value) =>
                                          _notifyOnOffline = value,
                                      graceDaysController:
                                          _offlineGraceDaysController,
                                    ),
                                  ),
                                  title: Text(
                                    t(context, 'link_hide_when_offline'),
                                  ),
                                  subtitle: Text(
                                    t(context, 'link_hide_when_offline_hint'),
                                  ),
                                  value: _hideWhenOffline,
                                  onChanged: (value) =>
                                      setState(() => _hideWhenOffline = value),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                SwitchListTile(
                                  secondary: IconButton(
                                    tooltip: '欺诈通知与缓冲期设置',
                                    icon: const Icon(Icons.settings_outlined),
                                    onPressed: () => _showAutoHideSettings(
                                      title: '检测到关键词欺诈时隐藏',
                                      notify: _notifyOnKeywordFraud,
                                      onNotifyChanged: (value) =>
                                          _notifyOnKeywordFraud = value,
                                      graceDaysController:
                                          _fraudGraceDaysController,
                                    ),
                                  ),
                                  title: Text(
                                    t(context, 'link_hide_when_keyword_fraud'),
                                  ),
                                  subtitle: Text(
                                    t(
                                      context,
                                      'link_hide_when_keyword_fraud_hint',
                                    ),
                                  ),
                                  value: _hideWhenKeywordFraudDetected,
                                  onChanged: (value) => setState(
                                    () => _hideWhenKeywordFraudDetected = value,
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                            if (_linkType == 0) ...[
                              TextFormField(
                                controller: _monitoringKeywordsController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: t(
                                    context,
                                    'link_monitoring_keywords',
                                  ),
                                  helperText: t(
                                    context,
                                    'link_monitoring_keywords_hint',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
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
