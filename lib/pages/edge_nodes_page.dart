part of 'package:windblog_admin_flutter/main.dart';

class EdgeNodesPage extends StatefulWidget {
  const EdgeNodesPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<EdgeNodesPage> createState() => _EdgeNodesPageState();
}

class _EdgeNodesPageState extends State<EdgeNodesPage> {
  bool loading = false;
  List<EdgeNode> nodes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      nodes = await widget.api.listEdgeNodes();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _toggleNode(String nodeId, bool enabled) async {
    try {
      await widget.api.toggleEdgeNode(nodeId, enabled);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteNode(String nodeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除节点 $nodeId 吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                      '删除', style: TextStyle(color: Colors.red))),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await widget.api.deleteEdgeNode(nodeId);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '边缘节点管理',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showEditDialog(null),
                icon: const Icon(Icons.add),
                label: const Text('手动添加'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (nodes.isEmpty) {
      return const Center(child: Text('暂无边缘节点配置'));
    }
    return ListView.builder(
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.router,
                      color: node.status == 'ONLINE' ? Colors.green : Colors
                          .grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      node.name.isNotEmpty ? node.name : node.nodeId,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    _buildBadge(node.region.code.toUpperCase(), Colors.blue),
                    const SizedBox(width: 4),
                    _buildBadge(node.connectionType.name, Colors.orange),
                    const SizedBox(width: 4),
                    if (node.certificateSerial != null)
                      _buildBadge(
                          node.certificateRevoked
                              ? '已吊销'
                              : (node.certificateExpiry != null &&
                              node.certificateExpiry!.isBefore(DateTime.now())
                              ? '已过期'
                              : (node.isTrusted ? '可信' : '待连接')),
                          node.certificateRevoked
                              ? Colors.red
                              : (node.certificateExpiry != null &&
                              node.certificateExpiry!.isBefore(DateTime.now())
                              ? Colors.orange
                              : (node.isTrusted ? Colors.green : Colors.blue))),
                    const Spacer(),
                    Switch(
                      value: node.isEnabled,
                      onChanged: (val) => _toggleNode(node.nodeId, val),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('节点 ID: ${node.nodeId}'),
                if (node.grpcAddress != null && node.grpcAddress!.isNotEmpty)
                  Text('地址: ${node.grpcAddress}'),
                Text('状态: ${node.status}'),
                Text('最后活跃: ${_formatDate(node.lastHeartbeat)}'),
                if (node.metrics.isNotEmpty)
                  Text('指标: ${node.metrics.toString()}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showEditDialog(node),
                      icon: const Icon(Icons.edit),
                      label: const Text('编辑'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _deleteNode(node.nodeId),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text(
                          '删除', style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _showDetailDialog(node),
                      icon: const Icon(Icons.analytics),
                      label: const Text('详情与同步'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _showEditDialog(EdgeNode? node) async {
    final isEdit = node != null;
    final idController = TextEditingController(text: node?.nodeId);
    final nameController = TextEditingController(text: node?.name);
    final externalUrlController = TextEditingController(
        text: node?.externalUrl);
    final apiUrlController = TextEditingController(text: node?.apiUrl);
    final grpcAddressController = TextEditingController(
        text: node?.grpcAddress);
    BlogRegion selectedRegion = node?.region ?? BlogRegion.global;
    EdgeConnectionType selectedConn = node?.connectionType ??
        EdgeConnectionType.heartbeat;
    bool isEnabled = node?.isEnabled ?? true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setDialogState) =>
                AlertDialog(
                  title: Text(isEdit ? '编辑边缘节点' : '添加边缘节点'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: idController,
                          enabled: !isEdit,
                          decoration: const InputDecoration(
                              labelText: '节点 ID (唯一标识)'),
                        ),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                              labelText: '节点名称'),
                        ),
                        TextField(
                          controller: externalUrlController,
                          decoration: const InputDecoration(
                              labelText: '外部访问地址',
                              hintText: 'https://edge.example.com'),
                        ),
                        TextField(
                          controller: apiUrlController,
                          decoration: const InputDecoration(
                              labelText: 'API 通信地址',
                              hintText: 'http://edge-node:8081'),
                        ),
                        TextField(
                          controller: grpcAddressController,
                          decoration: const InputDecoration(
                              labelText: 'gRPC 通信地址',
                              hintText: 'edge-node:9001 (主动连接模式必填)'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<BlogRegion>(
                          initialValue: selectedRegion,
                          decoration: const InputDecoration(
                              labelText: '所属区域'),
                          items: BlogRegion.values
                              .map((e) =>
                              DropdownMenuItem(value: e, child: Text(
                                  e.displayName)))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedRegion = v!),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<EdgeConnectionType>(
                          initialValue: selectedConn,
                          decoration: const InputDecoration(
                              labelText: '连接模式'),
                          items: EdgeConnectionType.values
                              .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedConn = v!),
                        ),
                        SwitchListTile(
                          title: const Text('是否启用'),
                          value: isEnabled,
                          onChanged: (v) => setDialogState(() => isEnabled = v),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context),
                        child: const Text('取消')),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(isEdit ? '保存' : '创建'),
                    ),
                  ],
                ),
          ),
    );

    if (confirmed != true) return;

    final newNode = EdgeNode(
      nodeId: idController.text,
      name: nameController.text,
      externalUrl: externalUrlController.text.isEmpty
          ? null
          : externalUrlController.text,
      apiUrl: apiUrlController.text.isEmpty ? null : apiUrlController.text,
      grpcAddress: grpcAddressController.text.isEmpty
          ? null
          : grpcAddressController.text,
      region: selectedRegion,
      connectionType: selectedConn,
      metrics: {},
      status: node?.status ?? 'OFFLINE',
      isEnabled: isEnabled,
    );

    try {
      if (isEdit) {
        await widget.api.updateEdgeNode(node.nodeId, newNode);
      } else {
        await widget.api.createEdgeNode(newNode);
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('提交失败: $e')));
      }
    }
  }

  Future<void> _showDetailDialog(EdgeNode node) async {
    showDialog(
      context: context,
      builder: (context) =>
          _EdgeNodeDetailDialog(
            node: node,
            api: widget.api,
          ),
    );
  }
}

String _formatDate(DateTime? dt) {
  if (dt == null) return '从未活跃';
  final localDt = dt.toLocal();
  return '${localDt.year}-${localDt.month}-${localDt.day} ${localDt.hour
      .toString().padLeft(2, '0')}:${localDt.minute.toString().padLeft(
      2, '0')}:${localDt.second.toString().padLeft(2, '0')}';
}

class _EdgeNodeDetailDialog extends StatefulWidget {
  final EdgeNode node;
  final AdminApiClient api;

  const _EdgeNodeDetailDialog({required this.node, required this.api});

  @override
  State<_EdgeNodeDetailDialog> createState() => _EdgeNodeDetailDialogState();
}

class _EdgeNodeDetailDialogState extends State<_EdgeNodeDetailDialog> {
  EdgeNode? detailedNode;
  EdgeSyncStatus? syncStatus;
  Timer? _timer;
  bool _forceSync = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer =
        Timer.periodic(const Duration(seconds: 3), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final n = await widget.api.getEdgeNode(widget.node.nodeId);
      final s = await widget.api.getEdgeNodeSyncStatus(widget.node.nodeId);
      if (mounted) {
        setState(() {
          detailedNode = n;
          syncStatus = s;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final s = await widget.api.getEdgeNodeSyncStatus(widget.node.nodeId);
      if (mounted) {
        setState(() => syncStatus = s);
      }
    } catch (_) {}
  }

  Future<void> _startSync() async {
    try {
      await widget.api.triggerEdgeNodeSync(
          widget.node.nodeId, force: _forceSync);
      _refreshStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已触发全量同步')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('触发同步失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = detailedNode ?? widget.node;
    return AlertDialog(
      title: Text('节点详情: ${node.name}'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionTitle('基本信息'),
              _buildInfoRow('节点 ID', node.nodeId),
              _buildInfoRow('外部访问', node.externalUrl ?? 'N/A'),
              _buildInfoRow('API 地址', node.apiUrl ?? 'N/A'),
              _buildInfoRow(
                  'gRPC 地址', node.grpcAddress ?? 'N/A'),
              _buildInfoRow('状态', node.status,
                  color: node.status == 'ONLINE' ? Colors.green : Colors.red),
              _buildInfoRow('区域', node.region.displayName),
              _buildInfoRow('连接模式', node.connectionType.name),
              const Divider(),
              _buildSectionTitle('安全与证书'),
              _buildInfoRow('可信状态',
                  node.certificateSerial == null ? '未授信' : (node
                      .certificateRevoked ? '已吊销' : (node.isTrusted
                      ? '可信'
                      : '已签发，待连接')),
                  color: node.certificateRevoked ? Colors.red : (node
                      .certificateSerial == null ? Colors.grey : (node.isTrusted
                      ? Colors.green
                      : Colors.blue))),
              if (node.certificateSerial != null) ...[
                _buildInfoRow('主证书序列号', node.certificateSerial!),
                _buildInfoRow(
                    '主证书过期', _formatDate(node.certificateExpiry)),
              ],
              if (node.certificateBackupSerial != null) ...[
                _buildInfoRow('备用证书序列号', node.certificateBackupSerial!),
                _buildInfoRow(
                    '备用证书过期', _formatDate(node.certificateBackupExpiry)),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCertificateSetup(node),
                  icon: const Icon(Icons.security),
                  label: const Text('管理证书与部署指引'),
                ),
              ),
              const Divider(),
              _buildSectionTitle('运行指标'),
              if (node.metrics.isEmpty)
                const Text('暂无指标数据', style: TextStyle(color: Colors.grey))
              else
                ...node.metrics.entries.map((e) =>
                    _buildInfoRow(e.key, e.value)),
              const Divider(),
              _buildSectionTitle('同步状态'),
              if (syncStatus == null)
                const Text('无活跃同步任务')
              else
                ...[
                  _buildInfoRow('当前阶段', syncStatus!.status),
                  _buildInfoRow('进度',
                      '${syncStatus!.processed} / ${syncStatus!.total}'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: syncStatus!.progress),
                  if (syncStatus!.lastError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('最后错误: ${syncStatus!.lastError}',
                          style: const TextStyle(
                              color: Colors.red, fontSize: 12)),
                    ),
                ],
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('强一致性同步 (覆盖所有数据)'),
                subtitle: const Text(
                    '勾选后将强制重置节点数据并同步，用于解决排序不一致等持久性问题'),
                value: _forceSync,
                onChanged: (v) {
                  setState(() => _forceSync = v ?? false);
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        FilledButton.icon(
          onPressed: syncStatus?.status == 'SYNCING' ? null : _startSync,
          icon: const Icon(Icons.sync),
          label: const Text('全量同步'),
        ),
      ],
    );
  }

  Future<void> _showCertificateSetup(EdgeNode node) async {
    bool localLoading = false;
    NodeDeploymentPackage? cert;

    await showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setDialogState) =>
                AlertDialog(
                  title: const Text('边缘节点部署与证书管理'),
                  content: SizedBox(
                    width: 700,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cert == null) ...[
                            const Text(
                                '边缘节点需要通过 mTLS 双向认证才能与主节点通信。'),
                            const SizedBox(height: 8),
                            const Text('部署流程：',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const Text(
                                '1. 点击下方按钮签发新的证书对（包含 24h 主证书和 72h 备用证书）。'),
                            const Text(
                                '2. 下载或复制生成的证书文件、环境变量和 Docker Compose 配置。'),
                            const Text('3. 在边缘节点服务器上运行部署命令。'),
                            const SizedBox(height: 16),
                            if (localLoading)
                              const Center(child: CircularProgressIndicator())
                            else
                              Center(
                                child: Column(
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () async {
                                        setDialogState(() =>
                                        localLoading = true);
                                        try {
                                          // 获取完整的部署包（包含证书 PEM）
                                          final res = await widget.api
                                              .getEdgeNodeDeploymentPackage(
                                              node.nodeId);
                                          setDialogState(() {
                                            cert = res;
                                            localLoading = false;
                                          });
                                          _refresh();
                                        } catch (e) {
                                          setDialogState(() =>
                                          localLoading = false);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger
                                              .of(context)
                                              .showSnackBar(SnackBar(
                                              content: Text('获取失败: $e')));
                                        }
                                      },
                                      icon: const Icon(Icons.cloud_download),
                                      label: const Text('生成并获取部署包'),
                                    ),
                                  ],
                                ),
                              ),
                          ] else
                            ...[
                              const Text(
                                  '✅ 部署信息已准备就绪！请务必保存私钥信息。',
                                  style: TextStyle(fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                              const SizedBox(height: 16),
                              _buildStep(1, '保存证书文件',
                                  '将以下证书内容保存到部署目录的 certs/ 文件夹中：'),
                              _buildFileBox('ca.crt (根证书)', cert!.caCert),
                              Row(
                                children: [
                                  Expanded(child: _buildFileBox(
                                      'server.crt (主证书)',
                                      cert!.primaryCert)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildFileBox(
                                      'server.key (主私钥)', cert!.primaryKey)),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(child: _buildFileBox(
                                      'backup.crt (备用证书)',
                                      cert!.backupCert)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildFileBox(
                                      'backup.key (备用私钥)',
                                      cert!.backupKey)),
                                ],
                              ),
                              _buildStep(2, '配置文件',
                                  '创建 .env 文件或 docker-compose.yml：'),
                              _buildFileBox('.env 环境变量', cert!.envFile),
                              _buildFileBox(
                                  'docker-compose.yml', cert!.dockerCompose),
                              _buildStep(
                                  3, '启动命令', '在目录下执行以下命令：'),
                              _buildFileBox('Shell', 'docker-compose up -d'),
                            ],
                          if (node.certificateSerial != null &&
                              !node.certificateRevoked) ...[
                            const Divider(),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (context) =>
                                      AlertDialog(
                                        title: const Text('确认吊销'),
                                        content: const Text(
                                            '吊销证书后，该节点将无法再通过 mTLS 与主节点通信。确定要继续吗？'),
                                        actions: [
                                          TextButton(onPressed: () =>
                                              Navigator.pop(context, false),
                                              child: const Text('取消')),
                                          TextButton(onPressed: () =>
                                              Navigator.pop(context, true),
                                              child: const Text('确定吊销',
                                                  style: TextStyle(
                                                      color: Colors.red))),
                                        ],
                                      ),
                                );
                                if (ok == true) {
                                  try {
                                    await widget.api.revokeNodeCertificate(
                                        node.nodeId);
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    _refresh();
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text('吊销失败: $e')));
                                  }
                                }
                              },
                              icon: const Icon(Icons.block, color: Colors.red),
                              label: const Text(
                                  '吊销当前证书', style: TextStyle(
                                  color: Colors.red)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context),
                        child: const Text('完成')),
                  ],
                ),
          ),
    );
  }

  Widget _buildStep(int num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$num. $title',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFileBox(String name, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: const TextStyle(fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 14),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板'),
                        duration: Duration(seconds: 1)),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            content.length > 80 ? '${content.substring(0, 80)}...' : content,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 10, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 100,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: TextStyle(color: color,
              fontWeight: color != null ? FontWeight.bold : null))),
        ],
      ),
    );
  }
}
