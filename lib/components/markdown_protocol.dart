part of 'package:windblog_admin_flutter/main.dart';

/// Custom Container Syntax (::: `<name>`)
class CustomContainerSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^:::\s+([a-zA-Z0-9_-]+)$');

  const CustomContainerSyntax();

  @override
  md.Node? parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    if (match == null) return null;

    final name = match.group(1)!.trim();
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
      return md.Element(
          'error-block', [md.Text('解析错误：缺少闭合标签 ::: /$name')])
        ..attributes['name'] = name;
    }

    return md.Element('custom-container', [md.Text(childLines.join('\n'))])
      ..attributes['name'] = name;
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
      case '!': type = 'warning'; break;
      case '!!': type = 'danger'; break;
      case '?': type = 'question'; break;
      case 'i': type = 'info'; break;
      default: type = 'info';
    }

    parser.advance();
    // Use a unique tag 'mdplus-callout' to avoid conflicts and force block rendering
    return md.Element('mdplus-callout', [md.Text(content)])..attributes['type'] = type;
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
      RegExp(r'^\[(hide-text|hide-attachment)(?:\s+price\s*=\s*(\d+))?\]\s*$',
          caseSensitive: false);

  const HideContentSyntax();

  @override
  md.Node? parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    if (match == null) return null;

    final type = match.group(1)!.toLowerCase();
    final price = match.group(2) ?? '0';
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
    final el = md.Element(
        'gamification-hide', [md.Text(childLines.join('\n'))]);
    el.attributes['type'] = type;
    el.attributes['price'] = price;
    el.attributes['foundEnd'] = foundEnd.toString();
    return el;
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
          Expanded(child: Text(element.textContent,
              style: const TextStyle(fontSize: 14, height: 1.5))),
        ],
      ),
    );
  }
}

class CalloutElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final type = element.attributes['type'] ?? 'info';
    Color color;
    String label;
    IconData icon;
    
    switch (type) {
      case 'danger':
        color = Colors.red;
        label = 'DANGER';
        icon = Icons.error_outline;
        break;
      case 'warning':
        color = Colors.orange;
        label = 'WARNING';
        icon = Icons.warning_amber_rounded;
        break;
      case 'question':
        color = Colors.deepPurple;
        label = 'QUESTION';
        icon = Icons.help_outline;
        break;
      default:
        color = Colors.blue;
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
                    fontWeight: FontWeight.bold,
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
            color: color.withValues(alpha: 0.05), // Transparent
            child: Text(
              element.textContent,
              style: TextStyle(
                color: Colors.grey.shade900,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final value = double.tryParse(element.attributes['value'] ?? '0') ?? 0;
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LinearProgressIndicator(value: value / 100, minHeight: 6, borderRadius: BorderRadius.circular(3)),
    );
  }
}

class StatusBadgeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final status = element.attributes['status'] ?? 'default';
    Color color = status == 'p' ? Colors.green : (status == 'w' ? Colors.orange : (status == 'e' ? Colors.red : Colors.blue));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Text(element.textContent, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class KeyboardElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.grey.shade300, offset: const Offset(0, 1))]),
      child: Text(element.textContent, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

class HighlightElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(color: Colors.yellow.withValues(alpha: 0.3), padding: const EdgeInsets.symmetric(horizontal: 2), child: Text(element.textContent, style: const TextStyle(fontWeight: FontWeight.w500)));
  }
}

class ErrorBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
          const SizedBox(width: 8),
          Text(
            element.textContent,
            style: TextStyle(color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class CustomContainerBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // We just render the inner text using MarkdownBody to support all Markdown syntax inside.
    return SizedBox(
      width: double.infinity,
      child: MarkdownBody(
        data: element.textContent,
        selectable: false,
        extensionSet: md.ExtensionSet(
          [
            const md.FencedCodeBlockSyntax(),
            const md.TableSyntax(),
            const CustomContainerSyntax(),
            const CalloutSyntax(),
            const HideContentSyntax(),
          ],
          [
            md.EmojiSyntax(),
            HighlightSyntax(),
            KeyboardSyntax(),
            ProgressSyntax(),
            StatusBadgeSyntax(),
            StoreItemSyntax(),
          ],
        ),
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
    );
  }
}

class GamificationHideBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final type = element.attributes['type'] ?? 'hide-text';
    final price = element.attributes['price'] ?? '0';
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
                  topLeft: Radius.circular(7), topRight: Radius.circular(7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isAttachment ? Icons.attach_file : Icons.lock_open,
                    color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  isAttachment ? '付费附件区块' : '付费隐藏内容',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
                if (price != '0') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('$price 积分', style: const TextStyle(
                        color: Colors.white, fontSize: 10)),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: MarkdownBody(
              data: content
                  .trim()
                  .isEmpty ? '_该区块内容为空_' : content,
              selectable: true,
              softLineBreak: true,
              // 启用软换行
              extensionSet: md.ExtensionSet(
                [
                  const md.FencedCodeBlockSyntax(),
                  const md.TableSyntax(),
                ],
                [
                  md.EmojiSyntax(),
                ],
              ),
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                    color: Colors.grey.shade800, fontSize: 13, height: 1.5),
              ),
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
                color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 10),
        ],
      ),
    );
  }
}
