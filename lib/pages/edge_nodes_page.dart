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
  Map<String, EdgeNodeDataStatus> dataStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      nodes = await widget.api.listEdgeNodes();
      dataStatuses = await _loadDataStatuses(nodes);
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

  Future<Map<String, EdgeNodeDataStatus>> _loadDataStatuses(
      List<EdgeNode> edgeNodes,) async {
    final Map<String, EdgeNodeDataStatus> loadedStatuses = {};
    for (int index = 0; index < edgeNodes.length; index++) {
      final node = edgeNodes[index];
      try {
        final status = await widget.api.getEdgeNodeDataStatus(node.nodeId);
        loadedStatuses[node.nodeId] = status;
      } catch (_) {}
    }
    return loadedStatuses;
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
                label: const Text('新建节点'),
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
        final dataStatus = dataStatuses[node.nodeId];
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
                    const SizedBox(width: 4),
                    if (dataStatus != null)
                      _buildBadge(
                        dataStatus.persistentChannelOnline
                            ? '通道在线'
                            : '通道离线',
                        dataStatus.persistentChannelOnline
                            ? Colors.green
                            : Colors.red,
                      ),
                    const SizedBox(width: 4),
                    if (dataStatus != null && dataStatus.readOnly)
                      _buildBadge('只读', Colors.deepOrange),
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
                if (dataStatus != null)
                  Text(
                    '数据状态: ${dataStatus.primaryOnline
                        ? '主节点在线'
                        : '主节点离线'} / '
                        '${dataStatus.readOnly ? '只读' : '可写回源'}',
                  ),
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
    final nameController = TextEditingController(text: node?.name ?? '');
    final externalUrlController = TextEditingController(
        text: node?.externalUrl);
    final apiUrlController = TextEditingController(text: node?.apiUrl);
    final grpcAddressController = TextEditingController(
        text: node?.grpcAddress);
    final ipController = TextEditingController();
    BlogRegion selectedRegion = node?.region ?? BlogRegion.global;
    EdgeConnectionType selectedConn = node?.connectionType ??
        EdgeConnectionType.heartbeat;
    bool isEnabled = node?.isEnabled ?? true;
    int selectedPort = node?.edgeGrpcPort ?? (9001 + Random().nextInt(999));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setDialogState) =>
                AlertDialog(
                  title: Text(isEdit ? '编辑边缘节点' : '新建边缘节点'),
                  content: SizedBox(
                    width: 450,
                    child: SingleChildScrollView(
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
                          if (isEdit) ...[
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
                          ],
                          if (!isEdit && selectedConn ==
                              EdgeConnectionType.activePoll) ...[
                            TextField(
                              controller: ipController,
                              decoration: const InputDecoration(
                                  labelText: '节点 IP (主动连接模式必填)',
                                  hintText: '例如: 192.168.1.100'),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<BlogRegion>(
                                  initialValue: selectedRegion,
                                  decoration: const InputDecoration(
                                      labelText: '所属区域'),
                                  items: BlogRegion.values
                                      .map((e) =>
                                      DropdownMenuItem(
                                      value: e, child: Text(e.displayName)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setDialogState(() => selectedRegion = v!),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: selectedPort.toString(),
                                  decoration: const InputDecoration(
                                      labelText: 'gRPC 端口'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    int parsed = int.tryParse(v) ??
                                        selectedPort;
                                    if (parsed > 0 && parsed < 65536) {
                                      setDialogState(() =>
                                      selectedPort = parsed);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<EdgeConnectionType>(
                            initialValue: selectedConn,
                            decoration: const InputDecoration(
                                labelText: '连接模式'),
                            items: EdgeConnectionType.values
                                .map((e) =>
                                DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                        e == EdgeConnectionType.heartbeat
                                            ? '心跳上报 (从→主)'
                                            : '主动轮询 (主→从)')))
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedConn = v!),
                          ),
                          if (isEdit)
                            SwitchListTile(
                              title: const Text('是否启用'),
                              value: isEnabled,
                              onChanged: (v) =>
                                  setDialogState(() => isEnabled = v),
                            ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context),
                        child: const Text('取消')),
                    FilledButton(
                      onPressed: () {
                        if (!isEdit &&
                            selectedConn == EdgeConnectionType.activePoll) {
                          if (ipController.text
                              .trim()
                              .isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text(
                                  '使用主动轮询模式时必须填写节点 IP')),
                            );
                            return;
                          }
                        }
                        Navigator.pop(context, true);
                      },
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
      edgeGrpcPort: selectedPort,
    );

    try {
      if (isEdit) {
        await widget.api.updateEdgeNode(node.nodeId, newNode);
        _loadData();
      } else {
        await widget.api.createEdgeNode(
            newNode, nodeIp: ipController.text.trim());
        _loadData();
        if (mounted) {
          _offerDownloadZip(idController.text);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('提交失败: $e')));
      }
    }
  }

  Future<void> _offerDownloadZip(String nodeId) async {
    final download = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('节点创建成功'),
            content: const Text(
                '是否立即下载部署包？\n\n部署包包含证书、配置文件和 Docker Compose，解压后执行 docker compose up -d 即可启动边缘节点。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('稍后')),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.download),
                label: const Text('下载部署包'),
              ),
            ],
          ),
    );

    if (download == true) {
      if (!mounted) return;
      _showDownloadProgressDialog(nodeId);
    }
  }

  Future<void> _showDownloadProgressDialog(String nodeId) async {
    double downloadProgress = 0;
    String downloadStatus = '准备下载...';
    bool downloadDone = false;
    Uint8List? zipBytes;
    String? downloadError;
    StateSetter? downloaderSetState;

    final dialogFuture = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setDialogState) {
              downloaderSetState = setDialogState;
              return AlertDialog(
                title: Text(downloadDone ? '下载完成' : '正在下载部署包'),
                content: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!downloadDone) ...[
                        LinearProgressIndicator(value: downloadProgress > 0
                            ? downloadProgress
                            : null),
                        const SizedBox(height: 12),
                        Text(downloadStatus,
                            style: const TextStyle(fontSize: 14, color: Colors
                                .grey)),
                      ] else
                        if (downloadError != null) ...[
                          const Icon(
                              Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text(downloadError, style: const TextStyle(
                              color: Colors.red)),
                        ] else
                          ...[
                            const Icon(
                                Icons.check_circle_outline, color: Colors.green,
                                size: 48),
                            const SizedBox(height: 12),
                            const Text('部署包已就绪', style: TextStyle(
                                fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('请选择保存方式：', style: TextStyle(
                                color: Colors.grey)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    if (zipBytes != null) {
                                      web_helper.downloadFile(zipBytes,
                                          'windblog-edge-$nodeId.zip',
                                          'application/zip');
                                    }
                                  },
                                  icon: const Icon(Icons.folder_open),
                                  label: const Text('保存到下载文件夹'),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  onPressed: () {
                                    if (zipBytes != null) {
                                      web_helper.saveFileWithPicker(zipBytes,
                                          'windblog-edge-$nodeId.zip');
                                    }
                                  },
                                  icon: const Icon(Icons.folder),
                                  label: const Text('选择保存位置'),
                                ),
                              ],
                            ),
                          ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (downloadDone && downloadError == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(
                              '您随时可从节点详情中重新下载部署包')),
                        );
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          ),
    );

    try {
      zipBytes = await widget.api.downloadDeploymentZipWithProgress(
        nodeId,
        onProgress: (progress) {
          downloadProgress = progress;
          int percent = (progress * 100).toInt();
          downloadStatus = '正在下载 ($percent%)';
          downloaderSetState?.call(() {});
        },
        onStatus: (status) {
          downloadStatus = status;
          downloaderSetState?.call(() {});
        },
      );
      downloadProgress = 1.0;
      downloadDone = true;
      downloaderSetState?.call(() {});
    } catch (e) {
      downloadError = '下载失败: $e';
      downloadDone = true;
      downloaderSetState?.call(() {});
    }

    await dialogFuture;
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
  EdgeNodeDataStatus? dataStatus;
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
      final d = await widget.api.getEdgeNodeDataStatus(widget.node.nodeId);
      if (mounted) {
        setState(() {
          detailedNode = n;
          dataStatus = d;
          syncStatus = d.syncProgress;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final d = await widget.api.getEdgeNodeDataStatus(widget.node.nodeId);
      if (mounted) {
        setState(() {
          dataStatus = d;
          syncStatus = d.syncProgress;
        });
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
              _buildSectionTitle('数据通道'),
              if (dataStatus == null)
                const Text('暂无数据通道状态')
              else
                ...[
                  _buildInfoRow(
                    '持久通道',
                    dataStatus!.persistentChannelOnline ? '在线' : '离线',
                    color: dataStatus!.persistentChannelOnline
                        ? Colors.green
                        : Colors.red,
                  ),
                  _buildInfoRow(
                    '主节点',
                    dataStatus!.primaryOnline ? '在线' : '离线',
                    color: dataStatus!.primaryOnline
                        ? Colors.green
                        : Colors.red,
                  ),
                  _buildInfoRow(
                    '写入模式',
                    dataStatus!.readOnly ? '只读' : '写请求回源主节点',
                    color: dataStatus!.readOnly
                        ? Colors.deepOrange
                        : Colors.green,
                  ),
                  if (dataStatus!.readOnlyMessage.isNotEmpty)
                    _buildInfoRow('只读原因', dataStatus!.readOnlyMessage),
                  _buildInfoRow(
                    '通道建立',
                    _formatDate(dataStatus!.channelConnectedAt),
                  ),
                ],
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
              if (_mergedMetrics(node).isEmpty)
                const Text('暂无指标数据', style: TextStyle(color: Colors.grey))
              else
                ..._mergedMetrics(node).entries.map((e) =>
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
    bool isDownloading = false;
    double downloadProgress = 0;
    String downloadStatus = '';
    bool downloadDone = false;
    Uint8List? zipBytes;
    String? downloadError;
    StateSetter? certDownloaderSetState;

    await showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setDialogState) {
              certDownloaderSetState = setDialogState;
              return AlertDialog(
                title: Text(downloadDone ? '下载完成' : '部署包下载'),
                content: SizedBox(
                  width: 550,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                            '边缘节点需要通过 mTLS 双向认证才能与主节点通信。'),
                        const SizedBox(height: 12),
                        const Text('部署包包含以下内容：',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text(
                            '  certs/  — 24h 主证书 + 72h 备用证书 + CA 根证书'),
                        const Text('  .env  — 预配置的环境变量'),
                        const Text('  docker-compose.yml  — 一键启动配置'),
                        const Text('  README.txt  — 部署步骤说明'),
                        const SizedBox(height: 16),
                        if (isDownloading) ...[
                          LinearProgressIndicator(value: downloadProgress > 0
                              ? downloadProgress
                              : null),
                          const SizedBox(height: 12),
                          Text(downloadStatus, style: const TextStyle(
                              fontSize: 14, color: Colors.grey)),
                        ] else
                          if (downloadDone && downloadError == null) ...[
                            const Icon(Icons.check_circle_outline,
                                color: Colors.green, size: 32),
                            const SizedBox(height: 8),
                            const Text('部署包已就绪',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('请选择保存方式：',
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    if (zipBytes != null) {
                                      web_helper.downloadFile(zipBytes!,
                                          'windblog-edge-${node.nodeId}.zip',
                                          'application/zip');
                                    }
                                  },
                                  icon: const Icon(Icons.folder_open),
                                  label: const Text('保存到下载文件夹'),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  onPressed: () {
                                    if (zipBytes != null) {
                                      web_helper.saveFileWithPicker(zipBytes!,
                                          'windblog-edge-${node.nodeId}.zip');
                                    }
                                  },
                                  icon: const Icon(Icons.folder),
                                  label: const Text('选择保存位置'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text('部署步骤：',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('1. 将 ZIP 解压到目标服务器上'),
                            const Text('2. 进入解压后的目录'),
                            const Text(
                                '3. 如主节点地址不是 localhost，编辑 .env'),
                            const Text('4. 执行: docker compose up -d'),
                          ] else
                            if (downloadError != null) ...[
                              const Icon(Icons.error_outline, color: Colors.red,
                                  size: 32),
                              const SizedBox(height: 8),
                              Text(downloadError!,
                                  style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: () async {
                                  downloadError = null;
                                  isDownloading = true;
                                  downloadProgress = 0;
                                  setDialogState(() {});
                                  zipBytes =
                                  await _performCertDownload(node, (p, s) {
                                    downloadProgress = p;
                                    downloadStatus = s;
                                    certDownloaderSetState?.call(() {});
                                  });
                                  isDownloading = false;
                                  if (zipBytes == null) {
                                    downloadError = '下载失败，请检查网络后重试';
                                  } else {
                                    downloadDone = true;
                                    downloadProgress = 1.0;
                                  }
                                  certDownloaderSetState?.call(() {});
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('重试'),
                              ),
                            ] else
                              ...[
                                Center(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      isDownloading = true;
                                      downloadProgress = 0;
                                      downloadStatus = '正在生成部署包...';
                                      setDialogState(() {});
                                      zipBytes =
                                      await _performCertDownload(node, (p, s) {
                                        downloadProgress = p;
                                        downloadStatus = s;
                                        certDownloaderSetState?.call(() {});
                                      });
                                      isDownloading = false;
                                      if (zipBytes == null) {
                                        downloadError =
                                        '下载失败，请检查网络后重试';
                                      } else {
                                        downloadDone = true;
                                        downloadProgress = 1.0;
                                        _refresh();
                                      }
                                      setDialogState(() {});
                                      certDownloaderSetState?.call(() {});
                                    },
                                    icon: const Icon(Icons.download),
                                    label: const Text('生成并下载部署 ZIP'),
                                  ),
                                ),
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
                                  await widget.api.revokeEdgeNodeCertificate(
                                      node.nodeId);
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  _refresh();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('吊销失败: $e')));
                                }
                              }
                            },
                            icon: const Icon(Icons.block, color: Colors.red),
                            label: const Text('吊销当前证书',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context),
                      child: const Text('关闭')),
                ],
              );
            },
          ),
    );
  }

  Future<Uint8List?> _performCertDownload(EdgeNode node,
      void Function(double progress, String status) onUpdate,) async {
    try {
      final bytes = await widget.api.downloadDeploymentZipWithProgress(
        node.nodeId,
        onProgress: (p) => onUpdate(p, '正在下载 (${(p * 100).toInt()}%)'),
        onStatus: (s) => onUpdate(0, s),
      );
      return bytes;
    } catch (_) {
      return null;
    }
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

  Map<String, String> _mergedMetrics(EdgeNode node) {
    if (dataStatus != null && dataStatus!.metrics.isNotEmpty) {
      return dataStatus!.metrics;
    }
    return node.metrics;
  }
}
