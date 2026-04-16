import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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
    if (t == null || t.isEmpty) throw Exception('Missing token in login response');
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
      roleName: user['roleName']?.toString() ?? '',
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
    return list.map((e) => AiProviderConfig.fromMap(_map(e))).toList();
  }

  Future<AiProviderConfig> updateAiProvider(
    String provider,
    AiProviderConfigUpdateRequest request,
  ) async {
    final res = await _put('/api/admin/ai/providers/$provider', body: request.toJson());
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

  Future<List<PostRevisionItem>> listPostRevisions(int postId) async {
    final res = await _get('/api/admin/posts/$postId/revisions');
    final list = (jsonDecode(res.body) as List<dynamic>? ?? []);
    return list.map((e) => PostRevisionItem.fromMap(_map(e))).toList();
  }

  Future<PostDetail> getPostRevision(int postId, int revisionNumber) async {
    final res = await _get(
        '/api/admin/posts/$postId/revisions/$revisionNumber');
    return PostDetail.fromMap(_map(jsonDecode(res.body)));
  }

  Future<PostDetail> activatePostRevision(int postId,
      int revisionNumber) async {
    final res = await _post(
        '/api/admin/posts/$postId/revisions/$revisionNumber/activate',
        body: const {});
    return PostDetail.fromMap(_map(jsonDecode(res.body)));
  }

  Future<MediaListResult> listMedia({
    int page = 1,
    int pageSize = 20,
    bool unreferenced = false,
  }) async {
    final res = await _get('/api/admin/media', query: {
      'page': '$page',
      'pageSize': '$pageSize',
      'unreferenced': unreferenced ? 'true' : 'false',
    });
    final map = _normalizeMediaListMap(_map(jsonDecode(res.body)));
    return MediaListResult.fromMap(map);
  }

  Future<MediaScanResult> scanMedia() async {
    final res = await _post('/api/admin/media/scan', body: {});
    return MediaScanResult.fromMap(_map(jsonDecode(res.body)));
  }

  Future<MediaItem> uploadMedia({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final uri = Uri.parse('$baseUrl/api/admin/media/upload');
    final request = http.MultipartRequest('POST', uri);
    final headers = _headers(true, json: false);
    request.headers.addAll(headers);
    final detected = mimeType ?? 'application/octet-stream';
    final parts = detected.split('/');
    final contentType = parts.length == 2
        ? MediaType(parts[0], parts[1])
        : MediaType('application', 'octet-stream');
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
      contentType: contentType,
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _check(response, authFailureAsSessionExpired: true);
    return MediaItem.fromMap(
        _normalizeMediaItemMap(_map(jsonDecode(response.body))));
  }

  Future<PageResult<UserListItem>> listUsers({
    int page = 1,
    int pageSize = 20,
    String? keyword,
  }) async {
    final res = await _get('/api/admin/users', query: {
      'page': '$page',
      'pageSize': '$pageSize',
      if ((keyword?.isNotEmpty ?? false)) 'keyword': keyword!,
    });
    final map = _map(jsonDecode(res.body));
    return PageResult.fromMap(map, (item) => UserListItem.fromMap(item));
  }

  Future<UserListItem> updateUser(
    int id, {
    String? email,
        String? avatar,
        String? nickname,
        String? phone,
    int? status,
    String? roleName,
  }) async {
    final payload = <String, dynamic>{};
    if (email != null) payload['email'] = email;
    if (avatar != null) payload['avatar'] = avatar;
    if (nickname != null) payload['nickname'] = nickname;
    if (phone != null) payload['phone'] = phone;
    if (status != null) payload['status'] = status;
    if (roleName != null) payload['roleName'] = roleName;
    final res = await _put('/api/admin/users/$id', body: payload);
    return UserListItem.fromMap(_map(jsonDecode(res.body)));
  }

  // ==================== 钱包管理 API ====================

  Future<WalletInfo> getUserWallet(int userId) async {
    final res = await _get('/api/admin/users/$userId/wallet');
    return WalletInfo.fromMap(_map(jsonDecode(res.body)));
  }

  Future<WalletTransactionHistory> getUserWalletTransactions({
    required int userId,
    required int page,
    required int pageSize,
  }) async {
    final res = await _get(
        '/api/admin/users/$userId/wallet/transactions', query: {
      'page': '$page',
      'pageSize': '$pageSize',
    });
    return WalletTransactionHistory.fromMap(_map(jsonDecode(res.body)));
  }

  Future<WalletInfo> adjustUserWallet(int userId, {
    required int newBalance,
    String? description,
  }) async {
    final res = await _post('/api/admin/users/$userId/wallet/adjust', body: {
      'newBalance': newBalance,
      'description': description ?? '管理员手动调整',
    });
    return WalletInfo.fromMap(_map(jsonDecode(res.body)));
  }

  Future<List<PermissionRoleItem>> listRoles() async {
    final res = await _get('/api/admin/permissions/roles');
    final list = (jsonDecode(res.body) as List<dynamic>? ?? []);
    return list
        .map((e) => PermissionRoleItem.fromMap(_map(e)))
        .toList();
  }

  Future<PermissionRoleItem> createRole(PermissionRoleRequest request) async {
    final res = await _post(
      '/api/admin/permissions/roles',
      body: request.toCreateJson(),
    );
    return PermissionRoleItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<PermissionRoleItem> updateRole(
    String name,
    PermissionRoleRequest request,
  ) async {
    final res = await _put(
      '/api/admin/permissions/roles/$name',
      body: request.toUpdateJson(),
    );
    return PermissionRoleItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> deleteRole(String name) async {
    await _delete('/api/admin/permissions/roles/$name');
  }

  Future<List<CategoryItem>> listCategories() async {
    final res = await _get('/api/admin/categories');
    final list = (jsonDecode(res.body) as List<dynamic>? ?? []);
    return list.map((e) => CategoryItem.fromMap(_map(e))).toList();
  }

  Future<CategoryItem> createCategory(CategoryCreateRequest request) async {
    final res = await _post('/api/admin/categories', body: request.toJson());
    return CategoryItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<CategoryItem> updateCategory(int id,
      CategoryUpdateRequest request) async {
    final res = await _put('/api/admin/categories/$id', body: request.toJson());
    return CategoryItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> deleteCategory(int id) async {
    await _delete('/api/admin/categories/$id');
  }

  Future<List<TagItem>> listTags() async {
    final res = await _get('/api/admin/tags');
    final list = (jsonDecode(res.body) as List<dynamic>? ?? []);
    return list.map((e) => TagItem.fromMap(_map(e))).toList();
  }

  Future<TagItem> createTag(TagCreateRequest request) async {
    final res = await _post('/api/admin/tags', body: request.toJson());
    return TagItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<TagItem> updateTag(int id, TagUpdateRequest request) async {
    final res = await _put('/api/admin/tags/$id', body: request.toJson());
    return TagItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> deleteTag(int id) async {
    await _delete('/api/admin/tags/$id');
  }

  Future<Map<String, dynamic>> databaseMigrate() async {
    final res = await _post('/api/admin/database/migrate', body: {});
    final map = _map(jsonDecode(res.body));
    return map;
  }

  Future<Map<String, dynamic>> databaseSeed() async {
    final res = await _post('/api/admin/database/seed', body: {});
    final map = _map(jsonDecode(res.body));
    return map;
  }

  Future<PostListResult> listPostsByCategory({
    required int categoryId,
    int page = 1,
    int pageSize = 10,
    String? keyword,
  }) async {
    final query = {
      'page': '$page',
      'pageSize': '$pageSize',
      'categoryId': '$categoryId',
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

  Map<String, String> _headers(bool auth, {bool json = true}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (auth) {
      if (token == null || token!.isEmpty) throw UnauthorizedException('Session expired');
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  void _check(http.Response res, {required bool authFailureAsSessionExpired}) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String message = '\u8bf7\u6c42\u5931\u8d25(${res.statusCode})';
    try {
      final map = _map(jsonDecode(res.body));
      final m = map['message']?.toString();
      if (m != null && m.isNotEmpty) message = m;
    } catch (_) {}

    if ((res.statusCode == 401 || res.statusCode == 403) &&
        authFailureAsSessionExpired) {
      throw UnauthorizedException('Session expired');
    }
    throw Exception(message);
  }

  Map<String, dynamic> _map(Object? obj) {
    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) return obj.map((k, v) => MapEntry('$k', v));
    return {};
  }

  Map<String, dynamic> _normalizeMediaListMap(Map<String, dynamic> map) {
    final normalized = Map<String, dynamic>.from(map);
    final rawItems = normalized['items'];
    if (rawItems is List) {
      normalized['items'] = rawItems
          .map((e) => e is Map ? _normalizeMediaItemMap(_map(e)) : e)
          .toList();
    }
    return normalized;
  }

  Map<String, dynamic> _normalizeMediaItemMap(Map<String, dynamic> map) {
    final normalized = Map<String, dynamic>.from(map);
    normalized['url'] = _normalizeMediaUrl(normalized['url']?.toString());
    normalized['thumbnailUrl'] =
        _normalizeMediaUrl(normalized['thumbnailUrl']?.toString());
    normalized['previewUrl'] =
        _normalizeMediaUrl(normalized['previewUrl']?.toString());
    return normalized;
  }

  String _normalizeMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) {
      return '';
    }
    final parsed = Uri.tryParse(rawUrl);
    if (parsed != null && parsed.hasScheme) {
      return rawUrl;
    }
    final base = Uri.parse(baseUrl);
    final resolved = rawUrl.startsWith('/')
        ? base.replace(path: rawUrl, query: null, fragment: null)
        : base.resolve(rawUrl);
    return resolved.toString();
  }
}

class UnauthorizedException implements Exception {
  UnauthorizedException(this.message);
  final String message;
  @override
  String toString() => message;
}
