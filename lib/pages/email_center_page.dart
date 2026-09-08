part of 'package:windblog_admin_flutter/main.dart';

class _EmailDeliveryFilter {
  const _EmailDeliveryFilter(this.label, this.status);

  final String label;
  final String status;
}

class EmailCenterPage extends StatefulWidget {
  const EmailCenterPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<EmailCenterPage> createState() => _EmailCenterPageState();
}

class _EmailCenterPageState extends State<EmailCenterPage>
    with TickerProviderStateMixin {
  static const List<String> _sectionTabs = [
    'SMTP 通道',
    '路由与分组',
    '邮件模板',
    '推广任务',
    '投递记录',
  ];
  static const List<_EmailDeliveryFilter> _deliveryFilters = [
    _EmailDeliveryFilter('全部', ''),
    _EmailDeliveryFilter('待发送', 'PENDING'),
    _EmailDeliveryFilter('处理中', 'IN_FLIGHT'),
    _EmailDeliveryFilter('已发送', 'SENT'),
    _EmailDeliveryFilter('失败', 'FAILED'),
  ];
  static const int _deliveryPageSize = 20;

  late final TabController _sectionTabController;
  late final TabController _deliveryStatusTabController;
  bool loading = true;
  bool deliveryLoading = false;
  List<Map<String, dynamic>> channels = [];
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> routes = [];
  List<Map<String, dynamic>> templates = [];
  List<Map<String, dynamic>> campaigns = [];
  List<EmailDeliveryItem> deliveries = [];
  int deliveryPage = 1;
  int deliveryTotal = 0;
  int deliveryStatusIndex = 0;

  @override
  void initState() {
    super.initState();
    _sectionTabController = TabController(
      length: _sectionTabs.length,
      vsync: this,
    );
    _deliveryStatusTabController = TabController(
      length: _deliveryFilters.length,
      vsync: this,
    );
    _load();
  }

  @override
  void dispose() {
    _sectionTabController.dispose();
    _deliveryStatusTabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      channels = await widget.api.listEmailChannels();
      groups = await widget.api.listEmailGroups();
      routes = await widget.api.listEmailRoutes();
      templates = await widget.api.listEmailTemplates();
      campaigns = await widget.api.listEmailCampaigns();
      await _loadDeliveries();
    } catch (_) {
      widget.onAuthError();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadDeliveries() async {
    if (mounted) setState(() => deliveryLoading = true);
    try {
      final filter = _deliveryFilters[deliveryStatusIndex];
      final result = await widget.api.listEmailDeliveries(
        page: deliveryPage,
        status: filter.status,
      );
      if (mounted) {
        setState(() {
          deliveries = result.items;
          deliveryTotal = result.total;
          deliveryPage = result.page;
        });
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (_) {
      if (mounted) {
        setState(() {
          deliveries = [];
          deliveryTotal = 0;
        });
      }
    } finally {
      if (mounted) setState(() => deliveryLoading = false);
    }
  }

  void _selectDeliveryStatus(int index) {
    if (index == deliveryStatusIndex) return;
    setState(() {
      deliveryStatusIndex = index;
      deliveryPage = 1;
    });
    _loadDeliveries();
  }

  Future<void> _createChannel() async {
    final name = TextEditingController();
    final host = TextEditingController();
    final username = TextEditingController();
    final password = TextEditingController();
    final fromAddress = TextEditingController();
    final fromName = TextEditingController(text: 'WindBlog');
    String securityMode = 'STARTTLS';
    int port = 587;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('新增 SMTP 通道'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                TextField(
                  controller: host,
                  decoration: const InputDecoration(labelText: 'SMTP 主机'),
                ),
                TextField(
                  controller: username,
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码或 API Key'),
                ),
                TextField(
                  controller: fromName,
                  decoration: const InputDecoration(labelText: '发件人名称'),
                ),
                TextField(
                  controller: fromAddress,
                  decoration: const InputDecoration(labelText: '发件人邮箱'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: securityMode,
                  items: const [
                    DropdownMenuItem(
                      value: 'STARTTLS',
                      child: Text('STARTTLS'),
                    ),
                    DropdownMenuItem(value: 'SSL_TLS', child: Text('SSL/TLS')),
                    DropdownMenuItem(value: 'NONE', child: Text('不加密')),
                  ],
                  onChanged: (value) => setDialogState(() {
                    securityMode = value!;
                    port = securityMode == 'SSL_TLS' ? 465 : 587;
                  }),
                  decoration: const InputDecoration(labelText: '加密方式'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (created == true) {
      await widget.api.createEmailChannel({
        'name': name.text.trim(),
        'provider': 'CUSTOM_SMTP',
        'host': host.text.trim(),
        'port': port,
        'securityMode': securityMode,
        'username': username.text.trim(),
        'password': password.text,
        'fromName': fromName.text.trim(),
        'fromAddress': fromAddress.text.trim(),
        'enabled': true,
      });
      await _load();
    }
    name.dispose();
    host.dispose();
    username.dispose();
    password.dispose();
    fromAddress.dispose();
    fromName.dispose();
  }

  Future<void> _retryDelivery(int deliveryId) async {
    try {
      await widget.api.retryEmailDelivery(deliveryId);
      await _loadDeliveries();
      _showMessage('邮件已重新加入投递队列');
    } catch (error) {
      _showMessage('重试投递失败：$error', error: true);
    }
  }

  Future<String?> _requestStepUpToken() => AdminStepUpAuthorization.obtain(
    context,
    widget.api,
    title: '确认批量失败待发送邮件',
  );

  Future<void> _testChannel(Map<String, dynamic> channel) async {
    final recipient = TextEditingController(
      text: channel['fromAddress']?.toString() ?? '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('手动测试投递'),
        content: TextField(
          controller: recipient,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: '测试收件人'),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('加入投递队列'),
          ),
        ],
      ),
    );
    final recipientAddress = recipient.text.trim();
    recipient.dispose();
    if (confirmed != true || recipientAddress.isEmpty) {
      if (confirmed == true) _showMessage('测试收件人不能为空', error: true);
      return;
    }

    await _sendTestDelivery(channel, recipientAddress);
  }

  Future<void> _sendTestDelivery(
    Map<String, dynamic> channel,
    String recipientAddress,
  ) async {
    try {
      await widget.api.testEmailChannel(
        (channel['id'] as num).toInt(),
        recipientAddress,
      );
      await _loadDeliveries();
      _showMessage('测试邮件已加入投递队列');
    } catch (error) {
      _showMessage('测试投递失败：$error', error: true);
    }
  }

  Future<void> _chooseChannelForTest() async {
    if (channels.isEmpty) {
      _showMessage('请先配置可用的 SMTP 通道', error: true);
      return;
    }
    int selectedChannelId = (channels.first['id'] as num).toInt();
    final recipient = TextEditingController(
      text: channels.first['fromAddress']?.toString() ?? '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('手动测试投递'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedChannelId,
                decoration: const InputDecoration(labelText: 'SMTP 通道'),
                items: channels
                    .map(
                      (channel) => DropdownMenuItem<int>(
                        value: (channel['id'] as num).toInt(),
                        child: Text(channel['name']?.toString() ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  selectedChannelId = value;
                  final channel = channels.firstWhere(
                    (item) => (item['id'] as num).toInt() == value,
                  );
                  recipient.text = channel['fromAddress']?.toString() ?? '';
                  setDialogState(() {});
                },
              ),
              TextField(
                controller: recipient,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '测试收件人'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('加入投递队列'),
            ),
          ],
        ),
      ),
    );
    final recipientAddress = recipient.text.trim();
    recipient.dispose();
    if (confirmed != true || recipientAddress.isEmpty) {
      if (confirmed == true) _showMessage('测试收件人不能为空', error: true);
      return;
    }
    final channel = channels.firstWhere(
      (item) => (item['id'] as num).toInt() == selectedChannelId,
    );
    await _sendTestDelivery(channel, recipientAddress);
  }

  Future<void> _failPendingDeliveries() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('一键失败所有待发送邮件？'),
        content: const Text('这会停止当前待发送和处理中的队列，并将这些记录标记为失败。已发送邮件不会受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认失败全部'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final stepUpToken = await _requestStepUpToken();
    if (stepUpToken == null) return;
    try {
      final failedCount = await widget.api.failPendingEmailDeliveries(
        stepUpToken: stepUpToken,
      );
      await _loadDeliveries();
      _showMessage('已将 $failedCount 封待发送邮件标记为失败');
    } catch (error) {
      _showMessage('批量失败操作失败：$error', error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    AdminFeedback.showSnackBar(
      context,
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _createTemplate() async {
    final templateKey = TextEditingController();
    final name = TextEditingController();
    final subject = TextEditingController();
    final title = TextEditingController();
    final content = TextEditingController();
    final buttonText = TextEditingController(text: '查看详情');
    final buttonUrl = TextEditingController(text: 'https://example.com');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新增固定主题模板'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: templateKey,
                decoration: const InputDecoration(labelText: '模板标识'),
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              TextField(
                controller: subject,
                decoration: const InputDecoration(labelText: '邮件主题'),
              ),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              TextField(
                controller: content,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '正文'),
              ),
              TextField(
                controller: buttonText,
                decoration: const InputDecoration(labelText: '按钮文字'),
              ),
              TextField(
                controller: buttonUrl,
                decoration: const InputDecoration(labelText: '按钮链接'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('保存并发布'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await widget.api.createEmailTemplate({
        'templateKey': templateKey.text.trim(),
        'name': name.text.trim(),
        'subjectTemplate': subject.text.trim(),
        'title': title.text.trim(),
        'greeting': '您好：',
        'content': content.text.trim(),
        'buttonText': buttonText.text.trim(),
        'buttonUrl': buttonUrl.text.trim(),
        'published': true,
      });
      await _load();
    }
    templateKey.dispose();
    name.dispose();
    subject.dispose();
    title.dispose();
    content.dispose();
    buttonText.dispose();
    buttonUrl.dispose();
  }

  Future<void> _createCampaign() async {
    final publishedTemplates = templates
        .where((item) => item['published'] == true)
        .toList();
    if (publishedTemplates.isEmpty) {
      AdminFeedback.showSnackBar(
        context,
        const SnackBar(content: Text('请先创建并发布邮件模板')),
      );
      return;
    }
    final name = TextEditingController();
    final subject = TextEditingController();
    int templateId = (publishedTemplates.first['id'] as num).toInt();
    String recipientType = 'PROMOTIONS';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('创建推广任务'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '任务名称'),
              ),
              TextField(
                controller: subject,
                decoration: const InputDecoration(labelText: '邮件主题'),
              ),
              DropdownButtonFormField<int>(
                initialValue: templateId,
                decoration: const InputDecoration(labelText: '已发布模板'),
                items: publishedTemplates
                    .map(
                      (item) => DropdownMenuItem(
                        value: (item['id'] as num).toInt(),
                        child: Text(item['name'].toString()),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => templateId = value!),
              ),
              DropdownButtonFormField<String>(
                initialValue: recipientType,
                decoration: const InputDecoration(labelText: '收件人'),
                items: const [
                  DropdownMenuItem(value: 'PROMOTIONS', child: Text('推广订阅用户')),
                  DropdownMenuItem(
                    value: 'ARTICLE_UPDATES',
                    child: Text('文章更新订阅用户'),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => recipientType = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      if (!mounted) {
        name.dispose();
        subject.dispose();
        return;
      }
      final stepUpToken = await AdminStepUpAuthorization.obtain(
        context,
        widget.api,
        title: '确认创建批量邮件活动',
      );
      if (stepUpToken == null) {
        name.dispose();
        subject.dispose();
        return;
      }
      await widget.api.createEmailCampaign({
        'name': name.text.trim(),
        'subject': subject.text.trim(),
        'templateId': templateId,
        'recipientType': recipientType,
      }, stepUpToken: stepUpToken);
      await _load();
    }
    name.dispose();
    subject.dispose();
  }

  Future<void> _createGroup() async {
    final name = TextEditingController();
    String dispatchMode = 'PRIMARY_BACKUP';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('新增通道组'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '组名称'),
              ),
              DropdownButtonFormField<String>(
                initialValue: dispatchMode,
                decoration: const InputDecoration(labelText: '策略'),
                items: const [
                  DropdownMenuItem(value: 'PRIMARY_BACKUP', child: Text('主备')),
                  DropdownMenuItem(value: 'ROUND_ROBIN', child: Text('轮询')),
                ],
                onChanged: (value) =>
                    setDialogState(() => dispatchMode = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await widget.api.createEmailGroup({
        'name': name.text.trim(),
        'dispatchMode': dispatchMode,
        'enabled': true,
      });
      await _load();
    }
    name.dispose();
  }

  Future<void> _configureGroupMembers(int groupId) async {
    final selectedChannelIds = <int>{};
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('配置通道组成员'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final channel in channels)
                  CheckboxListTile(
                    value: selectedChannelIds.contains(
                      (channel['id'] as num).toInt(),
                    ),
                    title: Text(channel['name'].toString()),
                    onChanged: (value) => setDialogState(() {
                      final channelId = (channel['id'] as num).toInt();
                      if (value == true) {
                        selectedChannelIds.add(channelId);
                      } else {
                        selectedChannelIds.remove(channelId);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final members = <Map<String, dynamic>>[];
      var priority = 0;
      for (final channelId in selectedChannelIds) {
        members.add({'channelId': channelId, 'priority': priority});
        priority = priority + 1;
      }
      await widget.api.replaceEmailGroupMembers(groupId, members);
      if (mounted) {
        AdminFeedback.showSnackBar(
          context,
          const SnackBar(content: Text('通道组成员已保存')),
        );
      }
    }
  }

  Future<void> _configureRoute(Map<String, dynamic> route) async {
    String targetType = route['channelGroupId'] != null ? 'GROUP' : 'CHANNEL';
    int? selectedTargetId = targetType == 'GROUP'
        ? (route['channelGroupId'] as num?)?.toInt()
        : (route['channelId'] as num?)?.toInt();
    final templateKey = TextEditingController(
      text: route['templateKey']?.toString() ?? route['scenario'].toString(),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final options = targetType == 'GROUP' ? groups : channels;
          return AlertDialog(
            title: Text('配置 ${route['scenario']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: targetType,
                  decoration: const InputDecoration(labelText: '目标类型'),
                  items: const [
                    DropdownMenuItem(value: 'GROUP', child: Text('通道组')),
                    DropdownMenuItem(value: 'CHANNEL', child: Text('单通道')),
                  ],
                  onChanged: (value) => setDialogState(() {
                    targetType = value!;
                    selectedTargetId = null;
                  }),
                ),
                DropdownButtonFormField<int>(
                  initialValue: selectedTargetId,
                  decoration: const InputDecoration(labelText: '默认发送目标'),
                  items: options
                      .map(
                        (item) => DropdownMenuItem(
                          value: (item['id'] as num).toInt(),
                          child: Text(item['name'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedTargetId = value),
                ),
                TextField(
                  controller: templateKey,
                  decoration: const InputDecoration(labelText: '模板标识'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true) {
      await widget.api.updateEmailRoute(route['scenario'].toString(), {
        'channelGroupId': targetType == 'GROUP' ? selectedTargetId : null,
        'channelId': targetType == 'CHANNEL' ? selectedTargetId : null,
        'templateKey': templateKey.text.trim(),
      });
      await _load();
    }
    templateKey.dispose();
  }

  Widget _buildSectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildChannelsTab() {
    if (channels.isEmpty) {
      return const AdminStatusView.empty(title: '暂无 SMTP 通道');
    }
    return ListView(
      children: [
        _buildSectionHeading('SMTP 通道'),
        for (final channel in channels)
          Card(
            child: ListTile(
              title: Text(
                '${channel['name']} · ${channel['host']}:${channel['port']}',
              ),
              subtitle: Text(
                '${channel['securityMode']} · ${channel['fromAddress']} · '
                '${channel['enabled'] == true ? '已启用' : '已停用'}',
              ),
              trailing: TextButton.icon(
                onPressed: () => _testChannel(channel),
                icon: const Icon(Icons.send_outlined),
                label: const Text('手动测试'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRoutingTab() {
    if (groups.isEmpty && routes.isEmpty) {
      return const AdminStatusView.empty(title: '暂无通道组或场景路由');
    }
    return ListView(
      children: [
        _buildSectionHeading('通道组'),
        for (final group in groups)
          Card(
            child: ListTile(
              title: Text(group['name']?.toString() ?? ''),
              subtitle: Text(group['dispatchMode']?.toString() ?? ''),
              trailing: TextButton(
                onPressed: () =>
                    _configureGroupMembers((group['id'] as num).toInt()),
                child: const Text('配置通道'),
              ),
            ),
          ),
        const SizedBox(height: 20),
        _buildSectionHeading('场景路由'),
        for (final route in routes)
          Card(
            child: ListTile(
              title: Text(route['scenario']?.toString() ?? ''),
              subtitle: Text(
                '通道 ${route['channelId'] ?? '-'}，分组 ${route['channelGroupId'] ?? '-'}',
              ),
              trailing: TextButton(
                onPressed: () => _configureRoute(route),
                child: const Text('配置'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTemplatesTab() {
    if (templates.isEmpty) {
      return const AdminStatusView.empty(title: '暂无邮件模板');
    }
    return ListView(
      children: [
        _buildSectionHeading('邮件模板'),
        for (final template in templates)
          Card(
            child: ListTile(
              title: Text(template['name']?.toString() ?? ''),
              subtitle: Text(
                '版本 ${template['version'] ?? 1} · '
                '${template['published'] == true ? '已发布' : '草稿'}',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCampaignsTab() {
    if (campaigns.isEmpty) {
      return const AdminStatusView.empty(title: '暂无推广任务');
    }
    return ListView(
      children: [
        _buildSectionHeading('推广任务'),
        for (final campaign in campaigns)
          Card(
            child: ListTile(
              title: Text(campaign['name']?.toString() ?? ''),
              subtitle: Text(campaign['subject']?.toString() ?? ''),
            ),
          ),
      ],
    );
  }

  Widget _buildDeliveriesTab() {
    int totalPages = (deliveryTotal / _deliveryPageSize).ceil().clamp(
      1,
      999999,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _deliveryStatusTabController,
                    isScrollable: true,
                    onTap: _selectDeliveryStatus,
                    tabs: _deliveryFilters
                        .map((filter) => Tab(text: filter.label))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _chooseChannelForTest,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('手动测试投递'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _failPendingDeliveries,
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('一键失败待发送'),
                ),
              ],
            ),
          ),
        ),
        if (deliveryLoading) const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 8),
        Expanded(child: _buildDeliveryList()),
        PaginationBar(
          currentPage: deliveryPage,
          totalPages: totalPages,
          totalItems: deliveryTotal,
          pageSize: _deliveryPageSize,
          onPageChanged: (page) {
            setState(() => deliveryPage = page);
            _loadDeliveries();
          },
        ),
      ],
    );
  }

  Widget _buildDeliveryList() {
    if (deliveryLoading && deliveries.isEmpty) {
      return const AdminStatusView.loading(title: '正在加载投递记录');
    }
    if (deliveries.isEmpty) {
      return const AdminStatusView.empty(title: '暂无投递记录');
    }
    return Card(
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: deliveries.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final delivery = deliveries[index];
          final status = _deliveryStatusLabel(delivery.status);
          final error = delivery.lastError;
          return ListTile(
            title: Text(
              delivery.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${delivery.recipientAddress} · ${delivery.scenario} · $status'
              '${error == null || error.isEmpty ? '' : '\n失败原因：$error'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: delivery.status == 'SENT'
                ? const Icon(Icons.check_circle_outline, color: Colors.green)
                : delivery.status == 'IN_FLIGHT'
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: () => _retryDelivery(delivery.id),
                    child: const Text('重试'),
                  ),
          );
        },
      ),
    );
  }

  String _deliveryStatusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return '待发送';
      case 'IN_FLIGHT':
        return '处理中';
      case 'SENT':
        return '已发送';
      case 'FAILED':
        return '失败';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: '邮件中心',
      actions: [
        FilledButton.icon(
          onPressed: _createChannel,
          icon: const Icon(Icons.add),
          label: const Text('新增 SMTP 通道'),
        ),
        TextButton(onPressed: _createTemplate, child: const Text('新增模板')),
        TextButton(onPressed: _createCampaign, child: const Text('创建推广')),
        TextButton(onPressed: _createGroup, child: const Text('新增通道组')),
      ],
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: TabBar(
                    controller: _sectionTabController,
                    isScrollable: true,
                    onTap: (index) {
                      if (index == _sectionTabs.length - 1) {
                        _loadDeliveries();
                      }
                    },
                    tabs: _sectionTabs
                        .map((label) => Tab(text: label))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _sectionTabController,
                    children: [
                      _buildChannelsTab(),
                      _buildRoutingTab(),
                      _buildTemplatesTab(),
                      _buildCampaignsTab(),
                      _buildDeliveriesTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
