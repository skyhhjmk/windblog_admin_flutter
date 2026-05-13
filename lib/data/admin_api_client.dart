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

  Future<AiProviderConfig> createAiProvider(
      AiProviderConfigUpdateRequest request,) async {
    final res = await _post('/api/admin/ai/providers', body: request.toJson());
    return AiProviderConfig.fromMap(_map(jsonDecode(res.body)));
  }

  Future<AiProviderConfig> updateAiProvider(int id,
    AiProviderConfigUpdateRequest request,
  ) async {
    final res = await _put(
        '/api/admin/ai/providers/$id', body: request.toJson());
    return AiProviderConfig.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> deleteAiProvider(int id) async {
    await _delete('/api/admin/ai/providers/$id');
  }

  Future<List<String>> fetchAiModels(
      AiProviderConfigUpdateRequest request) async {
    final res = await _post(
        '/api/admin/ai/providers/fetch-models', body: request.toJson());
    final list = (jsonDecode(res.body) as List<dynamic>? ?? []);
    return list.map((e) => e.toString()).toList();
  }

  Stream<String> testAiStream(int id,
      {required String prompt, String? systemPrompt, bool stream = true}) async* {
    if (token == null || token!.isEmpty) {
      throw UnauthorizedException('Session expired');
    }
    final uri = Uri.parse('$baseUrl/api/admin/ai/test/$id');
    final request = http.Request('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'prompt': prompt,
      'systemPrompt': systemPrompt,
      'stream': stream,
    });
    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode >= 400) {
        final body = await response.stream.bytesToString();
        throw Exception('测试失败: $body');
      }
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(
          const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith(':')) continue;

        if (trimmed.startsWith('data:')) {
          yield trimmed.substring(5).trim();
        } else {
          yield trimmed;
        }
      }
    } finally {
      client.close();
    }
  }

  Stream<Map<String, dynamic>> importStream() async* {
    if (token == null || token!.isEmpty) {
      throw UnauthorizedException('Session expired');
    }
    final uri = Uri.parse('$baseUrl/api/admin/import/stream');
    final request = http.Request('GET', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'text/event-stream';

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode >= 400) {
        final body = await response.stream.bytesToString();
        throw Exception('连接导入流失败: $body');
      }
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith(':')) continue;

        if (trimmed.startsWith('data:')) {
          final data = trimmed.substring(5).trim();
          try {
            yield jsonDecode(data) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
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

  Future<void> triggerAiSummary(int id) async =>
      _post('/api/admin/posts/$id/ai-summary/trigger', body: const {});

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
    bool failedOnly = false,
  }) async {
    final res = await _get('/api/admin/media', query: {
      'page': '$page',
      'pageSize': '$pageSize',
      'unreferenced': unreferenced ? 'true' : 'false',
      'failedOnly': failedOnly ? 'true' : 'false',
    });
    final map = _normalizeMediaListMap(_map(jsonDecode(res.body)));
    return MediaListResult.fromMap(map);
  }

  Future<MediaItem> findMedia(String url) async {
    final res = await _get('/api/admin/media/find', query: {'url': url});
    return MediaItem.fromMap(
        _normalizeMediaItemMap(_map(jsonDecode(res.body))));
  }

  Future<MediaScanResult> scanMedia() async {
    final res = await _post('/api/admin/media/scan', body: {});
    return MediaScanResult.fromMap(_map(jsonDecode(res.body)));
  }

  Future<MediaItem> retryMedia(int id) async {
    final res = await _post('/api/admin/media/$id/retry', body: {});
    return MediaItem.fromMap(
        _normalizeMediaItemMap(_map(jsonDecode(res.body))));
  }

  Future<int> batchRetryMedia() async {
    final res = await _post('/api/admin/media/batch-retry', body: {});
    final map = _map(jsonDecode(res.body));
    return (map['retriedCount'] as num?)?.toInt() ?? 0;
  }

  Future<MediaItem> getMediaItem(int id) async {
    final res = await _get('/api/admin/media/$id');
    return MediaItem.fromMap(
        _normalizeMediaItemMap(_map(jsonDecode(res.body))));
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

  Future<void> reScanCategories() async {
    await _post('/api/admin/categories/re-scan', body: const {});
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

  Future<Map<String, dynamic>> testImportConnection(
      Map<String, dynamic> body) async {
    final res = await _post('/api/admin/import/test-connection', body: body);
    return _map(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>> doImport(Map<String, dynamic> body) async {
    final res = await _post('/api/admin/import', body: body);
    return _map(jsonDecode(res.body));
  }

  // ==================== 评论管理 API ====================

  Future<CommentListResult> listComments({
    required int page,
    required int pageSize,
    String? status,
    String? keyword,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
    };
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;
    final res = await _get('/api/admin/comments', query: query);
    return CommentListResult.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> updateComment(int id, {required int status}) async {
    await _put('/api/admin/comments/$id', body: {'status': status});
  }

  Future<void> deleteComment(int id) async {
    await _delete('/api/admin/comments/$id');
  }

  Future<void> auditComment(int id) async {
    await _post('/api/admin/comments/$id/audit', body: {});
  }

  // ==================== 队列监控 API ====================

  Future<List<QueueInfo>> listQueues() async {
    final res = await _get('/api/admin/queues');
    final map = _map(jsonDecode(res.body));
    final list = (map['data'] as List<dynamic>? ?? []);
    return list.map((e) => QueueInfo.fromMap(_map(e))).toList();
  }

  Future<QueueInfo> getQueueInfo(String queueName) async {
    final res = await _get(
        '/api/admin/queues/${Uri.encodeComponent(queueName)}');
    final map = _map(jsonDecode(res.body));
    return QueueInfo.fromMap(_map(map['data']));
  }

  Future<void> publishTestMessage(String queueName,
      {int? postId, int? commentId, int? priority, String? content}) async {
    final body = <String, dynamic>{};
    if (postId != null) body['postId'] = postId;
    if (commentId != null) body['commentId'] = commentId;
    if (priority != null) body['priority'] = priority;
    if (content != null) body['content'] = content;
    await _post('/api/admin/queues/${Uri.encodeComponent(queueName)}/publish',
        body: body);
  }

  // ==================== 系统监控 API ====================

  Future<SystemMonitorInfo> getSystemMonitor() async {
    final res = await _get('/api/admin/system/monitor');
    return SystemMonitorInfo.fromMap(_map(jsonDecode(res.body)));
  }

  Future<String> decryptError(String trackingText) async {
    final res = await _post('/api/admin/system/decrypt-error', body: {
      'trackingText': trackingText,
    });
    final map = _map(jsonDecode(res.body));
    return map['decrypted']?.toString() ?? '解密失败';
  }

  // ==================== 审计日志 API ====================

  Future<PaginatedAuditLogResult> listAuditLogs({
    int page = 1,
    int pageSize = 20,
    String? entityType,
    String? action,
  }) async {
    final query = {
      'page': '$page',
      'pageSize': '$pageSize',
      if (entityType != null && entityType.isNotEmpty) 'entityType': entityType,
      if (action != null && action.isNotEmpty) 'action': action,
    };
    final res = await _get('/api/admin/audit-logs', query: query);
    return PaginatedAuditLogResult.fromMap(_map(jsonDecode(res.body)));
  }

  // ==================== 系统设置 API ====================

  Future<List<SystemSetting>> listSystemSettings({String? group}) async {
    final query = {
      if (group != null && group.isNotEmpty) 'group': group,
    };
    final res = await _get('/api/admin/settings', query: query);
    final map = _map(jsonDecode(res.body));
    final list = (map['data'] as List<dynamic>? ?? []);
    return list.map((e) => SystemSetting.fromMap(_map(e))).toList();
  }

  Future<SystemSetting> updateSystemSetting(String key, dynamic value,
      {String? reason}) async {
    final res = await _put('/api/admin/settings/$key', body: {
      'configValue': value,
      'reason': reason,
    });
    final map = _map(jsonDecode(res.body));
    return SystemSetting.fromMap(_map(map['data']));
  }

  Future<void> confirmSystemSetting(String key) async {
    await _post('/api/admin/settings/$key/confirm', body: const {});
  }

  Future<void> rollbackSystemSetting(String key) async {
    await _post('/api/admin/settings/$key/rollback', body: const {});
  }

  Future<List<SystemSettingHistory>> listSystemSettingHistory(
      String key) async {
    final res = await _get('/api/admin/settings/$key/history');
    final map = _map(jsonDecode(res.body));
    final list = (map['data'] as List<dynamic>? ?? []);
    return list.map((e) => SystemSettingHistory.fromMap(_map(e))).toList();
  }

  Future<SystemSetting> getSystemSetting(String key) async {
    final res = await _get('/api/admin/settings/$key');
    final map = _map(jsonDecode(res.body));
    return SystemSetting.fromMap(_map(map['data']));
  }

  Future<void> applyAuditSettingValue(String key, dynamic value) async {
    await _post('/api/admin/settings/apply-audit-value', body: {
      'key': key,
      'value': value,
    });
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

  // Store Items API
  Future<PageResult<StoreItem>> getStoreItems({
    int page = 1,
    int pageSize = 20,
    String? name,
    String? type,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (name != null && name.isNotEmpty) queryParams['name'] = name;
    if (type != null && type.isNotEmpty) queryParams['type'] = type;

    final res = await _get('/api/admin/store', query: queryParams);
    return PageResult<StoreItem>.fromMap(
      _map(jsonDecode(res.body)),
          (m) => StoreItem.fromMap(m),
    );
  }

  Future<StoreItem> getStoreItem(int id) async {
    final res = await _get('/api/admin/store/$id');
    return StoreItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<StoreItem> createStoreItem(StoreItemRequest request) async {
    final res = await _post('/api/admin/store', body: request.toJson());
    return StoreItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<StoreItem> updateStoreItem(int id, StoreItemRequest request) async {
    final res = await _put('/api/admin/store/$id', body: request.toJson());
    return StoreItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> deleteStoreItem(int id) async {
    await _delete('/api/admin/store/$id');
  }

  // ==================== Links API ====================

  Future<void> createLink(LinkCreateRequest request) async {
    await _post('/api/admin/links', body: request.toJson());
  }

  Future<void> updateLink(int id, LinkCreateRequest request) async {
    await _put('/api/admin/links/$id', body: request.toJson());
  }

  Future<LinkMetaResponse> parseLinkMeta(String url) async {
    final res = await _post('/api/admin/links/parse-meta', body: {'url': url});
    return LinkMetaResponse.fromMap(_map(jsonDecode(res.body)));
  }

  Future<List<AdminLinkItem>> listLinks() async {
    final res = await _get('/api/admin/links');
    final list = jsonDecode(res.body) as List;
    return list.map((e) => AdminLinkItem.fromMap(_map(e))).toList();
  }

  Future<void> deleteLink(int id) async {
    await _delete('/api/admin/links/$id');
  }

  // ==================== Storage Management API ====================

  Future<List<StorageProviderItem>> listStorageProviders() async {
    final res = await _get('/api/admin/storage/providers');
    final rawList = (jsonDecode(res.body) as List<dynamic>? ?? []);
    final List<StorageProviderItem> items = [];
    for (int i = 0; i < rawList.length; i++) {
      final element = rawList[i];
      final item = StorageProviderItem.fromMap(_map(element));
      items.add(item);
    }
    return items;
  }

  Future<StorageProviderItem> createStorageProvider(
      StorageProviderItem request) async {
    final res = await _post(
        '/api/admin/storage/providers', body: request.toCreateJson());
    return StorageProviderItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<StorageProviderItem> updateStorageProvider(int id,
      StorageProviderItem request) async {
    final res = await _put(
        '/api/admin/storage/providers/$id', body: request.toUpdateJson());
    return StorageProviderItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> deleteStorageProvider(int id) async {
    await _delete('/api/admin/storage/providers/$id');
  }

  Future<StorageProviderItem> testStorageProvider(String name) async {
    final res = await _post(
        '/api/admin/storage/providers/test/$name', body: {});
    return StorageProviderItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<StorageSyncStatus> getStorageSyncStatus(
      {int page = 0, int size = 20}) async {
    final res = await _get('/api/admin/storage/sync/status', query: {
      'page': page.toString(),
      'size': size.toString(),
    });
    return StorageSyncStatus.fromMap(_map(jsonDecode(res.body)));
  }

  Future<MediaSyncDetail> getSyncDetail(int mediaId) async {
    final res = await _get('/api/admin/storage/sync/detail/$mediaId');
    return MediaSyncDetail.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> triggerStorageSync(int mediaId) async {
    await _post('/api/admin/storage/sync/trigger/$mediaId', body: {});
  }

  Future<void> triggerBatchStorageSync() async {
    await _post('/api/admin/storage/sync/batch-trigger', body: {});
  }

  // ==================== Image Processing Config API ====================

  Future<List<ImageProcessingConfigItem>> listImageProcessingConfigs() async {
    final res = await _get('/api/admin/storage/image-processing/configs');
    final rawList = (jsonDecode(res.body) as List<dynamic>? ?? []);
    final List<ImageProcessingConfigItem> items = [];
    for (int i = 0; i < rawList.length; i++) {
      final element = rawList[i];
      final item = ImageProcessingConfigItem.fromMap(_map(element));
      items.add(item);
    }
    return items;
  }

  Future<ImageProcessingConfigItem> updateImageProcessingConfig(
      ImageProcessingConfigItem request) async {
    final res = await _put(
        '/api/admin/storage/image-processing/configs',
        body: request.toJson());
    return ImageProcessingConfigItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<List<ImageProcessingMetadata>> getImageProcessingMetadata() async {
    final res = await _get(
        '/api/admin/storage/image-processing/configs/metadata');
    final rawList = (jsonDecode(res.body) as List<dynamic>? ?? []);
    return rawList
        .map((e) => ImageProcessingMetadata.fromMap(_map(e)))
        .toList();
  }

  Future<Map<String, dynamic>> testImageProcessingTool(String testUrl) async {
    final res = await _post(testUrl, body: {});
    return _map(jsonDecode(res.body));
  }

  // ==================== Dead Letter Queue API ====================

  Future<List<DeadLetterMessageItem>> listDeadLetterMessages({
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _get('/api/admin/storage/dead-letter', query: {
      'page': '$page',
      'pageSize': '$pageSize',
    });
    final map = _map(jsonDecode(res.body));
    final rawList = (map['items'] as List<dynamic>? ?? []);
    final List<DeadLetterMessageItem> items = [];
    for (int i = 0; i < rawList.length; i++) {
      final element = rawList[i];
      final item = DeadLetterMessageItem.fromMap(_map(element));
      items.add(item);
    }
    return items;
  }

  Future<void> retryDeadLetterMessage(int id) async {
    await _post('/api/admin/storage/dead-letter/$id/retry', body: {});
  }

  Future<void> deleteDeadLetterMessage(int id) async {
    await _delete('/api/admin/storage/dead-letter/$id');
  }

  // ==================== Internal Helpers ====================

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

    String message = '请求失败(${res.statusCode})';
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
    normalized['url'] = normalizeUrl(normalized['url']?.toString());
    normalized['thumbnailUrl'] =
        normalizeUrl(normalized['thumbnailUrl']?.toString());
    normalized['previewUrl'] =
        normalizeUrl(normalized['previewUrl']?.toString());
    return normalized;
  }

  String normalizeUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl
        .trim()
        .isEmpty) {
      return '';
    }
    final trimmed = rawUrl.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return trimmed;
    }
    final base = Uri.parse(baseUrl);
    return base.resolve(trimmed).toString();
  }
}

class UnauthorizedException implements Exception {
  UnauthorizedException(this.message);
  final String message;
  @override
  String toString() => message;
}
