import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'admin_http_client.dart';
import 'models.dart';

class AdminApiClient {
  String baseUrl = 'http://localhost:8080';
  String? token;
  VoidCallback? onSessionExpired;
  bool _sessionExpiredNotified = false;

  Future<void> install({
    required String username,
    required String email,
    required String password,
    required String siteTitle,
    required String siteSubtitle,
    required String siteDescription,
    required List<String> siteKeywords,
    required String siteAuthor,
    required String siteUrl,
  }) async {
    await _post(
      '/api/admin/install',
      auth: false,
      authFailureAsSessionExpired: false,
      body: {
        'username': username,
        'email': email,
        'password': password,
        'siteTitle': siteTitle,
        'siteSubtitle': siteSubtitle,
        'siteDescription': siteDescription,
        'siteKeywords': siteKeywords,
        'siteAuthor': siteAuthor,
        'siteUrl': siteUrl,
      },
    );
  }

  String normalizeBaseUrl(String rawBaseUrl) {
    String normalizedBaseUrl = rawBaseUrl.trim();
    while (normalizedBaseUrl.endsWith('/')) {
      normalizedBaseUrl = normalizedBaseUrl.substring(
        0,
        normalizedBaseUrl.length - 1,
      );
    }

    final parsedUri = Uri.tryParse(normalizedBaseUrl);
    if (parsedUri == null || !parsedUri.hasScheme || parsedUri.host.isEmpty) {
      return normalizedBaseUrl;
    }

    String normalizedPath = parsedUri.path;
    if (normalizedPath == '/admin' ||
        normalizedPath.startsWith('/admin/') ||
        normalizedPath.startsWith('/api/admin/')) {
      final originUri = Uri(
        scheme: parsedUri.scheme,
        host: parsedUri.host,
        port: parsedUri.hasPort ? parsedUri.port : null,
      );
      return originUri.toString();
    }

    if (parsedUri.fragment.isNotEmpty) {
      final originUri = Uri(
        scheme: parsedUri.scheme,
        host: parsedUri.host,
        port: parsedUri.hasPort ? parsedUri.port : null,
        path: normalizedPath,
      );
      return originUri.toString();
    }
    return normalizedBaseUrl;
  }

  Future<String> login({
    required String account,
    required String password,
  }) async {
    baseUrl = normalizeBaseUrl(baseUrl);
    _sessionExpiredNotified = false;
    final res = await _post(
      '/api/admin/auth/login',
      body: {'account': account, 'password': password},
      auth: false,
      authFailureAsSessionExpired: false,
    );
    final map = _map(jsonDecode(res.body));
    final t = map['token'] as String?;
    if (t == null || t.isEmpty) {
      throw Exception('Missing token in login response');
    }
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
    AiProviderConfigUpdateRequest request,
  ) async {
    final res = await _post('/api/admin/ai/providers', body: request.toJson());
    return AiProviderConfig.fromMap(_map(jsonDecode(res.body)));
  }

  Future<AiProviderConfig> updateAiProvider(
    int id,
    AiProviderConfigUpdateRequest request,
  ) async {
    final res = await _put(
      '/api/admin/ai/providers/$id',
      body: request.toJson(),
    );
    return AiProviderConfig.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> deleteAiProvider(int id) async {
    await _delete('/api/admin/ai/providers/$id');
  }

  Future<List<String>> fetchAiModels(
    AiProviderConfigUpdateRequest request,
  ) async {
    final res = await _post(
      '/api/admin/ai/providers/fetch-models',
      body: request.toJson(),
    );
    final list = (jsonDecode(res.body) as List<dynamic>? ?? []);
    return list.map((e) => e.toString()).toList();
  }

  Stream<String> testAiStream(
    int id, {
    required String prompt,
    String? systemPrompt,
    bool stream = true,
  }) async* {
    if (token == null || token!.isEmpty) {
      _notifySessionExpired();
      throw UnauthorizedException('登录已过期，请重新登录');
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
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
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
      _notifySessionExpired();
      throw UnauthorizedException('登录已过期，请重新登录');
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
      await for (final line
          in response.stream
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

  Future<PostDetail> createPost(PostEditRequest req) async {
    final res = await _post('/api/admin/posts', body: req.toCreateBody());
    return PostDetail.fromMap(_map(jsonDecode(res.body)));
  }

  Future<PostDetail> updatePost(int id, PostEditRequest req) async {
    final res = await _put('/api/admin/posts/$id', body: req.toUpdateBody());
    return PostDetail.fromMap(_map(jsonDecode(res.body)));
  }

  Future<PostTranslationResult> translatePost(
    int postId, {
    required String sourceLanguage,
    required String targetLanguage,
    required String title,
    required String summary,
    required String contentMarkdown,
  }) async {
    final res = await _post(
      '/api/admin/posts/$postId/translation',
      body: {
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'title': title,
        'summary': summary,
        'contentMarkdown': contentMarkdown,
      },
    );
    return PostTranslationResult.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> publishPost(int id, {bool sendArticleUpdate = false}) async =>
      _post(
        '/api/admin/posts/$id/publish',
        body: {'sendArticleUpdate': sendArticleUpdate},
      );

  Future<void> publishLatestDraftPost(
    int id, {
    bool sendArticleUpdate = false,
    int? channelGroupId,
    int? channelId,
  }) async => _post(
    '/api/admin/posts/$id/publish',
    body: {
      'sendArticleUpdate': sendArticleUpdate,
      'channelGroupId': channelGroupId,
      'channelId': channelId,
    },
  );

  Future<void> publishPostRevision(
    int postId,
    int revisionNumber, {
    bool sendArticleUpdate = false,
    int? channelGroupId,
    int? channelId,
  }) async => _post(
    '/api/admin/posts/$postId/revisions/$revisionNumber/publish',
    body: {
      'sendArticleUpdate': sendArticleUpdate,
      'channelGroupId': channelGroupId,
      'channelId': channelId,
    },
  );

  Future<String> issueAdminStepUp(String password) async {
    final res = await _post(
      '/api/admin/auth/step-up',
      body: {'password': password},
      authFailureAsSessionExpired: false,
    );
    final map = _map(jsonDecode(res.body));
    final stepUpToken = map['token']?.toString() ?? '';
    if (stepUpToken.isEmpty) {
      throw Exception('未取得高风险操作凭证');
    }
    return stepUpToken;
  }

  Future<List<Map<String, dynamic>>> listEmailChannels() async {
    final res = await _get('/api/admin/email-channels');
    final values = jsonDecode(res.body) as List<dynamic>;
    return values.map((value) => _map(value)).toList();
  }

  Future<void> createEmailChannel(Map<String, dynamic> values) async {
    await _post('/api/admin/email-channels', body: values);
  }

  Future<List<Map<String, dynamic>>> listEmailGroups() async {
    final res = await _get('/api/admin/email-routing/groups');
    return (jsonDecode(res.body) as List<dynamic>)
        .map((value) => _map(value))
        .toList();
  }

  Future<void> createEmailGroup(Map<String, dynamic> values) async {
    await _post('/api/admin/email-routing/groups', body: values);
  }

  Future<void> replaceEmailGroupMembers(
    int groupId,
    List<Map<String, dynamic>> members,
  ) async {
    await _put(
      '/api/admin/email-routing/groups/$groupId/members',
      body: {'members': members},
    );
  }

  Future<List<Map<String, dynamic>>> listEmailRoutes() async {
    final res = await _get('/api/admin/email-routing/routes');
    return (jsonDecode(res.body) as List<dynamic>)
        .map((value) => _map(value))
        .toList();
  }

  Future<void> updateEmailRoute(
    String scenario,
    Map<String, dynamic> values,
  ) async {
    await _put('/api/admin/email-routing/routes/$scenario', body: values);
  }

  Future<List<Map<String, dynamic>>> listEmailTemplates() async {
    final res = await _get('/api/admin/email-templates');
    return (jsonDecode(res.body) as List<dynamic>)
        .map((value) => _map(value))
        .toList();
  }

  Future<void> createEmailTemplate(Map<String, dynamic> values) async {
    await _post('/api/admin/email-templates', body: values);
  }

  Future<List<Map<String, dynamic>>> listEmailCampaigns() async {
    final res = await _get('/api/admin/email-campaigns');
    return (jsonDecode(res.body) as List<dynamic>)
        .map((value) => _map(value))
        .toList();
  }

  Future<void> createEmailCampaign(Map<String, dynamic> values) async {
    await _post('/api/admin/email-campaigns', body: values);
  }

  Future<PaginatedEmailDeliveryResult> listEmailDeliveries({
    int page = 1,
    String? status,
  }) async {
    final query = <String, String>{
      'page': '$page',
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final res = await _get('/api/admin/email-deliveries', query: query);
    return PaginatedEmailDeliveryResult.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> retryEmailDelivery(int deliveryId) async {
    await _post(
      '/api/admin/email-deliveries/$deliveryId/retry',
      body: const {},
    );
  }

  Future<int> failPendingEmailDeliveries({required String stepUpToken}) async {
    final res = await _post(
      '/api/admin/email-deliveries/fail-pending',
      body: const {},
      stepUpToken: stepUpToken,
      idempotencyKey: _newIdempotencyKey(),
    );
    final map = _map(jsonDecode(res.body));
    return (map['failedCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> testEmailChannel(
    int channelId,
    String recipientAddress, {
    required String stepUpToken,
  }) async {
    await _post(
      '/api/admin/email-channels/$channelId/test',
      body: {'recipientAddress': recipientAddress},
      stepUpToken: stepUpToken,
      idempotencyKey: _newIdempotencyKey(),
    );
  }

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
      '/api/admin/posts/$postId/revisions/$revisionNumber',
    );
    return PostDetail.fromMap(_map(jsonDecode(res.body)));
  }

  Future<PostDetail> activatePostRevision(
    int postId,
    int revisionNumber,
  ) async {
    final res = await _post(
      '/api/admin/posts/$postId/revisions/$revisionNumber/activate',
      body: const {},
    );
    return PostDetail.fromMap(_map(jsonDecode(res.body)));
  }

  Future<MediaListResult> listMedia({
    int page = 1,
    int pageSize = 20,
    bool unreferenced = false,
    bool failedOnly = false,
  }) async {
    final res = await _get(
      '/api/admin/media',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        'unreferenced': unreferenced ? 'true' : 'false',
        'failedOnly': failedOnly ? 'true' : 'false',
      },
    );
    final map = _normalizeMediaListMap(_map(jsonDecode(res.body)));
    return MediaListResult.fromMap(map);
  }

  Future<MediaItem> findMedia(String url) async {
    final res = await _get('/api/admin/media/find', query: {'url': url});
    return MediaItem.fromMap(
      _normalizeMediaItemMap(_map(jsonDecode(res.body))),
    );
  }

  Future<MediaScanResult> scanMedia() async {
    final res = await _post('/api/admin/media/scan', body: {});
    return MediaScanResult.fromMap(_map(jsonDecode(res.body)));
  }

  Future<MediaItem> retryMedia(int id) async {
    final res = await _post('/api/admin/media/$id/retry', body: {});
    return MediaItem.fromMap(
      _normalizeMediaItemMap(_map(jsonDecode(res.body))),
    );
  }

  Future<MediaItem> scanMediaVirus(int id) async {
    final res = await _post('/api/admin/media/$id/virus-scan', body: {});
    return MediaItem.fromMap(
      _normalizeMediaItemMap(_map(jsonDecode(res.body))),
    );
  }

  Future<int> batchRetryMedia() async {
    final res = await _post('/api/admin/media/batch-retry', body: {});
    final map = _map(jsonDecode(res.body));
    return (map['retriedCount'] as num?)?.toInt() ?? 0;
  }

  Future<MediaItem> getMediaItem(int id) async {
    final res = await _get('/api/admin/media/$id');
    return MediaItem.fromMap(
      _normalizeMediaItemMap(_map(jsonDecode(res.body))),
    );
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
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: contentType,
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _check(response, authFailureAsSessionExpired: true);
    return MediaItem.fromMap(
      _normalizeMediaItemMap(_map(jsonDecode(response.body))),
    );
  }

  Future<MediaUploadSession> initiateMediaUploadSession({
    required String fileName,
    required String mimeType,
    required int totalSize,
  }) async {
    final res = await _post(
      '/api/admin/media/upload/session',
      body: {
        'fileName': fileName,
        'mimeType': mimeType,
        'totalSize': totalSize,
      },
    );
    return MediaUploadSession.fromMap(_map(jsonDecode(res.body)));
  }

  Future<MediaUploadSession> getMediaUploadSession(String uploadId) async {
    final res = await _get('/api/admin/media/upload/session/$uploadId');
    return MediaUploadSession.fromMap(_map(jsonDecode(res.body)));
  }

  Future<MediaUploadSession> uploadMediaChunk({
    required String uploadId,
    required int chunkIndex,
    required Uint8List bytes,
    void Function(int sentBytes)? onChunkProgress,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/admin/media/upload/session/$uploadId/chunk/$chunkIndex',
    );
    final request = http.StreamedRequest('PUT', uri);
    request.headers.addAll(_headers(true, json: false));
    request.headers['Content-Type'] = 'application/octet-stream';
    request.contentLength = bytes.length;
    final responseFuture = request.send().timeout(const Duration(minutes: 30));
    const int transferBlockSize = 64 * 1024;
    int sent = 0;
    try {
      while (sent < bytes.length) {
        final end = (sent + transferBlockSize).clamp(0, bytes.length);
        request.sink.add(bytes.sublist(sent, end));
        sent = end;
        onChunkProgress?.call(sent);
      }
      await request.sink.close();
      final streamed = await responseFuture;
      final response = await http.Response.fromStream(streamed);
      _check(response, authFailureAsSessionExpired: true);
      return MediaUploadSession.fromMap(_map(jsonDecode(response.body)));
    } catch (_) {
      await request.sink.close();
      rethrow;
    }
  }

  Future<MediaItem> completeMediaUpload(String uploadId) async {
    final client = createAdminHttpClient();
    try {
      final uri = Uri.parse(
        '$baseUrl/api/admin/media/upload/session/$uploadId/complete',
      );
      final response = await client
          .post(
            uri,
            headers: _headers(true),
            body: jsonEncode(const <String, dynamic>{}),
          )
          .timeout(const Duration(minutes: 10));
      _check(response, authFailureAsSessionExpired: true);
      return MediaItem.fromMap(
        _normalizeMediaItemMap(_map(jsonDecode(response.body))),
      );
    } finally {
      client.close();
    }
  }

  Future<MediaItem> uploadMediaResumable({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final session = await initiateMediaUploadSession(
      fileName: fileName,
      mimeType: mimeType,
      totalSize: bytes.length,
    );
    final completedChunks = <int>{...session.uploadedChunks};
    int uploadedBytes = 0;
    for (final chunkIndex in completedChunks) {
      final start = chunkIndex * session.chunkSize;
      final end = (start + session.chunkSize).clamp(0, bytes.length);
      if (start < end) uploadedBytes += end - start;
    }
    onProgress?.call(bytes.isEmpty ? 0 : uploadedBytes / bytes.length);

    for (int chunkIndex = 0; chunkIndex < session.chunkCount; chunkIndex++) {
      if (completedChunks.contains(chunkIndex)) continue;
      final start = chunkIndex * session.chunkSize;
      final end = (start + session.chunkSize).clamp(0, bytes.length);
      final chunk = bytes.sublist(start, end);
      await uploadMediaChunk(
        uploadId: session.uploadId,
        chunkIndex: chunkIndex,
        bytes: chunk,
        onChunkProgress: (sentBytes) {
          onProgress?.call((uploadedBytes + sentBytes) / bytes.length);
        },
      );
      uploadedBytes += chunk.length;
      onProgress?.call(uploadedBytes / bytes.length);
    }
    return completeMediaUpload(session.uploadId);
  }

  Future<PageResult<UserListItem>> listUsers({
    int page = 1,
    int pageSize = 20,
    String? keyword,
  }) async {
    final res = await _get(
      '/api/admin/users',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if ((keyword?.isNotEmpty ?? false)) 'keyword': keyword!,
      },
    );
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
      '/api/admin/users/$userId/wallet/transactions',
      query: {'page': '$page', 'pageSize': '$pageSize'},
    );
    return WalletTransactionHistory.fromMap(_map(jsonDecode(res.body)));
  }

  Future<WalletInfo> adjustUserWallet(
    int userId, {
    required int newBalance,
    String? description,
  }) async {
    final res = await _post(
      '/api/admin/users/$userId/wallet/adjust',
      body: {'newBalance': newBalance, 'description': description ?? '管理员手动调整'},
    );
    return WalletInfo.fromMap(_map(jsonDecode(res.body)));
  }

  Future<List<PermissionRoleItem>> listRoles() async {
    final res = await _get('/api/admin/permissions/roles');
    final list = (jsonDecode(res.body) as List<dynamic>? ?? []);
    return list.map((e) => PermissionRoleItem.fromMap(_map(e))).toList();
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

  Future<CategoryItem> updateCategory(
    int id,
    CategoryUpdateRequest request,
  ) async {
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
    Map<String, dynamic> body,
  ) async {
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
    final query = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
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

  // ==================== Outbox API ====================

  Future<PaginatedAdminOutboxResult> listAdminOutbox({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? eventType,
    String? traceId,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      if (status != null && status.isNotEmpty) 'status': status,
      if (eventType != null && eventType.isNotEmpty) 'eventType': eventType,
      if (traceId != null && traceId.isNotEmpty) 'traceId': traceId,
    };
    final response = await _get('/api/admin/outbox', query: query);
    return PaginatedAdminOutboxResult.fromMap(_map(jsonDecode(response.body)));
  }

  Future<AdminOutboxItem> replayAdminOutbox(int id) async {
    final response = await _post('/api/admin/outbox/$id/replay', body: {});
    final map = _map(jsonDecode(response.body));
    return AdminOutboxItem.fromMap(_map(map['data']));
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
      '/api/admin/queues/${Uri.encodeComponent(queueName)}',
    );
    final map = _map(jsonDecode(res.body));
    return QueueInfo.fromMap(_map(map['data']));
  }

  Future<void> publishTestMessage(
    String queueName, {
    int? postId,
    int? commentId,
    int? priority,
    String? content,
  }) async {
    final body = <String, dynamic>{};
    if (postId != null) body['postId'] = postId;
    if (commentId != null) body['commentId'] = commentId;
    if (priority != null) body['priority'] = priority;
    if (content != null) body['content'] = content;
    await _post(
      '/api/admin/queues/${Uri.encodeComponent(queueName)}/publish',
      body: body,
    );
  }

  // ==================== 系统监控 API ====================

  Future<SystemMonitorInfo> getSystemMonitor() async {
    final res = await _get('/api/admin/system/monitor');
    return SystemMonitorInfo.fromMap(_map(jsonDecode(res.body)));
  }

  Future<AmpInfo> getAmpInfo() async {
    final res = await _get('/api/admin/system/amp');
    final map = _map(jsonDecode(res.body));
    return AmpInfo.fromMap(_map(map['data']));
  }

  Future<AmpCheckResult> checkAmpArticle({
    required String slug,
    String language = 'zh-cn',
  }) async {
    final res = await _post(
      '/api/admin/system/amp/check',
      body: {'slug': slug, 'language': language},
    );
    final map = _map(jsonDecode(res.body));
    return AmpCheckResult.fromMap(_map(map['data']));
  }

  Future<ClamAvStatus> getClamAvStatus() async {
    final res = await _get('/api/admin/system/security-services');
    final map = _map(jsonDecode(res.body));
    return ClamAvStatus.fromMap(_map(map['data']));
  }

  Future<ClamAvStatus> testClamAv() async {
    final res = await _post(
      '/api/admin/system/security-services/clamav/test',
      body: const {},
    );
    final map = _map(jsonDecode(res.body));
    return ClamAvStatus.fromMap(_map(map['data']));
  }

  Future<String> decryptError(String trackingText) async {
    final res = await _post(
      '/api/admin/system/decrypt-error',
      body: {'trackingText': trackingText},
    );
    final map = _map(jsonDecode(res.body));
    return map['decrypted']?.toString() ?? '解密失败';
  }

  // ==================== 审计日志 API ====================

  Future<PaginatedAuditLogResult> listAuditLogs({
    int page = 1,
    int pageSize = 20,
    String? entityType,
    String? action,
    String? requestId,
  }) async {
    final query = {
      'page': '$page',
      'pageSize': '$pageSize',
      if (entityType != null && entityType.isNotEmpty) 'entityType': entityType,
      if (action != null && action.isNotEmpty) 'action': action,
      if (requestId != null && requestId.isNotEmpty) 'requestId': requestId,
    };
    final res = await _get('/api/admin/audit-logs', query: query);
    return PaginatedAuditLogResult.fromMap(_map(jsonDecode(res.body)));
  }

  // ==================== 系统设置 API ====================

  Future<List<SystemSetting>> listSystemSettings({String? group}) async {
    final query = {if (group != null && group.isNotEmpty) 'group': group};
    final res = await _get('/api/admin/settings', query: query);
    final map = _map(jsonDecode(res.body));
    final list = (map['data'] as List<dynamic>? ?? []);
    return list.map((e) => SystemSetting.fromMap(_map(e))).toList();
  }

  Future<SystemSetting> updateSystemSetting(
    String key,
    dynamic value, {
    String? reason,
    String? stepUpToken,
  }) async {
    final res = await _put(
      '/api/admin/settings/$key',
      body: {'configValue': value, 'reason': reason},
      stepUpToken: stepUpToken,
      idempotencyKey: _newIdempotencyKey(),
    );
    final map = _map(jsonDecode(res.body));
    return SystemSetting.fromMap(_map(map['data']));
  }

  Future<void> confirmSystemSetting(String key, {String? stepUpToken}) async {
    await _post(
      '/api/admin/settings/$key/confirm',
      body: const {},
      stepUpToken: stepUpToken,
      idempotencyKey: _newIdempotencyKey(),
    );
  }

  Future<void> rollbackSystemSetting(String key, {String? stepUpToken}) async {
    await _post(
      '/api/admin/settings/$key/rollback',
      body: const {},
      stepUpToken: stepUpToken,
      idempotencyKey: _newIdempotencyKey(),
    );
  }

  Future<List<SystemSettingHistory>> listSystemSettingHistory(
    String key,
  ) async {
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

  Future<Map<String, dynamic>> inspectClientIp() async {
    final res = await _get('/api/admin/settings/client-ip/inspect');
    final map = _map(jsonDecode(res.body));
    return _map(map['data']);
  }

  Future<Map<String, dynamic>> simulateClientIp({
    required String remoteIp,
    required String headerValue,
  }) async {
    final res = await _post(
      '/api/admin/settings/client-ip/simulate',
      body: {'remoteIp': remoteIp, 'headerValue': headerValue},
    );
    final map = _map(jsonDecode(res.body));
    return _map(map['data']);
  }

  Future<void> applyAuditSettingValue(String key, dynamic value) async {
    await _post(
      '/api/admin/settings/apply-audit-value',
      body: {'key': key, 'value': value},
    );
  }

  Future<Map<String, dynamic>> getElasticsearchStatus() async {
    final response = await _get('/api/admin/elasticsearch/status');
    return _map(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> testElasticsearchConnection() async {
    final response = await _post(
      '/api/admin/elasticsearch/test-connection',
      body: const {},
    );
    return _map(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> repairElasticsearchLogAlias() async {
    final response = await _post(
      '/api/admin/elasticsearch/repair-log-alias',
      body: const {},
    );
    return _map(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> applyElasticsearchIndexConfiguration() async {
    final response = await _post(
      '/api/admin/elasticsearch/apply-index-configuration',
      body: const {},
    );
    return _map(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> rebuildElasticsearchIndex() async {
    final response = await _post(
      '/api/admin/elasticsearch/rebuild',
      body: const {},
    );
    return _map(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> syncElasticsearchIndex() async {
    final response = await _post(
      '/api/admin/elasticsearch/posts/reindex-all',
      body: const {},
    );
    return _map(jsonDecode(response.body));
  }

  Future<List<String>> analyzeElasticsearchText(String text) async {
    final response = await _post(
      '/api/admin/elasticsearch/analyze',
      body: {'text': text},
    );
    Map<String, dynamic> responseBody = _map(jsonDecode(response.body));
    List<dynamic> rawTokens = responseBody['tokens'] as List<dynamic>? ?? [];
    return rawTokens.map((token) => token.toString()).toList();
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

  Future<AdminLinkItem?> findArticleLink(String url) async {
    try {
      final res = await _get(
        '/api/admin/links/article-link',
        query: {'url': url},
      );
      return AdminLinkItem.fromMap(_map(jsonDecode(res.body)));
    } catch (error) {
      if (error is UnauthorizedException) {
        rethrow;
      }
      return null;
    }
  }

  Future<List<LinkReferenceItem>> listLinkReferences(int id) async {
    final res = await _get('/api/admin/links/$id/references');
    final list = jsonDecode(res.body) as List;
    return list.map((e) => LinkReferenceItem.fromMap(_map(e))).toList();
  }

  Future<void> checkLink(int id) async {
    await _post('/api/admin/links/$id/check', body: {});
  }

  Future<void> reviewLinkApplication(
    int id, {
    required bool approved,
    String? note,
  }) async {
    await _post(
      '/api/admin/links/$id/review',
      body: {
        'approved': approved,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<List<LinkMonitorLogItem>> listLinkMonitorLogs(int linkId) async {
    final res = await _get(
      '/api/admin/links/monitor-logs',
      query: {'linkId': linkId.toString(), 'page': '1', 'pageSize': '50'},
    );
    final responseBody = _map(jsonDecode(res.body));
    final items = responseBody['items'] as List? ?? [];
    return items.map((item) => LinkMonitorLogItem.fromMap(_map(item))).toList();
  }

  Future<void> deleteLink(int id) async {
    await _delete('/api/admin/links/$id');
  }

  // ==================== Region Management API ====================

  Future<List<RegionRule>> listRegionRules() async {
    final res = await _get('/api/admin/regions');
    final list = jsonDecode(res.body) as List;
    return list.map((e) => RegionRule.fromJson(_map(e))).toList();
  }

  Future<RegionRule> createRegionRule(RegionRule rule) async {
    final res = await _post('/api/admin/regions', body: rule.toJson());
    return RegionRule.fromJson(_map(jsonDecode(res.body)));
  }

  Future<RegionRule> updateRegionRule(int id, RegionRule rule) async {
    final res = await _put('/api/admin/regions/$id', body: rule.toJson());
    return RegionRule.fromJson(_map(jsonDecode(res.body)));
  }

  Future<void> deleteRegionRule(int id) async {
    await _delete('/api/admin/regions/$id');
  }

  Future<MediaItem> updateMedia(
    int id, {
    List<String>? visibilityRegions,
    List<String>? hiddenRegions,
    List<String>? syncStorageClasses,
    List<String>? skipStorageClasses,
  }) async {
    final res = await _patch(
      '/api/admin/media/$id',
      body: {
        // ignore: use_null_aware_elements
        if (visibilityRegions != null) 'visibilityRegions': visibilityRegions,
        // ignore: use_null_aware_elements
        if (hiddenRegions != null) 'hiddenRegions': hiddenRegions,
        // ignore: use_null_aware_elements
        if (syncStorageClasses != null)
          'syncStorageClasses': syncStorageClasses,
        // ignore: use_null_aware_elements
        if (skipStorageClasses != null)
          'skipStorageClasses': skipStorageClasses,
      },
    );
    return MediaItem.fromMap(
      _normalizeMediaItemMap(_map(jsonDecode(res.body))),
    );
  }

  // ==================== Storage Management API ====================

  Future<List<StorageClassItem>> listStorageClasses() async {
    final res = await _get('/api/admin/storage/classes');
    final rawList = (jsonDecode(res.body) as List<dynamic>? ?? []);
    final List<StorageClassItem> items = [];
    for (int i = 0; i < rawList.length; i++) {
      final element = rawList[i];
      final item = StorageClassItem.fromMap(_map(element));
      items.add(item);
    }
    return items;
  }

  Future<StorageClassItem> createStorageClass(StorageClassItem request) async {
    final res = await _post(
      '/api/admin/storage/classes',
      body: request.toCreateJson(),
    );
    return StorageClassItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<StorageClassItem> updateStorageClass(
    int id,
    StorageClassItem request,
  ) async {
    final res = await _put(
      '/api/admin/storage/classes/$id',
      body: request.toUpdateJson(),
    );
    return StorageClassItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<void> deleteStorageClass(int id) async {
    await _delete('/api/admin/storage/classes/$id');
  }

  Future<StorageTestResult> testStorageClass(String name) async {
    final res = await _post('/api/admin/storage/classes/test/$name', body: {});
    return StorageTestResult.fromMap(_map(jsonDecode(res.body)));
  }

  Future<StorageSyncStatus> getStorageSyncStatus({
    int page = 0,
    int size = 20,
  }) async {
    final res = await _get(
      '/api/admin/storage/sync/status',
      query: {'page': page.toString(), 'size': size.toString()},
    );
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
    ImageProcessingConfigItem request,
  ) async {
    final res = await _put(
      '/api/admin/storage/image-processing/configs',
      body: request.toJson(),
    );
    return ImageProcessingConfigItem.fromMap(_map(jsonDecode(res.body)));
  }

  Future<List<ImageProcessingMetadata>> getImageProcessingMetadata() async {
    final res = await _get(
      '/api/admin/storage/image-processing/configs/metadata',
    );
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
    final res = await _get(
      '/api/admin/storage/dead-letter',
      query: {'page': '$page', 'pageSize': '$pageSize'},
    );
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

  // ==================== Edge Nodes API ====================

  Future<List<EdgeNode>> listEdgeNodes() async {
    final res = await _get('/api/admin/edge-nodes');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => EdgeNode.fromJson(_map(e))).toList();
  }

  Future<EdgeNode> createEdgeNode(EdgeNode node, {String? nodeIp}) async {
    final res = await _post(
      '/api/admin/edge-nodes',
      body: {
        'nodeId': node.nodeId,
        'nodeName': node.name,
        'region': node.region.code,
        'connectionType': node.connectionType.name,
        'edgeGrpcPort': node.edgeGrpcPort,
        if (nodeIp != null && nodeIp.isNotEmpty) 'nodeIp': nodeIp,
      },
    );
    return EdgeNode.fromJson(_map(jsonDecode(res.body)));
  }

  Future<EdgeNode> updateEdgeNode(String nodeId, EdgeNode node) async {
    final res = await _put(
      '/api/admin/edge-nodes/$nodeId',
      body: node.toJson(),
    );
    return EdgeNode.fromJson(_map(jsonDecode(res.body)));
  }

  Future<void> deleteEdgeNode(String nodeId) async {
    await _delete('/api/admin/edge-nodes/$nodeId');
  }

  Future<void> toggleEdgeNode(String nodeId, bool enabled) async {
    await _put(
      '/api/admin/edge-nodes/$nodeId/toggle',
      query: {'enabled': '$enabled'},
    );
  }

  Future<EdgeNode> getEdgeNode(String nodeId) async {
    final res = await _get('/api/admin/edge-nodes/$nodeId');
    return EdgeNode.fromJson(_map(jsonDecode(res.body)));
  }

  Future<void> triggerEdgeNodeSync(String nodeId, {bool force = false}) async {
    await _post(
      '/api/admin/edge-nodes/$nodeId/sync',
      body: {},
      query: {'force': force.toString()},
    );
  }

  Future<EdgeSyncStatus?> getEdgeNodeSyncStatus(String nodeId) async {
    final res = await _get('/api/admin/edge-nodes/$nodeId/sync-status');
    if (res.body.isEmpty || res.body == 'null') return null;
    final map = _map(jsonDecode(res.body));
    if (map.isEmpty) return null;
    return EdgeSyncStatus.fromMap(map);
  }

  Future<EdgeNodeDataStatus> getEdgeNodeDataStatus(String nodeId) async {
    final res = await _get('/api/admin/edge-nodes/$nodeId/data-status');
    return EdgeNodeDataStatus.fromMap(_map(jsonDecode(res.body)));
  }

  Future<EdgeNodeAvailabilityHistory> getEdgeNodeAvailabilityHistory(
    String nodeId, {
    int days = 30,
  }) async {
    final res = await _get(
      '/api/admin/edge-nodes/$nodeId/availability-history?days=$days',
    );
    return EdgeNodeAvailabilityHistory.fromMap(_map(jsonDecode(res.body)));
  }

  // ==================== Node Certificate API ====================

  Future<EdgeNode> issueEdgeNodeCertificate(String nodeId) async {
    final res = await _post(
      '/api/admin/edge-nodes/$nodeId/issue-certificate',
      body: {},
    );
    return EdgeNode.fromJson(_map(jsonDecode(res.body)));
  }

  Future<Uint8List> downloadDeploymentZip(
    String nodeId, {
    String? imageReference,
    String imageVariant = 'native-micro',
  }) async {
    final uri = _deploymentZipUri(
      nodeId,
      imageReference: imageReference,
      imageVariant: imageVariant,
    );
    final res = await http.get(uri, headers: _headers(true));
    _check(res, authFailureAsSessionExpired: true);
    return res.bodyBytes;
  }

  Future<Uint8List> downloadDeploymentZipWithProgress(
    String nodeId, {
    String? imageReference,
    String imageVariant = 'native-micro',
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    final uri = _deploymentZipUri(
      nodeId,
      imageReference: imageReference,
      imageVariant: imageVariant,
    );
    final request = http.Request('GET', uri);
    request.headers.addAll(_headers(true));

    final client = http.Client();
    try {
      onStatus?.call('正在生成部署包...');
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        final errorBody = await streamedResponse.stream.bytesToString();
        final mockResponse = http.Response(
          errorBody,
          streamedResponse.statusCode,
          request: request,
        );
        _check(mockResponse, authFailureAsSessionExpired: true);
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      final bytesBuilder = BytesBuilder();
      int received = 0;

      onStatus?.call('正在下载 (0%)');

      await for (final chunk in streamedResponse.stream) {
        bytesBuilder.add(chunk);
        received = received + chunk.length;
        if (contentLength > 0 && onProgress != null) {
          double ratio = received / contentLength;
          onProgress(ratio > 1.0 ? 1.0 : ratio);
          int percent = (ratio * 100).toInt();
          onStatus?.call('正在下载 ($percent%)');
        }
      }

      onProgress?.call(1.0);
      onStatus?.call('下载完成');
      return bytesBuilder.toBytes();
    } finally {
      client.close();
    }
  }

  Uri _deploymentZipUri(
    String nodeId, {
    String? imageReference,
    required String imageVariant,
  }) {
    final queryParameters = <String, String>{'variant': imageVariant};
    if (imageReference != null && imageReference.trim().isNotEmpty) {
      queryParameters['image'] = imageReference.trim();
    }

    return Uri.parse(
      '$baseUrl/api/admin/edge-nodes/$nodeId/deployment-zip',
    ).replace(queryParameters: queryParameters);
  }

  Future<void> revokeEdgeNodeCertificate(String nodeId) async {
    await _put(
      '/api/admin/edge-nodes/$nodeId',
      body: {'certificateRevoked': true},
    );
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
    Map<String, String>? query,
    bool auth = true,
    bool authFailureAsSessionExpired = true,
    String? stepUpToken,
    String? idempotencyKey,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await http.post(
      uri,
      headers: _headers(
        auth,
        stepUpToken: stepUpToken,
        idempotencyKey: idempotencyKey,
      ),
      body: jsonEncode(body),
    );
    _check(res, authFailureAsSessionExpired: authFailureAsSessionExpired);
    return res;
  }

  Future<http.Response> _put(
    String path, {
    Map<String, dynamic> body = const {},
    Map<String, String>? query,
    String? stepUpToken,
    String? idempotencyKey,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await http.put(
      uri,
      headers: _headers(
        true,
        stepUpToken: stepUpToken,
        idempotencyKey: idempotencyKey,
      ),
      body: jsonEncode(body),
    );
    _check(res, authFailureAsSessionExpired: true);
    return res;
  }

  Future<http.Response> _patch(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.patch(
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

  Map<String, String> _headers(
    bool auth, {
    bool json = true,
    String? stepUpToken,
    String? idempotencyKey,
  }) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    if (auth) {
      if (token == null || token!.isEmpty) {
        _notifySessionExpired();
        throw UnauthorizedException('登录已过期，请重新登录');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    if (stepUpToken != null && stepUpToken.isNotEmpty) {
      headers['X-Admin-Step-Up'] = stepUpToken;
    }
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  String _newIdempotencyKey() {
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }

  void _check(http.Response res, {required bool authFailureAsSessionExpired}) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    Map<String, dynamic> responseMap = {};
    String message = '请求失败(${res.statusCode})';
    try {
      responseMap = _map(jsonDecode(res.body));
      final m = responseMap['message']?.toString();
      if (m != null && m.isNotEmpty) message = m;
    } catch (_) {}

    if (res.statusCode == 428 && responseMap['code'] == 'INSTALL_REQUIRED') {
      throw InstallationRequiredException(message);
    }

    if (res.statusCode == 401 && authFailureAsSessionExpired) {
      _notifySessionExpired();
      throw UnauthorizedException('登录已过期，请重新登录');
    }
    throw Exception(message);
  }

  void _notifySessionExpired() {
    if (_sessionExpiredNotified) {
      return;
    }

    _sessionExpiredNotified = true;
    token = null;
    if (onSessionExpired != null) {
      onSessionExpired!();
    }
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
    normalized['thumbnailUrl'] = normalizeUrl(
      normalized['thumbnailUrl']?.toString(),
    );
    normalized['previewUrl'] = normalizeUrl(
      normalized['previewUrl']?.toString(),
    );
    return normalized;
  }

  String normalizeUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
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

class InstallationRequiredException implements Exception {
  InstallationRequiredException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  UnauthorizedException(this.message);
  final String message;
  @override
  String toString() => message;
}
