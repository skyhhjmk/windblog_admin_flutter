import 'dart:convert';

class AdminUser {
  AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.roleName,
  });
  final int id;
  final String username;
  final String email;
  final String roleName;
}

class PostListResult {
  PostListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<PostItem> items;
  final int total;
  final int page;
  final int pageSize;
}

class PostItem {
  PostItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.status,
    required this.renderType,
    required this.version,
  });
  final int id;
  final String slug;
  final Map<String, String> title;
  final int status;
  final int renderType;
  final int version;

  String get zhTitle =>
      title['zh-cn'] ?? (title.isEmpty ? '' : title.values.first);

  String get statusText =>
      status == 0 ? 'Draft' : (status == 1 ? 'Published' : (status == 2
          ? 'Archived'
          : 'Unknown'));
  String get renderTypeText => postRenderTypeText(renderType);

  factory PostItem.fromMap(Map<String, dynamic> map) {
    return PostItem(
      id: toInt(map['id']) ?? 0,
      slug: map['slug']?.toString() ?? '',
      title: toStringMap(map['title']),
      status: toInt(map['status']) ?? 0,
      renderType: toInt(map['renderType']) ?? 0,
      version: toInt(map['version']) ?? 0,
    );
  }
}

class PostDetail {
  PostDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.contentMarkdown,
    required this.status,
    required this.visibility,
    required this.renderType,
    required this.editorType,
    required this.version,
    this.categoryId,
    this.tagIds = const [],
  });

  final int id;
  final String slug;
  final Map<String, String> title;
  final Map<String, String> summary;
  final Map<String, String> contentMarkdown;
  final int status;
  final int visibility;
  final int renderType;
  final int editorType;
  final int version;
  final int? categoryId;
  final List<int> tagIds;

  factory PostDetail.fromMap(Map<String, dynamic> map) {
    return PostDetail(
      id: toInt(map['id']) ?? 0,
      slug: map['slug']?.toString() ?? '',
      title: toStringMap(map['title']),
      summary: toStringMap(map['summary']),
      contentMarkdown: toStringMap(map['contentMarkdown']),
      status: toInt(map['status']) ?? 0,
      visibility: toInt(map['visibility']) ?? 0,
      renderType: toInt(map['renderType']) ?? 0,
      editorType: toInt(map['editorType']) ?? 0,
      version: toInt(map['version']) ?? 0,
      categoryId: toInt(map['categoryId']),
      tagIds: (asDynamicList(map['tagIds']) ?? [])
          .map((e) => toInt(e) ?? 0)
          .where((id) => id > 0)
          .toList(),
    );
  }
}

class PostEditRequest {
  PostEditRequest({
    required this.slug,
    required this.title,
    required this.summary,
    required this.aiSummary,
    required this.contentMarkdown,
    required this.status,
    required this.visibility,
    required this.renderType,
    required this.editorType,
    required this.version,
    this.categoryId,
    this.tagIds = const [],
  });

  final String slug;
  final Map<String, String> title;
  final Map<String, String> summary;
  final Map<String, String> aiSummary;
  final Map<String, String> contentMarkdown;
  final int status;
  final int visibility;
  final int renderType;
  final int editorType;
  final int version;
  final int? categoryId;
  final List<int> tagIds;

  Map<String, dynamic> toCreateBody() {
    return {
      'slug': slug,
      'title': title,
      'summary': summary,
      'aiSummary': aiSummary,
      'contentMarkdown': contentMarkdown,
      'status': status,
      'visibility': visibility,
      'renderType': renderType,
      'editorType': editorType,
      'categoryId': categoryId,
      'tagIds': tagIds,
    };
  }

  Map<String, dynamic> toUpdateBody() {
    return {
      'slug': slug,
      'title': title,
      'summary': summary,
      'aiSummary': aiSummary,
      'contentMarkdown': contentMarkdown,
      'status': status,
      'visibility': visibility,
      'renderType': renderType,
      'editorType': editorType,
      'version': version,
      'categoryId': categoryId,
      'tagIds': tagIds,
    };
  }

  PostEditRequest copyWith({int? version, int? categoryId, List<int>? tagIds}) {
    return PostEditRequest(
      slug: slug,
      title: title,
      summary: summary,
      aiSummary: aiSummary,
      contentMarkdown: contentMarkdown,
      status: status,
      visibility: visibility,
      renderType: renderType,
      editorType: editorType,
      version: version ?? this.version,
      categoryId: categoryId ?? this.categoryId,
      tagIds: tagIds ?? this.tagIds,
    );
  }
}

String postRenderTypeText(int renderType) {
  switch (renderType) {
    case 0:
      return 'Markdown';
    case 1:
      return 'Active';
    case 2:
      return 'Disabled';
    case 3:
      return 'V Builder';
    case 4:
      return 'Gutenberg';
    default:
      return 'Unknown';
  }
}

Map<String, String> toStringMap(Object? value) {
  if (value is Map<String, String>) return value;
  if (value is Map) return value.map((k, v) => MapEntry('$k', '${v ?? ''}'));
  return {};
}

class AiProviderConfig {
  AiProviderConfig({
    required this.provider,
    required this.enabled,
    this.endpoint,
    this.model,
    this.apiKey,
    this.updatedAt,
  });

  final String provider;
  final bool enabled;
  final String? endpoint;
  final String? model;
  final String? apiKey;
  final DateTime? updatedAt;

  AiProviderConfig copyWith({
    bool? enabled,
    String? endpoint,
    String? model,
    String? apiKey,
    DateTime? updatedAt,
  }) {
    return AiProviderConfig(
      provider: provider,
      enabled: enabled ?? this.enabled,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AiProviderConfig.fromMap(Map<String, dynamic> map) {
    return AiProviderConfig(
      provider: map['provider']?.toString() ?? '',
      enabled: toBool(map['enabled']) ?? false,
      endpoint: map['endpoint']?.toString(),
      model: map['model']?.toString(),
      apiKey: map['apiKey']?.toString(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }
}

class AiProviderConfigUpdateRequest {
  AiProviderConfigUpdateRequest({
    required this.enabled,
    this.endpoint,
    this.model,
    this.apiKey,
  });

  final bool enabled;
  final String? endpoint;
  final String? model;
  final String? apiKey;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'enabled': enabled,
    };
    if (endpoint != null) {
      payload['endpoint'] = endpoint;
    }
    if (model != null) {
      payload['model'] = model;
    }
    if (apiKey != null) {
      payload['apiKey'] = apiKey;
    }
    return payload;
  }
}

class PageResult<T> {
  PageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  factory PageResult.fromMap(
    Map<String, dynamic> map,
    T Function(Map<String, dynamic>) converter,
  ) {
    final list = asDynamicList(map['items'])
            ?.map((e) => converter(toStringMap(e)))
            .toList() ??
        [];
    return PageResult(
      items: list,
      total: toInt(map['total']) ?? 0,
      page: toInt(map['page']) ?? 1,
      pageSize: toInt(map['pageSize']) ?? list.length,
    );
  }
}

class UserListItem {
  UserListItem({
    required this.id,
    required this.username,
    required this.email,
    required this.avatar,
    required this.roleName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String username;
  final String email;
  final String avatar;
  final String roleName;
  final int status;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get statusText => userStatusText(status);

  factory UserListItem.fromMap(Map<String, dynamic> map) {
    final statusValue = map['status'];
    int statusInt = 0;

    // 更详细地处理 status 值的各种可能类型
    if (statusValue != null) {
      if (statusValue is int) {
        statusInt = statusValue;
      } else if (statusValue is num) {
        statusInt = statusValue.toInt();
      } else if (statusValue is String) {
        statusInt = int.tryParse(statusValue) ?? 0;
      } else {
        // 尝试将其转换为字符串再解析
        try {
          statusInt = int.tryParse(statusValue.toString()) ?? 0;
        } catch (e) {
          statusInt = 0;
        }
      }
    }
    
    return UserListItem(
      id: toInt(map['id']) ?? 0,
      username: map['username']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      avatar: map['avatar']?.toString() ?? 'https://ui-avatars.com/api/?name=User',
      roleName: map['roleName']?.toString() ?? '',
      status: statusInt,
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }
}

String userStatusText(int status) {
  // 使用 if-else 而不是 switch，确保正确匹配 int 值
  if (status == 1) {
    return 'Active';
  } else if (status == 0) {
    return 'Disabled';
  } else if (status == 2) {
    return 'Locked';
  } else {
    return 'Unknown ($status)';
  }
}

class PermissionRoleItem {
  PermissionRoleItem({
    required this.name,
    required this.displayName,
    required this.description,
    required this.canUpload,
    required this.allowedMimeTypes,
    this.maxSingleUploadBytes,
    this.maxTotalUploadBytes,
    this.createdAt,
    this.updatedAt,
  });

  final String name;
  final String displayName;
  final String description;
  final bool canUpload;
  final List<String> allowedMimeTypes;
  final int? maxSingleUploadBytes;
  final int? maxTotalUploadBytes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PermissionRoleItem.fromMap(Map<String, dynamic> map) {
    final raw = asDynamicList(map['allowedMimeTypes']);
    return PermissionRoleItem(
      name: map['name']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      canUpload: toBool(map['canUpload']) ?? false,
      allowedMimeTypes:
          raw?.map((e) => e?.toString() ?? '').where((value) => value.isNotEmpty).toList() ?? [],
      maxSingleUploadBytes: toInt(map['maxSingleUploadBytes']),
      maxTotalUploadBytes: toInt(map['maxTotalUploadBytes']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

class PermissionRoleRequest {
  PermissionRoleRequest({
    this.name,
    required this.displayName,
    required this.description,
    required this.canUpload,
    required this.allowedMimeTypes,
    this.maxSingleUploadBytes,
    this.maxTotalUploadBytes,
  });

  final String? name;
  final String displayName;
  final String description;
  final bool canUpload;
  final List<String> allowedMimeTypes;
  final int? maxSingleUploadBytes;
  final int? maxTotalUploadBytes;

  Map<String, dynamic> toCreateJson() {
    final payload = _basePayload();
    if (name != null) {
      payload['name'] = name;
    }
    return payload;
  }

  Map<String, dynamic> toUpdateJson() {
    return _basePayload();
  }

  Map<String, dynamic> _basePayload() {
    return {
      'displayName': displayName,
      'description': description,
      'canUpload': canUpload,
      'allowedMimeTypes': allowedMimeTypes,
      if (maxSingleUploadBytes != null) 'maxSingleUploadBytes': maxSingleUploadBytes,
      if (maxTotalUploadBytes != null) 'maxTotalUploadBytes': maxTotalUploadBytes,
    };
  }
}

class MediaReference {
  MediaReference({
    required this.postId,
    required this.postSlug,
    required this.postTitle,
    required this.usageType,
    required this.referencedAt,
  });

  final int postId;
  final String postSlug;
  final String postTitle;
  final int usageType;
  final DateTime referencedAt;

  factory MediaReference.fromMap(Map<String, dynamic> map) {
    return MediaReference(
      postId: toInt(map['postId']) ?? 0,
      postSlug: map['postSlug']?.toString() ?? '',
      postTitle: map['postTitle']?.toString() ?? '',
      usageType: toInt(map['usageType']) ?? 0,
      referencedAt: parseDate(map['referencedAt']) ?? DateTime.now(),
    );
  }
}

class MediaItem {
  MediaItem({
    required this.id,
    required this.storageKey,
    required this.url,
    this.thumbnailUrl,
    this.previewUrl,
    required this.requiresManualOriginal,
    required this.fileName,
    required this.mimeType,
    required this.size,
    required this.mediaType,
    this.width,
    this.height,
    this.uploadedBy,
    this.uploadedByName,
    required this.createdAt,
    required this.referenced,
    required this.references,
  });

  final int id;
  final String storageKey;
  final String url;
  final String? thumbnailUrl;
  final String? previewUrl;
  final bool requiresManualOriginal;
  final String fileName;
  final String mimeType;
  final int? size;
  final int mediaType;
  final int? width;
  final int? height;
  final int? uploadedBy;
  final String? uploadedByName;
  final DateTime createdAt;
  final bool referenced;
  final List<MediaReference> references;

  bool get isImage => mimeType.toLowerCase().startsWith('image/');

  bool get isAudio => mimeType.toLowerCase().startsWith('audio/');

  bool get isVideo => mimeType.toLowerCase().startsWith('video/');

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    final refList = asDynamicList(map['references'])
            ?.map((e) => MediaReference.fromMap(toStringMap(e)))
            .toList() ??
        [];
    return MediaItem(
      id: toInt(map['id']) ?? 0,
      storageKey: map['storageKey']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      thumbnailUrl: map['thumbnailUrl']?.toString(),
      previewUrl: map['previewUrl']?.toString(),
      requiresManualOriginal: toBool(map['requiresManualOriginal']) ?? false,
      fileName: map['fileName']?.toString() ?? '',
      mimeType: map['mimeType']?.toString() ?? '',
      size: toInt(map['size']),
      mediaType: toInt(map['mediaType']) ?? 0,
      width: toInt(map['width']),
      height: toInt(map['height']),
      uploadedBy: toInt(map['uploadedBy']),
      uploadedByName: map['uploadedByName']?.toString(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      referenced: toBool(map['referenced']) ?? false,
      references: refList,
    );
  }
}

class MediaListResult {
  MediaListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<MediaItem> items;
  final int total;
  final int page;
  final int pageSize;

  factory MediaListResult.fromMap(Map<String, dynamic> map) {
    final items = asDynamicList(map['items'])
            ?.map((e) => MediaItem.fromMap(toStringMap(e)))
            .toList() ??
        [];
    return MediaListResult(
      items: items,
      total: toInt(map['total']) ?? 0,
      page: toInt(map['page']) ?? 1,
      pageSize: toInt(map['pageSize']) ?? items.length,
    );
  }
}

class MediaScanResult {
  MediaScanResult({
    required this.postsScanned,
    required this.referencesCreated,
    required this.unreferenced,
  });

  final int postsScanned;
  final int referencesCreated;
  final int unreferenced;

  factory MediaScanResult.fromMap(Map<String, dynamic> map) {
    return MediaScanResult(
      postsScanned: toInt(map['postsScanned']) ?? 0,
      referencesCreated: toInt(map['referencesCreated']) ?? 0,
      unreferenced: toInt(map['unreferenced']) ?? 0,
    );
  }
}

class CategoryItem {
  CategoryItem({
    required this.id,
    this.parentId,
    required this.slug,
    required this.name,
    this.description,
    required this.path,
    required this.createdAt,
  });

  final int id;
  final int? parentId;
  final String slug;
  final Map<String, String> name;
  final Map<String, String>? description;
  final String path;
  final DateTime createdAt;

  String get zhName => name['zh-cn'] ?? (name.isEmpty ? '' : name.values.first);

  String get displayName => zhName.isEmpty ? slug : zhName;

  factory CategoryItem.fromMap(Map<String, dynamic> map) {
    return CategoryItem(
      id: toInt(map['id']) ?? 0,
      parentId: toInt(map['parentId']),
      slug: map['slug']?.toString() ?? '',
      name: toStringMap(map['name']),
      description: map['description'] != null
          ? toStringMap(map['description'])
          : null,
      path: map['path']?.toString() ?? '',
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }
}

class CategoryCreateRequest {
  CategoryCreateRequest({
    this.parentId,
    required this.slug,
    required this.name,
    this.description,
  });

  final int? parentId;
  final String slug;
  final Map<String, String> name;
  final Map<String, String>? description;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'slug': slug,
      'name': name,
    };
    if (parentId != null) {
      payload['parentId'] = parentId;
    }
    if (description != null) {
      payload['description'] = description;
    }
    return payload;
  }
}

class CategoryUpdateRequest {
  CategoryUpdateRequest({
    this.parentId,
    required this.slug,
    required this.name,
    this.description,
  });

  final int? parentId;
  final String slug;
  final Map<String, String> name;
  final Map<String, String>? description;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'slug': slug,
      'name': name,
    };
    if (parentId != null) {
      payload['parentId'] = parentId;
    }
    if (description != null) {
      payload['description'] = description;
    }
    return payload;
  }
}

class TagItem {
  TagItem({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.createdAt,
  });

  final int id;
  final String slug;
  final Map<String, String> name;
  final Map<String, String>? description;
  final DateTime createdAt;

  String get zhName => name['zh-cn'] ?? (name.isEmpty ? '' : name.values.first);

  String get displayName => zhName.isEmpty ? slug : zhName;

  factory TagItem.fromMap(Map<String, dynamic> map) {
    return TagItem(
      id: toInt(map['id']) ?? 0,
      slug: map['slug']?.toString() ?? '',
      name: toStringMap(map['name']),
      description: map['description'] != null
          ? toStringMap(map['description'])
          : null,
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }
}

class TagCreateRequest {
  TagCreateRequest({
    required this.slug,
    required this.name,
    this.description,
  });

  final String slug;
  final Map<String, String> name;
  final Map<String, String>? description;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'slug': slug,
      'name': name,
    };
    if (description != null) {
      payload['description'] = description;
    }
    return payload;
  }
}

class TagUpdateRequest {
  TagUpdateRequest({
    required this.slug,
    required this.name,
    this.description,
  });

  final String slug;
  final Map<String, String> name;
  final Map<String, String>? description;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'slug': slug,
      'name': name,
    };
    if (description != null) {
      payload['description'] = description;
    }
    return payload;
  }
}

int? toInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    return int.tryParse(text) ?? double.tryParse(text)?.toInt();
  }
  return int.tryParse(value.toString());
}

bool? toBool(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) {
      return null;
    }
    if (text == 'true' || text == '1' || text == 'yes') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      return false;
    }
  }
  return null;
}

DateTime? parseDate(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

List<dynamic>? asDynamicList(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is List<dynamic>) {
    return value;
  }
  if (value is List) {
    return value.cast<dynamic>();
  }
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.startsWith('[') && text.endsWith(']')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List<dynamic>) {
          return decoded;
        }
        if (decoded is List) {
          return decoded.cast<dynamic>();
        }
      } catch (_) {}
    }
  }
  return null;
}
