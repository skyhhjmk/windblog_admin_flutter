part of 'package:windblog_admin_flutter/main.dart';

/// Custom Block Syntax for Semantic Regions (::: type)
class RegionBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^:::\s*(\w+)\s*$');

  const RegionBlockSyntax();

  @override
  md.Node? parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    if (match == null) return null;
    
    final type = match.group(1)!;
    final childLines = <String>[];
    parser.advance();
    
    while (!parser.isDone) {
      if (RegExp(r'^:::\s*$').hasMatch(parser.current.content)) {
        parser.advance();
        break;
      }
      childLines.add(parser.current.content);
      parser.advance();
    }
    
    return md.Element('region', [
      md.Text(childLines.join('\n'))
    ])..attributes['type'] = type;
  }
}

/// Column Layout Syntax (::: column)
class ColumnBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^:::\s*column\s*$');

  const ColumnBlockSyntax();

  @override
  md.Node? parse(md.BlockParser parser) {
    parser.advance();
    final childLines = <String>[];
    
    while (!parser.isDone) {
      if (RegExp(r'^:::\s*$').hasMatch(parser.current.content)) {
        parser.advance();
        break;
      }
      childLines.add(parser.current.content);
      parser.advance();
    }

    final content = childLines.join('\n');
    final columns = content.split('|');
    
    return md.Element('column', columns.map((col) => md.Element.text('col-item', col.trim())).toList());
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

/// Element Builders
class RegionElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final type = element.attributes['type'] ?? 'info';
    final content = element.textContent;
    Color color = _getColor(type);
    IconData icon = _getIcon(type);

    return Container(
      width: double.infinity, // Force full width
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(content, style: const TextStyle(fontSize: 14, height: 1.5))),
        ],
      ),
    );
  }

  Color _getColor(String type) {
    switch (type) {
      case 'tip': return Colors.green;
      case 'warning': return Colors.orange;
      case 'error': case 'danger': return Colors.red;
      default: return Colors.blue;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'tip': return Icons.check_circle_outline;
      case 'warning': return Icons.warning_amber_rounded;
      case 'error': case 'danger': return Icons.error_outline;
      default: return Icons.info_outline;
    }
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

class ColumnElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: element.children?.map((child) {
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    child.textContent,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              );
            }).toList() ??
            [],
      ),
    );
  }
}
