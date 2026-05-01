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
    required this.visibility,
    required this.renderType,
    required this.editorType,
    required this.aiSummaryStatus,
    required this.version,
    this.categoryId,
    this.tagIds = const [],
  });
  final int id;
  final String slug;
  final Map<String, String> title;
  final int status;
  final int visibility;
  final int renderType;
  final int editorType;
  final int aiSummaryStatus;
  final int version;
  final int? categoryId;
  final List<int> tagIds;

  String get zhTitle =>
      title['zh-cn'] ?? (title.isEmpty ? '' : title.values.first);

  String get statusText =>
      status == 0 ? 'Draft' : (status == 1 ? 'Published' : (status == 2
          ? 'Archived'
          : 'Unknown'));
  String get renderTypeText => postRenderTypeText(renderType);

  String get visibilityText =>
      visibility == 0 ? 'Public' : (visibility == 1 ? 'Private' : (visibility ==
          2
          ? 'Protected'
          : 'Unknown'));

  factory PostItem.fromMap(Map<String, dynamic> map) {
    return PostItem(
      id: toInt(map['id']) ?? 0,
      slug: map['slug']?.toString() ?? '',
      title: toStringMap(map['title']),
      status: toInt(map['status']) ?? 0,
      visibility: toInt(map['visibility']) ?? 0,
      renderType: toInt(map['renderType']) ?? 0,
      editorType: toInt(map['editorType']) ?? 0,
      aiSummaryStatus: toInt(map['aiSummaryStatus']) ?? 0,
      version: toInt(map['version']) ?? 0,
      categoryId: toInt(map['categoryId']),
      tagIds: (asDynamicList(map['tagIds']) ?? [])
          .map((e) => toInt(e) ?? 0)
          .where((id) => id > 0)
          .toList(),
    );
  }
}

class PostDetail {
  PostDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.aiSummary,
    required this.contentMarkdown,
    this.contentBlocks,
    this.tutorialLevelDefs,
    required this.status,
    required this.visibility,
    required this.renderType,
    required this.editorType,
    required this.aiSummaryStatus,
    required this.currentRevisionNumber,
    required this.version,
    this.categoryId,
    this.tagIds = const [],
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String slug;
  final Map<String, String> title;
  final Map<String, String> summary;
  final Map<String, String> aiSummary;
  final Map<String, String> contentMarkdown;
  final Map<String, List<TutorialBlock>>? contentBlocks;
  final List<TutorialLevelDef>? tutorialLevelDefs;
  final int status;
  final int visibility;
  final int renderType;
  final int editorType;
  final int aiSummaryStatus;
  final int currentRevisionNumber;
  final int version;
  final int? categoryId;
  final List<int> tagIds;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PostDetail.fromMap(Map<String, dynamic> map) {
    return PostDetail(
      id: toInt(map['id']) ?? 0,
      slug: map['slug']?.toString() ?? '',
      title: toStringMap(map['title']),
      summary: toStringMap(map['summary']),
      aiSummary: toStringMap(map['aiSummary']),
      contentMarkdown: toStringMap(map['contentMarkdown']),
      contentBlocks: _parseContentBlocks(map['contentBlocks']),
      tutorialLevelDefs: _parseTutorialLevelDefs(map['tutorialLevelDefs']),
      status: toInt(map['status']) ?? 0,
      visibility: toInt(map['visibility']) ?? 0,
      renderType: toInt(map['renderType']) ?? 0,
      editorType: toInt(map['editorType']) ?? 0,
      aiSummaryStatus: toInt(map['aiSummaryStatus']) ?? 0,
      currentRevisionNumber: toInt(map['currentRevisionNumber']) ?? 0,
      version: toInt(map['version']) ?? 0,
      categoryId: toInt(map['categoryId']),
      tagIds: (asDynamicList(map['tagIds']) ?? [])
          .map((e) => toInt(e) ?? 0)
          .where((id) => id > 0)
          .toList(),
      publishedAt: parseDate(map['publishedAt']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

class PostRevisionItem {
  PostRevisionItem({
    required this.id,
    required this.revisionNumber,
    required this.title,
    required this.editorType,
    this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  final int id;
  final int revisionNumber;
  final Map<String, String> title;
  final int editorType;
  final int? createdBy;
  final String createdByName;
  final DateTime createdAt;

  String get zhTitle =>
      title['zh-cn'] ?? (title.isEmpty ? '' : title.values.first);

  factory PostRevisionItem.fromMap(Map<String, dynamic> map) {
    return PostRevisionItem(
      id: toInt(map['id']) ?? 0,
      revisionNumber: toInt(map['revisionNumber']) ?? 0,
      title: toStringMap(map['title']),
      editorType: toInt(map['editorType']) ?? 0,
      createdBy: toInt(map['createdBy']),
      createdByName: map['createdByName']?.toString() ?? '',
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
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
    this.contentBlocks,
    this.tutorialLevelDefs,
    required this.status,
    required this.visibility,
    required this.renderType,
    required this.editorType,
    required this.aiSummaryStatus,
    required this.version,
    this.categoryId,
    this.tagIds = const [],
  });

  final String slug;
  final Map<String, String> title;
  final Map<String, String> summary;
  final Map<String, String> aiSummary;
  final Map<String, String> contentMarkdown;
  final Map<String, List<TutorialBlock>>? contentBlocks;
  final List<TutorialLevelDef>? tutorialLevelDefs;
  final int status;
  final int visibility;
  final int renderType;
  final int editorType;
  final int aiSummaryStatus;
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
      if (contentBlocks != null) 'contentBlocks': _blocksToJson(contentBlocks!),
      if (tutorialLevelDefs != null) 'tutorialLevelDefs': tutorialLevelDefs!.map((e) => e.toJson()).toList(),
      'status': status,
      'visibility': visibility,
      'renderType': renderType,
      'editorType': editorType,
      'aiSummaryStatus': aiSummaryStatus,
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
      if (contentBlocks != null) 'contentBlocks': _blocksToJson(contentBlocks!),
      if (tutorialLevelDefs != null) 'tutorialLevelDefs': tutorialLevelDefs!.map((e) => e.toJson()).toList(),
      'status': status,
      'visibility': visibility,
      'renderType': renderType,
      'editorType': editorType,
      'aiSummaryStatus': aiSummaryStatus,
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
      aiSummaryStatus: aiSummaryStatus,
      version: version ?? this.version,
      categoryId: categoryId ?? this.categoryId,
      tagIds: tagIds ?? this.tagIds,
    );
  }
}

String postRenderTypeText(int renderType) {
  switch (renderType) {
    case 0:
      return 'Markdown (Retired)';
    case 1:
      return 'HTML (Retired)';
    case 2:
      return 'Vditor (Retired)';
    case 3:
      return 'V Builder (Retired)';
    case 4:
      return 'Gutenberg (Retired)';
    case 5:
      return 'Quill (Retired)';
    case 6:
      return 'Markdown+';
    case 7:
      return 'Tutorial Block';
    default:
      return 'Unknown';
  }
}

class TutorialBlock {
  TutorialBlock({
    required this.type,
    this.level,
    this.data,
    this.children,
  });

  final String type;
  final int? level;
  final Map<String, dynamic>? data;
  final List<TutorialBlock>? children;

  factory TutorialBlock.fromMap(Map<String, dynamic> map) {
    return TutorialBlock(
      type: map['type']?.toString() ?? 'p',
      level: toInt(map['level']),
      data: map['data'] as Map<String, dynamic>?,
      children: (asDynamicList(map['children']))
          ?.map((e) => TutorialBlock.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (level != null) 'level': level,
      if (data != null) 'data': data,
      if (children != null) 'children': children!.map((e) => e.toJson()).toList(),
    };
  }
}

class TutorialLevelDef {
  TutorialLevelDef({
    required this.level,
    required this.name,
    this.color,
  });

  final int level;
  final String name;
  final String? color;

  factory TutorialLevelDef.fromMap(Map<String, dynamic> map) {
    return TutorialLevelDef(
      level: toInt(map['level']) ?? 0,
      name: map['name']?.toString() ?? '',
      color: map['color']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'name': name,
      if (color != null) 'color': color,
    };
  }
}

Map<String, List<TutorialBlock>>? _parseContentBlocks(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value.map((k, v) {
      final list = asDynamicList(v)?.map((e) => TutorialBlock.fromMap(e as Map<String, dynamic>)).toList() ?? [];
      return MapEntry(k, list);
    });
  }
  return null;
}

List<TutorialLevelDef>? _parseTutorialLevelDefs(dynamic value) {
  return asDynamicList(value)?.map((e) => TutorialLevelDef.fromMap(e as Map<String, dynamic>)).toList();
}

Map<String, dynamic> _blocksToJson(Map<String, List<TutorialBlock>> blocks) {
  return blocks.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()));
}

Map<String, String> toStringMap(Object? value) {
  if (value is Map<String, String>) return value;
  if (value is Map) return value.map((k, v) => MapEntry('$k', '${v ?? ''}'));
  return {};
}

class AiProviderConfig {
  AiProviderConfig({
    required this.id,
    required this.type,
    required this.name,
    required this.provider,
    required this.enabled,
    this.endpoint,
    this.model,
    this.apiKey,
    this.config,
    this.updatedAt,
  });

  final int id;
  final String type;
  final String name;
  final String provider;
  final bool enabled;
  final String? endpoint;
  final String? model;
  final String? apiKey;
  final String? config;
  final DateTime? updatedAt;

  AiProviderConfig copyWith({
    int? id,
    String? type,
    String? name,
    String? provider,
    bool? enabled,
    String? endpoint,
    String? model,
    String? apiKey,
    String? config,
    DateTime? updatedAt,
  }) {
    return AiProviderConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      enabled: enabled ?? this.enabled,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      config: config ?? this.config,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AiProviderConfig.fromMap(Map<String, dynamic> map) {
    return AiProviderConfig(
      id: toInt(map['id']) ?? 0,
      type: map['type']?.toString() ?? 'PROVIDER',
      name: map['name']?.toString() ?? '',
      provider: map['provider']?.toString() ?? '',
      enabled: toBool(map['enabled']) ?? false,
      endpoint: map['endpoint']?.toString(),
      model: map['model']?.toString(),
      apiKey: map['apiKey']?.toString(),
      config: map['config']?.toString(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AiProviderConfig &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AiProviderConfigUpdateRequest {
  AiProviderConfigUpdateRequest({
    required this.type,
    required this.name,
    required this.provider,
    required this.enabled,
    this.endpoint,
    this.model,
    this.apiKey,
    this.config,
  });

  final String type;
  final String name;
  final String provider;
  final bool enabled;
  final String? endpoint;
  final String? model;
  final String? apiKey;
  final String? config;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'type': type,
      'name': name,
      'provider': provider,
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
    if (config != null) {
      payload['config'] = config;
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
    this.nickname,
    this.phone,
    required this.roleName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.pointsBalance,
  });

  final int id;
  final String username;
  final String email;
  final String avatar;
  final String? nickname;
  final String? phone;
  final String roleName;
  final int status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? pointsBalance;

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
      nickname: map['nickname']?.toString(),
      phone: map['phone']?.toString(),
      roleName: map['roleName']?.toString() ?? '',
      status: statusInt,
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now(),
      pointsBalance: toInt(map['pointsBalance']),
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
    this.postCount = 0,
  });

  final int id;
  final int? parentId;
  final String slug;
  final Map<String, String> name;
  final Map<String, String>? description;
  final String path;
  final DateTime createdAt;
  final int postCount;

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
      postCount: toInt(map['postCount']) ?? 0,
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
    this.postCount = 0,
  });

  final int id;
  final String slug;
  final Map<String, String> name;
  final Map<String, String>? description;
  final DateTime createdAt;
  final int postCount;

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
      postCount: toInt(map['postCount']) ?? 0,
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

class CategoryTreeNode {
  CategoryTreeNode({
    required this.category,
    required this.children,
    required this.posts,
    this.isLoading = false,
    this.isExpanded = false,
    this.page = 1,
    this.total = 0,
  });

  final CategoryItem category;
  final List<CategoryTreeNode> children;
  final List<PostItem> posts;
  final bool isLoading;
  final bool isExpanded;
  final int page;
  final int total;

  CategoryTreeNode copyWith({
    List<CategoryTreeNode>? children,
    List<PostItem>? posts,
    bool? isLoading,
    bool? isExpanded,
    int? page,
    int? total,
  }) {
    return CategoryTreeNode(
      category: category,
      children: children ?? this.children,
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isExpanded: isExpanded ?? this.isExpanded,
      page: page ?? this.page,
      total: total ?? this.total,
    );
  }

  factory CategoryTreeNode.fromCategory(CategoryItem category) {
    return CategoryTreeNode(
      category: category,
      children: [],
      posts: [],
      isLoading: false,
      isExpanded: false,
      page: 1,
      total: 0,
    );
  }
}

class SystemSetting {
  SystemSetting({
    required this.id,
    required this.configKey,
    required this.configValue,
    required this.configType,
    required this.groupName,
    required this.uiSchema,
    this.description,
    required this.version,
    required this.isFrozen,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String configKey;
  final dynamic configValue;
  final String configType;
  final String groupName;
  final UISchema uiSchema;
  final String? description;
  final int version;
  final bool isFrozen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SystemSetting.fromMap(Map<String, dynamic> map) {
    return SystemSetting(
      id: toInt(map['id']) ?? 0,
      configKey: map['configKey']?.toString() ?? '',
      configValue: map['configValue'],
      configType: map['configType']?.toString() ?? 'string',
      groupName: map['groupName']?.toString() ?? 'general',
      uiSchema: UISchema.fromMap(
          map['uiSchema'] is Map ? Map<String, dynamic>.from(
              map['uiSchema'] as Map) : {}),
      description: map['description']?.toString(),
      version: toInt(map['version']) ?? 1,
      isFrozen: toBool(map['isFrozen']) ?? false,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

class UISchema {
  UISchema({
    required this.type,
    required this.fields,
  });

  final String type;
  final List<UISchemaField> fields;

  factory UISchema.fromMap(Map<String, dynamic> map) {
    return UISchema(
      type: map['type']?.toString() ?? 'object',
      fields: (asDynamicList(map['fields']) ?? [])
          .map((e) =>
          UISchemaField.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class UISchemaField {
  UISchemaField({
    required this.key,
    required this.label,
    required this.widget,
    this.required = false,
    this.options,
    this.validation,
  });

  final String key;
  final String label;
  final String widget;
  final bool required;
  final List<Map<String, dynamic>>? options;
  final Map<String, dynamic>? validation;

  factory UISchemaField.fromMap(Map<String, dynamic> map) {
    return UISchemaField(
      key: map['key']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      widget: map['widget']?.toString() ?? 'input',
      required: toBool(map['required']) ?? false,
      options: (asDynamicList(map['options']))
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      validation: map['validation'] is Map ? Map<String, dynamic>.from(
          map['validation'] as Map) : null,
    );
  }
}

class SystemSettingHistory {
  SystemSettingHistory({
    required this.id,
    required this.settingId,
    required this.configKey,
    required this.configValue,
    required this.version,
    this.operatorId,
    this.changeReason,
    this.createdAt,
  });

  final int id;
  final int settingId;
  final String configKey;
  final dynamic configValue;
  final int version;
  final int? operatorId;
  final String? changeReason;
  final DateTime? createdAt;

  factory SystemSettingHistory.fromMap(Map<String, dynamic> map) {
    return SystemSettingHistory(
      id: toInt(map['id']) ?? 0,
      settingId: toInt(map['settingId']) ?? 0,
      configKey: map['configKey']?.toString() ?? '',
      configValue: map['configValue'],
      version: toInt(map['version']) ?? 0,
      operatorId: toInt(map['operatorId']),
      changeReason: map['changeReason']?.toString(),
      createdAt: parseDate(map['createdAt']),
    );
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

// ==================== 钱包相关模型 ====================

class WalletInfo {
  WalletInfo({
    required this.id,
    required this.userId,
    required this.pointsBalance,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int userId;
  final int pointsBalance;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WalletInfo.fromMap(Map<String, dynamic> map) {
    return WalletInfo(
      id: toInt(map['id']) ?? 0,
      userId: toInt(map['userId']) ?? 0,
      pointsBalance: toInt(map['pointsBalance']) ?? 0,
      version: toInt(map['version']) ?? 0,
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }
}

class WalletTransactionItem {
  WalletTransactionItem({
    required this.id,
    required this.walletId,
    required this.userId,
    required this.changeAmount,
    required this.balanceAfter,
    required this.bizType,
    this.bizId,
    this.description,
    required this.createdAt,
  });

  final int id;
  final int walletId;
  final int userId;
  final int changeAmount;
  final int balanceAfter;
  final String bizType;
  final int? bizId;
  final String? description;
  final DateTime createdAt;

  String get bizTypeText => _bizTypeText(bizType);

  factory WalletTransactionItem.fromMap(Map<String, dynamic> map) {
    return WalletTransactionItem(
      id: toInt(map['id']) ?? 0,
      walletId: toInt(map['walletId']) ?? 0,
      userId: toInt(map['userId']) ?? 0,
      changeAmount: toInt(map['changeAmount']) ?? 0,
      balanceAfter: toInt(map['balanceAfter']) ?? 0,
      bizType: map['bizType']?.toString() ?? '',
      bizId: toInt(map['bizId']),
      description: map['description']?.toString(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }
}

class WalletTransactionHistory {
  WalletTransactionHistory({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<WalletTransactionItem> items;
  final int total;
  final int page;
  final int pageSize;

  factory WalletTransactionHistory.fromMap(Map<String, dynamic> map) {
    final list = (map['items'] as List<dynamic>?) ?? [];
    return WalletTransactionHistory(
      items: list.map((e) =>
          WalletTransactionItem.fromMap(e as Map<String, dynamic>)).toList(),
      total: toInt(map['total']) ?? 0,
      page: toInt(map['page']) ?? 1,
      pageSize: toInt(map['pageSize']) ?? list.length,
    );
  }
}

String _bizTypeText(String bizType) {
  switch (bizType) {
    case 'REGISTER':
      return '注册奖励';
    case 'REWARD':
      return '奖励';
    case 'PURCHASE':
      return '消费';
    case 'ADMIN_ADJUST':
      return '管理员调整';
    case 'REFUND':
      return '退款';
    default:
      return bizType;
  }
}

// ==================== 评论相关模型 ====================

class CommentItem {
  CommentItem({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.userId,
    required this.userName,
    required this.content,
    required this.status,
    required this.auditStatus,
    required this.auditReason,
    required this.createdAt,
  });

  final int id;
  final int postId;
  final String postTitle;
  final int userId;
  final String userName;
  final String content;
  final int status;
  final int auditStatus;
  final String? auditReason;
  final DateTime createdAt;

  String get statusText {
    switch (status) {
      case 0:
        return '待审核';
      case 1:
        return '已通过';
      case 2:
        return '已驳回';
      default:
        return '未知';
    }
  }

  String get auditStatusText {
    switch (auditStatus) {
      case 0:
        return '未审核';
      case 1:
        return 'AI 审核中';
      case 2:
        return 'AI 审核通过';
      case 3:
        return 'AI 审核拒绝';
      default:
        return '未知';
    }
  }

  factory CommentItem.fromMap(Map<String, dynamic> map) {
    return CommentItem(
      id: toInt(map['id']) ?? 0,
      postId: toInt(map['postId']) ?? 0,
      postTitle: map['postTitle']?.toString() ?? '',
      userId: toInt(map['userId']) ?? 0,
      userName: map['userName']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      status: toInt(map['status']) ?? 0,
      auditStatus: toInt(map['auditStatus']) ?? 0,
      auditReason: map['auditReason']?.toString(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }
}

class CommentListResult {
  CommentListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<CommentItem> items;
  final int total;
  final int page;
  final int pageSize;

  factory CommentListResult.fromMap(Map<String, dynamic> map) {
    final list = (map['items'] as List<dynamic>?) ?? [];
    return CommentListResult(
      items: list
          .map((e) => CommentItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      total: toInt(map['total']) ?? 0,
      page: toInt(map['page']) ?? 1,
      pageSize: toInt(map['pageSize']) ?? list.length,
    );
  }
}

// ==================== 队列相关模型 ====================

class QueueInfo {
  QueueInfo({
    required this.name,
    required this.messageCount,
    required this.consumerCount,
    required this.deadLetterQueue,
    this.deadLetterMessageCount = 0,
  });

  final String name;
  final int messageCount;
  final int consumerCount;
  final String deadLetterQueue;
  final int deadLetterMessageCount;

  factory QueueInfo.fromMap(Map<String, dynamic> map) {
    return QueueInfo(
      name: map['name']?.toString() ?? '',
      messageCount: toInt(map['messageCount']) ?? 0,
      consumerCount: toInt(map['consumerCount']) ?? 0,
      deadLetterQueue: map['deadLetterQueue']?.toString() ?? '',
      deadLetterMessageCount: toInt(map['deadLetterMessageCount']) ?? 0,
    );
  }
}

// ==================== 系统监控相关模型 ====================

class SystemMonitorInfo {
  SystemMonitorInfo({
    required this.jvm,
    required this.system,
    required this.application,
    required this.health,
  });

  final JvmInfo jvm;
  final SystemInfo system;
  final ApplicationInfo application;
  final HealthInfo health;

  factory SystemMonitorInfo.fromMap(Map<String, dynamic> map) {
    return SystemMonitorInfo(
      jvm: JvmInfo.fromMap(_toMap(map['jvm'])),
      system: SystemInfo.fromMap(_toMap(map['system'])),
      application: ApplicationInfo.fromMap(_toMap(map['application'])),
      health: HealthInfo.fromMap(_toMap(map['health'])),
    );
  }

  // 安全地把任意类型转为 Map<String, dynamic>，防止类型转换崩溃
  static Map<String, dynamic> _toMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry('$k', v));
    }
    return {};
  }
}

class JvmInfo {
  JvmInfo({
    required this.memoryUsed,
    required this.memoryMax,
    required this.memoryCommitted,
    required this.threadCount,
    required this.peakThreadCount,
    required this.uptime,
  });

  final int memoryUsed;
  final int memoryMax;
  final int memoryCommitted;
  final int threadCount;
  final int peakThreadCount;
  final int uptime;

  String get memoryUsedText => _formatBytes(memoryUsed);

  String get memoryMaxText => _formatBytes(memoryMax);

  String get memoryCommittedText => _formatBytes(memoryCommitted);

  String get uptimeText => _formatDuration(uptime);

  double get memoryUsagePercent {
    if (memoryMax == 0) return 0;
    return (memoryUsed / memoryMax * 100);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  static String _formatDuration(int millis) {
    final seconds = millis ~/ 1000;
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    final days = hours ~/ 24;
    if (days > 0) return '${days}d ${hours % 24}h';
    if (hours > 0) return '${hours}h ${minutes % 60}m';
    if (minutes > 0) return '${minutes}m ${seconds % 60}s';
    return '${seconds}s';
  }

  factory JvmInfo.fromMap(Map<String, dynamic> map) {
    return JvmInfo(
      memoryUsed: toInt(map['memoryUsed']) ?? 0,
      memoryMax: toInt(map['memoryMax']) ?? 0,
      memoryCommitted: toInt(map['memoryCommitted']) ?? 0,
      threadCount: toInt(map['threadCount']) ?? 0,
      peakThreadCount: toInt(map['peakThreadCount']) ?? 0,
      uptime: toInt(map['uptime']) ?? 0,
    );
  }
}

class SystemInfo {
  SystemInfo({
    required this.cpuCount,
    required this.systemLoadAverage,
    required this.osName,
    required this.osVersion,
    required this.osArch,
  });

  final int cpuCount;
  final double systemLoadAverage;
  final String osName;
  final String osVersion;
  final String osArch;

  String get loadText {
    if (systemLoadAverage < 0) return 'N/A';
    return systemLoadAverage.toStringAsFixed(2);
  }

  factory SystemInfo.fromMap(Map<String, dynamic> map) {
    return SystemInfo(
      cpuCount: toInt(map['cpuCount']) ?? 0,
      systemLoadAverage: (map['systemLoadAverage'] is num)
          ? (map['systemLoadAverage'] as num).toDouble()
          : double.tryParse(map['systemLoadAverage']?.toString() ?? '') ?? -1,
      osName: map['osName']?.toString() ?? '',
      osVersion: map['osVersion']?.toString() ?? '',
      osArch: map['osArch']?.toString() ?? '',
    );
  }
}

class ApplicationInfo {
  ApplicationInfo({
    required this.name,
    required this.version,
    required this.startTime,
    required this.uptime,
  });

  final String name;
  final String version;
  final String startTime;
  final int uptime;

  String get uptimeText {
    final seconds = uptime ~/ 1000;
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    final days = hours ~/ 24;
    if (days > 0) return '${days}d ${hours % 24}h';
    if (hours > 0) return '${hours}h ${minutes % 60}m';
    if (minutes > 0) return '${minutes}m ${seconds % 60}s';
    return '${seconds}s';
  }

  factory ApplicationInfo.fromMap(Map<String, dynamic> map) {
    return ApplicationInfo(
      name: map['name']?.toString() ?? '',
      version: map['version']?.toString() ?? '',
      startTime: map['startTime']?.toString() ?? '',
      uptime: toInt(map['uptime']) ?? 0,
    );
  }
}

class HealthInfo {
  HealthInfo({
    required this.status,
    required this.components,
  });

  final String status;
  final Map<String, HealthComponent> components;

  bool get isHealthy => status.toUpperCase() == 'UP';

  factory HealthInfo.fromMap(Map<String, dynamic> map) {
    final comps = <String, HealthComponent>{};
    final rawComponents = map['components'];
    if (rawComponents is Map) {
      for (final entry in rawComponents.entries) {
        final componentValue = entry.value;
        if (componentValue is Map) {
          final componentMap = componentValue.map((k, v) => MapEntry('$k', v));
          comps[entry.key.toString()] = HealthComponent.fromMap(componentMap);
        }
      }
    }
    return HealthInfo(
      status: map['status']?.toString() ?? 'UNKNOWN',
      components: comps,
    );
  }
}

class HealthComponent {
  HealthComponent({
    required this.status,
    this.details,
  });

  final String status;
  final Map<String, dynamic>? details;

  bool get isHealthy => status.toUpperCase() == 'UP';

  factory HealthComponent.fromMap(Map<String, dynamic> map) {
    return HealthComponent(
      status: map['status']?.toString() ?? 'UNKNOWN',
      details: map['details'] as Map<String, dynamic>?,
    );
  }
}

class AuditLogItem {
  AuditLogItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.oldValue,
    this.newValue,
    this.extInfo,
    this.performedById,
    this.performedByUsername,
    this.createdAt,
    this.createdAtFormatted,
  });

  final int id;
  final String entityType;
  final String entityId;
  final String action;
  final dynamic oldValue;
  final dynamic newValue;
  final Map<String, dynamic>? extInfo;
  final int? performedById;
  final String? performedByUsername;
  final DateTime? createdAt;
  final String? createdAtFormatted;

  factory AuditLogItem.fromMap(Map<String, dynamic> map) {
    return AuditLogItem(
      id: toInt(map['id']) ?? 0,
      entityType: map['entityType']?.toString() ?? '',
      entityId: map['entityId']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      oldValue: map['oldValue'],
      newValue: map['newValue'],
      extInfo: (map['extInfo'] is Map) ? Map<String, dynamic>.from(
          map['extInfo'] as Map) : null,
      performedById: toInt(map['performedById']),
      performedByUsername: map['performedByUsername']?.toString(),
      createdAt: map['createdAt'] != null ? DateTime.tryParse(
          map['createdAt'].toString()) : null,
      createdAtFormatted: map['createdAtFormatted']?.toString(),
    );
  }
}


class PaginatedAuditLogResult {
  PaginatedAuditLogResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<AuditLogItem> items;
  final int total;
  final int page;
  final int pageSize;

  factory PaginatedAuditLogResult.fromMap(Map<String, dynamic> map) {
    return PaginatedAuditLogResult(
      items: (map['items'] as List?)
          ?.map((e) => AuditLogItem.fromMap(e as Map<String, dynamic>))
          .toList() ??
          [],
      total: toInt(map['total']) ?? 0,
      page: toInt(map['page']) ?? 1,
      pageSize: toInt(map['pageSize']) ?? 10,
    );
  }
}
