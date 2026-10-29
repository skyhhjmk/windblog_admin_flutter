import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/admin_api_client.dart';
import '../../data/models.dart';
import 'mcp_models.dart';

class FlutterMcpServer {
  FlutterMcpServer._();
  static final FlutterMcpServer instance = FlutterMcpServer._();

  static const String keyMcpHost = 'admin_mcp_host';
  static const String keyMcpPort = 'admin_mcp_port';
  static const String keyMcpAutoStart = 'admin_mcp_auto_start';

  HttpServer? _server;
  String _host = '127.0.0.1';
  int _port = 58180;
  bool _autoStart = true;
  bool _isRunning = false;

  AdminApiClient? _api;
  AdminUser? _user;
  PostEditorStateInterface? _activeEditor;

  final List<McpLogEntry> _logs = [];
  final StreamController<McpLogEntry> _logStream = StreamController<McpLogEntry>.broadcast();
  final StreamController<bool> _statusStream = StreamController<bool>.broadcast();

  final Map<String, HttpResponse> _sseClients = {};

  bool get isRunning => _isRunning;
  String get host => _host;
  int get port => _port;
  bool get autoStart => _autoStart;

  List<McpLogEntry> get logs => List.unmodifiable(_logs);
  Stream<McpLogEntry> get logStream => _logStream.stream;
  Stream<bool> get statusStream => _statusStream.stream;

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _host = prefs.getString(keyMcpHost) ?? '127.0.0.1';
      _port = prefs.getInt(keyMcpPort) ?? 58180;
      _autoStart = prefs.getBool(keyMcpAutoStart) ?? true;
    } catch (_) {}
  }

  Future<void> saveSettings({String? host, int? port, bool? autoStart}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool changed = false;
      if (host != null && host.trim().isNotEmpty && host.trim() != _host) {
        _host = host.trim();
        await prefs.setString(keyMcpHost, _host);
        changed = true;
      }
      if (port != null && port > 0 && port != _port) {
        _port = port;
        await prefs.setInt(keyMcpPort, _port);
        changed = true;
      }
      if (autoStart != null && autoStart != _autoStart) {
        _autoStart = autoStart;
        await prefs.setBool(keyMcpAutoStart, _autoStart);
      }
      if (changed && _isRunning) {
        await stop();
        await start(host: _host, port: _port);
      }
    } catch (_) {}
  }

  Future<void> init(AdminApiClient api, {AdminUser? user, bool autoStartServer = true}) async {
    _api = api;
    _user = user;
    await loadSettings();
    if (autoStartServer && _autoStart && !_isRunning) {
      await start(host: _host, port: _port);
    }
  }

  void updateSession({AdminApiClient? api, AdminUser? user}) {
    if (api != null) _api = api;
    if (user != null) _user = user;
    _addLog('info', 'session', 'Updated admin session bound to MCP: user=${_user?.username ?? "unknown"}, baseUrl=${_api?.baseUrl ?? "none"}');
  }

  void setActiveEditor(PostEditorStateInterface editor) {
    _activeEditor = editor;
    _addLog('info', 'editor', 'Active article editor hooked into MCP (postId=${editor.currentPostId})');
  }

  void clearActiveEditor(PostEditorStateInterface editor) {
    if (identical(_activeEditor, editor)) {
      _activeEditor = null;
      _addLog('info', 'editor', 'Active article editor unhooked from MCP');
    }
  }

  void clearLogs() {
    _logs.clear();
  }

  void _addLog(String level, String method, String message, [Map<String, dynamic>? details]) {
    final entry = McpLogEntry(
      level: level,
      method: method,
      message: message,
      details: details,
    );
    _logs.insert(0, entry);
    if (_logs.length > 200) {
      _logs.removeLast();
    }
    _logStream.add(entry);
    debugPrint('[MCP] $entry');
  }

  Future<bool> start({String? host, int? port}) async {
    if (_isRunning) {
      if ((host != null && host != _host) || (port != null && port != _port)) {
        await stop();
      } else {
        return true;
      }
    }
    _host = host ?? _host;
    _port = port ?? _port;
    try {
      InternetAddress address;
      if (_host == '0.0.0.0') {
        address = InternetAddress.anyIPv4;
      } else if (_host == '127.0.0.1' || _host == 'localhost') {
        address = InternetAddress.loopbackIPv4;
      } else {
        address = InternetAddress.tryParse(_host) ?? InternetAddress.loopbackIPv4;
      }

      _server = await HttpServer.bind(address, _port);
      _isRunning = true;
      _statusStream.add(true);
      _addLog('info', 'server', 'WindBlog Flutter MCP Server started on http://$_host:$_port');
      _listen();
      return true;
    } catch (e) {
      _isRunning = false;
      _statusStream.add(false);
      _addLog('error', 'server', 'Failed to start MCP Server: $e');
      return false;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    for (final client in _sseClients.values) {
      try {
        await client.close();
      } catch (_) {}
    }
    _sseClients.clear();
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    _statusStream.add(false);
    _addLog('info', 'server', 'MCP Server stopped');
  }

  void _listen() {
    _server?.listen((HttpRequest request) async {
      _handleCors(request);
      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      final path = request.uri.path;
      if (request.method == 'GET' && path == '/sse') {
        await _handleSse(request);
      } else if (request.method == 'POST' && (path == '/message' || path == '/mcp' || path == '/rpc' || path == '/')) {
        await _handlePostMessage(request);
      } else if (request.method == 'GET' && (path == '/' || path == '/status')) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'server': 'windblog-flutter-admin-mcp',
          'status': 'running',
          'host': _host,
          'port': _port,
          'hasSession': _api?.token != null && _api!.token!.isNotEmpty,
          'user': _user?.username,
          'baseUrl': _api?.baseUrl,
        }));
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }, onError: (err) {
      _addLog('error', 'server', 'Server error: $err');
    });
  }

  void _handleCors(HttpRequest request) {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');
  }

  Future<void> _handleSse(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Content-Type', 'text/event-stream; charset=utf-8');
    response.headers.set('Cache-Control', 'no-cache, no-transform');
    response.headers.set('Connection', 'keep-alive');

    final sessionId = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    _sseClients[sessionId] = response;
    _addLog('info', 'sse', 'Client connected to SSE stream (sessionId=$sessionId)');

    // MCP initial event providing the endpoint to post messages to
    response.write('event: endpoint\ndata: /message?sessionId=$sessionId\n\n');
    await response.flush();

    request.response.done.then((_) {
      _sseClients.remove(sessionId);
      _addLog('info', 'sse', 'Client disconnected from SSE stream (sessionId=$sessionId)');
    }).catchError((_) {
      _sseClients.remove(sessionId);
    });
  }

  Future<void> _handlePostMessage(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    String body = '';
    try {
      body = await utf8.decodeStream(request);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final rpcResponse = await _handleJsonRpc(json);

      if (sessionId != null && _sseClients.containsKey(sessionId)) {
        final sseRes = _sseClients[sessionId]!;
        sseRes.write('event: message\ndata: ${jsonEncode(rpcResponse)}\n\n');
        await sseRes.flush();

        request.response.statusCode = HttpStatus.accepted;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'status': 'delivered_via_sse'}));
        await request.response.close();
      } else {
        // Direct HTTP response
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(rpcResponse));
        await request.response.close();
      }
    } catch (e) {
      _addLog('error', 'rpc', 'Failed to process RPC: $e');
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'jsonrpc': '2.0',
        'error': {'code': -32700, 'message': 'Parse error or internal exception: $e'},
      }));
      await request.response.close();
    }
  }

  Future<Map<String, dynamic>> _handleJsonRpc(Map<String, dynamic> rpc) async {
    final method = rpc['method'] as String? ?? '';
    final id = rpc['id'];
    final params = rpc['params'] as Map<String, dynamic>? ?? {};

    _addLog('call', method, 'Method call: $method', params);

    switch (method) {
      case 'initialize':
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': '2024-11-05',
            'capabilities': {
              'tools': {},
            },
            'serverInfo': {
              'name': 'windblog-flutter-admin-mcp',
              'version': '1.0.0',
            },
          },
        };

      case 'notifications/initialized':
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {},
        };

      case 'ping':
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {},
        };

      case 'tools/list':
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'tools': _toolDefinitions(),
          },
        };

      case 'tools/call':
        final toolName = params['name'] as String? ?? '';
        final args = params['arguments'] as Map<String, dynamic>? ?? {};
        try {
          final resultData = await _executeTool(toolName, args);
          _addLog('result', toolName, 'Tool execution succeeded: $toolName', resultData);
          return {
            'jsonrpc': '2.0',
            'id': id,
            'result': {
              'content': [
                {
                  'type': 'text',
                  'text': jsonEncode(resultData),
                }
              ],
            },
          };
        } catch (e) {
          _addLog('error', toolName, 'Tool execution error: $e');
          return {
            'jsonrpc': '2.0',
            'id': id,
            'result': {
              'isError': true,
              'content': [
                {
                  'type': 'text',
                  'text': 'Tool execution failed: $e',
                }
              ],
            },
          };
        }

      default:
        return {
          'jsonrpc': '2.0',
          'id': id,
          'error': {
            'code': -32601,
            'message': 'Method not found: $method',
          },
        };
    }
  }

  List<Map<String, dynamic>> _toolDefinitions() {
    return [
      {
        'name': 'windblog_get_session_status',
        'description': 'Check the current login session status of the Flutter admin client, including target blog baseUrl, token presence, and authenticated administrator profile.',
        'inputSchema': {
          'type': 'object',
          'properties': {},
        },
      },
      {
        'name': 'windblog_list_posts',
        'description': 'List articles from WindBlog using the administrator active session. Supports filtering by keyword, status, and pagination.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'page': {'type': 'integer', 'default': 1},
            'size': {'type': 'integer', 'default': 10},
            'query': {'type': 'string', 'description': 'Keyword search'},
            'status': {'type': 'string', 'enum': ['ALL', 'PUBLISHED', 'DRAFT', 'PENDING_REVIEW']},
          },
        },
      },
      {
        'name': 'windblog_get_post',
        'description': 'Get full details of a WindBlog post by ID, including multi-language titles, summaries, and markdown contents across all languages.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'postId': {'type': 'integer', 'description': 'Post primary ID'},
          },
          'required': ['postId'],
        },
      },
      {
        'name': 'windblog_translate_post',
        'description': 'Translate an article title, summary, and markdown content from sourceLanguage to targetLanguage using the active administrator credentials and WindBlog AI translation service.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'postId': {'type': 'integer', 'description': 'Post ID to translate'},
            'sourceLanguage': {'type': 'string', 'default': 'zh-cn', 'description': 'Source language code, e.g. zh-cn'},
            'targetLanguage': {'type': 'string', 'description': 'Target language code, e.g. en-us'},
            'title': {'type': 'string', 'description': 'Optional override of source title'},
            'summary': {'type': 'string', 'description': 'Optional override of source summary'},
            'contentMarkdown': {'type': 'string', 'description': 'Optional override of source markdown content'},
          },
          'required': ['postId', 'targetLanguage'],
        },
      },
      {
        'name': 'windblog_save_post_translation',
        'description': 'Save or update a translated edition (targetLanguage, title, summary, contentMarkdown) of an article into WindBlog using the administrator credentials.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'postId': {'type': 'integer', 'description': 'Target post ID'},
            'targetLanguage': {'type': 'string', 'description': 'Target language code, e.g. en-us'},
            'title': {'type': 'string', 'description': 'Translated title'},
            'summary': {'type': 'string', 'description': 'Translated summary'},
            'contentMarkdown': {'type': 'string', 'description': 'Translated markdown content'},
          },
          'required': ['postId', 'targetLanguage', 'title', 'contentMarkdown'],
        },
      },
      {
        'name': 'windblog_get_active_editor_post',
        'description': 'Get the current article being actively edited in the Flutter post editor (if open), including dirty status, title, summary, and content.',
        'inputSchema': {
          'type': 'object',
          'properties': {},
        },
      },
      {
        'name': 'windblog_apply_translation_to_editor',
        'description': 'Apply a generated translation directly into the active Flutter post editor for the specified target language.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'targetLanguage': {'type': 'string', 'description': 'Target language code, e.g. en-us'},
            'title': {'type': 'string', 'description': 'Translated title'},
            'summary': {'type': 'string', 'description': 'Translated summary'},
            'contentMarkdown': {'type': 'string', 'description': 'Translated markdown content'},
          },
          'required': ['targetLanguage', 'title', 'contentMarkdown'],
        },
      },
    ];
  }

  Future<Map<String, dynamic>> _executeTool(String name, Map<String, dynamic> args) async {
    final api = _api;
    if (api == null) {
      throw Exception('AdminApiClient is not initialized in Flutter MCP Server');
    }

    switch (name) {
      case 'windblog_get_session_status':
        return {
          'isLoggedIn': api.token != null && api.token!.isNotEmpty,
          'baseUrl': api.baseUrl,
          'hasToken': api.token != null && api.token!.isNotEmpty,
          'username': _user?.username,
          'roleName': _user?.roleName,
          'email': _user?.email,
          'activeEditorOpen': _activeEditor != null,
        };

      case 'windblog_list_posts':
        _requireAuth(api);
        final page = args['page'] as int? ?? 1;
        final size = args['size'] as int? ?? 10;
        final query = args['query'] as String?;
        final postsRes = await api.listPosts(
          page: page,
          pageSize: size,
          keyword: query,
        );
        return {
          'total': postsRes.total,
          'page': postsRes.page,
          'pageSize': postsRes.pageSize,
          'posts': postsRes.items.map((p) => {
            'id': p.id,
            'slug': p.slug,
            'title': p.title,
            'status': p.status,
            'version': p.version,
          }).toList(),
        };

      case 'windblog_get_post':
        _requireAuth(api);
        final postId = args['postId'] as int?;
        if (postId == null) throw Exception('postId is required');
        final post = await api.postDetail(postId);
        return {
          'id': post.id,
          'slug': post.slug,
          'version': post.version,
          'title': post.title,
          'summary': post.summary,
          'contentMarkdown': post.contentMarkdown,
          'status': post.status,
          'aiSummary': post.aiSummary,
          'createdAt': post.createdAt?.toIso8601String(),
          'updatedAt': post.updatedAt?.toIso8601String(),
        };

      case 'windblog_translate_post':
        _requireAuth(api);
        final postId = args['postId'] as int?;
        if (postId == null) throw Exception('postId is required');
        final targetLanguage = (args['targetLanguage'] as String?)?.trim().toLowerCase();
        if (targetLanguage == null || targetLanguage.isEmpty) {
          throw Exception('targetLanguage is required');
        }
        final sourceLanguage = ((args['sourceLanguage'] as String?)?.trim().toLowerCase()) ?? 'zh-cn';

        String? title = args['title'] as String?;
        String? summary = args['summary'] as String?;
        String? contentMarkdown = args['contentMarkdown'] as String?;

        if (title == null || contentMarkdown == null) {
          final post = await api.postDetail(postId);
          title ??= post.title[sourceLanguage] ?? (post.title.isNotEmpty ? post.title.values.first : '');
          summary ??= post.summary[sourceLanguage] ?? (post.summary.isNotEmpty ? post.summary.values.first : '');
          contentMarkdown ??= post.contentMarkdown[sourceLanguage] ?? (post.contentMarkdown.isNotEmpty ? post.contentMarkdown.values.first : '');
        }

        final effectiveTitle = title;
        final effectiveContent = contentMarkdown;

        if (effectiveTitle.isEmpty) throw Exception('Source article title is empty');
        if (effectiveContent.isEmpty) throw Exception('Source article content is empty');

        final translation = await api.translatePost(
          postId,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          title: effectiveTitle,
          summary: summary ?? '',
          contentMarkdown: effectiveContent,
        );

        return {
          'postId': postId,
          'sourceLanguage': sourceLanguage,
          'targetLanguage': targetLanguage,
          'title': translation.title,
          'summary': translation.summary,
          'contentMarkdown': translation.contentMarkdown,
        };

      case 'windblog_save_post_translation':
        _requireAuth(api);
        final postId = args['postId'] as int?;
        if (postId == null) throw Exception('postId is required');
        final targetLanguage = (args['targetLanguage'] as String?)?.trim().toLowerCase();
        final title = (args['title'] as String?)?.trim();
        final summary = args['summary'] as String?;
        final contentMarkdown = (args['contentMarkdown'] as String?)?.trim();

        if (targetLanguage == null || targetLanguage.isEmpty) throw Exception('targetLanguage is required');
        if (title == null || title.isEmpty) throw Exception('title is required');
        if (contentMarkdown == null || contentMarkdown.isEmpty) throw Exception('contentMarkdown is required');

        final updatedPost = await api.savePostTranslation(
          postId,
          targetLanguage: targetLanguage,
          title: title,
          summary: summary,
          contentMarkdown: contentMarkdown,
        );

        if (_activeEditor != null && _activeEditor!.currentPostId == postId) {
          _activeEditor!.applyTranslation(
            targetLanguage: targetLanguage,
            title: title,
            summary: summary,
            contentMarkdown: contentMarkdown,
          );
        }

        return {
          'success': true,
          'postId': postId,
          'targetLanguage': targetLanguage,
          'title': title,
          'message': 'Translation saved successfully to WindBlog',
          'version': updatedPost.version,
        };

      case 'windblog_get_active_editor_post':
        if (_activeEditor == null) {
          return {
            'hasActiveEditor': false,
            'message': 'No article is currently being edited in Flutter admin client',
          };
        }
        return {
          'hasActiveEditor': true,
          ..._activeEditor!.getEditorData(),
        };

      case 'windblog_apply_translation_to_editor':
        if (_activeEditor == null) {
          throw Exception('No active editor is open in Flutter admin client');
        }
        final targetLanguage = (args['targetLanguage'] as String?)?.trim().toLowerCase();
        final title = (args['title'] as String?)?.trim();
        final summary = args['summary'] as String?;
        final contentMarkdown = (args['contentMarkdown'] as String?)?.trim();

        if (targetLanguage == null || targetLanguage.isEmpty) throw Exception('targetLanguage is required');
        if (title == null || title.isEmpty) throw Exception('title is required');
        if (contentMarkdown == null || contentMarkdown.isEmpty) throw Exception('contentMarkdown is required');

        _activeEditor!.applyTranslation(
          targetLanguage: targetLanguage,
          title: title,
          summary: summary,
          contentMarkdown: contentMarkdown,
        );

        return {
          'success': true,
          'targetLanguage': targetLanguage,
          'message': 'Translation successfully applied to active editor',
        };

      default:
        throw Exception('Unknown tool: $name');
    }
  }

  void _requireAuth(AdminApiClient api) {
    if (api.token == null || api.token!.isEmpty) {
      throw Exception('Flutter admin client is not logged in. Please log in first to use WindBlog MCP tools.');
    }
  }
}
