part of 'package:windblog_admin_flutter/main.dart';

class InternalLinkGraphPage extends StatefulWidget {
  const InternalLinkGraphPage({
    super.key,
    required this.api,
    required this.onAuthError,
    this.postId,
  });
  final AdminApiClient api;
  final VoidCallback onAuthError;
  final int? postId;
  @override
  State<InternalLinkGraphPage> createState() => _InternalLinkGraphPageState();
}

class _InternalLinkGraphPageState extends State<InternalLinkGraphPage> {
  late final TextEditingController _root = TextEditingController(
    text: widget.postId?.toString() ?? '',
  );
  int _depth = 3;
  bool _loading = false;
  bool? _enabled;
  String? _error;
  Map<String, dynamic>? _graph;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _generation++;
    _root.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final status = await widget.api.seoGet('link-graph/status');
      if (!mounted) return;
      setState(() => _enabled = status['enabled'] == true);
      if (_enabled == true && widget.postId != null) await _analyze();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _analyze() async {
    final id = int.tryParse(_root.text.trim());
    if (id == null || id < 1) {
      setState(() => _error = '请输入有效的文章 ID');
      return;
    }
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.seoGet(
        'posts/$id/link-graph?depth=$_depth&maxNodes=150',
      );
      if (mounted && generation == _generation) setState(() => _graph = data);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.toString();
          _graph = null;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('内部链接图')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_enabled == null && _error == null)
            const LinearProgressIndicator(),
          if (_enabled == false) const Text('内部链接图尚未开启，请在系统设置 → SEO 中启用。'),
          if (_enabled == true) ...[
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _root,
                    enabled: !_loading,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '起始文章 ID'),
                    onSubmitted: (_) => _analyze(),
                  ),
                ),
                DropdownButton<int>(
                  value: _depth,
                  items: List.generate(
                    8,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('递归 ${index + 1} 层'),
                    ),
                  ),
                  onChanged: _loading
                      ? null
                      : (value) => setState(() => _depth = value ?? 3),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _analyze,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('分析链接图'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '箭头表示正文引用方向。可缩放、拖动；点击节点以该文章为起点继续分析。后台分析已发布公开文章的完整正文，前台仅展示公开预览的一层引用。',
            ),
          ],
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_graph != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '${(_graph!['nodes'] as List).length} 篇文章 · ${(_graph!['edges'] as List).length} 条引用${_graph!['truncated'] == true ? ' · 已达到分析上限，部分关系未展示' : ''}',
              ),
            ),
            Expanded(
              child: _InternalLinkGraphCanvas(
                graph: _graph!,
                onSelect: _loading
                    ? null
                    : (id) {
                        _root.text = '$id';
                        _analyze();
                      },
              ),
            ),
          ] else if (_enabled == true)
            const Expanded(child: Center(child: Text('选择文章与递归深度后开始分析'))),
        ],
      ),
    ),
  );
}

class _InternalLinkGraphCanvas extends StatelessWidget {
  const _InternalLinkGraphCanvas({required this.graph, this.onSelect});
  final Map<String, dynamic> graph;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final nodes = (graph['nodes'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final edges = (graph['edges'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
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
      max(900, (maxDepth + 1) * 270 + 40).toDouble(),
      max(450, maxRows * 100 + 40).toDouble(),
    );
    final positions = <int, Offset>{};
    for (final entry in lanes.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        positions[toInt(entry.value[i]['id'])!] = Offset(
          30 + entry.key * 270,
          20 + i * 100,
        );
      }
    }
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: colors.surfaceContainerLowest,
        child: InteractiveViewer(
          key: ValueKey('${graph['rootId']}-${graph['depth']}'),
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
                    painter: _InternalLinkEdgesPainter(
                      positions: positions,
                      edges: edges,
                      color: colors.outline,
                    ),
                  ),
                ),
                for (final node in nodes)
                  Positioned(
                    left: positions[toInt(node['id'])!]!.dx,
                    top: positions[toInt(node['id'])!]!.dy,
                    width: 220,
                    height: 64,
                    child: Tooltip(
                      message: '${node['title']}\n${node['slug']}',
                      child: Material(
                        color: node['id'] == graph['rootId']
                            ? colors.primaryContainer
                            : colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: onSelect == null
                              ? null
                              : () => onSelect!(toInt(node['id'])!),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  node['title']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: node['id'] == graph['rootId']
                                        ? colors.onPrimaryContainer
                                        : colors.onSurface,
                                  ),
                                ),
                                Text(
                                  '#${node['id']} · 第 ${node['depth']} 层',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

class _InternalLinkEdgesPainter extends CustomPainter {
  const _InternalLinkEdgesPainter({
    required this.positions,
    required this.edges,
    required this.color,
  });
  final Map<int, Offset> positions;
  final List<Map<String, dynamic>> edges;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (final edge in edges) {
      final source = positions[toInt(edge['source'])];
      final target = positions[toInt(edge['target'])];
      if (source == null || target == null) continue;
      final forward = target.dx > source.dx;
      final start = source + Offset(forward ? 220 : 0, 32);
      final end = target + Offset(forward ? 0 : 220, 32);
      final bend = forward ? 60.0 : -70.0;
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(
            start.dx + bend,
            start.dy,
            end.dx - bend,
            end.dy,
            end.dx,
            end.dy,
          ),
        paint,
      );
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
  bool shouldRepaint(covariant _InternalLinkEdgesPainter oldDelegate) =>
      oldDelegate.positions != positions ||
      oldDelegate.edges != edges ||
      oldDelegate.color != color;
}
