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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('边缘节点管理'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _buildList(),
    );
  }

  Widget _buildList() {
    if (nodes.isEmpty) {
      return const Center(child: Text('暂无已连接的边缘节点'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return Card(
          child: ListTile(
            leading: Icon(
              Icons.router,
              color: node.status == 'ONLINE' ? Colors.green : Colors.grey,
            ),
            title: Text(node.nodeId),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('区域: ${node.region}'),
                Text('最后心跳: ${_formatDate(node.lastHeartbeat)}'),
                if (node.metrics.isNotEmpty)
                  Text('负载: ${node.metrics['cpu_load'] ?? 'N/A'}% CPU, ${node
                      .metrics['mem_used'] ?? 'N/A'}MB RAM'),
              ],
            ),
            trailing: Switch(
              value: node.isEnabled,
              onChanged: (val) => _toggleNode(node.nodeId, val),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.hour}:${dt.minute}:${dt.second}';
  }
}
