part of 'package:windblog_admin_flutter/main.dart';

md.ExtensionSet markdownEditorExtensionSet() => md.ExtensionSet(
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
);

Map<String, MarkdownElementBuilder> markdownEditorBuilders({
  AdminApiClient? api,
  ValueChanged<String>? onLinkTap,
  ValueChanged<String>? onImageTap,
}) => {
  'mdplus-callout': CalloutElementBuilder(),
  'mark': HighlightElementBuilder(),
  'kbd': KeyboardElementBuilder(),
  'progress': ProgressElementBuilder(),
  'badge': StatusBadgeElementBuilder(),
  'error-block': ErrorBlockBuilder(),
  'custom-container': CustomContainerBuilder(
    api: api,
    onLinkTap: onLinkTap,
    onImageTap: onImageTap,
  ),
  'gamification-hide': GamificationHideBuilder(
    api: api,
    onLinkTap: onLinkTap,
    onImageTap: onImageTap,
  ),
  'store-item': StoreItemBuilder(),
};

Map<String, MarkdownPaddingBuilder> markdownEditorPaddingBuilders() => {
  'blockquote': BlockquotePaddingBuilder(),
};

/// Custom Container Syntax (::: `<name>`)
class CustomContainerSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern =>
      RegExp(r'^:::\s+([a-zA-Z0-9_-]+)(?:\s+\{([^}]*)\})?\s*$');

  const CustomContainerSyntax();

  @override
  md.Node? parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    if (match == null) return null;

    final name = match.group(1)!.trim();
    final rawAttrStr = match.group(2) ?? '';
    final childLines = <String>[];

    parser.advance();

    bool foundEnd = false;
    while (!parser.isDone) {
      final line = parser.current.content.trim();
      if (line == '::: /$name') {
        foundEnd = true;
        parser.advance();
        break;
      }
      childLines.add(parser.current.content);
      parser.advance();
    }

    if (!foundEnd) {
      return md.Element('error-block', [md.Text('解析错误：缺少闭合标签 ::: /$name')])
        ..attributes['name'] = name;
    }

    final el = md.Element('custom-container', [md.Text(childLines.join('\n'))])
      ..attributes['name'] = name;
    if (rawAttrStr.isNotEmpty) {
      el.attributes['raw_attrs'] = rawAttrStr;
      final attrReg = RegExp(
        r'''([a-zA-Z0-9_-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^,\s}]+))''',
      );
      for (final m in attrReg.allMatches(rawAttrStr)) {
        final key = m.group(1)!.toLowerCase();
        final val = m.group(2) ?? m.group(3) ?? m.group(4) ?? '';
        el.attributes[key] = val.trim();
      }
    }
    return el;
  }
}

/// Callout Syntax for >!, >?, >i (Block Level)
class CalloutSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\s*>(!!|[!?i])\s*(.*)$');

  const CalloutSyntax();

  @override
  md.Node? parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    if (match == null) return null;

    final symbol = match.group(1);
    final content = match.group(2) ?? '';
    String type;
    switch (symbol) {
      case '!':
        type = 'warning';
        break;
      case '!!':
        type = 'danger';
        break;
      case '?':
        type = 'question';
        break;
      case 'i':
        type = 'info';
        break;
      default:
        type = 'info';
    }

    parser.advance();
    // Use a unique tag 'mdplus-callout' to avoid conflicts and force block rendering
    return md.Element('mdplus-callout', [md.Text(content)])
      ..attributes['type'] = type;
  }
}

/// Custom Inline Syntaxes
class HighlightSyntax extends md.InlineSyntax {
  HighlightSyntax() : super(r'==(.+?)==');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('mark', match.group(1)!));
    return true;
  }
}

class KeyboardSyntax extends md.InlineSyntax {
  KeyboardSyntax() : super(r'\[\[(.+?)\]\]');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('kbd', match.group(1)!));
    return true;
  }
}

class ProgressSyntax extends md.InlineSyntax {
  ProgressSyntax() : super(r'\[%\s*(\d+)\s*%\]');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final el = md.Element.empty('progress');
    el.attributes['value'] = match.group(1)!;
    parser.addNode(el);
    return true;
  }
}

class StatusBadgeSyntax extends md.InlineSyntax {
  StatusBadgeSyntax() : super(r'\[!!\s*(\w+)\s*\|\s*(.+?)\s*\]');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final el = md.Element.text('badge', match.group(2)!);
    el.attributes['status'] = match.group(1)!;
    parser.addNode(el);
    return true;
  }
}

/// [store-item id=X]
class StoreItemSyntax extends md.InlineSyntax {
  StoreItemSyntax() : super(r'\[store-item\s+id=(\d+)\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final el = md.Element.empty('store-item');
    el.attributes['id'] = match.group(1)!;
    parser.addNode(el);
    return true;
  }
}

/// [hide-text price=X] ... [/hide-text]
class HideContentSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern =>
      RegExp(r'^\[(hide-text|hide-attachment)(.*)\]\s*$', caseSensitive: false);

  const HideContentSyntax();

  @override
  md.Node? parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    if (match == null) return null;

    final type = match.group(1)!.toLowerCase();
    final attrStr = match.group(2) ?? '';

    // 提取属性
    String price = '0';
    final priceMatch = RegExp(
      r'price\s*=\s*(?:"([^"]*)"|(\d+))',
      caseSensitive: false,
    ).firstMatch(attrStr);
    if (priceMatch != null) {
      price = priceMatch.group(1) ?? priceMatch.group(2) ?? '0';
    }

    String? showText;
    final showMatch = RegExp(
      r'show\s*=\s*"([^"]*)"',
      caseSensitive: false,
    ).firstMatch(attrStr);
    if (showMatch != null) {
      showText = showMatch.group(1);
    }

    final childLines = <String>[];

    // 移动到起始标签之后的一行
    parser.advance();

    bool foundEnd = false;
    while (!parser.isDone) {
      final lineContent = parser.current.content;
      final trimmedLine = lineContent.trim();

      // 检查是否是对应的结束标签
      if (trimmedLine.toLowerCase() == '[/$type]') {
        foundEnd = true;
        parser.advance();
        break;
      }

      childLines.add(lineContent);
      parser.advance();
    }

    // 将捕获到的所有行合并，并包装成 gamification-hide 元素
    final el = md.Element('gamification-hide', [
      md.Text(childLines.join('\n')),
    ]);
    el.attributes['type'] = type;
    el.attributes['price'] = price;
    if (showText != null) el.attributes['show'] = showText;
    el.attributes['foundEnd'] = foundEnd.toString();
    return el;
  }
}

/// Padding Builders
class BlockquotePaddingBuilder extends MarkdownPaddingBuilder {
  int _paragraphIndex = 0;
  int _paragraphCount = 0;

  @override
  void visitElementBefore(md.Element element) {
    _paragraphIndex = 0;
    _paragraphCount = element.children?.whereType<md.Element>().length ?? 0;
  }

  @override
  EdgeInsets getPadding() {
    _paragraphIndex++;
    if (_paragraphCount > 1 && _paragraphIndex < _paragraphCount) {
      return const EdgeInsets.only(bottom: 16);
    }
    return EdgeInsets.zero;
  }
}

/// Element Builders
class BlockquoteBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    const color = Colors.green;
    const icon = Icons.check_circle_outline;

    // We don't have access to the pre-rendered children in visitElementAfter if we just use the text.
    // Standard blockquote has its own children parsed, but MarkdownElementBuilder is limited.
    // If we return a widget here, flutter_markdown uses it instead of standard blockquote.
    // We will just use textContent like the old RegionElementBuilder did.
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: const Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              element.textContent,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class CalloutElementBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final colors = ArticlePreviewPalette.of(context);
    final type = element.attributes['type'] ?? 'info';
    Color color;
    String label;
    IconData icon;

    switch (type) {
      case 'danger':
        color = const Color(0xffef4444);
        label = 'DANGER';
        icon = Icons.error_outline;
        break;
      case 'warning':
        color = const Color(0xfff59e0b);
        label = 'WARNING';
        icon = Icons.warning_amber_rounded;
        break;
      case 'question':
        color = const Color(0xff8b5cf6);
        label = 'QUESTION';
        icon = Icons.help_outline;
        break;
      default:
        color = const Color(0xff3b82f6);
        label = 'INFO';
        icon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      clipBehavior: Clip.antiAlias, // For rounded corners
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            width: double.infinity,
            color: color.withValues(alpha: 0.9), // Saturated
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          // Content Area
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            color: colors.hover,
            child: Text(
              element.textContent,
              style: TextStyle(color: colors.main, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final colors = ArticlePreviewPalette.of(context);
    final value = double.tryParse(element.attributes['value'] ?? '0') ?? 0;
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LinearProgressIndicator(
        value: value.clamp(0, 100) / 100,
        color: colors.accent,
        backgroundColor: colors.input,
        minHeight: 6,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class StatusBadgeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final status = element.attributes['status'] ?? 'default';
    Color color = status == 'p'
        ? const Color(0xff10b981)
        : (status == 'w'
              ? const Color(0xfff59e0b)
              : (status == 'e'
                    ? const Color(0xffef4444)
                    : const Color(0xff3b82f6)));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        element.textContent,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class KeyboardElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final colors = ArticlePreviewPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: colors.input,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: colors.border, offset: const Offset(0, 1)),
        ],
      ),
      child: Text(
        element.textContent,
        style: TextStyle(
          color: colors.main,
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class HighlightElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return Container(
      color: const Color(0xfffef08a).withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        element.textContent,
        style: const TextStyle(
          color: Color(0xfffde047),
          fontSize: 15,
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class ErrorBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
            : Colors.red.withValues(alpha: 0.1),
        border: Border.all(
          color: isDark
              ? Colors.red.shade400.withValues(alpha: 0.5)
              : Colors.red.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: isDark ? Colors.red.shade300 : Colors.red.shade700,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            element.textContent,
            style: TextStyle(
              color: isDark ? Colors.red.shade200 : Colors.red.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomContainerBuilder extends MarkdownElementBuilder {
  CustomContainerBuilder({this.api, this.onLinkTap, this.onImageTap});
  final AdminApiClient? api;
  final ValueChanged<String>? onLinkTap;
  final ValueChanged<String>? onImageTap;
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final containerName = (element.attributes['name'] ?? '').toLowerCase();
    if (containerName == 'article') {
      final colors = ArticlePreviewPalette.of(context);
      return ArticleReferenceCard(
        child: ArticlePreviewMarkdown(
          data: element.textContent,
          api: api,
          onLinkTap: onLinkTap,
          onImageTap: onImageTap,
          styleSheet: articlePreviewStyle(context).copyWith(
            p: TextStyle(fontSize: 13, height: 1.6, color: colors.body),
            a: TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
        ),
      );
    }
    if (containerName == 'asciinema-player' || containerName == 'asciinema') {
      return AsciinemaPreviewCard(element: element, api: api);
    }
    return SizedBox(
      width: double.infinity,
      child: ArticlePreviewMarkdown(
        data: element.textContent,
        api: api,
        onLinkTap: onLinkTap,
        onImageTap: onImageTap,
      ),
    );
  }
}

class AsciinemaPreviewCard extends StatefulWidget {
  const AsciinemaPreviewCard({super.key, required this.element, this.api});

  final md.Element element;
  final AdminApiClient? api;

  @override
  State<AsciinemaPreviewCard> createState() => _AsciinemaPreviewCardState();
}

class _AsciinemaPreviewCardState extends State<AsciinemaPreviewCard> {
  AsciicastEditorController? _previewController;
  bool _loadingCast = false;
  bool _showTerminalPreview = false;
  String? _loadError;
  String? _loadedSrc;

  ({
    String src,
    String title,
    String idleTimeLimit,
    String speed,
    bool pauseOnMarkers,
  })
  _extractConfig() {
    final attrs = widget.element.attributes;
    var src = attrs['src'] ?? attrs['url'] ?? '';
    var title = attrs['title'] ?? '';
    final idle =
        attrs['idletimelimit'] ??
        attrs['idle-time-limit'] ??
        attrs['idle_time_limit'] ??
        '2';
    final speed = attrs['speed'] ?? '1';
    final pauseOnMarkers =
        (attrs['pauseonmarkers'] ??
                attrs['pause-on-markers'] ??
                attrs['pause_on_markers'] ??
                'true')
            .toLowerCase() !=
        'false';

    final body = widget.element.textContent.trim();
    if (body.isNotEmpty) {
      final linkMatch = RegExp(r'\[([^\]]*)\]\(([^)]+)\)').firstMatch(body);
      if (linkMatch != null) {
        if (title.isEmpty) title = linkMatch.group(1)!.trim();
        if (src.isEmpty) src = linkMatch.group(2)!.trim();
      } else if (src.isEmpty) {
        for (final rawLine in body.split('\n')) {
          final line = rawLine.trim();
          if (line.startsWith('/') ||
              line.startsWith('http://') ||
              line.startsWith('https://')) {
            src = line;
            break;
          }
        }
      }
    }
    if (title.isEmpty) {
      title = src.isEmpty ? 'Asciinema Recording' : src.split('/').last;
    }
    return (
      src: src,
      title: title,
      idleTimeLimit: idle,
      speed: speed,
      pauseOnMarkers: pauseOnMarkers,
    );
  }

  @override
  void dispose() {
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _toggleLivePreview(String src) async {
    if (_showTerminalPreview) {
      _previewController?.pause();
      setState(() => _showTerminalPreview = false);
      return;
    }

    setState(() {
      _showTerminalPreview = true;
      _loadError = null;
    });

    if (_previewController != null && _loadedSrc == src) {
      return;
    }

    setState(() => _loadingCast = true);
    try {
      String castText;
      if (widget.api != null && src.isNotEmpty) {
        castText = await widget.api!.fetchTextResource(src);
      } else {
        castText = '';
      }
      if (!mounted) return;
      _previewController?.dispose();
      _previewController = AsciicastEditorController(
        initialCastContent: castText,
        initialClipName: src.split('/').last,
      );
      _loadedSrc = src;
      setState(() => _loadingCast = false);
    } catch (e) {
      if (!mounted) return;
      _previewController?.dispose();
      _previewController = AsciicastEditorController();
      setState(() {
        _loadingCast = false;
        _loadError = '加载远程录屏失败，已载入演示预览 ($e)';
      });
    }
  }

  Future<void> _openNleDialog(String src, String title) async {
    String? initialCast;
    if (widget.api != null && src.isNotEmpty) {
      try {
        initialCast = await widget.api!.fetchTextResource(src);
      } catch (_) {}
    }
    if (!mounted) return;
    await AsciicastEditorDialog.show(
      context,
      initialCastContent: initialCast,
      initialFileName: title.endsWith('.cast') ? title : '$title.cast',
      exportButtonLabel: '完成预览剪辑',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ArticlePreviewPalette.of(context);
    final cfg = _extractConfig();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: colors.hover,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.terminal, size: 16, color: Colors.cyan),
                    const SizedBox(width: 6),
                    Text(
                      cfg.title,
                      style: TextStyle(
                        color: colors.main,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'idleTimeLimit: ${cfg.idleTimeLimit}s · ${cfg.speed}x · pauseOnMarkers: ${cfg.pauseOnMarkers}',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => _toggleLivePreview(cfg.src),
                      icon: Icon(
                        _showTerminalPreview
                            ? Icons.visibility_off_outlined
                            : Icons.play_circle_outline,
                        size: 15,
                      ),
                      label: Text(
                        _showTerminalPreview
                            ? '收起 termui_flutter 预览'
                            : 'termui_flutter 实时预览',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      onPressed: () => _openNleDialog(cfg.src, cfg.title),
                      icon: const Icon(Icons.video_settings_outlined, size: 14),
                      label: const Text(
                        '非线性编辑器',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (cfg.src.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                '录屏源: ${cfg.src}',
                style: TextStyle(
                  color: colors.body,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          if (_showTerminalPreview)
            Container(
              height: 300,
              padding: const EdgeInsets.all(10),
              color: const Color(0xFF0B0E14),
              child: _loadingCast
                  ? const Center(child: CircularProgressIndicator())
                  : _previewController == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        if (_loadError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              _loadError!,
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        Expanded(
                          child: AsciicastTerminalPreview(
                            controller: _previewController!,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ListenableBuilder(
                          listenable: _previewController!,
                          builder: (context, _) {
                            final ctrl = _previewController!;
                            return Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    ctrl.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  onPressed: ctrl.togglePlay,
                                ),
                                Expanded(
                                  child: Slider(
                                    value: ctrl.playheadTime.clamp(
                                      0.0,
                                      ctrl.totalDuration > 0
                                          ? ctrl.totalDuration
                                          : 1.0,
                                    ),
                                    min: 0.0,
                                    max: ctrl.totalDuration > 0
                                        ? ctrl.totalDuration
                                        : 1.0,
                                    onChanged: (v) {
                                      ctrl.pause();
                                      ctrl.seek(v);
                                    },
                                  ),
                                ),
                                TextButton(
                                  onPressed: ctrl.jumpToFinalResult,
                                  child: const Text(
                                    '查看最终结果',
                                    style: TextStyle(
                                      color: Colors.tealAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class GamificationHideBuilder extends MarkdownElementBuilder {
  GamificationHideBuilder({this.api, this.onLinkTap, this.onImageTap});
  final AdminApiClient? api;
  final ValueChanged<String>? onLinkTap;
  final ValueChanged<String>? onImageTap;
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final type = element.attributes['type'] ?? 'hide-text';
    final price = element.attributes['price'] ?? '0';
    final showText = element.attributes['show'];
    final isAttachment = type == 'hide-attachment';
    final content = element.textContent;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAttachment ? Icons.attach_file : Icons.lock_open,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  showText ?? (isAttachment ? '付费附件区块' : '付费隐藏内容'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (price != '0') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$price 积分',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ArticlePreviewMarkdown(
              data: content.trim().isEmpty ? '_该区块内容为空_' : content,
              api: api,
              onLinkTap: onLinkTap,
              onImageTap: onImageTap,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreItemBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final id = element.attributes['id'] ?? '0';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_bag_outlined, color: Colors.blue, size: 18),
          const SizedBox(width: 8),
          Text(
            '商店物品引用 (ID: $id)',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 10),
        ],
      ),
    );
  }
}
