part of 'package:windblog_admin_flutter/main.dart';

class HoneypotPage extends StatefulWidget {
  const HoneypotPage({super.key, required this.api, required this.onAuthError});

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<HoneypotPage> createState() => _HoneypotPageState();
}

class _HoneypotPageState extends State<HoneypotPage>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 20;
  static const int _eventsTabIndex = 3;
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  )..addListener(_handleTabChanged);
  final TextEditingController _ipController = TextEditingController();
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();
  String _ruleFilter = '';
  String _actionFilter = '';
  int _page = 1;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _events = [];
  int _total = 0;
  bool _loading = true;
  bool _statsLoading = true;
  bool _rulesLoading = true;
  bool _eventsLoading = true;
  late int _activeTabIndex = 0;
  String? _statsError;
  String? _rulesError;
  String? _eventsError;

  String get _fromIso => _from.toUtc().toIso8601String();
  String get _toIso => _to.toUtc().toIso8601String();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _handleTabChanged() {
    if (_activeTabIndex == _tabController.index) return;
    setState(() => _activeTabIndex = _tabController.index);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      await Future.wait([_loadStats(), _loadRules(), _loadEvents()]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });
    try {
      final stats = await widget.api.getHoneypotStats(
        from: _fromIso,
        to: _toIso,
      );
      if (mounted) {
        setState(() {
          _stats = {
            ...stats,
            'byRule': _asList(stats['byRule']),
            'trend': _asList(stats['trend']),
          };
        });
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) setState(() => _statsError = error.toString());
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadRules() async {
    setState(() {
      _rulesLoading = true;
      _rulesError = null;
    });
    try {
      final rules = await widget.api.listHoneypotRules();
      if (mounted) setState(() => _rules = rules);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) setState(() => _rulesError = error.toString());
    } finally {
      if (mounted) setState(() => _rulesLoading = false);
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _eventsLoading = true;
      _eventsError = null;
    });
    try {
      final result = await widget.api.listHoneypotEvents(
        page: _page,
        pageSize: _pageSize,
        ruleKey: _ruleFilter,
        action: _actionFilter,
        clientIp: _ipController.text.trim(),
        from: _fromIso,
        to: _toIso,
      );
      if (mounted) {
        setState(() {
          _events = result.items;
          _total = result.total;
        });
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) setState(() => _eventsError = error.toString());
    } finally {
      if (mounted) setState(() => _eventsLoading = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range == null) return;
    setState(() {
      _from = DateTime(range.start.year, range.start.month, range.start.day);
      _to = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
      _page = 1;
    });
    await _load();
  }

  Future<void> _updateRule(
    Map<String, dynamic> rule, {
    bool? enabled,
    String? action,
  }) async {
    try {
      await widget.api.updateHoneypotRule(
        ruleKey: rule['key'].toString(),
        enabled: enabled ?? rule['enabled'] == true,
        action: action ?? rule['action']?.toString() ?? 'OBSERVE',
      );
      await _loadRules();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text('保存蜜罐规则失败：$error')),
      );
    }
  }

  Future<void> _showEvent(Map<String, dynamic> event) async {
    try {
      final result = await widget.api.getHoneypotEventDetail(
        toInt(event['id']) ?? 0,
      );
      if (!mounted) return;
      final detail =
          (result['event'] as Map?)?.cast<String, dynamic>() ?? event;
      final headers =
          (result['requestHeaders'] as Map?)?.cast<String, dynamic>() ?? {};
      final encoded = result['bodySampleBase64']?.toString() ?? '';
      final body = encoded.isEmpty
          ? '(空请求体)'
          : utf8.decode(base64.decode(encoded), allowMalformed: true);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('攻击事件 #${detail['id']}'),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _detailLine('时间', detail['createdAt']?.toString() ?? ''),
                  _detailLine('来源 IP', detail['clientIp']?.toString() ?? ''),
                  _detailLine(
                    '请求',
                    '${detail['method']} ${detail['requestUri']}',
                  ),
                  _detailLine('规则', _asList(detail['matchedRules']).join(', ')),
                  _detailLine('动作', _actionLabel(detail['action']?.toString())),
                  const SizedBox(height: 14),
                  const Text(
                    '请求头（含 Cookie 等原始值）',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _samplePanel(
                    const JsonEncoder.withIndent('  ').convert({...headers}),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '请求体样本',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (detail['bodyTruncated'] == true)
                    const Text('超过 8 MB，已截断'),
                  _samplePanel(body),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(
        context,
        SnackBar(content: Text('加载事件样本失败：$error')),
      );
    }
  }

  Widget _detailLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text('$label：$value'),
  );

  Widget _samplePanel(String value) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(maxHeight: 240),
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: SingleChildScrollView(
      child: SelectableText(
        value,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: '蜜罐监控',
      filters: AdminToolbar(
        children: [
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
            label: Text('${_date(_from)} — ${_date(_to)}'),
          ),
          OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新'),
          ),
        ],
      ),
      body: _buildContent(),
      footer: _activeTabIndex == _eventsTabIndex
          ? PaginationBar(
              currentPage: _page,
              totalPages: (_total / _pageSize).ceil().clamp(1, 999999),
              totalItems: _total,
              onPageChanged: (page) {
                setState(() => _page = page);
                _loadEvents();
              },
            )
          : null,
    );
  }

  Widget _buildContent() {
    final byRule = _asList(_stats['byRule']);
    final trend = _asList(_stats['trend']);
    return Column(
      children: [
        Card(
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.shield_outlined), text: '攻击类型统计'),
              Tab(icon: Icon(Icons.show_chart), text: '每日趋势'),
              Tab(icon: Icon(Icons.tune), text: '规则配置'),
              Tab(icon: Icon(Icons.list_alt), text: '攻击事件'),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAttackTypeTab(byRule),
              _buildDailyTrendTab(trend),
              _buildRulesTab(),
              _buildEventsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttackTypeTab(List<dynamic> byRule) {
    final maxCount = byRule
        .map((item) => toInt((item as Map)['count']) ?? 0)
        .fold<int>(1, (a, b) => a > b ? a : b);
    if (_statsLoading && _stats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_statsError != null && _stats.isEmpty) {
      return _tabError(_statsError!, _loadStats);
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metric('命中总数', _stats['total'] ?? 0, Icons.warning_amber),
            _metric('观察中', _stats['observed'] ?? 0, Icons.visibility_outlined),
            _metric('已拦截', _stats['blocked'] ?? 0, Icons.block_outlined),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: byRule.isEmpty
                ? const AdminStatusView.empty(title: '所选时间范围内暂无命中')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle('按攻击规则统计'),
                      ...byRule.map((row) {
                        final map = (row as Map).cast<String, dynamic>();
                        final key = map['ruleKey']?.toString() ?? '';
                        final count = toInt(map['count']) ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 140,
                                child: Text(_ruleLabel(key)),
                              ),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: count / maxCount,
                                  minHeight: 9,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(width: 48, child: Text('$count')),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyTrendTab(List<dynamic> trend) {
    if (_statsLoading && _stats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_statsError != null && _stats.isEmpty) {
      return _tabError(_statsError!, _loadStats);
    }
    final counts = <String, int>{};
    for (final item in trend) {
      if (item is! Map) continue;
      final row = item.cast<String, dynamic>();
      final day = _normalizeDay(row['day']?.toString() ?? '');
      if (day.isNotEmpty) counts[day] = toInt(row['count']) ?? 0;
    }
    final start = DateTime(_from.year, _from.month, _from.day);
    final end = DateTime(_to.year, _to.month, _to.day);
    final points = <_TrendPoint>[];
    for (
      var day = start;
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))
    ) {
      final label = _date(day);
      points.add(_TrendPoint(label, counts[label] ?? 0));
    }
    final hasHits = points.any((point) => point.count > 0);
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('每日攻击命中'),
                SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _DailyTrendPainter(
                      points: points,
                      color: Theme.of(context).colorScheme.primary,
                      labelColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                      gridColor: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                if (!hasHits)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Center(child: Text('所选时间范围内暂无命中')),
                  ),
                if (_statsError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('刷新失败：${_statsError!}'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRulesTab() {
    if (_rulesLoading && _rules.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rulesError != null && _rules.isEmpty) {
      return _tabError(_rulesError!, _loadRules);
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Card(
          child: _rules.isEmpty
              ? const AdminStatusView.empty(title: '暂无蜜罐规则')
              : Column(children: _rules.map(_ruleTile).toList()),
        ),
      ],
    );
  }

  Widget _buildEventsTab() => Column(
    children: [
      AdminToolbar(
        children: [
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              initialValue: _ruleFilter,
              decoration: const InputDecoration(labelText: '攻击规则'),
              items: [
                const DropdownMenuItem(value: '', child: Text('全部规则')),
                ..._rules.map(
                  (rule) => DropdownMenuItem(
                    value: rule['key'].toString(),
                    child: Text(
                      rule['label']?.toString() ?? rule['key'].toString(),
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _ruleFilter = value ?? '';
                  _page = 1;
                });
                _loadEvents();
              },
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              initialValue: _actionFilter,
              decoration: const InputDecoration(labelText: '处理动作'),
              items: const [
                DropdownMenuItem(value: '', child: Text('全部动作')),
                DropdownMenuItem(value: 'OBSERVE', child: Text('观察')),
                DropdownMenuItem(value: 'BLOCK', child: Text('拦截')),
              ],
              onChanged: (value) {
                setState(() {
                  _actionFilter = value ?? '';
                  _page = 1;
                });
                _loadEvents();
              },
            ),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: '来源 IP',
                prefixIcon: Icon(Icons.language),
              ),
              onSubmitted: (_) {
                setState(() => _page = 1);
                _loadEvents();
              },
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              setState(() => _page = 1);
              _loadEvents();
            },
            icon: const Icon(Icons.search),
            label: const Text('筛选'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Expanded(
        child: _eventsLoading && _events.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _eventsError != null && _events.isEmpty
            ? _tabError(_eventsError!, _loadEvents)
            : _events.isEmpty
            ? const AdminStatusView.empty(title: '当前筛选条件下没有攻击事件')
            : Card(
                child: ListView.separated(
                  itemCount: _events.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final rules = _asList(
                      event['matchedRules'],
                    ).map((key) => _ruleLabel(key.toString())).join('、');
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: event['action'] == 'BLOCK'
                            ? Colors.red.withValues(alpha: .12)
                            : Colors.orange.withValues(alpha: .12),
                        child: Icon(
                          event['action'] == 'BLOCK'
                              ? Icons.block
                              : Icons.visibility,
                          color: event['action'] == 'BLOCK'
                              ? Colors.red
                              : Colors.orange,
                        ),
                      ),
                      title: Text(
                        '${event['method']} ${event['requestUri']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${event['clientIp']} · $rules · ${event['createdAt']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showEvent(event),
                    );
                  },
                ),
              ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '请求样本保留 30 天，Cookie 等字段按原样保存；查看样本仅限超级管理员。',
          style: TextStyle(fontSize: 12, color: Colors.orange),
        ),
      ),
    ],
  );

  Widget _metric(String title, dynamic value, IconData icon) => SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 28, color: AdminTheme.brandColor),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12)),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _ruleTile(Map<String, dynamic> rule) => ListTile(
    title: Text(rule['label']?.toString() ?? rule['key'].toString()),
    subtitle: Text(rule['key'].toString()),
    leading: Switch(
      value: rule['enabled'] == true,
      onChanged: (enabled) => _updateRule(rule, enabled: enabled),
    ),
    trailing: DropdownButton<String>(
      value: rule['action']?.toString() == 'BLOCK' ? 'BLOCK' : 'OBSERVE',
      items: const [
        DropdownMenuItem(value: 'OBSERVE', child: Text('观察')),
        DropdownMenuItem(value: 'BLOCK', child: Text('拦截')),
      ],
      onChanged: (action) {
        if (action != null) _updateRule(rule, action: action);
      },
    ),
  );

  Widget _sectionTitle(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(value, style: Theme.of(context).textTheme.titleMedium),
  );

  String _ruleLabel(String key) {
    for (final rule in _rules) {
      if (rule['key'] == key) return rule['label']?.toString() ?? key;
    }
    return key;
  }

  String _actionLabel(String? action) => action == 'BLOCK' ? '拦截' : '观察';

  Widget _tabError(String message, Future<void> Function() retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 36),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    ),
  );

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } on FormatException {
        return const [];
      }
    }
    return const [];
  }

  String _normalizeDay(String value) {
    final datePart = value.trim().split(RegExp(r'[T ]')).first;
    final parsed = DateTime.tryParse(datePart);
    return parsed == null ? '' : _date(parsed);
  }

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _TrendPoint {
  const _TrendPoint(this.day, this.count);

  final String day;
  final int count;
}

class _DailyTrendPainter extends CustomPainter {
  const _DailyTrendPainter({
    required this.points,
    required this.color,
    required this.labelColor,
    required this.gridColor,
  });

  final List<_TrendPoint> points;
  final Color color;
  final Color labelColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    const left = 42.0;
    const right = 12.0;
    const top = 12.0;
    const bottom = 38.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;
    final maxCount = points.fold<int>(
      0,
      (maximum, point) => point.count > maximum ? point.count : maximum,
    );
    final scaleMax = maxCount == 0 ? 1 : maxCount;
    final textStyle = TextStyle(fontSize: 11, color: labelColor);
    final gridPaint = Paint()..color = gridColor;
    for (var i = 0; i <= 4; i++) {
      final y = plot.top + plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final value = (scaleMax * (4 - i) / 4).round();
      _drawLabel(canvas, '$value', Offset(0, y - 7), textStyle, left - 8);
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length <= 1
          ? plot.left + plot.width / 2
          : plot.left + plot.width * i / (points.length - 1);
      final y = plot.bottom - plot.height * points[i].count / scaleMax;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (points.isEmpty) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final step = max(1, (points.length / 7).ceil());
    for (var i = 0; i < points.length; i += step) {
      final x = points.length <= 1
          ? plot.left + plot.width / 2
          : plot.left + plot.width * i / (points.length - 1);
      final y = plot.bottom - plot.height * points[i].count / scaleMax;
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = color);
      _drawLabel(
        canvas,
        points[i].day.substring(5),
        Offset(x - 20, plot.bottom + 10),
        textStyle,
        42,
      );
    }
    if ((points.length - 1) % step != 0 && points.length > 1) {
      _drawLabel(
        canvas,
        points.last.day.substring(5),
        Offset(plot.right - 42, plot.bottom + 10),
        textStyle,
        42,
      );
    }
  }

  void _drawLabel(
    Canvas canvas,
    String value,
    Offset offset,
    TextStyle style,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DailyTrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.gridColor != gridColor;
}
