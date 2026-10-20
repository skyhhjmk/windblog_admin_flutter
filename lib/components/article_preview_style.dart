part of 'package:windblog_admin_flutter/main.dart';

/// Native equivalents of theme.css tokens and .prose rules. Keep these aligned
/// when changing the public article theme, rather than inheriting AdminTheme.
class ArticlePreviewPalette {
  const ArticlePreviewPalette(this.dark);
  final bool dark;
  Color get background => dark ? const Color(0xff0d1117) : Colors.white;
  Color get body => dark ? const Color(0xff94a3b8) : const Color(0xff374151);
  Color get main =>
      dark ? Colors.white.withValues(alpha: .9) : const Color(0xff111827);
  Color get accent => dark ? const Color(0xff06b6d4) : const Color(0xff0891b2);
  Color get input => dark ? const Color(0xff161b22) : const Color(0xfff3f4f6);
  Color get border =>
      (dark ? Colors.white : Colors.black).withValues(alpha: dark ? .05 : .08);
  Color get hover =>
      (dark ? Colors.white : Colors.black).withValues(alpha: dark ? .01 : .02);
  static ArticlePreviewPalette of(BuildContext context) =>
      ArticlePreviewPalette(Theme.of(context).brightness == Brightness.dark);
}

MarkdownStyleSheet articlePreviewStyle(BuildContext context) {
  final colors = ArticlePreviewPalette.of(context);
  final body = TextStyle(
    fontSize: 15,
    height: 1.6,
    color: colors.body,
    fontWeight: FontWeight.w400,
  );
  // Tailwind's reset leaves .prose headings at the inherited size and weight;
  // the site distinguishes h1-h3 using the main color and 2.5em/1em spacing.
  final heading = body.copyWith(color: colors.main);
  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    p: body,
    pPadding: const EdgeInsets.only(bottom: 16),
    a: body.copyWith(color: colors.accent, decoration: TextDecoration.none),
    h1: heading,
    h2: heading,
    h3: heading,
    h4: body,
    h5: body,
    h6: body,
    h1Padding: const EdgeInsets.only(top: 37.5, bottom: 15),
    h2Padding: const EdgeInsets.only(top: 37.5, bottom: 23),
    h3Padding: const EdgeInsets.only(top: 37.5, bottom: 15),
    blockSpacing: 0,
    listBullet: body,
    listIndent: 24,
    code: body.copyWith(
      fontFamily: 'monospace',
      fontSize: 13.5,
      color: colors.accent.withValues(alpha: .8),
      backgroundColor: colors.input,
    ),
    codeblockPadding: const EdgeInsets.all(8),
    codeblockDecoration: BoxDecoration(
      color: colors.input,
      borderRadius: BorderRadius.circular(4),
    ),
    blockquote: body.copyWith(
      color: colors.main,
      fontSize: 14,
      height: 1.5,
      fontStyle: FontStyle.italic,
    ),
    blockquotePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    blockquoteDecoration: BoxDecoration(
      color: colors.hover,
      border: Border(
        left: BorderSide(
          color: colors.dark
              ? const Color(0xff164e63)
              : const Color(0xffcffafe),
          width: 2,
        ),
      ),
      borderRadius: BorderRadius.circular(4),
    ),
    tableHead: body.copyWith(fontWeight: FontWeight.w700),
    tableBody: body,
    tableHeadAlign: TextAlign.left,
    tableBorder: TableBorder.all(color: colors.border),
    tableColumnWidth: const MaxColumnWidth(
      FixedColumnWidth(128),
      IntrinsicColumnWidth(),
    ),
    tableCellsPadding: const EdgeInsets.symmetric(
      horizontal: 14.4,
      vertical: 11.2,
    ),
    tablePadding: const EdgeInsets.symmetric(vertical: 28),
    tableCellsDecoration: BoxDecoration(color: colors.hover),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: colors.border)),
    ),
  );
}

/// Nested containers must use the same typography and instance-aware media as
/// the outer document, including link/image actions in the editor.
class ArticlePreviewMarkdown extends StatelessWidget {
  const ArticlePreviewMarkdown({
    super.key,
    required this.data,
    this.api,
    this.onLinkTap,
    this.onImageTap,
    this.styleSheet,
  });
  final String data;
  final MarkdownStyleSheet? styleSheet;
  final AdminApiClient? api;
  final ValueChanged<String>? onLinkTap;
  final ValueChanged<String>? onImageTap;

  @override
  Widget build(BuildContext context) => MarkdownBody(
    data: data,
    selectable: false,
    styleSheet: styleSheet ?? articlePreviewStyle(context),
    extensionSet: markdownEditorExtensionSet(),
    builders: markdownEditorBuilders(
      api: api,
      onLinkTap: onLinkTap,
      onImageTap: onImageTap,
    ),
    onTapLink: (_, href, _) {
      if (href != null) onLinkTap?.call(href);
    },
    imageBuilder: api == null
        ? null
        : (uri, title, alt) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: GestureDetector(
              onTap: () => onImageTap?.call(uri.toString()),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _FriendlyNetworkImage(
                  url: uri.toString(),
                  api: api!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
  );
}

class ArticleReferenceCard extends StatelessWidget {
  const ArticleReferenceCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ArticlePreviewPalette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.hover,
        border: Border.all(color: colors.accent.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.article_outlined, size: 16, color: colors.body),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '引用文章',
                  style: TextStyle(fontSize: 12, color: colors.body),
                ),
              ),
              Icon(Icons.north_east, size: 16, color: colors.accent),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
