part of 'package:windblog_admin_flutter/main.dart';

class RepostManagementPage extends StatefulWidget {
  const RepostManagementPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<RepostManagementPage> createState() => _RepostManagementPageState();
}

class _RepostTabData {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = const [];
  int page = 1;
  int total = 0;
  static const int pageSize = 20;
  String statusFilter = 'all';
  String keyword = '';
}

class _RepostManagementPageState extends State<RepostManagementPage>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 9;
  static const int _licensesTab = 0;
  static const int _affiliateLinksTab = 1;
  static const int _tokensTab = 2;
  static const int _clickEventsTab = 3;
  static const int _referralsTab = 4;
  static const int _suspiciousTab = 5;
  static const int _blockedDomainsTab = 6;
  static const int _riskDevicesTab = 7;
  static const int _usersTab = 8;

  late final TabController _tabController;
  final List<_RepostTabData> _tabs = List.generate(
    _tabCount,
    (_) => _RepostTabData(),
  );
  final Map<int, TextEditingController> _keywordControllers = {
    _licensesTab: TextEditingController(),
    _tokensTab: TextEditingController(),
    _usersTab: TextEditingController(),
  };
  Map<String, dynamic> _stats = const {};
  bool _statsLoading = true;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _reloadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _keywordControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _reloadAll() async {
    await Future.wait<void>([
      _loadStats(),
      for (int index = 0; index < _tabCount; index++) _loadTab(index),
    ]);
  }

  Future<void> _loadStats() async {
    if (mounted) {
      setState(() {
        _statsLoading = true;
        _statsError = null;
      });
    }
    try {
      final stats = await widget.api.repostStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (!mounted) return;
      setState(() => _statsError = error.toString());
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  int? _statusQuery(String filter) {
    switch (filter) {
      case 'active':
        return 1;
      case 'revoked':
        return 2;
      default:
        return null;
    }
  }

  Future<void> _loadTab(int index) async {
    final data = _tabs[index];
    if (mounted) {
      setState(() {
        data.loading = true;
        data.error = null;
      });
    }
    try {
      final PageResult<Map<String, dynamic>> result;
      switch (index) {
        case _licensesTab:
          result = await widget.api.listRepostLicenses(
            page: data.page,
            pageSize: _RepostTabData.pageSize,
            status: _statusQuery(data.statusFilter),
            keyword: data.keyword,
          );
          break;
        case _affiliateLinksTab:
          result = await widget.api.listRepostAffiliateLinks(
            page: data.page,
            pageSize: _RepostTabData.pageSize,
            status: _statusQuery(data.statusFilter),
          );
          break;
        case _tokensTab:
          result = await widget.api.listRepostTokens(
            page: data.page,
            pageSize: _RepostTabData.pageSize,
            status: _statusQuery(data.statusFilter),
            keyword: data.keyword,
          );
          break;
        case _clickEventsTab:
          result = await widget.api.listRepostClickEvents(
            page: data.page,
            pageSize: _RepostTabData.pageSize,
          );
          break;
        case _referralsTab:
          result = await widget.api.listRepostReferrals(
            page: data.page,
            pageSize: _RepostTabData.pageSize,
          );
          break;
        case _suspiciousTab:
          result = await widget.api.listSuspiciousReposts(
            page: data.page,
            pageSize: _RepostTabData.pageSize,
          );
          break;
        case _blockedDomainsTab:
          result = await widget.api.listRepostBlockedDomains(
            page: data.page,
            pageSize: _RepostTabData.pageSize,
          );
          break;
        case _riskDevicesTab:
          result = await widget.api.listRepostRiskDevices(
            page: data.page,
            pageSize: _RepostTabData.pageSize,
          );
          break;
        case _usersTab:
          result = await widget.api.listRepostUsers(
            page: data.page,
            pageSize: _RepostTabData.pageSize,
            keyword: data.keyword,
            banned: data.statusFilter == 'active'
                ? false
                : data.statusFilter == 'revoked'
                ? true
                : null,
          );
          break;
        default:
          return;
      }
      if (!mounted) return;
      setState(() {
        data.items = result.items;
        data.total = result.total;
        data.page = result.page;
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (!mounted) return;
      setState(() => data.error = error.toString());
    } finally {
      if (mounted) setState(() => data.loading = false);
    }
  }

  Future<void> _refreshAll() async {
    await _reloadAll();
  }

  void _applyFilter(int index, String filter) {
    final data = _tabs[index];
    data.statusFilter = filter;
    data.page = 1;
    _loadTab(index);
  }

  void _search(int index, String keyword) {
    final data = _tabs[index];
    data.keyword = keyword.trim();
    data.page = 1;
    _loadTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: t(context, 'repost_management'),
      actions: [
        OutlinedButton.icon(
          onPressed: _refreshAll,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(t(context, 'refresh')),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStats(),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: t(context, 'repost_tab_licenses')),
                Tab(text: t(context, 'repost_tab_affiliate_links')),
                Tab(text: t(context, 'repost_tab_tokens')),
                Tab(text: t(context, 'repost_tab_clicks')),
                Tab(text: t(context, 'repost_tab_referrals')),
                Tab(text: t(context, 'repost_tab_suspicious')),
                Tab(text: t(context, 'repost_tab_blocked_domains')),
                Tab(text: t(context, 'repost_tab_risk_devices')),
                Tab(text: t(context, 'repost_tab_users')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(_tabCount, _buildTab),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    if (_statsLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    if (_statsError != null) {
      return Text(
        '${t(context, 'load_failed')}: $_statsError',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    final entries = <List<String>>[
      [
        t(context, 'repost_stats_licenses'),
        '${_stats['activeLicenses'] ?? 0}/${_stats['licenses'] ?? 0}',
      ],
      [t(context, 'repost_stats_tokens'), '${_stats['tokens'] ?? 0}'],
      [t(context, 'repost_stats_clicks'), '${_stats['clickEvents'] ?? 0}'],
      [
        t(context, 'repost_stats_referrals'),
        '${_stats['referralEvents'] ?? 0}',
      ],
      [
        t(context, 'repost_stats_suspicious'),
        '${_stats['suspiciousReposts'] ?? 0}',
      ],
      [
        t(context, 'repost_stats_affiliate_links'),
        '${_stats['affiliateLinks'] ?? 0}',
      ],
      [
        t(context, 'repost_stats_blocked_domains'),
        '${_stats['blockedDomains'] ?? 0}',
      ],
      [
        t(context, 'repost_stats_risk_devices'),
        '${_stats['riskDevices'] ?? 0}',
      ],
      [
        t(context, 'repost_stats_banned_users'),
        '${_stats['bannedUsers'] ?? 0}',
      ],
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries
          .map(
            (entry) => Chip(
              label: Text('${entry[0]}: ${entry[1]}'),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.35),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTab(int index) {
    final data = _tabs[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (index == _affiliateLinksTab) _buildAffiliateLinkExplainer(),
        _buildToolbar(index),
        const SizedBox(height: 8),
        Expanded(child: _buildList(index, data)),
        if (data.total > _RepostTabData.pageSize)
          PaginationBar(
            currentPage: data.page,
            totalPages: (_RepostTabData.pageSize == 0
                ? 1
                : (data.total + _RepostTabData.pageSize - 1) ~/
                      _RepostTabData.pageSize),
            totalItems: data.total,
            pageSize: _RepostTabData.pageSize,
            onPageChanged: (page) {
              data.page = page;
              _loadTab(index);
            },
          ),
      ],
    );
  }

  Widget _buildAffiliateLinkExplainer() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(t(context, 'repost_affiliate_link_explained')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(int index) {
    final hasStatusFilter =
        index == _licensesTab ||
        index == _affiliateLinksTab ||
        index == _tokensTab ||
        index == _usersTab;
    final hasSearch =
        index == _licensesTab || index == _tokensTab || index == _usersTab;
    final showCreate =
        index == _affiliateLinksTab ||
        index == _blockedDomainsTab ||
        index == _riskDevicesTab;
    if (!hasStatusFilter && !hasSearch && !showCreate) {
      return const SizedBox.shrink();
    }
    final data = _tabs[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasStatusFilter)
            DropdownButton<String>(
              value: data.statusFilter,
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(t(context, 'repost_filter_all')),
                ),
                DropdownMenuItem(
                  value: 'active',
                  child: Text(
                    index == _usersTab
                        ? t(context, 'repost_filter_normal')
                        : t(context, 'repost_filter_active'),
                  ),
                ),
                DropdownMenuItem(
                  value: 'revoked',
                  child: Text(
                    index == _affiliateLinksTab
                        ? t(context, 'repost_filter_disabled')
                        : index == _usersTab
                        ? t(context, 'repost_filter_banned')
                        : t(context, 'repost_filter_revoked'),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) _applyFilter(index, value);
              },
            ),
          if (hasSearch)
            SizedBox(
              width: 260,
              child: TextField(
                controller: _keywordControllers[index],
                decoration: InputDecoration(
                  hintText: t(context, 'repost_search_hint'),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
                onSubmitted: (value) => _search(index, value),
              ),
            ),
          if (showCreate)
            FilledButton.icon(
              onPressed: () => _showCreateDialog(index),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                index == _affiliateLinksTab
                    ? t(context, 'repost_create_affiliate_link')
                    : index == _blockedDomainsTab
                    ? t(context, 'repost_block_domain')
                    : t(context, 'repost_add_risk_device'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(int index, _RepostTabData data) {
    if (data.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(t(context, 'loading')),
          ],
        ),
      );
    }
    if (data.error != null) {
      return AdminStatusView.error(
        title: t(context, 'load_failed'),
        message: data.error,
        action: FilledButton.icon(
          onPressed: () => _loadTab(index),
          icon: const Icon(Icons.refresh),
          label: Text(t(context, 'retry')),
        ),
      );
    }
    if (data.items.isEmpty) {
      return AdminStatusView.empty(title: t(context, 'repost_no_items'));
    }
    return ListView.separated(
      itemCount: data.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, itemIndex) =>
          _buildItemCard(index, data.items[itemIndex]),
    );
  }

  Widget _buildItemCard(int index, Map<String, dynamic> item) {
    switch (index) {
      case _licensesTab:
        return _buildLicenseCard(item);
      case _affiliateLinksTab:
        return _buildAffiliateLinkCard(item);
      case _tokensTab:
        return _buildTokenCard(item);
      case _clickEventsTab:
        return _buildClickEventCard(item);
      case _referralsTab:
        return _buildReferralCard(item);
      case _suspiciousTab:
        return _buildSuspiciousCard(item);
      case _blockedDomainsTab:
        return _buildBlockedDomainCard(item);
      case _riskDevicesTab:
        return _buildRiskDeviceCard(item);
      case _usersTab:
        return _buildRepostUserCard(item);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLicenseCard(Map<String, dynamic> item) {
    final status = _asInt(item['status']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectableText(
                  _text(item['code']),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _statusChip(status),
              ],
            ),
            _buildField('repost_post', _text(item['postTitle'])),
            _buildField('repost_user', _text(item['userName'])),
            _buildField('repost_allowed_domain', _text(item['allowedDomain'])),
            _buildField('repost_target_url', _text(item['targetUrl'])),
            _buildField(
              'repost_original_visits',
              '${item['originalClicks'] ?? 0}',
            ),
            _buildField('repost_go_visits', '${item['goClicks'] ?? 0}'),
            _buildField('created_at', _formatDate(item['createdAt'])),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _checkCompliance(item),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(t(context, 'repost_check_compliance')),
                ),
                if (status == 1)
                  TextButton.icon(
                    onPressed: () => _revokeLicense(item),
                    icon: const Icon(Icons.block, size: 18),
                    label: Text(t(context, 'repost_revoke')),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAffiliateLinkCard(Map<String, dynamic> item) {
    final status = _asInt(item['status']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectableText(
                  _text(item['name']),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _statusChip(status, inactiveKey: 'repost_filter_disabled'),
              ],
            ),
            _buildField(
              'repost_affiliate_link_target',
              _text(item['targetUrl']),
            ),
            _buildField('repost_allowed_domain', _text(item['targetDomain'])),
            _buildField('repost_note', _text(item['note'])),
            _buildField('created_at', _formatDate(item['createdAt'])),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _toggleAffiliateLink(item, status),
              icon: Icon(
                status == 1
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                size: 18,
              ),
              label: Text(
                status == 1
                    ? t(context, 'repost_disable')
                    : t(context, 'repost_enable'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenCard(Map<String, dynamic> item) {
    final status = _asInt(item['status']);
    final tokenType = _text(item['tokenType']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectableText(
                  _text(item['shortDisplay']),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Chip(
                  label: Text(
                    tokenType == 'FIRST_PARTY'
                        ? t(context, 'repost_token_first_party')
                        : t(context, 'repost_token_repost'),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            _buildField('repost_post', _text(item['postTitle'])),
            _buildField(
              'repost_affiliate_link',
              _text(item['affiliateLinkName']),
            ),
            _buildField(
              'repost_affiliate_link_target',
              _text(item['affiliateTargetUrl']),
            ),
            _buildField(
              'repost_license_code',
              _text(item['repostLicenseCode']),
            ),
            _buildField('repost_allowed_domain', _text(item['allowedDomain'])),
            _buildField('created_at', _formatDate(item['createdAt'])),
            if (status == 1) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _revokeToken(item),
                icon: const Icon(Icons.block, size: 18),
                label: Text(t(context, 'repost_revoke')),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClickEventCard(Map<String, dynamic> item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _text(item['refererDomain'], fallback: t(context, 'unknown')),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Chip(label: Text(_text(item['refererCategory']))),
                Chip(
                  label: Text(
                    '${t(context, 'repost_risk_score')}: ${item['riskScore'] ?? 0}',
                  ),
                ),
              ],
            ),
            _buildField('repost_token', _text(item['tokenShortDisplay'])),
            _buildField(
              'repost_license_code',
              _text(item['repostLicenseCode']),
            ),
            _buildField('repost_device_risk_id', _text(item['deviceRiskId'])),
            _buildField('repost_source_node', _text(item['sourceNodeId'])),
            _buildField('repost_clicked_at', _formatDate(item['clickedAt'])),
          ],
        ),
      ),
    );
  }

  Widget _buildSuspiciousCard(Map<String, dynamic> item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _text(item['domain']),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Chip(
                  label: Text(
                    '${t(context, 'repost_click_count')}: ${item['clickCount'] ?? 0}',
                  ),
                ),
                Chip(
                  label: Text(
                    '${t(context, 'repost_risk_score')}: ${item['riskScore'] ?? 0}',
                  ),
                ),
              ],
            ),
            _buildField('repost_post', _text(item['postTitle'])),
            _buildField(
              'repost_latest_referer',
              _text(item['latestRefererUrl']),
            ),
            _buildField('repost_first_seen', _formatDate(item['firstSeenAt'])),
            _buildField('repost_last_seen', _formatDate(item['lastSeenAt'])),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedDomainCard(Map<String, dynamic> item) {
    final status = _asInt(item['status']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectableText(
                  _text(item['domainName']),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _statusChip(status, inactiveKey: 'repost_filter_disabled'),
              ],
            ),
            _buildField('repost_reason', _text(item['reason'])),
            _buildField('created_at', _formatDate(item['createdAt'])),
            if (status == 1) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _unblockDomain(item),
                icon: const Icon(Icons.lock_open, size: 18),
                label: Text(t(context, 'repost_unblock')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRiskDeviceCard(Map<String, dynamic> item) {
    final status = _asInt(item['status']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectableText(
                  _text(item['deviceRiskId']),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _statusChip(status, inactiveKey: 'repost_filter_disabled'),
              ],
            ),
            _buildField('repost_reason', _text(item['reason'])),
            _buildField('created_at', _formatDate(item['createdAt'])),
            if (status == 1) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _unblockRiskDevice(item),
                icon: const Icon(Icons.lock_open, size: 18),
                label: Text(t(context, 'repost_unblock')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCard(Map<String, dynamic> item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectableText(
                  _text(item['licenseCode']),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Chip(label: Text(_text(item['refererCategory']))),
              ],
            ),
            _buildField('repost_post', _text(item['postTitle'])),
            _buildField('repost_referer_domain', _text(item['refererDomain'])),
            _buildField('repost_latest_referer', _text(item['refererUrl'])),
            _buildField('repost_source_node', _text(item['sourceNodeId'])),
            _buildField('repost_viewed_at', _formatDate(item['viewedAt'])),
          ],
        ),
      ),
    );
  }

  Widget _buildRepostUserCard(Map<String, dynamic> item) {
    final banned = item['repostBanned'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectableText(
                  _text(item['username']),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Chip(
                  label: Text(
                    banned
                        ? t(context, 'repost_filter_banned')
                        : t(context, 'repost_filter_normal'),
                  ),
                  backgroundColor: banned
                      ? Theme.of(context).colorScheme.errorContainer
                      : Colors.green.shade100,
                ),
              ],
            ),
            _buildField('repost_user_email', _text(item['email'])),
            _buildField('repost_user_nickname', _text(item['nickname'])),
            _buildField(
              'repost_user_license_count',
              '${item['licenseCount'] ?? 0}',
            ),
            _buildField(
              'repost_user_active_license_count',
              '${item['activeLicenseCount'] ?? 0}',
            ),
            _buildField('repost_reason', _text(item['repostBanReason'])),
            _buildField(
              'repost_user_banned_at',
              _formatDate(item['repostBannedAt']),
            ),
            const SizedBox(height: 8),
            banned
                ? OutlinedButton.icon(
                    onPressed: () => _unbanUser(item),
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: Text(t(context, 'repost_unban_user')),
                  )
                : TextButton.icon(
                    onPressed: () => _banUser(item),
                    icon: const Icon(Icons.block, size: 18),
                    label: Text(t(context, 'repost_ban_user')),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _banUser(Map<String, dynamic> item) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _RepostBanUserDialog(username: _text(item['username'])),
    );
    if (reason == null || !mounted) return;
    final stepUpToken = await AdminStepUpAuthorization.obtain(
      context,
      widget.api,
      title: t(context, 'repost_ban_user'),
    );
    if (stepUpToken == null || !mounted) return;
    try {
      await widget.api.banRepostUser(
        _asInt(item['id']),
        reason: reason,
        stepUpToken: stepUpToken,
      );
      if (!mounted) return;
      AdminFeedback.success(context, t(context, 'repost_ban_success'));
      await _reloadAll();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, error.toString());
    }
  }

  Future<void> _unbanUser(Map<String, dynamic> item) async {
    final confirmed = await AdminConfirmDialog.show(
      context: context,
      title: t(context, 'repost_unban_user'),
      message: t(context, 'repost_unban_user_confirm'),
      confirmText: t(context, 'confirm'),
      cancelText: t(context, 'cancel'),
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.api.unbanRepostUser(_asInt(item['id']));
      if (!mounted) return;
      AdminFeedback.success(context, t(context, 'repost_unban_success'));
      await _reloadAll();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, error.toString());
    }
  }

  Widget _statusChip(
    int status, {
    String inactiveKey = 'repost_filter_revoked',
  }) {
    final active = status == 1;
    return Chip(
      label: Text(
        active ? t(context, 'repost_filter_active') : t(context, inactiveKey),
      ),
      backgroundColor: active
          ? Colors.green.shade100
          : Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildField(String labelKey, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              t(context, labelKey),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: Colors.grey.shade700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Future<void> _checkCompliance(Map<String, dynamic> item) async {
    final id = _asInt(item['id']);
    try {
      final result = await widget.api.checkRepostLicenseCompliance(id);
      if (!mounted) return;
      final lines = <String>[
        '${t(context, 'repost_checked_url')}: ${result['checkedUrl'] ?? ''}',
        '${t(context, 'repost_checked_at')}: ${result['checkedAt'] ?? ''}',
        '${t(context, 'repost_has_original_link')}: ${_yesNo(result['hasOriginalLink'])}',
        '${t(context, 'repost_has_license_code')}: ${_yesNo(result['hasLicenseCode'])}',
        '${t(context, 'repost_has_go_link')}: ${_yesNo(result['hasGoLink'])}',
        '${t(context, 'repost_snippet')}: ${result['snippetSummary'] ?? ''}',
      ];
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(t(context, 'repost_compliance_result')),
          content: SingleChildScrollView(
            child: SelectableText(lines.join('\n\n')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t(context, 'close')),
            ),
          ],
        ),
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) {
        AdminFeedback.error(
          context,
          '${t(context, 'repost_check_failed')}: $error',
        );
      }
    }
  }

  Future<void> _revokeLicense(Map<String, dynamic> item) async {
    final confirmed = await AdminConfirmDialog.show(
      context: context,
      title: t(context, 'repost_revoke'),
      message: t(context, 'repost_revoke_confirm'),
      confirmText: t(context, 'confirm'),
      cancelText: t(context, 'cancel'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    final stepUpToken = await AdminStepUpAuthorization.obtain(
      context,
      widget.api,
      title: t(context, 'repost_revoke'),
    );
    if (stepUpToken == null || !mounted) return;
    try {
      await widget.api.revokeRepostLicense(
        _asInt(item['id']),
        stepUpToken: stepUpToken,
      );
      if (!mounted) return;
      AdminFeedback.success(context, t(context, 'repost_revoke_success'));
      await _reloadAll();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, error.toString());
    }
  }

  Future<void> _revokeToken(Map<String, dynamic> item) async {
    final confirmed = await AdminConfirmDialog.show(
      context: context,
      title: t(context, 'repost_revoke'),
      message: t(context, 'repost_revoke_token_confirm'),
      confirmText: t(context, 'confirm'),
      cancelText: t(context, 'cancel'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    final stepUpToken = await AdminStepUpAuthorization.obtain(
      context,
      widget.api,
      title: t(context, 'repost_revoke'),
    );
    if (stepUpToken == null || !mounted) return;
    try {
      await widget.api.revokeRepostToken(
        _asInt(item['id']),
        stepUpToken: stepUpToken,
      );
      if (!mounted) return;
      AdminFeedback.success(context, t(context, 'repost_revoke_success'));
      await _reloadAll();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, error.toString());
    }
  }

  Future<void> _toggleAffiliateLink(
    Map<String, dynamic> item,
    int status,
  ) async {
    try {
      await widget.api.updateRepostAffiliateLinkStatus(
        _asInt(item['id']),
        status == 1 ? 2 : 1,
      );
      if (!mounted) return;
      AdminFeedback.success(context, t(context, 'repost_status_updated'));
      await _loadTab(_affiliateLinksTab);
      await _loadStats();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, error.toString());
    }
  }

  Future<void> _unblockDomain(Map<String, dynamic> item) async {
    try {
      await widget.api.unblockRepostDomain(_asInt(item['id']));
      if (!mounted) return;
      AdminFeedback.success(context, t(context, 'repost_status_updated'));
      await _loadTab(_blockedDomainsTab);
      await _loadStats();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, error.toString());
    }
  }

  Future<void> _unblockRiskDevice(Map<String, dynamic> item) async {
    try {
      await widget.api.unblockRepostRiskDevice(_asInt(item['id']));
      if (!mounted) return;
      AdminFeedback.success(context, t(context, 'repost_status_updated'));
      await _loadTab(_riskDevicesTab);
      await _loadStats();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, error.toString());
    }
  }

  Future<void> _showCreateDialog(int index) async {
    final kind = index == _affiliateLinksTab
        ? 'affiliate'
        : index == _blockedDomainsTab
        ? 'blocked'
        : 'risk';
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => _RepostCreateDialog(kind: kind),
    );
    if (values == null || !mounted) return;
    try {
      if (index == _affiliateLinksTab) {
        await widget.api.createRepostAffiliateLink(
          name: values['name'] ?? '',
          targetUrl: values['targetUrl'] ?? '',
          note: values['note'],
        );
      } else if (index == _blockedDomainsTab) {
        await widget.api.createRepostBlockedDomain(
          domain: values['domain'] ?? '',
          reason: values['reason'],
        );
      } else {
        await widget.api.createRepostRiskDevice(
          deviceRiskId: values['deviceRiskId'] ?? '',
          reason: values['reason'],
        );
      }
      if (!mounted) return;
      AdminFeedback.success(context, t(context, 'repost_created'));
      await _loadTab(index);
      await _loadStats();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      if (mounted) AdminFeedback.error(context, error.toString());
    }
  }

  int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  String _text(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  String _yesNo(Object? value) {
    final yes = value == true || value == 'true' || value == 1;
    return yes ? t(context, 'yes') : t(context, 'no');
  }

  String _formatDate(Object? value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return parsed.toLocal().toString().split('.').first;
  }
}

class _RepostCreateDialog extends StatefulWidget {
  const _RepostCreateDialog({required this.kind});

  final String kind;

  @override
  State<_RepostCreateDialog> createState() => _RepostCreateDialogState();
}

class _RepostCreateDialogState extends State<_RepostCreateDialog> {
  final TextEditingController _first = TextEditingController();
  final TextEditingController _second = TextEditingController();
  final TextEditingController _third = TextEditingController();

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _third.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAffiliate = widget.kind == 'affiliate';
    final isBlockedDomain = widget.kind == 'blocked';
    final title = isAffiliate
        ? t(context, 'repost_create_affiliate_link')
        : isBlockedDomain
        ? t(context, 'repost_block_domain')
        : t(context, 'repost_add_risk_device');
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _first,
              decoration: InputDecoration(
                labelText: isAffiliate
                    ? t(context, 'name')
                    : isBlockedDomain
                    ? t(context, 'repost_domain')
                    : t(context, 'repost_device_risk_id'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _second,
              decoration: InputDecoration(
                labelText: isAffiliate
                    ? t(context, 'repost_affiliate_link_target')
                    : t(context, 'repost_reason'),
              ),
              maxLines: isAffiliate ? 1 : 3,
            ),
            if (isAffiliate) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _third,
                decoration: InputDecoration(
                  labelText: t(context, 'repost_note'),
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t(context, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            final first = _first.text.trim();
            if (first.isEmpty) return;
            final result = <String, String>{};
            if (isAffiliate) {
              final target = _second.text.trim();
              if (target.isEmpty) return;
              result['name'] = first;
              result['targetUrl'] = target;
              result['note'] = _third.text.trim();
            } else if (isBlockedDomain) {
              result['domain'] = first;
              result['reason'] = _second.text.trim();
            } else {
              result['deviceRiskId'] = first;
              result['reason'] = _second.text.trim();
            }
            Navigator.pop(context, result);
          },
          child: Text(t(context, 'create')),
        ),
      ],
    );
  }
}

class _RepostBanUserDialog extends StatefulWidget {
  const _RepostBanUserDialog({required this.username});

  final String username;

  @override
  State<_RepostBanUserDialog> createState() => _RepostBanUserDialogState();
}

class _RepostBanUserDialogState extends State<_RepostBanUserDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t(context, 'repost_ban_user')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.username),
            const SizedBox(height: 8),
            Text(t(context, 'repost_ban_user_confirm')),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t(context, 'repost_ban_reason_hint'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t(context, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: Text(t(context, 'confirm')),
        ),
      ],
    );
  }
}
