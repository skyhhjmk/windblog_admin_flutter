part of 'package:windblog_admin_flutter/main.dart';

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

class _EmailCenterPageState extends State<EmailCenterPage> {
  bool loading = true;
  List<Map<String, dynamic>> channels = [];
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> routes = [];
  List<Map<String, dynamic>> templates = [];
  List<Map<String, dynamic>> campaigns = [];
  List<Map<String, dynamic>> deliveries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      channels = await widget.api.listEmailChannels();
      groups = await widget.api.listEmailGroups();
      routes = await widget.api.listEmailRoutes();
      templates = await widget.api.listEmailTemplates();
      campaigns = await widget.api.listEmailCampaigns();
      deliveries = await widget.api.listEmailDeliveries();
    } catch (_) {
      widget.onAuthError();
    }
    if (mounted) setState(() => loading = false);
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
      builder: (dialogContext) =>
          StatefulBuilder(
            builder: (dialogContext, setDialogState) =>
                AlertDialog(
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
                          decoration: const InputDecoration(
                              labelText: 'SMTP 主机'),
                        ),
                        TextField(
                          controller: username,
                          decoration: const InputDecoration(
                              labelText: '用户名'),
                        ),
                        TextField(
                          controller: password,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: '密码或 API Key'),
                        ),
                        TextField(
                          controller: fromName,
                          decoration: const InputDecoration(
                              labelText: '发件人名称'),
                        ),
                        TextField(
                          controller: fromAddress,
                          decoration: const InputDecoration(
                              labelText: '发件人邮箱'),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: securityMode,
                          items: const [
                            DropdownMenuItem(
                              value: 'STARTTLS',
                              child: Text('STARTTLS'),
                            ),
                            DropdownMenuItem(
                                value: 'SSL_TLS', child: Text('SSL/TLS')),
                            DropdownMenuItem(
                                value: 'NONE', child: Text('不加密')),
                          ],
                          onChanged: (value) =>
                              setDialogState(() {
                                securityMode = value!;
                                port = securityMode == 'SSL_TLS' ? 465 : 587;
                              }),
                          decoration: const InputDecoration(
                              labelText: '加密方式'),
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
    await widget.api.retryEmailDelivery(deliveryId);
    await _load();
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
      builder: (dialogContext) =>
          AlertDialog(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先创建并发布邮件模板')));
      return;
    }
    final name = TextEditingController();
    final subject = TextEditingController();
    int templateId = (publishedTemplates.first['id'] as num).toInt();
    String recipientType = 'PROMOTIONS';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          StatefulBuilder(
            builder: (dialogContext, setDialogState) =>
                AlertDialog(
                  title: const Text('创建推广任务'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                            labelText: '任务名称'),
                      ),
                      TextField(
                        controller: subject,
                        decoration: const InputDecoration(
                            labelText: '邮件主题'),
                      ),
                      DropdownButtonFormField<int>(
                        initialValue: templateId,
                        decoration: const InputDecoration(
                            labelText: '已发布模板'),
                        items: publishedTemplates
                            .map(
                              (item) =>
                              DropdownMenuItem(
                                value: (item['id'] as num).toInt(),
                                child: Text(item['name'].toString()),
                              ),
                        )
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => templateId = value!),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: recipientType,
                        decoration: const InputDecoration(labelText: '收件人'),
                        items: const [
                          DropdownMenuItem(
                              value: 'PROMOTIONS', child: Text('推广订阅用户')),
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
      await widget.api.createEmailCampaign({
        'name': name.text.trim(),
        'subject': subject.text.trim(),
        'templateId': templateId,
        'recipientType': recipientType,
      });
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
      builder: (dialogContext) =>
          StatefulBuilder(
            builder: (dialogContext, setDialogState) =>
                AlertDialog(
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
                          DropdownMenuItem(
                              value: 'PRIMARY_BACKUP', child: Text('主备')),
                          DropdownMenuItem(
                              value: 'ROUND_ROBIN', child: Text('轮询')),
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
      builder: (dialogContext) =>
          StatefulBuilder(
            builder: (dialogContext, setDialogState) =>
                AlertDialog(
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
                            onChanged: (value) =>
                                setDialogState(() {
                                  final channelId = (channel['id'] as num)
                                      .toInt();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('通道组成员已保存')));
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
      builder: (dialogContext) =>
          StatefulBuilder(
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
                        DropdownMenuItem(
                            value: 'CHANNEL', child: Text('单通道')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() {
                            targetType = value!;
                            selectedTargetId = null;
                          }),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: selectedTargetId,
                      decoration: const InputDecoration(
                          labelText: '默认发送目标'),
                      items: options
                          .map(
                            (item) =>
                            DropdownMenuItem(
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

  @override
  Widget build(BuildContext context) =>
      AdminPageScaffold(
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
            : ListView(
          children: [
            const Text(
              'SMTP 通道',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final channel in channels)
              Card(
                child: ListTile(
                  title: Text(
                    '${channel['name']} · ${channel['host']}:${channel['port']}',
                  ),
                  subtitle: Text(
                    '${channel['securityMode']} · ${channel['fromAddress']}',
                  ),
                  trailing: Text(
                      channel['enabled'] == true ? '已启用' : '已停用'),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              '通道组与场景路由',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
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
            for (final route in routes)
              Card(
                child: ListTile(
                  title: Text(route['scenario']?.toString() ?? ''),
                  subtitle: Text(
                    '通道 ${route['channelId'] ??
                        '-'}，分组 ${route['channelGroupId'] ?? '-'}',
                  ),
                  trailing: TextButton(
                    onPressed: () => _configureRoute(route),
                    child: const Text('配置'),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              '邮件模板',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            for (final template in templates)
              Card(
                child: ListTile(
                  title: Text(template['name']?.toString() ?? ''),
                  subtitle: Text(
                    '版本 ${template['version'] ??
                        1} · ${template['published'] == true
                        ? '已发布'
                        : '草稿'}',
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              '推广任务',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            for (final campaign in campaigns)
              Card(
                child: ListTile(
                  title: Text(campaign['name']?.toString() ?? ''),
                  subtitle: Text(campaign['subject']?.toString() ?? ''),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              '投递记录',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            for (final delivery in deliveries)
              Card(
                child: ListTile(
                  title: Text(delivery['subject']?.toString() ?? ''),
                  subtitle: Text(
                    '${delivery['recipientAddress'] ??
                        ''} · ${delivery['status'] ?? ''}',
                  ),
                  trailing: delivery['status'] == 'SENT'
                      ? null
                      : TextButton(
                    onPressed: () =>
                        _retryDelivery((delivery['id'] as num).toInt()),
                    child: const Text('重试'),
                  ),
                ),
              ),
          ],
        ),
      );
}
