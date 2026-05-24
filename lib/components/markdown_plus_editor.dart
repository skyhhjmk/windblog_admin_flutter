part of 'package:windblog_admin_flutter/main.dart';

// Regex for markdown image syntax: ![alt](url)
final _imageRegExp = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
final _markdownLinkRegExp = RegExp(
    r'(?<!!)\[([^\]]+)\]\(([^)\s]+)(?:\s+"[^"]*")?\)');

class MarkdownSyntaxController extends TextEditingController {
  MarkdownSyntaxController({super.text});

  @override
  TextSpan buildTextSpan(
      {required BuildContext context, TextStyle? style, required bool withComposing}) {
    final List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in _imageRegExp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
            text: text.substring(lastMatchEnd, match.start), style: style));
      }

      spans.add(TextSpan(
        text: match.group(0),
        // Style only — no recognizer attached here
        style: style?.copyWith(
          color: Colors.blue.shade600,
          decoration: TextDecoration.underline,
          decorationColor: Colors.blue.shade400,
        ),
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }

    return TextSpan(style: style, children: spans);
  }

  /// Returns the image URL if [offset] (character offset in text) falls
  /// inside a `![alt](url)` match, otherwise null.
  String? imageUrlAtOffset(int offset) {
    for (final match in _imageRegExp.allMatches(text)) {
      if (offset >= match.start && offset <= match.end) {
        return match.group(2);
      }
    }
    return null;
  }

  String? linkUrlAtOffset(int offset) {
    for (final match in _markdownLinkRegExp.allMatches(text)) {
      if (offset >= match.start && offset <= match.end) {
        return match.group(2);
      }
    }
    return null;
  }
}

class MarkdownPlusEditor extends StatefulWidget {
  const MarkdownPlusEditor({
    super.key,
    required this.controller,
    required this.api,
    this.isBlockMode = false,
    this.onChanged,
    this.scrollController,
  });

  final TextEditingController controller;
  final AdminApiClient api;
  final bool isBlockMode;
  final VoidCallback? onChanged;
  final ScrollController? scrollController;

  @override
  State<MarkdownPlusEditor> createState() => _MarkdownPlusEditorState();
}

class _MarkdownPlusEditorState extends State<MarkdownPlusEditor> {
  bool isPreviewVisible = true;
  bool isFullScreen = false;
  bool isOutlineVisible = false;
  final FocusNode _focusNode = FocusNode();
  ScrollController? _internalScrollController;
  final ScrollController _previewScrollController = ScrollController();
  dynamic _pasteSubscription;
  


  ScrollController get _editorScrollController =>
      widget.scrollController ?? _internalScrollController!;
  
  List<String> _outline = [];
  Map<String, int> _blockStats = {};
  int _lastSyncedLine = -1;
  int _activeHighlightIndex = -1;
  Timer? _highlightTimer;
  String _lastText = '';
  bool _isPointerDown = false;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController == null) {
      _internalScrollController = ScrollController();
    }
    _lastText = widget.controller.text;
    widget.controller.addListener(_updateOutline);
    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_onSelectionChanged);
    _updateOutline();
    if (kIsWeb) {
      web_helper.disableBrowserContextMenu();
      _pasteSubscription =
          web_helper.listenToNativePaste((bytes, fileName, mimeType) {
            _uploadPastedImageBytes(bytes, fileName, mimeType);
          });
    }
  }

  void _checkImageTap() {
    if (widget.controller is! MarkdownSyntaxController) return;
    final ctrl = widget.controller as MarkdownSyntaxController;
    final offset = ctrl.selection.baseOffset;
    if (offset < 0) return;

    // Only trigger if selection is collapsed (a simple tap, not a range selection)
    if (ctrl.selection.baseOffset != ctrl.selection.extentOffset) return;

    final url = ctrl.imageUrlAtOffset(offset);
    if (url != null && url.isNotEmpty) {
      _handleImageTap(url);
      return;
    }

    final linkUrl = ctrl.linkUrlAtOffset(offset);
    if (linkUrl != null && linkUrl.isNotEmpty) {
      _handleMarkdownLinkTap(linkUrl);
    }
  }

  Future<void> _handleMarkdownLinkTap(String rawUrl) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    AdminLinkItem? link;
    try {
      link = await widget.api.findArticleLink(rawUrl);
    } catch (_) {
      link = null;
    }

    if (!mounted) return;
    Navigator.pop(context);

    await _showMarkdownLinkDialog(rawUrl, link);
  }

  Future<void> _showMarkdownLinkDialog(String rawUrl, AdminLinkItem? link) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final title = link?.name ?? '未登记文章外链';
        final description = link?.description ??
            '保存文章后，系统会自动把这个 Markdown 链接登记到“文章外链”。';
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.link_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(rawUrl),
                const SizedBox(height: 12),
                Text(description),
                if (link != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(label: Text('ID: ${link.id}')),
                      Chip(label: Text(link.status == 1 ? '启用' : '停用')),
                      const Chip(label: Text('文章外链')),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleImageTap(String rawUrl) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // 获取规范化前的 URL 供 API 查找
    // 后端会处理解码和路径匹配
    MediaItem? foundItem;
    try {
      foundItem = await widget.api.findMedia(rawUrl);
    } catch (_) {
      // API 报错通常说明库中没有该文件（例如外部链接）
    }

    if (!mounted) return;
    Navigator.pop(context); // 关闭加载框

    if (foundItem != null) {
      MediaDetailDialog.show(context, item: foundItem, api: widget.api);
    } else {
      // 降级逻辑：处理外部链接或未收录的媒体
      final url = widget.api.normalizeUrl(rawUrl);
      final fileName = url
          .split('/')
          .last
          .split('?')
          .first;
      final mimeType = lookupMimeType(fileName) ?? 'image/jpeg';
      final fallbackItem = MediaItem(
        id: 0,
        storageKey: '',
        url: url,
        requiresManualOriginal: false,
        fileName: fileName,
        mimeType: mimeType,
        size: 0,
        mediaType: 0,
        createdAt: DateTime.now(),
        referenced: false,
        references: [],
      );
      MediaDetailDialog.show(context, item: fallbackItem, api: widget.api);
    }
  }

  Future<void> _uploadPastedImageBytes(Uint8List bytes, String fileName,
      String mimeType) async {
    final placeholder = '![上传中...]()';
    _insertText(placeholder, '\n');

    try {
      final uploaded = await widget.api.uploadMedia(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      );

      if (mounted) {
        final text = widget.controller.text;
        final newText = text.replaceFirst(
            placeholder, '![${uploaded.fileName}](${uploaded.url})');
        widget.controller.value = widget.controller.value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(
              offset: widget.controller.selection.baseOffset -
                  placeholder.length +
                  '![${uploaded.fileName}](${uploaded.url})'.length
          ),
        );
        widget.onChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('图片上传失败: $e')));
        final text = widget.controller.text;
        final newText = text.replaceFirst(placeholder, '');
        widget.controller.value = widget.controller.value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(
              offset: widget.controller.selection.baseOffset -
                  placeholder.length - 1
          ),
        );
        widget.onChanged?.call();
      }
    }
  }

  void _onSelectionChanged() {
    if (!isPreviewVisible || !mounted) return;

    final text = widget.controller.text;
    final isTextEdit = text != _lastText;
    _lastText = text;
    
    final selection = widget.controller.selection;
    if (!selection.isValid) return;
    
    if (selection.baseOffset > text.length) return;
    
    final textBefore = text.substring(0, selection.baseOffset);
    final currentLine = textBefore.split('\n').length;
    
    if (currentLine != _lastSyncedLine) {
      _lastSyncedLine = currentLine;
      _syncPreview(shouldHighlight: _isPointerDown && !isTextEdit);
      _autoScrollEditor(currentLine);
    }
  }

  void _autoScrollEditor(int currentLine) {
    if (!_editorScrollController.hasClients) return;

    const double lineHeight = 24.0;
    const double topPadding = 24.0;
    final cursorY = topPadding + (currentLine - 1) * lineHeight;

    final offset = _editorScrollController.offset;
    final viewport = _editorScrollController.position.viewportDimension;
    final bottomBoundary = offset + viewport * 0.8; // 1/5th from bottom

    if (cursorY > bottomBoundary) {
      final targetOffset = cursorY - viewport * 0.8;
      // Use microtask to avoid fighting TextField's internal scroll
      Future.microtask(() {
        if (mounted && _editorScrollController.hasClients) {
          _editorScrollController.animateTo(
            targetOffset.clamp(
                0.0, _editorScrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  void _syncPreview({bool shouldHighlight = true}) {
    if (!_previewScrollController.hasClients) return;
    
    final text = widget.controller.text;
    final lines = text.split('\n');
    final totalLines = lines.length;
    if (totalLines <= 1) return;
    
    // Calculate ratio based on cursor line
    double ratio = (_lastSyncedLine - 1) / (totalLines - 1);
    // Clamp ratio between 0 and 1
    ratio = ratio.clamp(0.0, 1.0);
    
    final target = ratio * _previewScrollController.position.maxScrollExtent;
    
    _previewScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );

    // Identify and highlight the current block only if it was a navigation action
    if (shouldHighlight) {
      _highlightCurrentBlock();
    }
  }

  void _highlightCurrentBlock() {
    final text = widget.controller.text;
    final blocks = _splitMarkdownBlocks(text);
    int targetIndex = -1;

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final nextStart = (i + 1 < blocks.length)
          ? blocks[i + 1].startLine
          : 1000000;
      if (_lastSyncedLine >= block.startLine && _lastSyncedLine < nextStart) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex != -1 && targetIndex != _activeHighlightIndex) {
      _highlightTimer?.cancel();
      setState(() => _activeHighlightIndex = targetIndex);
      _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _activeHighlightIndex = -1);
        }
      });
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(MarkdownPlusEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      if (oldWidget.scrollController == null && _internalScrollController != null) {
        _internalScrollController!.dispose();
        _internalScrollController = null;
      }
      if (widget.scrollController == null) {
        _internalScrollController = ScrollController();
      }
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_updateOutline);
      oldWidget.controller.removeListener(_onTextChanged);
      oldWidget.controller.removeListener(_onSelectionChanged);
      widget.controller.addListener(_updateOutline);
      widget.controller.addListener(_onTextChanged);
      widget.controller.addListener(_onSelectionChanged);
      _updateOutline();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateOutline);
    widget.controller.removeListener(_onTextChanged);
    widget.controller.removeListener(_onSelectionChanged);
    _internalScrollController?.dispose();
    _focusNode.dispose();
    _previewScrollController.dispose();
    _highlightTimer?.cancel();
    _pasteSubscription?.cancel();
    if (kIsWeb) {
      web_helper.enableBrowserContextMenu();
    }
    super.dispose();
  }

  void _updateOutline() {
    final text = widget.controller.text;
    final lines = text.split('\n');
    final newOutline = <String>[];
    final newStats = <String, int>{};

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('#')) {
        newOutline.add(line);
      } else if (line.startsWith('::: ') && !line.startsWith('::: /')) {
        final name = line.substring(4).trim();
        if (name.isNotEmpty) {
          bool found = false;
          for (int j = i + 1; j < lines.length; j++) {
            if (lines[j].trim() == '::: /$name') {
              found = true;
              break;
            }
          }
          if (found) {
            newStats[name] = (newStats[name] ?? 0) + 1;
          } else {
            newStats['错误块 (Error)'] = (newStats['错误块 (Error)'] ?? 0) + 1;
          }
        }
      }
    }

    bool outlineChanged = !listEquals(_outline, newOutline);
    bool statsChanged = !mapEquals(_blockStats, newStats);

    if (outlineChanged || statsChanged) {
      setState(() {
        _outline = newOutline;
        _blockStats = newStats;
      });
    }
  }

  void _insertText(String prefix, [String suffix = '']) {
    final selection = widget.controller.selection;
    final text = widget.controller.text;
    
    if (selection.isValid) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selectedText$suffix',
      );
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + prefix.length + selectedText.length + suffix.length,
        ),
      );
    } else {
      final newText = '$text$prefix$suffix';
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    _focusNode.requestFocus();
    widget.onChanged?.call();
  }

  Future<void> _pickImage() async {
    final items = await showDialog<List<MediaItem>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从媒体库选择'),
        content: SizedBox(
          width: 800,
          height: 600,
          child: MediaLibraryPicker(api: widget.api),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (items != null && items.isNotEmpty) {
      for (final item in items) {
        _insertText('![${item.fileName}](${item.url})', '\n');
      }
    }
  }

  Future<void> _pickStoreItem() async {
    final item = await showDialog<StoreItem>(
      context: context,
      builder: (context) => _StoreItemPickerDialog(api: widget.api),
    );

    if (item != null) {
      _insertText('\n[store-item id=${item.id}]\n');
    }
  }

  Future<void> _insertHideContent(String type) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        final priceCtrl = TextEditingController(text: '0');
        final showCtrl = TextEditingController();
        return AlertDialog(
          title: Text(type == 'hide-text' ? '插入隐藏文本' : '插入付费附件'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                    labelText: '购买价格 (0表示跟随文章买断价格)',
                    suffixText: '积分'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: showCtrl,
                decoration: const InputDecoration(
                    labelText: '显示文本 (可选)',
                    hintText: '例如：付费后解锁'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            TextButton(
                onPressed: () =>
                    Navigator.pop(context, {
                      'price': priceCtrl.text.trim(),
                      'show': showCtrl.text.trim(),
                    }),
                child: const Text('确定')),
          ],
        );
      },
    );
    if (result == null) return;

    final priceStr = result['price'] ?? '0';
    final showText = result['show'] ?? '';
    
    final price = int.tryParse(priceStr) ?? 0;
    String attributes = '';
    if (price > 0) attributes += ' price=$price';
    if (showText.isNotEmpty) attributes += ' show="$showText"';

    _insertText('\n[$type$attributes]\n隐藏内容写在这里\n[/$type]\n');
  }

  void _showSyntaxHints() {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Markdown 扩展语法提示'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHintItem('自定义容器',
                        '::: info\n内容\n::: /info\n(支持 info, warning, danger, success, tip 等)'),
                    _buildHintItem('提示框 (Callouts)',
                        '>! 警告内容\n>i 信息内容\n>? 疑问内容\n>!! 危险内容'),
                    _buildHintItem('文本高亮', '==被高亮的文字=='),
                    _buildHintItem('键盘按键', '[[Ctrl]] + [[C]]'),
                    _buildHintItem('进度条', '[% 85 %]'),
                    _buildHintItem('状态标签',
                        '[!! p | 已发布 ] (p: 成功, w: 警告, e: 错误)'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
    );
  }

  Widget _buildHintItem(String title, String syntax) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText(
              syntax,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget editor = Column(
      children: [
        _buildToolbar(),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isOutlineVisible || widget.isBlockMode) _buildOutlineSidebar(),
              if (isOutlineVisible || widget.isBlockMode) const VerticalDivider(width: 1),
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.white,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Listener(
                        onPointerDown: (_) => _isPointerDown = true,
                        onPointerUp: (_) =>
                            Future.delayed(const Duration(
                                milliseconds: 100), () {
                              if (mounted) _isPointerDown = false;
                            }),
                        onPointerCancel: (_) => _isPointerDown = false,
                        child: TextField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          maxLines: null,
                          expands: true,
                          scrollController: _editorScrollController,
                          onTap: _checkImageTap,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 32, vertical: 24),
                            hintText: '开始你的创作...',
                          ),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 15,
                            height: 1.6,
                          ),
                          onChanged: (_) => widget.onChanged?.call(),
                        ),
                    ),
                  ),
                  ),
              ),
              ),
              if (isPreviewVisible) const VerticalDivider(width: 1),
              if (isPreviewVisible)
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.grey.shade50,
                    child: SelectionArea(
                      child: SingleChildScrollView(
                        controller: _previewScrollController,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  48, 32, 48, 300),
                              // Added bottom padding for preview
                              child: _buildPreviewBlocks(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (isFullScreen) {
      return Scaffold(
        body: SafeArea(child: editor),
      );
    }

    return editor;
  }

  Widget _buildToolbar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ToolbarButton(
            icon: Icons.title,
            tooltip: 'H1',
            onPressed: () => _insertText('# ', '\n'),
          ),
          _ToolbarButton(
            icon: Icons.format_bold,
            tooltip: '粗体',
            onPressed: () => _insertText('**', '**'),
          ),
          _ToolbarButton(
            icon: Icons.format_italic,
            tooltip: '斜体',
            onPressed: () => _insertText('*', '*'),
          ),
          _ToolbarButton(
            icon: Icons.format_strikethrough,
            tooltip: '删除线',
            onPressed: () => _insertText('~~', '~~'),
          ),
          const VerticalDivider(width: 16, indent: 12, endIndent: 12),
          _ToolbarButton(
            icon: Icons.format_list_bulleted,
            tooltip: '无序列表',
            onPressed: () => _insertText('- '),
          ),
          _ToolbarButton(
            icon: Icons.format_list_numbered,
            tooltip: '有序列表',
            onPressed: () => _insertText('1. '),
          ),
          _ToolbarButton(
            icon: Icons.format_quote,
            tooltip: '引用',
            onPressed: () => _insertText('> '),
          ),
          const VerticalDivider(width: 16, indent: 12, endIndent: 12),
          _ToolbarButton(
            icon: Icons.link,
            tooltip: '链接',
            onPressed: () => _insertText('[', '](url)'),
          ),
          _ToolbarButton(
            icon: Icons.image,
            tooltip: '插入图片',
            onPressed: _pickImage,
          ),
          _ToolbarButton(
            icon: Icons.storefront,
            tooltip: '插入商店物品短代码',
            onPressed: _pickStoreItem,
          ),
          _ToolbarButton(
            icon: Icons.lock_outline,
            tooltip: '插入隐藏文本区块',
            onPressed: () => _insertHideContent('hide-text'),
          ),
          _ToolbarButton(
            icon: Icons.attachment,
            tooltip: '插入付费附件区块',
            onPressed: () => _insertHideContent('hide-attachment'),
          ),
          _ToolbarButton(
            icon: Icons.code,
            tooltip: '代码块',
            onPressed: () => _insertText('```\n', '\n```'),
          ),
          _ToolbarButton(
            icon: Icons.table_chart_outlined,
            tooltip: '表格',
            onPressed: () => _insertText('\n| 标题 | 标题 |\n| --- | --- |\n| 内容 | 内容 |\n'),
          ),
          const VerticalDivider(width: 16, indent: 12, endIndent: 12),
          _ToolbarButton(
            icon: isOutlineVisible ? Icons.toc : Icons.toc_outlined,
            tooltip: '大纲',
            onPressed: () => setState(() => isOutlineVisible = !isOutlineVisible),
          ),
          _ToolbarButton(
            icon: isPreviewVisible ? Icons.visibility : Icons.visibility_off,
            tooltip: '预览',
            onPressed: () => setState(() => isPreviewVisible = !isPreviewVisible),
          ),
          _ToolbarButton(
            icon: isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
            tooltip: '全屏',
            onPressed: () => setState(() => isFullScreen = !isFullScreen),
          ),
          _ToolbarButton(
            icon: Icons.help_outline,
            tooltip: '语法提示',
            onPressed: _showSyntaxHints,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBlocks() {
    final text = widget.controller.text;
    final blocks = _splitMarkdownBlocks(text);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(blocks.length, (index) {
        final block = blocks[index];

        final isHighlighted = _activeHighlightIndex == index;
        
        return MarkdownBlockWrapper(
          key: ValueKey('block-$index-${block.content.hashCode}'),
          block: block,
          isHighlighted: isHighlighted,
          onJumpToSource: () => _jumpToEditorLine(block.startLine),
          onImageTap: (url) => _handleImageTap(url),
          onLinkTap: (url) => _handleMarkdownLinkTap(url),
          onCopyHtml: (styled) => _copyBlockAsHtml(block.content, styled),
          onCopyMarkdown: () => _copyBlockAsMarkdown(block.content),
          api: widget.api,
        );
      }),
    );
  }

  List<MarkdownBlock> _splitMarkdownBlocks(String text) {
    final lines = text.split('\n');
    final blocks = <MarkdownBlock>[];
    
    if (lines.isEmpty) return [];
    
    List<String> currentBlockLines = [];
    int blockStartLine = 1;
    bool inCodeBlock = false;
    bool inCustomBlock = false;
    String customBlockName = '';
    bool inHideBlock = false;
    String hideBlockType = '';
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      
      // Handle code block boundaries
      if (trimmed.startsWith('```')) {
        if (!inCodeBlock && currentBlockLines.isNotEmpty) {
          blocks.add(MarkdownBlock(blockStartLine, currentBlockLines.join('\n')));
          currentBlockLines = [];
          blockStartLine = i + 1;
        }
        inCodeBlock = !inCodeBlock;
        currentBlockLines.add(line);
        if (!inCodeBlock) {
          blocks.add(MarkdownBlock(blockStartLine, currentBlockLines.join('\n')));
          currentBlockLines = [];
          blockStartLine = i + 2;
        }
        continue;
      }
      
      if (inCodeBlock) {
        currentBlockLines.add(line);
        continue;
      }

      // Handle custom block boundaries
      if (trimmed.startsWith('::: ')) {
        if (!inCustomBlock && !trimmed.startsWith('::: /')) {
          final name = trimmed.substring(4).trim();
          if (name.isNotEmpty) {
            if (currentBlockLines.isNotEmpty) {
              blocks.add(
                  MarkdownBlock(blockStartLine, currentBlockLines.join('\n')));
              currentBlockLines = [];
            }
            inCustomBlock = true;
            customBlockName = name;
            blockStartLine = i + 1;
            currentBlockLines.add(line);
            continue;
          }
        } else if (inCustomBlock && trimmed == '::: /$customBlockName') {
          currentBlockLines.add(line);
          blocks.add(
              MarkdownBlock(blockStartLine, currentBlockLines.join('\n')));
          currentBlockLines = [];
          blockStartLine = i + 2;
          inCustomBlock = false;
          customBlockName = '';
          continue;
        }
      }

      if (inCustomBlock) {
        currentBlockLines.add(line);
        continue;
      }

      // Handle hide block boundaries
      if (trimmed.startsWith('[hide-') && !inHideBlock) {
        final match = RegExp(
            r'^\[(hide-text|hide-attachment)(.*)\]$',
            caseSensitive: false).firstMatch(trimmed);
        if (match != null) {
          if (currentBlockLines.isNotEmpty) {
            blocks.add(
                MarkdownBlock(blockStartLine, currentBlockLines.join('\n')));
            currentBlockLines = [];
          }
          inHideBlock = true;
          hideBlockType = match.group(1)!.toLowerCase();
          blockStartLine = i + 1;
          currentBlockLines.add(line);
          continue;
        }
      }

      if (inHideBlock) {
        currentBlockLines.add(line);
        if (trimmed.toLowerCase() == '[/$hideBlockType]') {
          blocks.add(
              MarkdownBlock(blockStartLine, currentBlockLines.join('\n')));
          currentBlockLines = [];
          blockStartLine = i + 2;
          inHideBlock = false;
          hideBlockType = '';
        }
        continue;
      }
      
      // Handle block starters
      final isBlockStarter = trimmed.startsWith('#') || 
                            trimmed.startsWith('- ') || 
                            trimmed.startsWith('* ') || 
                            trimmed.startsWith('> ') || 
                            trimmed.startsWith('|') ||
                            RegExp(r'^\d+\. ').hasMatch(trimmed);
                            
      if (isBlockStarter && currentBlockLines.isNotEmpty && trimmed.isNotEmpty) {
          blocks.add(MarkdownBlock(blockStartLine, currentBlockLines.join('\n')));
          currentBlockLines = [line];
          blockStartLine = i + 1;
          continue;
      }

      if (trimmed.isEmpty) {
        if (currentBlockLines.isNotEmpty) {
          blocks.add(MarkdownBlock(blockStartLine, currentBlockLines.join('\n')));
          currentBlockLines = [];
        }
        blockStartLine = i + 2;
      } else {
        if (currentBlockLines.isEmpty) blockStartLine = i + 1;
        currentBlockLines.add(line);
      }
    }
    
    if (currentBlockLines.isNotEmpty) {
      blocks.add(MarkdownBlock(blockStartLine, currentBlockLines.join('\n')));
    }
    
    return blocks;
  }

  void _jumpToEditorLine(int line) {
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
    
    const double lineHeight = 24.0; // font size 15 * 1.6 height
    final targetOffset = (line - 1) * lineHeight;
    
    _editorScrollController.animateTo(
      targetOffset.clamp(0.0, _editorScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    
    final text = widget.controller.text;
    final lines = text.split('\n');
    int offset = 0;
    for (int i = 0; i < line - 1 && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }
    
    widget.controller.selection = TextSelection.collapsed(offset: offset);
  }

  void _copyBlockAsHtml(String markdown, bool styled) {
    final htmlContent = md.markdownToHtml(markdown);
    final finalHtml = styled ? '<div style="font-family: sans-serif; line-height: 1.6;">$htmlContent</div>' : htmlContent;
    
    Clipboard.setData(ClipboardData(text: finalHtml));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(styled ? '已复制带样式 HTML' : '已复制原始 HTML')),
    );
  }

  void _copyBlockAsMarkdown(String markdown) {
    Clipboard.setData(ClipboardData(text: markdown));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制 Markdown 源码')),
    );
  }

  Widget _buildOutlineSidebar() {
    return Container(
      width: 200,
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '文档大纲',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _outline.length,
              itemBuilder: (context, index) {
                final item = _outline[index];
                final level = !item.contains(' ') ? item.length : item.split(' ')[0].length;
                final text = item.replaceFirst(RegExp(r'^#+\s*'), '');
                return InkWell(
                  onTap: () {
                    // TODO: Scroll to line
                  },
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12 + (level - 1) * 12, 8, 12, 8),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_blockStats.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '块统计 (Block Stats)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12).copyWith(
                  bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _blockStats.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade800)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${e.value}', style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MarkdownBlock {
  final int startLine;
  final String content;
  MarkdownBlock(this.startLine, this.content);
}

class MarkdownBlockWrapper extends StatefulWidget {
  final MarkdownBlock block;
  final bool isHighlighted;
  final VoidCallback onJumpToSource;
  final Function(String) onImageTap;
  final Function(String) onLinkTap;
  final Function(bool) onCopyHtml;
  final VoidCallback onCopyMarkdown;
  final AdminApiClient api;

  const MarkdownBlockWrapper({
    super.key,
    required this.block,
    required this.isHighlighted,
    required this.onJumpToSource,
    required this.onImageTap,
    required this.onLinkTap,
    required this.onCopyHtml,
    required this.onCopyMarkdown,
    required this.api,
  });

  @override
  State<MarkdownBlockWrapper> createState() => _MarkdownBlockWrapperState();
}

class _MarkdownBlockWrapperState extends State<MarkdownBlockWrapper>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _flashController;
  late Animation<Color?> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flashAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.blue.withAlpha(80),
    ).animate(
        CurvedAnimation(parent: _flashController, curve: Curves.easeInOut));

    if (widget.isHighlighted) {
      _flashController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(MarkdownBlockWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _flashController.repeat(reverse: true);
    } else if (!widget.isHighlighted && oldWidget.isHighlighted) {
      _flashController.stop();
      _flashController.animateTo(0);
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
        child: AnimatedBuilder(
          animation: _flashAnimation,
          builder: (context, child) {
            final hoverColor = _isHovered ? Colors.blue.withAlpha(15) : Colors
                .transparent;
            final color = widget.isHighlighted
                ? _flashAnimation.value
                : hoverColor;

            return Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: child,
            );
          },
          child: MarkdownBody(
            data: widget.block.content,
            selectable: false,
            extensionSet: md.ExtensionSet(
              [
                ...md.ExtensionSet.gitHubWeb.blockSyntaxes,
                const CustomContainerSyntax(),
                const CalloutSyntax(),
                const HideContentSyntax(),
              ],
              [
                ...md.ExtensionSet.gitHubWeb.inlineSyntaxes,
                HighlightSyntax(),
                KeyboardSyntax(),
                ProgressSyntax(),
                StatusBadgeSyntax(),
                StoreItemSyntax(),
              ],
            ),
            imageBuilder: (uri, title, alt) {
              final url = uri.toString();
              return GestureDetector(
                onTap: () => widget.onImageTap(url),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      widget.api.normalizeUrl(url),
                      headers: const {
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                      },
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.grey.shade100,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.broken_image,
                                    size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  '图片加载失败\n错误: $error\nURL: $url',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          color: Colors.grey.shade100,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            onTapLink: (text, href, title) {
              if (href == null || href.isEmpty) {
                return;
              }
              widget.onLinkTap(href);
            },
            builders: {
              'blockquote': BlockquoteBuilder(),
              'mdplus-callout': CalloutElementBuilder(),
              'mark': HighlightElementBuilder(),
              'kbd': KeyboardElementBuilder(),
              'progress': ProgressElementBuilder(),
              'badge': StatusBadgeElementBuilder(),
              'error-block': ErrorBlockBuilder(),
              'custom-container': CustomContainerBuilder(),
              'gamification-hide': GamificationHideBuilder(),
              'store-item': StoreItemBuilder(),
            },
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          onTap: widget.onJumpToSource,
          child: const Row(
            children: [
              Icon(Icons.code, size: 18, color: Colors.blue),
              SizedBox(width: 12),
              Text('跳转到源码行'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => widget.onCopyHtml(false),
          child: const Row(
            children: [
              Icon(Icons.html, size: 18),
              SizedBox(width: 12),
              Text('复制为 HTML'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => widget.onCopyHtml(true),
          child: const Row(
            children: [
              Icon(Icons.style, size: 18),
              SizedBox(width: 12),
              Text('复制为带样式 HTML'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: widget.onCopyMarkdown,
          child: const Row(
            children: [
              Icon(Icons.article_outlined, size: 18),
              SizedBox(width: 12),
              Text('复制为 Markdown 源码'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}

bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _StoreItemPickerDialog extends StatefulWidget {
  const _StoreItemPickerDialog({required this.api});

  final AdminApiClient api;

  @override
  State<_StoreItemPickerDialog> createState() => _StoreItemPickerDialogState();
}

class _StoreItemPickerDialogState extends State<_StoreItemPickerDialog> {
  List<StoreItem> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await widget.api.getStoreItems(page: 1, pageSize: 100);
      if (mounted) {
        setState(() {
          items = res.items;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择商店物品'),
      content: SizedBox(
        width: 600,
        height: 400,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
            ? const Center(child: Text('无可用物品'))
            : ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: const Icon(Icons.inventory_2),
              title: Text(item.name),
              subtitle: Text(
                  '${item.price} 积分 | 类型: ${item.type ?? "未知"}'),
              onTap: () => Navigator.pop(context, item),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
