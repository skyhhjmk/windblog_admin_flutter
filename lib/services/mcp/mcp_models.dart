/// Represents a log entry of MCP tool execution or server events.
class McpLogEntry {
  final DateTime timestamp;
  final String level; // 'info', 'call', 'result', 'error'
  final String method;
  final String message;
  final Map<String, dynamic>? details;

  McpLogEntry({
    DateTime? timestamp,
    this.level = 'info',
    required this.method,
    required this.message,
    this.details,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level,
    'method': method,
    'message': message,
    'details': details,
  };

  @override
  String toString() => '[$formattedTime] [$level] $method: $message';
}

/// Interface for active post editor in Flutter client to hook with MCP.
abstract class PostEditorStateInterface {
  int? get currentPostId;
  Map<String, dynamic> getEditorData();
  void applyTranslation({
    required String targetLanguage,
    required String title,
    String? summary,
    required String contentMarkdown,
  });
}
