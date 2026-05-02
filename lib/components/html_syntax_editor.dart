part of 'package:windblog_admin_flutter/main.dart';

class HtmlSyntaxController extends TextEditingController {
  HtmlSyntaxController({super.text});

  @override
  TextSpan buildTextSpan(
      {required BuildContext context, TextStyle? style, required bool withComposing}) {
    final List<InlineSpan> spans = [];

    // Simple HTML highlighting regex
    // 1. Tags: <[^>]+>
    // 2. Comments: <!--.*?-->
    final pattern = RegExp(
      r'(<!--.*?-->)|(<[^>]+>)',
      dotAll: true,
    );

    int lastMatchEnd = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }

      if (match.group(1) != null) {
        // Comment
        spans.add(TextSpan(
          text: match.group(1),
          style: style?.copyWith(
              color: Colors.grey.shade500, fontStyle: FontStyle.italic),
        ));
      } else if (match.group(2) != null) {
        // Tag
        final tagText = match.group(2)!;
        spans.add(TextSpan(
          text: tagText,
          style: style?.copyWith(
              color: const Color(0xFF0D6EFD), fontWeight: FontWeight.bold),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ));
    }

    return TextSpan(style: style, children: spans);
  }
}

class HtmlSyntaxEditor extends StatelessWidget {
  const HtmlSyntaxEditor({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 32, vertical: 24),
              hintText: '在这里输入 HTML 内容...',
            ),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
