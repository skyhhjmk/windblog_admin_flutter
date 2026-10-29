part of 'package:windblog_admin_flutter/main.dart';

/// Store a portable link, rather than admin-only IDs or draft content.
String articleReferenceMarkdown(PostItem article) {
  final title =
      (article.zhTitle.trim().isEmpty ? article.slug : article.zhTitle)
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAllMapped(
            RegExp(r'[\\`*_{}\[\]()<>!#|~]'),
            (match) => '\\${match[0]}',
          );
  final slug = Uri.encodeComponent(
    article.slug,
  ).replaceAll('(', '%28').replaceAll(')', '%29');
  return '\n\n::: article\n[$title](/post/$slug)\n::: /article\n\n';
}

class ArticleReferencePicker extends StatefulWidget {
  const ArticleReferencePicker({
    super.key,
    required this.api,
    this.dialogTitle = '引用文章',
    this.description = '选择已公开发布的文章，以卡片形式嵌入正文。',
  });
  final AdminApiClient api;
  final String dialogTitle;
  final String description;

  @override
  State<ArticleReferencePicker> createState() => _ArticleReferencePickerState();
}

class _ArticleReferencePickerState extends State<ArticleReferencePicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _generation = 0;
  int _page = 1;
  int _total = 0;
  static const _pageSize = 20;
  List<PostItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _generation++;
    setState(() {
      _loading = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 300), () => _load(1));
  }

  Future<void> _load(int page) async {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _page = page;
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.listPosts(
        page: page,
        pageSize: _pageSize,
        keyword: _search.text.trim(),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = '加载文章失败：$error';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.dialogTitle),
    content: SizedBox(
      width: 640,
      height: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _search,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '搜索文章标题或 slug',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _searchChanged,
            onSubmitted: (_) => _load(1),
          ),
          const SizedBox(height: 8),
          Text(widget.description),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: () => _load(_page),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : _items.isEmpty
                ? const Center(child: Text('没有找到文章'))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, index) {
                      final article = _items[index];
                      final available =
                          article.status == 1 &&
                          article.visibility == 0 &&
                          article.hasPublishedRevision;
                      return ListTile(
                        enabled: available,
                        leading: const Icon(Icons.article_outlined),
                        title: Text(
                          article.zhTitle.trim().isEmpty
                              ? article.slug
                              : article.zhTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          available
                              ? '/post/${article.slug}'
                              : '${article.slug} · 未公开发布，无法引用',
                        ),
                        trailing: available
                            ? const Icon(Icons.add)
                            : const Icon(Icons.lock_outline),
                        onTap: available
                            ? () => Navigator.pop(context, article)
                            : null,
                      );
                    },
                  ),
          ),
          Row(
            children: [
              Expanded(child: Text('第 $_page 页 · 共 $_total 篇')),
              IconButton(
                tooltip: '上一页',
                onPressed: _loading || _error != null || _page <= 1
                    ? null
                    : () => _load(_page - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: '下一页',
                onPressed:
                    _loading || _error != null || _page * _pageSize >= _total
                    ? null
                    : () => _load(_page + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
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
