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
                    _buildBadge(node.region.name, Colors.blue),
                    const SizedBox(width: 4),
                    _buildBadge(node.connectionType.name, Colors.orange),
                    const Spacer(),
                    Switch(
                      value: node.isEnabled,
                      onChanged: (val) => _toggleNode(node.nodeId, val),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('节点 ID: ${node.nodeId}'),
                if (node.address != null && node.address!.isNotEmpty)
                  Text('地址: ${node.address}'),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
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
    final addressController = TextEditingController(text: node?.address);
    EdgeRegion selectedRegion = node?.region ?? EdgeRegion.GLOBAL;
    EdgeConnectionType selectedConn = node?.connectionType ??
        EdgeConnectionType.HEARTBEAT;
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
                          controller: addressController,
                          decoration: const InputDecoration(
                              labelText: '节点地址 (host:port)',
                              hintText: '主动连接模式必填'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<EdgeRegion>(
                          value: selectedRegion,
                          decoration: const InputDecoration(
                              labelText: '所属区域'),
                          items: EdgeRegion.values
                              .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedRegion = v!),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<EdgeConnectionType>(
                          value: selectedConn,
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
      address: addressController.text,
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return '从未活跃';
    final localDt = dt.toLocal();
    return '${localDt.year}-${localDt.month}-${localDt.day} ${localDt.hour
        .toString().padLeft(
        2, '0')}:${localDt.minute.toString().padLeft(2, '0')}:${localDt.second
        .toString()
        .padLeft(2, '0')}';
  }
}
