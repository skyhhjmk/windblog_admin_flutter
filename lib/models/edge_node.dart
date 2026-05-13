class EdgeNode {
  final String nodeId;
  final String region;
  final DateTime lastHeartbeat;
  final Map<String, String> metrics;
  final String status;
  final bool isEnabled;

  EdgeNode({
    required this.nodeId,
    required this.region,
    required this.lastHeartbeat,
    required this.metrics,
    required this.status,
    required this.isEnabled,
  });

  factory EdgeNode.fromJson(Map<String, dynamic> json) {
    return EdgeNode(
      nodeId: json['nodeId'] ?? '',
      region: json['region'] ?? '',
      lastHeartbeat: DateTime.parse(json['lastHeartbeat']),
      metrics: Map<String, String>.from(json['metrics'] ?? {}),
      status: json['status'] ?? 'OFFLINE',
      isEnabled: json['isEnabled'] ?? true,
    );
  }
}
