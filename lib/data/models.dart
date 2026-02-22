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
  String get statusText => status == 1 ? '已发布' : (status == 2 ? '归档' : '草稿');
  String get renderTypeText => postRenderTypeText(renderType);

  factory PostItem.fromMap(Map<String, dynamic> map) {
    return PostItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      slug: map['slug']?.toString() ?? '',
      title: toStringMap(map['title']),
      status: (map['status'] as num?)?.toInt() ?? 0,
      renderType: (map['renderType'] as num?)?.toInt() ?? 0,
      version: (map['version'] as num?)?.toInt() ?? 0,
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

  factory PostDetail.fromMap(Map<String, dynamic> map) {
    return PostDetail(
      id: (map['id'] as num?)?.toInt() ?? 0,
      slug: map['slug']?.toString() ?? '',
      title: toStringMap(map['title']),
      summary: toStringMap(map['summary']),
      contentMarkdown: toStringMap(map['contentMarkdown']),
      status: (map['status'] as num?)?.toInt() ?? 0,
      visibility: (map['visibility'] as num?)?.toInt() ?? 0,
      renderType: (map['renderType'] as num?)?.toInt() ?? 0,
      editorType: (map['editorType'] as num?)?.toInt() ?? 0,
      version: (map['version'] as num?)?.toInt() ?? 0,
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
    };
  }

  PostEditRequest copyWith({int? version}) {
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
    );
  }
}

String postRenderTypeText(int renderType) {
  switch (renderType) {
    case 0:
      return 'Markdown';
    case 1:
      return 'HTML';
    case 2:
      return 'Vditor';
    case 3:
      return 'V Builder';
    case 4:
      return 'Gutenberg';
    default:
      return 'Unknown($renderType)';
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
      enabled: (map['enabled'] as bool?) ?? false,
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
    final list = (map['items'] as List<dynamic>?)
            ?.map((e) => converter(toStringMap(e)))
            .toList() ??
        [];
    return PageResult(
      items: list,
      total: (map['total'] as num?)?.toInt() ?? 0,
      page: (map['page'] as num?)?.toInt() ?? 1,
      pageSize: (map['pageSize'] as num?)?.toInt() ?? list.length,
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
    return UserListItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      username: map['username']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      avatar: map['avatar']?.toString() ?? 'https://ui-avatars.com/api/?name=User',
      roleName: map['roleName']?.toString() ?? '',
      status: (map['status'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }
}

String userStatusText(int status) {
  switch (status) {
    case 1:
      return '正常';
    case 2:
      return '已封禁';
    default:
      return '未激活';
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
    final raw = map['allowedMimeTypes'] as List<dynamic>?;
    return PermissionRoleItem(
      name: map['name']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      canUpload: map['canUpload'] as bool? ?? false,
      allowedMimeTypes:
          raw?.map((e) => e?.toString() ?? '').where((value) => value.isNotEmpty).toList() ?? [],
      maxSingleUploadBytes: (map['maxSingleUploadBytes'] as num?)?.toInt(),
      maxTotalUploadBytes: (map['maxTotalUploadBytes'] as num?)?.toInt(),
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
      postId: (map['postId'] as num?)?.toInt() ?? 0,
      postSlug: map['postSlug']?.toString() ?? '',
      postTitle: map['postTitle']?.toString() ?? '',
      usageType: (map['usageType'] as num?)?.toInt() ?? 0,
      referencedAt: parseDate(map['referencedAt']) ?? DateTime.now(),
    );
  }
}

class MediaItem {
  MediaItem({
    required this.id,
    required this.storageKey,
    required this.url,
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

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    final refList = (map['references'] as List<dynamic>?)
            ?.map((e) => MediaReference.fromMap(toStringMap(e)))
            .toList() ??
        [];
    return MediaItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      storageKey: map['storageKey']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      fileName: map['fileName']?.toString() ?? '',
      mimeType: map['mimeType']?.toString() ?? '',
      size: (map['size'] as num?)?.toInt(),
      mediaType: (map['mediaType'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      uploadedBy: (map['uploadedBy'] as num?)?.toInt(),
      uploadedByName: map['uploadedByName']?.toString(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      referenced: map['referenced'] as bool? ?? false,
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
    final items = (map['items'] as List<dynamic>?)
            ?.map((e) => MediaItem.fromMap(toStringMap(e)))
            .toList() ??
        [];
    return MediaListResult(
      items: items,
      total: (map['total'] as num?)?.toInt() ?? 0,
      page: (map['page'] as num?)?.toInt() ?? 1,
      pageSize: (map['pageSize'] as num?)?.toInt() ?? items.length,
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
      postsScanned: (map['postsScanned'] as num?)?.toInt() ?? 0,
      referencesCreated: (map['referencesCreated'] as num?)?.toInt() ?? 0,
      unreferenced: (map['unreferenced'] as num?)?.toInt() ?? 0,
    );
  }
}

DateTime? parseDate(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
