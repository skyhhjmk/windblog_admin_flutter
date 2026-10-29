part of 'package:windblog_admin_flutter/main.dart';

class ArticleMapPage extends StatefulWidget {
  const ArticleMapPage({
    super.key,
    required this.api,
    required this.onAuthError,
    this.postId,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;
  final int? postId;

  @override
  State<ArticleMapPage> createState() => _ArticleMapPageState();
}

class _ArticleMapPageState extends State<ArticleMapPage> {
  static const List<(String, String)> _languages = [
    ('zh-cn', '简体中文'),
    ('en-US', '英语'),
  ];

  int? _rootId;
  String? _rootTitle;
  String _language = 'zh-cn';
  int _depth = 2;
  static const int _maxNodes = 80;
  int _relatedPerNode = 4;
  Map<String, dynamic>? _map;
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.postId != null) {
      _rootId = widget.postId;
      _loadRootTitle(widget.postId!);
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _loadRootTitle(int id) async {
    try {
      final detail = await widget.api.postDetail(id);
      if (!mounted) return;
      setState(
        () => _rootTitle =
            detail.title['zh-cn'] ??
            (detail.title.isEmpty ? detail.slug : detail.title.values.first),
      );
    } catch (_) {
      // The graph request will surface a concrete error if the post is invalid.
    }
  }

  Future<void> _chooseRoot() async {
    final article = await showDialog<PostItem>(
      context: context,
      builder: (_) => ArticleReferencePicker(
        api: widget.api,
        dialogTitle: '选择文章地图起点',
        description: '选择一篇已公开发布的文章，查看它与其它文章之间的显式引用和 ES 模糊关联。',
      ),
    );
    if (article == null || !mounted) return;
    setState(() {
      _rootId = article.id;
      _rootTitle = article.zhTitle.trim().isEmpty
          ? article.slug
          : article.zhTitle;
      _map = null;
    });
    await _load();
  }

  Future<void> _load() async {
    final rootId = _rootId;
    if (rootId == null) {
      setState(() => _error = '请先选择起点文章');
      return;
    }
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.articleMap(
        rootId,
        language: _language,
        depth: _depth,
        maxNodes: _maxNodes,
        relatedPerNode: _relatedPerNode,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _map = data;
        _loading = false;
      });
    } on UnauthorizedException {
      widget.onAuthError();
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = '读取文章地图失败：$error';
        _loading = false;
        _map = null;
      });
    }
  }

  void _selectNode(int id) {
    setState(() {
      _rootId = id;
      _map = null;
    });
    unawaited(_loadRootTitle(id));
    unawaited(_load());
  }

  Widget _toolbar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _loading ? null : _chooseRoot,
                  icon: const Icon(Icons.article_outlined, size: 18),
                  label: Text(_rootId == null ? '选择起点文章' : '更换起点文章'),
                ),
                SizedBox(
                  width: 220,
                  child: Text(
                    _rootTitle ?? (_rootId == null ? '未选择文章' : '#$_rootId'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    initialValue: _language,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '语言',
                      isDense: true,
                    ),
                    items: _languages
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.$1,
                            child: Text('${entry.$2} (${entry.$1})'),
                          ),
                        )
                        .toList(),
                    onChanged: _loading
                        ? null
                        : (value) {
                            if (value == null || value == _language) return;
                            setState(() => _language = value);
                            unawaited(_load());
                          },
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<int>(
                    initialValue: _depth,
                    decoration: const InputDecoration(
                      labelText: '显式链接深度',
                      isDense: true,
                    ),
                    items: List.generate(
                      4,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1} 层'),
                      ),
                    ),
                    onChanged: _loading
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _depth = value);
                            unawaited(_load());
                          },
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    initialValue: _relatedPerNode,
                    decoration: const InputDecoration(
                      labelText: '每篇 ES 关联',
                      isDense: true,
                    ),
                    items: List.generate(
                      9,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text(index == 0 ? '关闭' : '$index 篇'),
                      ),
                    ),
                    onChanged: _loading
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _relatedPerNode = value);
                            unawaited(_load());
                          },
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading || _rootId == null ? null : _load,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重新分析'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const _ArticleMapLegend(
                  color: Color(0xFF64748B),
                  dashed: false,
                  label: '显式链接引用（正文中的文章链接）',
                ),
                const _ArticleMapLegend(
                  color: Color(0xFFF59E0B),
                  dashed: true,
                  label: 'ES 模糊关联（more_like_this / fuzzy）',
                ),
                if (_map?['esAvailable'] == false)
                  Text(
                    'Elasticsearch 当前不可用，仅显示显式链接关系',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_rootId == null) {
      return AdminStatusView.empty(
        title: '还没有选择文章',
        message: '选择一篇已公开发布的文章，查看它的内部链接与 ES 模糊关联。',
        action: FilledButton.icon(
          onPressed: _chooseRoot,
          icon: const Icon(Icons.article_outlined),
          label: const Text('选择起点文章'),
        ),
      );
    }
    if (_error != null) {
      return AdminStatusView.error(
        title: '读取文章地图失败',
        message: _error,
        action: FilledButton.tonal(
          onPressed: _loading ? null : _load,
          child: const Text('重试'),
        ),
      );
    }
    if (_loading && _map == null) {
      return const AdminStatusView.loading(title: '正在分析文章关系与 ES 关联');
    }
    final map = _map;
    if (map == null) {
      return const AdminStatusView.empty(title: '暂无文章地图');
    }
    final nodes = (map['nodes'] as List<dynamic>? ?? [])
        .map((item) => toDynamicMap(item))
        .toList();
    final edges = (map['edges'] as List<dynamic>? ?? [])
        .map((item) => toDynamicMap(item))
        .toList();
    final explicitCount = edges.where((edge) => edge['type'] != 'FUZZY').length;
    final fuzzyCount = edges.where((edge) => edge['type'] == 'FUZZY').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('${nodes.length} 篇文章'),
              Text('$explicitCount 条显式链接'),
              Text('$fuzzyCount 条 ES 模糊关联'),
              if (map['relatedCacheHits'] != null)
                Text('缓存命中 ${map['relatedCacheHits']}'),
              if (map['truncated'] == true)
                Text(
                  '已达到分析上限，部分关系未展示',
                  style: TextStyle(color: Colors.orange.shade800),
                ),
            ],
          ),
        ),
        Expanded(
          child: _ArticleMapCanvas(
            map: map,
            onSelect: _loading ? null : _selectNode,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: '文章地图',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      filters: _toolbar(),
      body: _content(),
    );
  }
}

class _ArticleMapLegend extends StatelessWidget {
  const _ArticleMapLegend({
    required this.color,
    required this.dashed,
    required this.label,
  });

  final Color color;
  final bool dashed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(34, 12),
          painter: _ArticleMapLegendPainter(color: color, dashed: dashed),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}

class _ArticleMapLegendPainter extends CustomPainter {
  const _ArticleMapLegendPainter({required this.color, required this.dashed});
  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
    canvas.drawPath(dashed ? _dashPath(path, 6, 5) : path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArticleMapLegendPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}

Path _dashPath(Path source, double dash, double gap) {
  final result = Path();
  for (final metric in source.computeMetrics()) {
    double distance = 0;
    while (distance < metric.length) {
      final end = min(distance + dash, metric.length);
      result.addPath(metric.extractPath(distance, end), Offset.zero);
      distance = end + gap;
    }
  }
  return result;
}

class _ArticleMapCanvas extends StatelessWidget {
  const _ArticleMapCanvas({required this.map, this.onSelect});

  final Map<String, dynamic> map;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final nodes = (map['nodes'] as List<dynamic>? ?? [])
        .map((item) => toDynamicMap(item))
        .toList();
    final edges = (map['edges'] as List<dynamic>? ?? [])
        .map((item) => toDynamicMap(item))
        .toList();
    final lanes = <int, List<Map<String, dynamic>>>{};
    for (final node in nodes) {
      lanes.putIfAbsent(toInt(node['depth']) ?? 0, () => []).add(node);
    }
    final maxDepth = lanes.keys.fold<int>(0, max);
    final maxRows = lanes.values.fold<int>(
      1,
      (value, lane) => max(value, lane.length),
    );
    final size = Size(
      max(900, (maxDepth + 1) * 280 + 40).toDouble(),
      max(480, maxRows * 104 + 40).toDouble(),
    );
    final positions = <int, Offset>{};
    for (final entry in lanes.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        positions[toInt(entry.value[i]['id'])!] = Offset(
          30 + entry.key * 280,
          20 + i * 104,
        );
      }
    }
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: colors.surfaceContainerLowest,
        child: InteractiveViewer(
          key: ValueKey(
            '${map['rootId']}-${map['depth']}-${nodes.length}-${edges.length}',
          ),
          constrained: false,
          minScale: 0.12,
          maxScale: 2.5,
          boundaryMargin: const EdgeInsets.all(100),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ArticleMapEdgesPainter(
                      positions: positions,
                      edges: edges,
                      linkColor: colors.outline,
                      fuzzyColor: const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                for (final node in nodes)
                  Positioned(
                    left: positions[toInt(node['id'])!]!.dx,
                    top: positions[toInt(node['id'])!]!.dy,
                    width: 230,
                    height: 68,
                    child: _ArticleMapNodeCard(
                      node: node,
                      isRoot: node['id'] == map['rootId'],
                      onTap: onSelect == null
                          ? null
                          : () => onSelect!(toInt(node['id'])!),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleMapNodeCard extends StatelessWidget {
  const _ArticleMapNodeCard({
    required this.node,
    required this.isRoot,
    this.onTap,
  });

  final Map<String, dynamic> node;
  final bool isRoot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fuzzy = node['fuzzy'] == true;
    final borderColor = isRoot
        ? colors.primary
        : (fuzzy ? const Color(0xFFF59E0B) : colors.outlineVariant);
    return Tooltip(
      message:
          '${node['title']}\n${node['slug']}\n${fuzzy ? 'ES 模糊关联' : '显式链接文章'}',
      child: Material(
        color: isRoot
            ? colors.primaryContainer
            : (fuzzy ? const Color(0xFFFFF7E6) : colors.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderColor,
                width: isRoot || fuzzy ? 1.6 : 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        node['title']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isRoot
                              ? colors.onPrimaryContainer
                              : colors.onSurface,
                        ),
                      ),
                    ),
                    if (fuzzy)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ES',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '#${node['id']} · 第 ${node['depth']} 层',
                  style: TextStyle(
                    fontSize: 11,
                    color: isRoot
                        ? colors.onPrimaryContainer.withValues(alpha: 0.8)
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleMapEdgesPainter extends CustomPainter {
  const _ArticleMapEdgesPainter({
    required this.positions,
    required this.edges,
    required this.linkColor,
    required this.fuzzyColor,
  });

  final Map<int, Offset> positions;
  final List<Map<String, dynamic>> edges;
  final Color linkColor;
  final Color fuzzyColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final source = positions[toInt(edge['source'])];
      final target = positions[toInt(edge['target'])];
      if (source == null || target == null) continue;
      final fuzzy = edge['type'] == 'FUZZY';
      final color = fuzzy ? fuzzyColor : linkColor;
      final paint = Paint()
        ..color = color.withValues(alpha: fuzzy ? 0.85 : 0.7)
        ..strokeWidth = fuzzy ? 1.3 : 1.6
        ..style = PaintingStyle.stroke;
      final forward = target.dx > source.dx;
      final start = source + Offset(forward ? 230 : 0, 34);
      final end = target + Offset(forward ? 0 : 230, 34);
      final bend = forward ? 65.0 : -75.0;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + bend,
          start.dy,
          end.dx - bend,
          end.dy,
          end.dx,
          end.dy,
        );
      canvas.drawPath(fuzzy ? _dashPath(path, 7, 5) : path, paint);
      final direction = forward ? -1.0 : 1.0;
      canvas.drawPath(
        Path()
          ..moveTo(end.dx + 8 * direction, end.dy - 4)
          ..lineTo(end.dx, end.dy)
          ..lineTo(end.dx + 8 * direction, end.dy + 4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArticleMapEdgesPainter oldDelegate) =>
      oldDelegate.positions != positions ||
      oldDelegate.edges != edges ||
      oldDelegate.linkColor != linkColor ||
      oldDelegate.fuzzyColor != fuzzyColor;
}
