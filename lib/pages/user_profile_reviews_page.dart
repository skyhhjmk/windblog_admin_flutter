part of 'package:windblog_admin_flutter/main.dart';

class UserProfileReviewsPage extends StatefulWidget {
  const UserProfileReviewsPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<UserProfileReviewsPage> createState() => _UserProfileReviewsPageState();
}

class _UserProfileReviewsPageState extends State<UserProfileReviewsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<int, Future<Uint8List?>> _pendingAvatarFutures = {};
  final Set<int> _selectedIds = {};

  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _statusFilter = 'PENDING';
  int _page = 1;
  final int _pageSize = 20;
  int _total = 0;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _summary = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.fetchUserProfileReviews(
          status: _statusFilter,
          keyword: _searchController.text,
          page: _page,
          pageSize: _pageSize,
        ),
        widget.api.fetchUserProfileReviewSummary(),
      ]);
      if (!mounted) return;
      final listData = results[0];
      final rawItems = listData['items'];
      final parsed = <Map<String, dynamic>>[];
      if (rawItems is List) {
        for (final entry in rawItems) {
          if (entry is Map) {
            parsed.add(Map<String, dynamic>.from(entry));
          }
        }
      }
      setState(() {
        _items = parsed;
        _total = (listData['total'] as num?)?.toInt() ?? parsed.length;
        _summary = results[1];
        _selectedIds.clear();
        _pendingAvatarFutures.clear();
        _loading = false;
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Uint8List?> _pendingAvatarFuture(int reviewId) {
    return _pendingAvatarFutures.putIfAbsent(
      reviewId,
      () => widget.api.fetchPendingAvatarBytes(reviewId),
    );
  }

  Future<void> _approve(int id) async {
    setState(() => _busy = true);
    try {
      await widget.api.approveUserProfileReview(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已审核通过')));
      await _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askRejectReason({String title = '输入驳回原因'}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '例如：头像包含违规内容 / 昵称存在广告引流'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确认驳回'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _reject(int id) async {
    final reason = await _askRejectReason();
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await widget.api.rejectUserProfileReview(
        id,
        reason: reason.isEmpty ? '资料内容不符合社区规范' : reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已驳回变更')));
      await _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reAuditAi(int id) async {
    setState(() => _busy = true);
    try {
      await widget.api.aiAuditUserProfileReview(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AI 审核已完成')));
      await _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI 审核失败: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _batch(String action) async {
    if (_selectedIds.isEmpty) return;
    String? reason;
    if (action == 'reject') {
      reason = await _askRejectReason(title: '批量驳回原因');
      if (reason == null) return;
    }
    setState(() => _busy = true);
    try {
      final res = await widget.api.batchUserProfileReviews(
        ids: _selectedIds.toList(),
        action: action,
        reason: reason,
      );
      if (!mounted) return;
      final processed = res['processed'] ?? 0;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已批量处理 $processed 条记录')));
      await _load();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('批量操作失败: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Color _aiStatusColor(String aiStatus) {
    switch (aiStatus) {
      case 'PASSED':
        return Colors.green;
      case 'FLAGGED':
        return Colors.red;
      case 'MANUAL_REQUIRED':
        return Colors.deepOrange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = (_summary['pending'] as num?)?.toInt() ?? 0;
    final flaggedCount = (_summary['flagged'] as num?)?.toInt() ?? 0;
    final manualCount = (_summary['manualRequired'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '用户资料信息审核',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Chip(label: Text('待审 $pendingCount')),
              if (flaggedCount > 0)
                Chip(
                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                  label: Text('AI 标记风险 $flaggedCount'),
                ),
              if (manualCount > 0)
                Chip(
                  backgroundColor: Colors.orange.withValues(alpha: 0.15),
                  label: Text('需人工复核 $manualCount'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final entry in const [
                ('PENDING', '待审核'),
                ('APPROVED', '已通过'),
                ('REJECTED', '已驳回'),
                ('ALL', '全部'),
              ])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: _statusFilter == entry.$1,
                  onSelected: (_) {
                    setState(() {
                      _statusFilter = entry.$1;
                      _page = 1;
                    });
                    _load();
                  },
                ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '搜索用户名/昵称/简介',
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                  onSubmitted: (_) {
                    _page = 1;
                    _load();
                  },
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: '刷新',
              ),
              if (_selectedIds.isNotEmpty) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : () => _batch('approve'),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text('批量通过 (${_selectedIds.length})'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _batch('reject'),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text('批量驳回 (${_selectedIds.length})'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('加载失败: $_error'),
                        const SizedBox(height: 8),
                        FilledButton(onPressed: _load, child: const Text('重试')),
                      ],
                    ),
                  )
                : _items.isEmpty
                ? const Center(child: Text('暂无符合条件的资料变更记录'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final id = (item['id'] as num).toInt();
                      final status = item['status']?.toString() ?? 'PENDING';
                      final aiStatus =
                          item['aiStatus']?.toString() ?? 'NOT_RUN';
                      final hasPendingAvatar = item['hasPendingAvatar'] == true;
                      final oldAvatar = item['oldAvatar']?.toString();
                      final isPending = status == 'PENDING';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isPending)
                                    Checkbox(
                                      value: _selectedIds.contains(id),
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedIds.add(id);
                                          } else {
                                            _selectedIds.remove(id);
                                          }
                                        });
                                      },
                                    ),
                                  Expanded(
                                    child: Text(
                                      '${item['username'] ?? ''} (${item['email'] ?? '-'}) · #$id',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(status),
                                    backgroundColor: _statusColor(
                                      status,
                                    ).withValues(alpha: 0.14),
                                  ),
                                  const SizedBox(width: 6),
                                  Chip(
                                    label: Text(
                                      item['aiScore'] != null
                                          ? 'AI: $aiStatus (${item['aiScore']})'
                                          : 'AI: $aiStatus',
                                    ),
                                    backgroundColor: _aiStatusColor(
                                      aiStatus,
                                    ).withValues(alpha: 0.14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _diffRow(
                                '昵称',
                                item['oldNickname']?.toString(),
                                item['newNickname']?.toString(),
                              ),
                              const SizedBox(height: 4),
                              _diffRow(
                                '简介',
                                item['oldBio']?.toString(),
                                item['newBio']?.toString(),
                              ),
                              if (hasPendingAvatar ||
                                  (oldAvatar != null &&
                                      oldAvatar.isNotEmpty)) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (oldAvatar != null &&
                                        oldAvatar.isNotEmpty) ...[
                                      Column(
                                        children: [
                                          const Text(
                                            '旧头像',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              widget.api.normalizeUrl(
                                                oldAvatar,
                                              ),
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.broken_image,
                                                    size: 40,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Icon(Icons.arrow_forward),
                                      ),
                                    ],
                                    if (hasPendingAvatar)
                                      Column(
                                        children: [
                                          const Text(
                                            '待审新头像',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          const SizedBox(height: 4),
                                          FutureBuilder<Uint8List?>(
                                            future: _pendingAvatarFuture(id),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const SizedBox(
                                                  width: 64,
                                                  height: 64,
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                );
                                              }
                                              final bytes = snapshot.data;
                                              if (bytes == null) {
                                                return const Icon(
                                                  Icons.broken_image,
                                                  size: 40,
                                                );
                                              }
                                              return ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.memory(
                                                  bytes,
                                                  width: 64,
                                                  height: 64,
                                                  fit: BoxFit.cover,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                              if (item['aiReason'] != null &&
                                  item['aiReason'].toString().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'AI 审核说明：${item['aiReason']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              if (item['reviewNote'] != null &&
                                  item['reviewNote'].toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '审核备注：${item['reviewNote']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              if (isPending) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _approve(id),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('通过'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _reject(id),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('驳回'),
                                    ),
                                    TextButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _reAuditAi(id),
                                      icon: const Icon(
                                        Icons.auto_awesome,
                                        size: 16,
                                      ),
                                      label: const Text('重新 AI 审核'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          PaginationBar(
            currentPage: _page,
            pageSize: _pageSize,
            totalItems: _total,
            totalPages: _total == 0
                ? 1
                : ((_total + _pageSize - 1) ~/ _pageSize),
            onPageChanged: (nextPage) {
              setState(() => _page = nextPage);
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _diffRow(String label, String? oldVal, String? newVal) {
    final oldText = (oldVal == null || oldVal.isEmpty) ? '(空)' : oldVal;
    final newText = (newVal == null || newVal.isEmpty) ? '(空)' : newVal;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            '$oldText  →  $newText',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
