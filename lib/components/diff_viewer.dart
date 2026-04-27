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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
              children: diffs.map((diff) {
                final text = diff.text;
                Color? bgColor;
                Color? textColor;
                TextDecoration? decoration;

                if (diff.operation == diff_match_patch.DIFF_INSERT) {
                  bgColor = Colors.green.shade100;
                  textColor = Colors.green.shade900;
                } else if (diff.operation == diff_match_patch.DIFF_DELETE) {
                  bgColor = Colors.red.shade100;
                  textColor = Colors.red.shade900;
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
