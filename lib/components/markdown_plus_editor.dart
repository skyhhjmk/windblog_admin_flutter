part of 'package:windblog_admin_flutter/main.dart';

class MarkdownPlusEditor extends StatefulWidget {
  const MarkdownPlusEditor({
    super.key,
    required this.controller,
    required this.api,
    this.isBlockMode = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final AdminApiClient api;
  final bool isBlockMode;
  final VoidCallback? onChanged;

  @override
  State<MarkdownPlusEditor> createState() => _MarkdownPlusEditorState();
}

class _MarkdownPlusEditorState extends State<MarkdownPlusEditor> {
  bool isPreviewVisible = true;
  bool isFullScreen = false;
  bool isOutlineVisible = false;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();
  final ScrollController _previewScrollController = ScrollController();
  
  List<String> _outline = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateOutline);
    widget.controller.addListener(_onTextChanged);
    _updateOutline();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateOutline);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _editorScrollController.dispose();
    _previewScrollController.dispose();
    super.dispose();
  }

  void _updateOutline() {
    final text = widget.controller.text;
    final lines = text.split('\n');
    final newOutline = <String>[];
    for (final line in lines) {
      if (line.startsWith('#')) {
        newOutline.add(line);
      }
    }
    if (!listEquals(_outline, newOutline)) {
      setState(() {
        _outline = newOutline;
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
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  maxLines: null,
                  expands: true,
                  scrollController: _editorScrollController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    hintText: '开始你的创作...',
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.5,
                  ),
                  onChanged: (_) => widget.onChanged?.call(),
                ),
              ),
              if (isPreviewVisible) const VerticalDivider(width: 1),
              if (isPreviewVisible)
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.grey.shade50,
                    child: SingleChildScrollView(
                      controller: _previewScrollController,
                      padding: const EdgeInsets.all(24),
                      child: MarkdownBody(
                        data: widget.controller.text,
                        selectable: true,
                        extensionSet: md.ExtensionSet(
                          [
                            const md.FencedCodeBlockSyntax(),
                            const md.TableSyntax(),
                            const RegionBlockSyntax(),
                            const CalloutSyntax(), // Important: Custom block syntax
                            const ColumnBlockSyntax(),
                          ],
                          [
                            md.EmojiSyntax(),
                            HighlightSyntax(),
                            KeyboardSyntax(),
                            ProgressSyntax(),
                            StatusBadgeSyntax(),
                          ],
                        ),
                        builders: {
                          'region': RegionElementBuilder(),
                          'mdplus-callout': CalloutElementBuilder(), // Changed from 'callout'
                          'column': ColumnElementBuilder(),
                          'mark': HighlightElementBuilder(),
                          'kbd': KeyboardElementBuilder(),
                          'progress': ProgressElementBuilder(),
                          'badge': StatusBadgeElementBuilder(),
                        },
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
        ],
      ),
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
        ],
      ),
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
