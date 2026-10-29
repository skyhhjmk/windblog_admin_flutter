import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/services/mcp/mcp_server.dart';

class MockEditorState implements PostEditorStateInterface {
  @override
  int? currentPostId = 101;

  final Map<String, String> titles = {'zh-cn': '测试文章标题'};
  final Map<String, String> summaries = {'zh-cn': '测试文章摘要'};
  final Map<String, String> contents = {'zh-cn': '测试文章正文内容'};
  bool isDirty = false;

  @override
  Map<String, dynamic> getEditorData() => {
    'postId': currentPostId,
    'slug': 'test-article-slug',
    'titles': titles,
    'summaries': summaries,
    'contents': contents,
    'isDirty': isDirty,
  };

  @override
  void applyTranslation({
    required String targetLanguage,
    required String title,
    String? summary,
    required String contentMarkdown,
  }) {
    titles[targetLanguage] = title;
    if (summary != null) summaries[targetLanguage] = summary;
    contents[targetLanguage] = contentMarkdown;
    isDirty = true;
  }
}

void main() {
  const testPort = 58199;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final api = AdminApiClient();
    api.baseUrl = 'https://blog.example.com';
    api.token = 'test-token-12345';
    final user = AdminUser(
      id: 1,
      username: 'admin',
      email: 'admin@example.com',
      roleName: 'ADMIN',
    );
    await FlutterMcpServer.instance.init(api, user: user, autoStartServer: false);
    await FlutterMcpServer.instance.start(host: '127.0.0.1', port: testPort);
  });

  tearDown(() async {
    await FlutterMcpServer.instance.stop();
  });

  test('FlutterMcpServer starts and serves status', () async {
    expect(FlutterMcpServer.instance.isRunning, isTrue);
    expect(FlutterMcpServer.instance.host, equals('127.0.0.1'));
    expect(FlutterMcpServer.instance.port, equals(testPort));

    final res = await http.get(Uri.parse('http://127.0.0.1:$testPort/status'));
    expect(res.statusCode, equals(200));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['status'], equals('running'));
    expect(body['host'], equals('127.0.0.1'));
    expect(body['port'], equals(testPort));
    expect(body['server'], equals('windblog-flutter-admin-mcp'));
    expect(body['user'], equals('admin'));
  });

  test('FlutterMcpServer saves host, port, and autoStart settings', () async {
    await FlutterMcpServer.instance.saveSettings(
      host: '127.0.0.1',
      port: 58198,
      autoStart: true,
    );
    expect(FlutterMcpServer.instance.port, equals(58198));
    expect(FlutterMcpServer.instance.host, equals('127.0.0.1'));
    expect(FlutterMcpServer.instance.autoStart, isTrue);

    // Switch back to testPort
    await FlutterMcpServer.instance.saveSettings(
      port: testPort,
    );
    expect(FlutterMcpServer.instance.port, equals(testPort));
  });

  test('FlutterMcpServer handles initialize and tools/list', () async {
    // 1. initialize
    final initRes = await http.post(
      Uri.parse('http://127.0.0.1:$testPort/mcp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2024-11-05',
          'clientInfo': {'name': 'test-client', 'version': '1.0'},
        },
      }),
    );
    expect(initRes.statusCode, equals(200));
    final initBody = jsonDecode(initRes.body) as Map<String, dynamic>;
    expect(initBody['result']['serverInfo']['name'], equals('windblog-flutter-admin-mcp'));

    // 2. tools/list
    final listRes = await http.post(
      Uri.parse('http://127.0.0.1:$testPort/mcp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
        'params': {},
      }),
    );
    expect(listRes.statusCode, equals(200));
    final listBody = jsonDecode(listRes.body) as Map<String, dynamic>;
    final tools = listBody['result']['tools'] as List<dynamic>;
    expect(tools.length, equals(7));

    final toolNames = tools.map((t) => t['name']).toList();
    expect(toolNames, contains('windblog_get_session_status'));
    expect(toolNames, contains('windblog_list_posts'));
    expect(toolNames, contains('windblog_get_post'));
    expect(toolNames, contains('windblog_translate_post'));
    expect(toolNames, contains('windblog_save_post_translation'));
    expect(toolNames, contains('windblog_get_active_editor_post'));
    expect(toolNames, contains('windblog_apply_translation_to_editor'));
  });

  test('tools/call windblog_get_session_status returns admin credentials info', () async {
    final res = await http.post(
      Uri.parse('http://127.0.0.1:$testPort/mcp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/call',
        'params': {
          'name': 'windblog_get_session_status',
          'arguments': {},
        },
      }),
    );
    expect(res.statusCode, equals(200));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['result']['content'], isNotEmpty);
    final text = body['result']['content'][0]['text'] as String;
    final data = jsonDecode(text) as Map<String, dynamic>;
    expect(data['isLoggedIn'], isTrue);
    expect(data['username'], equals('admin'));
    expect(data['roleName'], equals('ADMIN'));
    expect(data['baseUrl'], equals('https://blog.example.com'));
  });

  test('tools/call active editor inspection and translation injection', () async {
    final mockEditor = MockEditorState();
    FlutterMcpServer.instance.setActiveEditor(mockEditor);

    // 1. Get active editor post
    final getRes = await http.post(
      Uri.parse('http://127.0.0.1:$testPort/mcp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 4,
        'method': 'tools/call',
        'params': {
          'name': 'windblog_get_active_editor_post',
          'arguments': {},
        },
      }),
    );
    expect(getRes.statusCode, equals(200));
    final getBody = jsonDecode(getRes.body) as Map<String, dynamic>;
    final getData = jsonDecode(getBody['result']['content'][0]['text']) as Map<String, dynamic>;
    expect(getData['hasActiveEditor'], isTrue);
    expect(getData['postId'], equals(101));
    expect(getData['titles']['zh-cn'], equals('测试文章标题'));

    // 2. Apply translation into active editor
    final applyRes = await http.post(
      Uri.parse('http://127.0.0.1:$testPort/mcp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 5,
        'method': 'tools/call',
        'params': {
          'name': 'windblog_apply_translation_to_editor',
          'arguments': {
            'targetLanguage': 'en-us',
            'title': 'Test Article Title in English',
            'summary': 'English Summary',
            'contentMarkdown': 'Translated English Markdown Content',
          },
        },
      }),
    );
    expect(applyRes.statusCode, equals(200));
    final applyBody = jsonDecode(applyRes.body) as Map<String, dynamic>;
    final applyData = jsonDecode(applyBody['result']['content'][0]['text']) as Map<String, dynamic>;
    expect(applyData['success'], isTrue);

    // Verify mock editor received the translation
    expect(mockEditor.titles['en-us'], equals('Test Article Title in English'));
    expect(mockEditor.summaries['en-us'], equals('English Summary'));
    expect(mockEditor.contents['en-us'], equals('Translated English Markdown Content'));
    expect(mockEditor.isDirty, isTrue);

    FlutterMcpServer.instance.clearActiveEditor(mockEditor);
  });
}
