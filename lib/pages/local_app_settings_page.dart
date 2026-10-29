part of 'package:windblog_admin_flutter/main.dart';

class LocalAppSettingsPage extends StatefulWidget {
  const LocalAppSettingsPage({super.key, required this.api, this.user});

  final AdminApiClient api;
  final AdminUser? user;

  @override
  State<LocalAppSettingsPage> createState() => _LocalAppSettingsPageState();
}

class _LocalAppSettingsPageState extends State<LocalAppSettingsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  bool _autoStart = true;
  bool _isSavingOrSwitching = false;

  StreamSubscription<McpLogEntry>? _logSub;
  StreamSubscription<bool>? _statusSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _hostCtrl = TextEditingController(text: FlutterMcpServer.instance.host);
    _portCtrl = TextEditingController(text: FlutterMcpServer.instance.port.toString());
    _autoStart = FlutterMcpServer.instance.autoStart;

    _logSub = FlutterMcpServer.instance.logStream.listen((_) {
      if (mounted) setState(() {});
    });
    _statusSub = FlutterMcpServer.instance.statusStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _statusSub?.cancel();
    _tabController.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  String get _clientConnectHost {
    final configured = _hostCtrl.text.trim();
    if (configured == '0.0.0.0' || configured.isEmpty) {
      return '127.0.0.1';
    }
    return configured;
  }

  String get _configJson {
    final host = _clientConnectHost;
    final port = int.tryParse(_portCtrl.text.trim()) ?? FlutterMcpServer.instance.port;
    final map = {
      'mcpServers': {
        'windblog': {
          'url': 'http://$host:$port/sse',
        }
      }
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  Future<void> _saveMcpSettings() async {
    setState(() => _isSavingOrSwitching = true);
    final host = _hostCtrl.text.trim().isEmpty ? '127.0.0.1' : _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 58180;
    await FlutterMcpServer.instance.saveSettings(
      host: host,
      port: port,
      autoStart: _autoStart,
    );
    if (!mounted) return;
    setState(() => _isSavingOrSwitching = false);
    AdminFeedback.showSnackBar(
      context,
      const SnackBar(content: Text('MCP 设置已保存并应用')),
    );
  }

  Future<void> _toggleServer(bool start) async {
    setState(() => _isSavingOrSwitching = true);
    final host = _hostCtrl.text.trim().isEmpty ? '127.0.0.1' : _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 58180;
    if (start) {
      await FlutterMcpServer.instance.saveSettings(host: host, port: port, autoStart: _autoStart);
      await FlutterMcpServer.instance.start(host: host, port: port);
    } else {
      await FlutterMcpServer.instance.stop();
    }
    if (mounted) {
      setState(() => _isSavingOrSwitching = false);
    }
  }

  Future<void> _copyConfigJson() async {
    await Clipboard.setData(ClipboardData(text: _configJson));
    if (!mounted) return;
    AdminFeedback.showSnackBar(
      context,
      const SnackBar(content: Text('已复制 MCP 配置 JSON 到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminPageScaffold(
      title: '本地应用设置',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '刷新',
          onPressed: () => setState(() {}),
        ),
      ],
      body: Column(
        children: [
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              tabs: const [
                Tab(
                  icon: Icon(Icons.hub_outlined, size: 20),
                  text: 'MCP 服务设置',
                ),
                Tab(
                  icon: Icon(Icons.settings_suggest_outlined, size: 20),
                  text: '客户端环境',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMcpSettingsTab(context),
                _buildClientEnvTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMcpSettingsTab(BuildContext context) {
    final theme = Theme.of(context);
    final isRunning = FlutterMcpServer.instance.isRunning;
    final hasSession = widget.api.token != null && widget.api.token!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 状态卡片
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.hub, color: theme.colorScheme.primary, size: 26),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MCP 服务运行状态',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '用于连接 Claude Desktop、Cursor、Antigravity 等 AI 编程助手',
                                style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isRunning ? Colors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isRunning ? Colors.green.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isRunning ? Colors.green : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isRunning ? '运行中 (http://${FlutterMcpServer.instance.host}:${FlutterMcpServer.instance.port})' : '已停止',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isRunning ? Colors.green : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Switch(
                            value: isRunning,
                            onChanged: _isSavingOrSwitching ? null : (val) => _toggleServer(val),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(
                            hasSession ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                            size: 20,
                            color: hasSession ? Colors.green : Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasSession
                                  ? '已绑定当前管理员登录凭据: ${widget.user?.username ?? "管理员"} (${widget.api.baseUrl})'
                                  : '未检测到登录凭据，AI 将无法使用您的登录信息执行文章翻译与持久化操作',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: hasSession ? theme.colorScheme.onSurface : Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 监听配置卡片
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '网络监听设置',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _hostCtrl,
                                  decoration: InputDecoration(
                                    labelText: '监听地址 (Host)',
                                    hintText: '127.0.0.1',
                                    border: const OutlineInputBorder(),
                                    helperText: '127.0.0.1 仅本机回环（推荐）；0.0.0.0 允许局域网外部设备访问',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ActionChip(
                                      label: const Text('127.0.0.1 (本机)'),
                                      onPressed: () {
                                        _hostCtrl.text = '127.0.0.1';
                                        setState(() {});
                                      },
                                    ),
                                    ActionChip(
                                      label: const Text('0.0.0.0 (局域网)'),
                                      onPressed: () {
                                        _hostCtrl.text = '0.0.0.0';
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _portCtrl,
                              decoration: const InputDecoration(
                                labelText: '监听端口 (Port)',
                                hintText: '58180',
                                border: OutlineInputBorder(),
                                helperText: '推荐 58180（避免与 WindBlog 服务端冲突）',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('应用启动时自动运行 MCP 服务'),
                        subtitle: const Text('客户端开启后无需手动点击，随时响应外部 AI 的上下文与翻译请求'),
                        value: _autoStart,
                        onChanged: (val) => setState(() => _autoStart = val),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isSavingOrSwitching ? null : _saveMcpSettings,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('保存并应用网络设置'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 客户端配置 JSON 卡片
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MCP 客户端配置 JSON',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _copyConfigJson,
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('复制配置 JSON'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '直接粘贴到 Claude Desktop 的配置文件 (claude_desktop_config.json)、Cursor 的 mcp.json 或 Antigravity 配置中：',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _configJson,
                          style: const TextStyle(
                            color: Colors.lightGreenAccent,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 工具清单与调用日志
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '实时调用日志 (${FlutterMcpServer.instance.logs.length})',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              FlutterMcpServer.instance.clearLogs();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('清空日志'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (FlutterMcpServer.instance.logs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: Text(
                            '暂无调用记录。当外部 AI 助手发起工具调用时，日志将实时在此显示。',
                            style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                          ),
                        )
                      else
                        Container(
                          height: 200,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                          ),
                          child: ListView.separated(
                            itemCount: FlutterMcpServer.instance.logs.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final log = FlutterMcpServer.instance.logs[i];
                              Color levelColor = Colors.grey;
                              if (log.level == 'call') levelColor = Colors.blue;
                              if (log.level == 'result') levelColor = Colors.green;
                              if (log.level == 'error') levelColor = Colors.red;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.formattedTime,
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: levelColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        log.level.toUpperCase(),
                                        style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: levelColor),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${log.method}: ${log.message}',
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientEnvTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '客户端实例信息',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.link),
                        title: const Text('当前连接博客基地址 (Base URL)'),
                        subtitle: Text(widget.api.baseUrl),
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: const Text('已登录账号'),
                        subtitle: Text(widget.user != null ? '${widget.user!.username} (${widget.user!.roleName})' : '未登录'),
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.app_shortcut_outlined),
                        title: const Text('客户端应用版本'),
                        subtitle: const Text('1.0.0+1 (WindBlog Flutter Admin)'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
