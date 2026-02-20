import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class AdminApiClient {
  String baseUrl = 'http://localhost:8080';
  String? token;

  Future<String> login({
    required String account,
    required String password,
  }) async {
    final res = await _post(
      '/api/admin/auth/login',
      body: {'account': account, 'password': password},
      auth: false,
      authFailureAsSessionExpired: false,
    );
    final map = _map(jsonDecode(res.body));
    final t = map['token'] as String?;
    if (t == null || t.isEmpty) throw Exception('登录失败: token 为空');
    token = t;
    return t;
  }

  Future<AdminUser> me() async {
    final res = await _get('/api/admin/auth/me');
    final map = _map(jsonDecode(res.body));
    final user = _map(map['user']);
    return AdminUser(
      id: (user['id'] as num?)?.toInt() ?? 0,
      username: user['username']?.toString() ?? '-',
      email: user['email']?.toString() ?? '-',
    );
  }

  Future<Map<String, dynamic>> overview() async {
    final res = await _get('/api/admin/base/overview');
    final map = _map(jsonDecode(res.body));
    return _map(map['data']);
  }

  Future<List<AiProviderConfig>> listAiProviders() async {
    final res = await _get('/api/admin/ai/providers');
    final list = (jsonDecode(res.body) as List<dynamic>? ?? []);
    return list
        .map((e) => AiProviderConfig.fromMap(_map(e)))
        .toList();
  }

  Future<AiProviderConfig> updateAiProvider(String provider,
      AiProviderConfigUpdateRequest request,) async {
    final res = await _put(
        '/api/admin/ai/providers/$provider', body: request.toJson());
    return AiProviderConfig.fromMap(_map(jsonDecode(res.body)));
  }

  Future<PostListResult> listPosts({
    required int page,
    required int pageSize,
    String? keyword,
  }) async {
    final query = {
      'page': '$page',
      'pageSize': '$pageSize',
      if ((keyword?.isNotEmpty ?? false)) 'keyword': keyword!,
    };
    final res = await _get('/api/admin/posts', query: query);
    final map = _map(jsonDecode(res.body));
    final list = (map['items'] as List<dynamic>? ?? [])
        .map((e) => PostItem.fromMap(_map(e)))
        .toList();
    return PostListResult(
      items: list,
      total: (map['total'] as num?)?.toInt() ?? 0,
      page: (map['page'] as num?)?.toInt() ?? 1,
      pageSize: (map['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<PostDetail> postDetail(int id) async {
    final res = await _get('/api/admin/posts/$id');
    return PostDetail.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> createPost(PostEditRequest req) async =>
      _post('/api/admin/posts', body: req.toCreateBody());
  Future<void> updatePost(int id, PostEditRequest req) async =>
      _put('/api/admin/posts/$id', body: req.toUpdateBody());
  Future<void> publishPost(int id) async =>
      _post('/api/admin/posts/$id/publish', body: const {});
  Future<void> deletePost(int id) async => _delete('/api/admin/posts/$id');

  Future<http.Response> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers(true));
    _check(res, authFailureAsSessionExpired: true);
    return res;
  }

  Future<http.Response> _post(
    String path, {
    required Map<String, dynamic> body,
    bool auth = true,
    bool authFailureAsSessionExpired = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(
      uri,
      headers: _headers(auth),
      body: jsonEncode(body),
    );
    _check(res, authFailureAsSessionExpired: authFailureAsSessionExpired);
    return res;
  }

  Future<http.Response> _put(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.put(
      uri,
      headers: _headers(true),
      body: jsonEncode(body),
    );
    _check(res, authFailureAsSessionExpired: true);
    return res;
  }

  Future<http.Response> _delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.delete(uri, headers: _headers(true));
    _check(res, authFailureAsSessionExpired: true);
    return res;
  }

  Map<String, String> _headers(bool auth) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      if (token == null || token!.isEmpty) throw UnauthorizedException('请先登录');
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  void _check(http.Response res, {required bool authFailureAsSessionExpired}) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String message = '请求失败(${res.statusCode})';
    try {
      final map = _map(jsonDecode(res.body));
      final m = map['message']?.toString();
      if (m != null && m.isNotEmpty) message = m;
    } catch (_) {}

    if ((res.statusCode == 401 || res.statusCode == 403) &&
        authFailureAsSessionExpired) {
      throw UnauthorizedException('登录已过期或无权限');
    }
    throw Exception(message);
  }

  Map<String, dynamic> _map(Object? obj) {
    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) return obj.map((k, v) => MapEntry('$k', v));
    return {};
  }
}

class UnauthorizedException implements Exception {
  UnauthorizedException(this.message);
  final String message;
  @override
  String toString() => message;
}
