import 'dart:async';
import '../../data/admin_api_client.dart';
import '../../data/models.dart';
import 'mcp_models.dart';

class FlutterMcpServer {
  FlutterMcpServer._();
  static final FlutterMcpServer instance = FlutterMcpServer._();

  bool get isRunning => false;
  String get host => '127.0.0.1';
  int get port => 58180;
  bool get autoStart => true;
  List<McpLogEntry> get logs => const [];

  final StreamController<McpLogEntry> _logStream = StreamController<McpLogEntry>.broadcast();
  final StreamController<bool> _statusStream = StreamController<bool>.broadcast();

  Stream<McpLogEntry> get logStream => _logStream.stream;
  Stream<bool> get statusStream => _statusStream.stream;

  Future<void> loadSettings() async {}
  Future<void> saveSettings({String? host, int? port, bool? autoStart}) async {}
  Future<void> init(AdminApiClient api, {AdminUser? user, bool autoStartServer = true}) async {}
  void updateSession({AdminApiClient? api, AdminUser? user}) {}
  void setActiveEditor(PostEditorStateInterface editor) {}
  void clearActiveEditor(PostEditorStateInterface editor) {}

  Future<bool> start({String? host, int? port}) async => false;
  Future<void> stop() async {}
  void clearLogs() {}
}
