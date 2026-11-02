part of 'package:windblog_admin_flutter/main.dart';

class DiffViewer extends StatelessWidget {
  const DiffViewer({
    super.key,
    required this.oldText,
    required this.newText,
    this.title,
  });

  final String oldText;
  final String newText;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final dmp = diff_match_patch.DiffMatchPatch();
    final diffs = dmp.diff(oldText, newText);
    dmp.diffCleanupSemantic(diffs);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg =
        isDark
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.35)
            : Colors.grey.shade50;
    final containerBorder =
        isDark
            ? Theme.of(context).dividerColor.withValues(alpha: 0.3)
            : Colors.grey.shade300;
    final defaultTextColor =
        isDark ? Theme.of(context).colorScheme.onSurface : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: containerBg,
            border: Border.all(color: containerBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: defaultTextColor,
                height: 1.5,
              ),
              children:
                  diffs.map((diff) {
                    final text = diff.text;
                    Color? bgColor;
                    Color? textColor;
                    TextDecoration? decoration;

                    if (diff.operation == diff_match_patch.DIFF_INSERT) {
                      bgColor =
                          isDark
                              ? Colors.green.shade900.withValues(alpha: 0.4)
                              : Colors.green.shade100;
                      textColor =
                          isDark
                              ? Colors.green.shade200
                              : Colors.green.shade900;
                    } else if (diff.operation == diff_match_patch.DIFF_DELETE) {
                      bgColor =
                          isDark
                              ? Colors.red.shade900.withValues(alpha: 0.4)
                              : Colors.red.shade100;
                      textColor =
                          isDark ? Colors.red.shade200 : Colors.red.shade900;
                      decoration = TextDecoration.lineThrough;
                    }

                    return TextSpan(
                      text: text,
                      style: TextStyle(
                        backgroundColor: bgColor,
                        color: textColor,
                        decoration: decoration,
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
