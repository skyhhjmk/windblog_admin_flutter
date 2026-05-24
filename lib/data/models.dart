import 'dart:convert';

enum BlogRegion {
  global('global', 'Global (全局)'),
  cn('cn', 'CN (China)'),
  us('us', 'US (United States)'),
  eu('eu', 'EU (Europe)'),
  jp('jp', 'JP (Japan)'),
  hk('hk', 'HK (Hong Kong)'),
  tw('tw', 'TW (Taiwan)');

  final String code;
  final String displayName;

  const BlogRegion(this.code, this.displayName);

  static BlogRegion fromCode(String code) {
    return values.firstWhere(
          (r) => r.code == code,
      orElse: () => BlogRegion.global,
    );
  }
}

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
    this.userName,
    this.tagIds = const [],
    required this.publishedRevisionNumber,
    required this.hasPublishedRevision,
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
  final String? userName;
  final List<int> tagIds;
  final int publishedRevisionNumber;
  final bool hasPublishedRevision;

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
      userName: map['userName']?.toString(),
      tagIds: (asDynamicList(map['tagIds']) ?? [])
          .map((e) => toInt(e) ?? 0)
          .where((id) => id > 0)
          .toList(),
      publishedRevisionNumber: toInt(map['publishedRevisionNumber']) ?? 0,
      hasPublishedRevision: map['hasPublishedRevision'] == true,
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
    this.password,
    required this.hasPassword,
    required this.renderType,
    required this.editorType,
    required this.aiSummaryStatus,
    required this.currentRevisionNumber,
    required this.version,
    this.categoryId,
    this.userName,
    this.tagIds = const [],
    this.visibilityRegions = const [],
    this.pointsPrice,
    this.freeLines,
    required this.publishedRevisionNumber,
    required this.hasPublishedRevision,
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
  final String? password;
  final bool hasPassword;
  final int renderType;
  final int editorType;
  final int aiSummaryStatus;
  final int currentRevisionNumber;
  final int version;
  final int? categoryId;
  final String? userName;
  final List<int> tagIds;
  final List<String> visibilityRegions;
  final int? pointsPrice;
  final int? freeLines;
  final int publishedRevisionNumber;
  final bool hasPublishedRevision;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get zhTitle =>
      title['zh-cn'] ?? (title.isEmpty ? '' : title.values.first);

  String get zhSummary =>
      summary['zh-cn'] ?? (summary.isEmpty ? '' : summary.values.first);

  String get zhContent =>
      contentMarkdown['zh-cn'] ??
          (contentMarkdown.isEmpty ? '' : contentMarkdown.values.first);

  String get zhAiSummary =>
      aiSummary['zh-cn'] ?? (aiSummary.isEmpty ? '' : aiSummary.values.first);


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
      password: map['password']?.toString(),
      hasPassword: map['hasPassword'] == true,
      renderType: toInt(map['renderType']) ?? 0,
      editorType: toInt(map['editorType']) ?? 0,
      aiSummaryStatus: toInt(map['aiSummaryStatus']) ?? 0,
      currentRevisionNumber: toInt(map['currentRevisionNumber']) ?? 0,
      version: toInt(map['version']) ?? 0,
      categoryId: toInt(map['categoryId']),
      userName: map['userName']?.toString(),
      tagIds: (asDynamicList(map['tagIds']) ?? [])
          .map((e) => toInt(e) ?? 0)
          .where((id) => id > 0)
          .toList(),
      visibilityRegions: toStringList(map['visibilityRegions']) ?? [],
      pointsPrice: toInt(map['pointsPrice']),
      freeLines: toInt(map['freeLines']),
      publishedRevisionNumber: toInt(map['publishedRevisionNumber']) ?? 0,
      hasPublishedRevision: map['hasPublishedRevision'] == true,
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
    required this.isPublishedRevision,
    required this.createdAt,
  });

  final int id;
  final int revisionNumber;
  final Map<String, String> title;
  final int editorType;
  final int? createdBy;
  final String createdByName;
  final bool isPublishedRevision;
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
      isPublishedRevision: map['isPublishedRevision'] == true,
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
    this.password,
    required this.renderType,
    required this.editorType,
    required this.aiSummaryStatus,
    required this.version,
    this.categoryId,
    this.tagIds = const [],
    this.visibilityRegions = const [],
    this.pointsPrice,
    this.freeLines,
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
  final String? password;
  final int renderType;
  final int editorType;
  final int aiSummaryStatus;
  final int version;
  final int? categoryId;
  final List<int> tagIds;
  final List<String> visibilityRegions;
  final int? pointsPrice;
  final int? freeLines;

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
      if (password != null) 'password': password,
      'renderType': renderType,
      'editorType': editorType,
      'aiSummaryStatus': aiSummaryStatus,
      'categoryId': categoryId,
      'tagIds': tagIds,
      'visibilityRegions': visibilityRegions,
      if (pointsPrice != null) 'pointsPrice': pointsPrice,
      if (freeLines != null) 'freeLines': freeLines,
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
      if (password != null) 'password': password,
      'renderType': renderType,
      'editorType': editorType,
      'aiSummaryStatus': aiSummaryStatus,
      'version': version,
      'categoryId': categoryId,
      'tagIds': tagIds,
      'visibilityRegions': visibilityRegions,
      if (pointsPrice != null) 'pointsPrice': pointsPrice,
      if (freeLines != null) 'freeLines': freeLines,
    };
  }

  PostEditRequest copyWith({
    int? version,
    int? categoryId,
    List<int>? tagIds,
    String? password,
  }) {
    return PostEditRequest(
      slug: slug,
      title: title,
      summary: summary,
      aiSummary: aiSummary,
      contentMarkdown: contentMarkdown,
      status: status,
      visibility: visibility,
      password: password ?? this.password,
      renderType: renderType,
      editorType: editorType,
      aiSummaryStatus: aiSummaryStatus,
      version: version ?? this.version,
      categoryId: categoryId ?? this.categoryId,
      tagIds: tagIds ?? this.tagIds,
      visibilityRegions: visibilityRegions,
      pointsPrice: pointsPrice,
      freeLines: freeLines,
    );
  }
}

String postRenderTypeText(int renderType) {
  switch (renderType) {
    case 0:
      return 'Markdown (旧版/Retired)';
    case 1:
      return 'HTML';
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
    this.visibilityRegions = const [],
    this.metadata = const {},
    this.processingStatus,
    this.processingProgress,
    this.processingError,
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
  final List<String> visibilityRegions;
  final Map<String, dynamic> metadata;
  final String? processingStatus;
  final int? processingProgress;
  final String? processingError;

  bool get isImage => mimeType.toLowerCase().startsWith('image/');

  bool get isAudio => mimeType.toLowerCase().startsWith('audio/');

  bool get isVideo => mimeType.toLowerCase().startsWith('video/');

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    final refList = asDynamicList(map['references'])
            ?.map((e) => MediaReference.fromMap(toStringMap(e)))
            .toList() ??
        [];
    return MediaItem(
      processingStatus: map['processingStatus']?.toString(),
      processingProgress: toInt(map['processingProgress']),
      processingError: map['processingError']?.toString(),
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
      visibilityRegions: toStringList(map['visibilityRegions']) ?? [],
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(
          map['metadata']) : {},
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
    final rawItems = asDynamicList(map['items']);
    final List<MediaItem> items = [];
    if (rawItems != null) {
      for (int i = 0; i < rawItems.length; i++) {
        final raw = rawItems[i];
        if (raw is Map<String, dynamic>) {
          items.add(MediaItem.fromMap(raw));
        } else if (raw is Map) {
          items.add(MediaItem.fromMap(Map<String, dynamic>.from(raw)));
        }
      }
    }
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

  String get zhDescription =>
      description?['zh-cn'] ??
          (description == null || description!.isEmpty ? '' : description!
              .values.first);

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

  String get zhDescription =>
      description?['zh-cn'] ??
          (description == null || description!.isEmpty ? '' : description!
              .values.first);

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
  final dt = DateTime.tryParse(value.toString());
  return dt?.toLocal();
}

String? _parseSupportedTypes(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final text = value.trim();
    if (text.startsWith('[') && text.endsWith(']')) {
      try {
        final list = jsonDecode(text);
        if (list is List) {
          return list.join(',');
        }
      } catch (_) {}
    }
    return text;
  }
  if (value is List) {
    return value.join(',');
  }
  return value.toString();
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

List<String>? toStringList(Object? value) {
  final list = asDynamicList(value);
  if (list == null) return null;
  return list.map((e) => e.toString()).toList();
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
    this.aiReviewData,
    required this.isReviewing,
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
  final Map<String, dynamic>? aiReviewData;
  final bool isReviewing;
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
        return '审核中';
      case 2:
        return '审核通过';
      case 3:
        return '审核拒绝';
      default:
        return '未知';
    }
  }

  String? get aiResultText {
    if (aiReviewData == null) return null;
    final isSafe = aiReviewData!['isSafe'];
    if (isSafe == null) return '无结果';
    return isSafe == true ? '建议通过' : '建议驳回';
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
      aiReviewData: map['aiReviewData'] as Map<String, dynamic>?,
      isReviewing: toBool(map['isReviewing']) ?? false,
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
    this.description = '',
    required this.deadLetterQueue,
    this.deadLetterMessageCount = 0,
  });

  final String name;
  final int messageCount;
  final int consumerCount;
  final String description;
  final String deadLetterQueue;
  final int deadLetterMessageCount;

  factory QueueInfo.fromMap(Map<String, dynamic> map) {
    return QueueInfo(
      name: map['name']?.toString() ?? '',
      messageCount: toInt(map['messageCount']) ?? 0,
      consumerCount: toInt(map['consumerCount']) ?? 0,
      description: map['description']?.toString() ?? '',
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

class StoreItem {
  StoreItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.rarity,
    this.type,
    this.extraInfo,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;
  final int price;
  final String? rarity;
  final String? type;
  final dynamic extraInfo;
  final int status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory StoreItem.fromMap(Map<String, dynamic> map) {
    return StoreItem(
      id: toInt(map['id']) ?? 0,
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      price: toInt(map['price']) ?? 0,
      rarity: map['rarity']?.toString(),
      type: map['type']?.toString(),
      extraInfo: map['extraInfo'],
      status: toInt(map['status']) ?? 1,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(
          map['createdAt'].toString()) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(
          map['updatedAt'].toString()) : null,
    );
  }
}

class StoreItemRequest {
  StoreItemRequest({
    required this.name,
    this.description,
    required this.price,
    this.rarity,
    this.type,
    this.extraInfo,
    required this.status,
  });

  final String name;
  final String? description;
  final int price;
  final String? rarity;
  final String? type;
  final dynamic extraInfo;
  final int status;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'price': price,
      if (rarity != null) 'rarity': rarity,
      if (type != null) 'type': type,
      if (extraInfo != null) 'extraInfo': extraInfo,
      'status': status,
    };
  }
}

class LinkMetaResponse {
  LinkMetaResponse({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final String icon;

  factory LinkMetaResponse.fromMap(Map<String, dynamic> map) {
    return LinkMetaResponse(
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      icon: map['icon']?.toString() ?? '',
    );
  }
}

class LinkCreateRequest {
  LinkCreateRequest({
    required this.name,
    required this.url,
    this.description,
    this.image,
    this.icon,
    this.sortOrder,
    this.status,
    this.target,
    this.redirectType,
    this.showUrl,
    this.email,
    this.note,
    this.seoTitle,
    this.seoKeywords,
    this.seoDescription,
    this.type,
  });

  final String name;
  final String url;
  final String? description;
  final String? image;
  final String? icon;
  final int? sortOrder;
  final int? status;
  final String? target;
  final int? redirectType;
  final bool? showUrl;
  final String? email;
  final String? note;
  final String? seoTitle;
  final String? seoKeywords;
  final String? seoDescription;
  final int? type;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'name': name,
      'url': url,
    };
    if (description != null) payload['description'] = description;
    if (image != null) payload['image'] = image;
    if (icon != null) payload['icon'] = icon;
    if (sortOrder != null) payload['sortOrder'] = sortOrder;
    if (status != null) payload['status'] = status;
    if (target != null) payload['target'] = target;
    if (redirectType != null) payload['redirectType'] = redirectType;
    if (showUrl != null) payload['showUrl'] = showUrl;
    if (email != null) payload['email'] = email;
    if (note != null) payload['note'] = note;
    if (seoTitle != null) payload['seoTitle'] = seoTitle;
    if (seoKeywords != null) payload['seoKeywords'] = seoKeywords;
    if (seoDescription != null) payload['seoDescription'] = seoDescription;
    if (type != null) payload['type'] = type;

    return payload;
  }
}

class AdminLinkItem {
  AdminLinkItem({
    required this.id,
    required this.name,
    required this.url,
    this.description,
    this.image,
    this.icon,
    required this.sortOrder,
    required this.status,
    required this.target,
    required this.redirectType,
    required this.showUrl,
    this.email,
    this.note,
    this.seoTitle,
    this.seoKeywords,
    this.seoDescription,
    this.type,
    this.referencedPostCount = 0,
    this.referenceCount = 0,
    this.createdAt,
  });

  final int id;
  final String name;
  final String url;
  final String? description;
  final String? image;
  final String? icon;
  final int sortOrder;
  final int status;
  final String target;
  final int redirectType;
  final bool showUrl;
  final String? email;
  final String? note;
  final String? seoTitle;
  final String? seoKeywords;
  final String? seoDescription;
  final int? type;
  final int referencedPostCount;
  final int referenceCount;
  final DateTime? createdAt;

  factory AdminLinkItem.fromMap(Map<String, dynamic> map) {
    return AdminLinkItem(
      id: toInt(map["id"]) ?? 0,
      name: map["name"]?.toString() ?? '',
      url: map["url"]?.toString() ?? '',
      description: map["description"]?.toString(),
      image: map["image"]?.toString(),
      icon: map["icon"]?.toString(),
      sortOrder: toInt(map["sortOrder"]) ?? 0,
      status: toInt(map["status"]) ?? 1,
      target: map["target"]?.toString() ?? '_blank',
      redirectType: toInt(map["redirectType"]) ?? 1,
      showUrl: toBool(map["showUrl"]) ?? true,
      email: map["email"]?.toString(),
      note: map["note"]?.toString(),
      seoTitle: map["seoTitle"]?.toString(),
      seoKeywords: map["seoKeywords"]?.toString(),
      seoDescription: map["seoDescription"]?.toString(),
      type: toInt(map["type"]),
      referencedPostCount: toInt(map["referencedPostCount"]) ?? 0,
      referenceCount: toInt(map["referenceCount"]) ?? 0,
      createdAt: parseDate(map["createdAt"]),
    );
  }
}

class LinkReferenceItem {
  LinkReferenceItem({
    required this.id,
    required this.postId,
    required this.postSlug,
    required this.postTitle,
    this.anchorText,
    required this.normalizedUrl,
    required this.referenceCount,
    this.updatedAt,
  });

  final int id;
  final int postId;
  final String postSlug;
  final String postTitle;
  final String? anchorText;
  final String normalizedUrl;
  final int referenceCount;
  final DateTime? updatedAt;

  factory LinkReferenceItem.fromMap(Map<String, dynamic> map) {
    return LinkReferenceItem(
      id: toInt(map['id']) ?? 0,
      postId: toInt(map['postId']) ?? 0,
      postSlug: map['postSlug']?.toString() ?? '',
      postTitle: map['postTitle']?.toString() ?? '',
      anchorText: map['anchorText']?.toString(),
      normalizedUrl: map['normalizedUrl']?.toString() ?? '',
      referenceCount: toInt(map['referenceCount']) ?? 0,
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

// ==================== 存储管理相关模型 ====================

class StorageProviderItem {
  StorageProviderItem({
    required this.id,
    required this.name,
    required this.displayName,
    required this.providerType,
    required this.isEnabled,
    required this.isPrimary,
    this.role,
    this.configJson,
    this.supportedTypes,
    this.cdnDomain,
    this.cdnEnabled,
    this.region,
    this.priority,
  });

  final int? id;
  final String name;
  final String displayName;
  final String providerType;
  final bool isEnabled;
  final bool isPrimary;
  final String? role;
  final String? configJson;
  final String? supportedTypes;
  final String? cdnDomain;
  final bool? cdnEnabled;
  final String? region;
  final int? priority;

  String get providerTypeText {
    switch (providerType) {
      case 'aliyun_oss_v2':
        return '阿里云 OSS v2';
      case 'local_fs':
        return '本地文件系统';
      default:
        return providerType;
    }
  }

  String get roleText {
    switch (role) {
      case 'primary':
        return '主存储 (Primary)';
      case 'backup':
        return '备份存储 (Backup)';
      case 'archive':
        return '归档存储 (Archive)';
      default:
        return role ?? '未设置';
    }
  }

  factory StorageProviderItem.fromMap(Map<String, dynamic> map) {
    return StorageProviderItem(
      id: toInt(map['id']),
      name: map['name']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      providerType: map['providerType']?.toString() ?? '',
      isEnabled: toBool(map['isEnabled']) ?? false,
      isPrimary: toBool(map['isPrimary']) ?? false,
      role: map['role']?.toString(),
      configJson: map['configJson']?.toString(),
      supportedTypes: _parseSupportedTypes(map['supportedTypes']),
      cdnDomain: map['cdnDomain']?.toString(),
      cdnEnabled: toBool(map['cdnEnabled']),
      region: map['region']?.toString(),
      priority: toInt(map['priority']),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'displayName': displayName,
      'providerType': providerType,
      'isEnabled': isEnabled,
      'isPrimary': isPrimary,
      if (role != null) 'role': role,
      if (configJson != null) 'configJson': configJson,
      if (supportedTypes != null) 'supportedTypes': supportedTypes,
      if (cdnDomain != null) 'cdnDomain': cdnDomain,
      if (cdnEnabled != null) 'cdnEnabled': cdnEnabled,
      if (region != null) 'region': region,
      if (priority != null) 'priority': priority,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'displayName': displayName,
      'isEnabled': isEnabled,
      if (role != null) 'role': role,
      if (configJson != null) 'configJson': configJson,
      if (supportedTypes != null) 'supportedTypes': supportedTypes,
      if (cdnDomain != null) 'cdnDomain': cdnDomain,
      if (cdnEnabled != null) 'cdnEnabled': cdnEnabled,
      if (region != null) 'region': region,
      if (priority != null) 'priority': priority,
    };
  }
}

class StorageSyncStatus {
  StorageSyncStatus({
    required this.totalMedia,
    required this.totalVariants,
    required this.syncedCount,
    required this.pendingCount,
    required this.failedCount,
    required this.details,
    required this.totalDetails,
    required this.page,
    required this.size,
  });

  final int totalMedia;
  final int totalVariants;
  final int syncedCount;
  final int pendingCount;
  final int failedCount;
  final List<MediaSyncDetail> details;
  final int totalDetails;
  final int page;
  final int size;

  double get syncPercent {
    if (totalVariants == 0) return 0;
    return syncedCount / totalVariants * 100;
  }

  factory StorageSyncStatus.fromMap(Map<String, dynamic> map) {
    final rawDetails = asDynamicList(map['details']) ?? [];
    return StorageSyncStatus(
      totalMedia: toInt(map['totalMedia']) ?? 0,
      totalVariants: toInt(map['totalVariants']) ?? 0,
      syncedCount: toInt(map['syncedCount']) ?? 0,
      pendingCount: toInt(map['pendingCount']) ?? 0,
      failedCount: toInt(map['failedCount']) ?? 0,
      details: rawDetails
          .map((e) => MediaSyncDetail.fromMap(toStringMap(e)))
          .toList(),
      totalDetails: toInt(map['totalDetails']) ?? 0,
      page: toInt(map['page']) ?? 0,
      size: toInt(map['size']) ?? 20,
    );
  }
}

class MediaSyncDetail {
  MediaSyncDetail({
    required this.mediaId,
    required this.fileName,
    required this.mimeType,
    this.storageNodes,
  });

  final int mediaId;
  final String fileName;
  final String mimeType;
  final Map<String, dynamic>? storageNodes;

  factory MediaSyncDetail.fromMap(Map<String, dynamic> map) {
    return MediaSyncDetail(
      mediaId: toInt(map['mediaId']) ?? 0,
      fileName: map['fileName']?.toString() ?? '',
      mimeType: map['mimeType']?.toString() ?? '',
      storageNodes: map['storageNodes'] is Map
          ? Map<String, dynamic>.from(map['storageNodes'] as Map)
          : null,
    );
  }
}

class StorageTestResult {
  StorageTestResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;

  factory StorageTestResult.fromMap(Map<String, dynamic> map) {
    return StorageTestResult(
      success: toBool(map['success']) ?? false,
      message: map['message']?.toString() ?? '',
    );
  }
}

class ImageProcessingConfigItem {
  ImageProcessingConfigItem({
    required this.id,
    required this.configKey,
    required this.configValue,
    this.description,
    required this.version,
    required this.isFrozen,
  });

  final int id;
  final String configKey;
  final String configValue;
  final String? description;
  final int version;
  final bool isFrozen;

  factory ImageProcessingConfigItem.fromMap(Map<String, dynamic> map) {
    return ImageProcessingConfigItem(
      id: toInt(map['id']) ?? 0,
      configKey: map['configKey']?.toString() ?? '',
      configValue: map['configValue']?.toString() ?? '',
      description: map['description']?.toString(),
      version: toInt(map['version']) ?? 1,
      isFrozen: toBool(map['isFrozen']) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'configKey': configKey,
      'configValue': configValue,
      if (description != null) 'description': description,
      'version': version,
    };
  }
}

class DeadLetterMessageItem {
  DeadLetterMessageItem({
    required this.id,
    required this.queueName,
    required this.payload,
    required this.errorReason,
    required this.retryCount,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String queueName;
  final String payload;
  final String? errorReason;
  final int retryCount;
  final int status;
  final DateTime createdAt;

  String get statusText {
    if (status == 0) return '待处理';
    if (status == 1) return '处理中';
    if (status == 2) return '已处理';
    if (status == 3) return '已忽略';
    return '未知';
  }

  factory DeadLetterMessageItem.fromMap(Map<String, dynamic> map) {
    return DeadLetterMessageItem(
      id: toInt(map['id']) ?? 0,
      queueName: map['queueName']?.toString() ?? '',
      payload: map['payload']?.toString() ?? '',
      errorReason: map['errorReason']?.toString(),
      retryCount: toInt(map['retryCount']) ?? 0,
      status: toInt(map['status']) ?? 0,
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }
}

class ImageProcessingMetadata {
  ImageProcessingMetadata({
    required this.key,
    required this.label,
    required this.type,
    this.description,
    this.min,
    this.max,
    this.testUrl,
  });

  final String key;
  final String label;
  final String type;
  final String? description;
  final num? min;
  final num? max;
  final String? testUrl;

  factory ImageProcessingMetadata.fromMap(Map<String, dynamic> map) {
    return ImageProcessingMetadata(
      key: map['key']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      description: map['description']?.toString(),
      min: map['min'] as num?,
      max: map['max'] as num?,
      testUrl: map['testUrl']?.toString(),
    );
  }
}

enum EdgeConnectionType {
  heartbeat,
  activePoll,
}

class EdgeNode {
  final String nodeId;
  final String name;
  final String? externalUrl;
  final String? apiUrl;
  final String? grpcAddress;
  @Deprecated('Use grpcAddress instead')
  final String? address;
  final BlogRegion region;
  final EdgeConnectionType connectionType;
  final DateTime? lastHeartbeat;
  final Map<String, String> metrics;
  final String status;
  final bool isEnabled;
  final String? certificateSerial;
  final DateTime? certificateExpiry;
  final bool certificateRevoked;
  final String? certificateBackupSerial;
  final DateTime? certificateBackupExpiry;
  final bool isTrusted;
  final int? edgeGrpcPort;

  EdgeNode({
    required this.nodeId,
    required this.name,
    this.externalUrl,
    this.apiUrl,
    this.grpcAddress,
    @Deprecated('Use grpcAddress instead') this.address,
    required this.region,
    required this.connectionType,
    this.lastHeartbeat,
    required this.metrics,
    required this.status,
    required this.isEnabled,
    this.certificateSerial,
    this.certificateExpiry,
    this.certificateRevoked = false,
    this.certificateBackupSerial,
    this.certificateBackupExpiry,
    this.isTrusted = false,
    this.edgeGrpcPort,
  });

  factory EdgeNode.fromJson(Map<String, dynamic> json) {
    return EdgeNode(
      nodeId: json['nodeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      externalUrl: json['externalUrl']?.toString(),
      apiUrl: json['apiUrl']?.toString(),
      grpcAddress: json['grpcAddress']?.toString() ??
          json['address']?.toString(),
      // ignore: deprecated_member_use_from_same_package
      address: json['address']?.toString(),
      region: BlogRegion.fromCode(json['region']?.toString() ?? 'global'),
      connectionType: _parseConnectionType(json['connectionType']),
      lastHeartbeat: parseDate(json['lastHeartbeat']),
      metrics: (json['metrics'] as Map?)?.map((k, v) =>
          MapEntry(k.toString(), v.toString())) ?? {},
      status: json['status']?.toString() ?? 'OFFLINE',
      isEnabled: json['isEnabled'] == true || json['enabled'] == true,
      certificateSerial: json['certificateSerial']?.toString(),
      certificateExpiry: parseDate(json['certificateExpiry']),
      certificateRevoked: json['certificateRevoked'] == true,
      certificateBackupSerial: json['certificateBackupSerial']?.toString(),
      certificateBackupExpiry: parseDate(json['certificateBackupExpiry']),
      isTrusted: json['isTrusted'] == true,
      edgeGrpcPort: json['edgeGrpcPort'] != null ? int.tryParse(
          json['edgeGrpcPort'].toString()) : null,
    );
  }

  static EdgeConnectionType _parseConnectionType(dynamic value) {
    if (value == 'activePoll' || value == 'ACTIVE_POLL') {
      return EdgeConnectionType.activePoll;
    }
    return EdgeConnectionType.heartbeat;
  }

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'name': name,
      'externalUrl': externalUrl,
      'apiUrl': apiUrl,
      'grpcAddress': grpcAddress,
      'region': region.code,
      'connectionType': connectionType.name,
      'isEnabled': isEnabled,
      'edgeGrpcPort': edgeGrpcPort,
    };
  }
}

class NodeDeploymentPackage {
  final String primaryCert;
  final String primaryKey;
  final String backupCert;
  final String backupKey;
  final String caCert;
  final String envFile;
  final String dockerCompose;

  NodeDeploymentPackage({
    required this.primaryCert,
    required this.primaryKey,
    required this.backupCert,
    required this.backupKey,
    required this.caCert,
    required this.envFile,
    required this.dockerCompose,
  });

  factory NodeDeploymentPackage.fromJson(Map<String, dynamic> json) {
    return NodeDeploymentPackage(
      primaryCert: json['primaryCert']?.toString() ?? '',
      primaryKey: json['primaryKey']?.toString() ?? '',
      backupCert: json['backupCert']?.toString() ?? '',
      backupKey: json['backupKey']?.toString() ?? '',
      caCert: json['caCert']?.toString() ?? '',
      envFile: json['envFile']?.toString() ?? '',
      dockerCompose: json['dockerCompose']?.toString() ?? '',
    );
  }
}

class EdgeSyncStatus {
  final int total;
  final int processed;
  final String status;
  final String? lastError;

  EdgeSyncStatus({
    required this.total,
    required this.processed,
    required this.status,
    this.lastError,
  });

  factory EdgeSyncStatus.fromMap(Map<String, dynamic> map) {
    return EdgeSyncStatus(
      total: toInt(map['total']) ?? 0,
      processed: toInt(map['processed']) ?? 0,
      status: map['status']?.toString() ?? 'IDLE',
      lastError: map['lastError']?.toString(),
    );
  }

  double get progress => total > 0 ? processed / total : 0.0;
}

class EdgeNodeDataStatus {
  EdgeNodeDataStatus({
    required this.nodeId,
    required this.nodeStatus,
    required this.enabled,
    required this.trusted,
    required this.persistentChannelOnline,
    required this.primaryOnline,
    required this.readOnly,
    required this.readOnlyMessage,
    this.channelConnectedAt,
    this.lastHeartbeat,
    required this.metrics,
    this.availability,
    this.syncProgress,
  });

  final String nodeId;
  final String nodeStatus;
  final bool enabled;
  final bool trusted;
  final bool persistentChannelOnline;
  final bool primaryOnline;
  final bool readOnly;
  final String readOnlyMessage;
  final DateTime? channelConnectedAt;
  final DateTime? lastHeartbeat;
  final Map<String, String> metrics;
  final EdgeNodeAvailabilityRates? availability;
  final EdgeSyncStatus? syncProgress;

  factory EdgeNodeDataStatus.fromMap(Map<String, dynamic> map) {
    final rawSyncProgress = map['syncProgress'];
    EdgeSyncStatus? parsedSyncProgress;
    if (rawSyncProgress is Map) {
      parsedSyncProgress = EdgeSyncStatus.fromMap(
        rawSyncProgress.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    EdgeNodeAvailabilityRates? parsedAvailability;
    final rawAvailability = map['availability'];
    if (rawAvailability is Map) {
      parsedAvailability = EdgeNodeAvailabilityRates.fromMap(
        rawAvailability.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    return EdgeNodeDataStatus(
      nodeId: map['nodeId']?.toString() ?? '',
      nodeStatus: map['nodeStatus']?.toString() ?? 'OFFLINE',
      enabled: toBool(map['enabled']) ?? false,
      trusted: toBool(map['trusted']) ?? false,
      persistentChannelOnline: toBool(map['persistentChannelOnline']) ?? false,
      primaryOnline: toBool(map['primaryOnline']) ?? false,
      readOnly: toBool(map['readOnly']) ?? true,
      readOnlyMessage: map['readOnlyMessage']?.toString() ?? '',
      channelConnectedAt: parseDate(map['channelConnectedAt']),
      lastHeartbeat: parseDate(map['lastHeartbeat']),
      metrics: (map['metrics'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
      ) ??
          {},
      availability: parsedAvailability,
      syncProgress: parsedSyncProgress,
    );
  }
}

class EdgeNodeAvailabilityRates {
  EdgeNodeAvailabilityRates({
    required this.lastHour,
    required this.last24Hours,
    required this.last7Days,
    required this.last30Days,
  });

  final EdgeNodeAvailabilityRate lastHour;
  final EdgeNodeAvailabilityRate last24Hours;
  final EdgeNodeAvailabilityRate last7Days;
  final EdgeNodeAvailabilityRate last30Days;

  factory EdgeNodeAvailabilityRates.fromMap(Map<String, dynamic> map) {
    return EdgeNodeAvailabilityRates(
      lastHour: EdgeNodeAvailabilityRate.fromMap(
        _availabilityRateMap(map['lastHour']),
      ),
      last24Hours: EdgeNodeAvailabilityRate.fromMap(
        _availabilityRateMap(map['last24Hours']),
      ),
      last7Days: EdgeNodeAvailabilityRate.fromMap(
        _availabilityRateMap(map['last7Days']),
      ),
      last30Days: EdgeNodeAvailabilityRate.fromMap(
        _availabilityRateMap(map['last30Days']),
      ),
    );
  }
}

Map<String, dynamic> _availabilityRateMap(Object? value) {
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return {};
}

class EdgeNodeAvailabilityRate {
  EdgeNodeAvailabilityRate({
    this.onlineRate,
    required this.totalSamples,
    required this.onlineSamples,
  });

  final double? onlineRate;
  final int totalSamples;
  final int onlineSamples;

  factory EdgeNodeAvailabilityRate.fromMap(Map<String, dynamic> map) {
    double? parsedOnlineRate;
    final rawOnlineRate = map['onlineRate'];
    if (rawOnlineRate is num) {
      parsedOnlineRate = rawOnlineRate.toDouble();
    }

    return EdgeNodeAvailabilityRate(
      onlineRate: parsedOnlineRate,
      totalSamples: toInt(map['totalSamples']) ?? 0,
      onlineSamples: toInt(map['onlineSamples']) ?? 0,
    );
  }
}

class EdgeNodeAvailabilityHistory {
  EdgeNodeAvailabilityHistory({
    required this.nodeId,
    required this.from,
    required this.to,
    required this.rates,
    required this.samples,
    required this.onlinePeriods,
    required this.calendarDays,
  });

  final String nodeId;
  final DateTime? from;
  final DateTime? to;
  final EdgeNodeAvailabilityRates rates;
  final List<EdgeNodeAvailabilitySamplePoint> samples;
  final List<EdgeNodeOnlinePeriod> onlinePeriods;
  final List<EdgeNodeAvailabilityCalendarDay> calendarDays;

  factory EdgeNodeAvailabilityHistory.fromMap(Map<String, dynamic> map) {
    final List<EdgeNodeAvailabilitySamplePoint> parsedSamples = [];
    final rawSamples = asDynamicList(map['samples']) ?? [];
    for (int index = 0; index < rawSamples.length; index++) {
      final rawSample = rawSamples[index];
      if (rawSample is Map) {
        parsedSamples.add(EdgeNodeAvailabilitySamplePoint.fromMap(
          rawSample.map((key, value) => MapEntry(key.toString(), value)),
        ));
      }
    }

    final List<EdgeNodeOnlinePeriod> parsedOnlinePeriods = [];
    final rawOnlinePeriods = asDynamicList(map['onlinePeriods']) ?? [];
    for (int index = 0; index < rawOnlinePeriods.length; index++) {
      final rawPeriod = rawOnlinePeriods[index];
      if (rawPeriod is Map) {
        parsedOnlinePeriods.add(EdgeNodeOnlinePeriod.fromMap(
          rawPeriod.map((key, value) => MapEntry(key.toString(), value)),
        ));
      }
    }

    final List<EdgeNodeAvailabilityCalendarDay> parsedCalendarDays = [];
    final rawCalendarDays = asDynamicList(map['calendarDays']) ?? [];
    for (int index = 0; index < rawCalendarDays.length; index++) {
      final rawDay = rawCalendarDays[index];
      if (rawDay is Map) {
        parsedCalendarDays.add(EdgeNodeAvailabilityCalendarDay.fromMap(
          rawDay.map((key, value) => MapEntry(key.toString(), value)),
        ));
      }
    }

    return EdgeNodeAvailabilityHistory(
      nodeId: map['nodeId']?.toString() ?? '',
      from: parseDate(map['from']),
      to: parseDate(map['to']),
      rates: EdgeNodeAvailabilityRates.fromMap(
        _availabilityRateMap(map['rates']),
      ),
      samples: parsedSamples,
      onlinePeriods: parsedOnlinePeriods,
      calendarDays: parsedCalendarDays,
    );
  }
}

class EdgeNodeAvailabilitySamplePoint {
  EdgeNodeAvailabilitySamplePoint({
    required this.sampledAt,
    required this.online,
  });

  final DateTime? sampledAt;
  final bool online;

  factory EdgeNodeAvailabilitySamplePoint.fromMap(Map<String, dynamic> map) {
    return EdgeNodeAvailabilitySamplePoint(
      sampledAt: parseDate(map['sampledAt']),
      online: toBool(map['online']) ?? false,
    );
  }
}

class EdgeNodeOnlinePeriod {
  EdgeNodeOnlinePeriod({
    required this.startAt,
    required this.endAt,
  });

  final DateTime? startAt;
  final DateTime? endAt;

  factory EdgeNodeOnlinePeriod.fromMap(Map<String, dynamic> map) {
    return EdgeNodeOnlinePeriod(
      startAt: parseDate(map['startAt']),
      endAt: parseDate(map['endAt']),
    );
  }
}

class EdgeNodeAvailabilityCalendarDay {
  EdgeNodeAvailabilityCalendarDay({
    required this.date,
    this.onlineRate,
    required this.totalSamples,
    required this.onlineSamples,
  });

  final String date;
  final double? onlineRate;
  final int totalSamples;
  final int onlineSamples;

  factory EdgeNodeAvailabilityCalendarDay.fromMap(Map<String, dynamic> map) {
    double? parsedOnlineRate;
    final rawOnlineRate = map['onlineRate'];
    if (rawOnlineRate is num) {
      parsedOnlineRate = rawOnlineRate.toDouble();
    }

    return EdgeNodeAvailabilityCalendarDay(
      date: map['date']?.toString() ?? '',
      onlineRate: parsedOnlineRate,
      totalSamples: toInt(map['totalSamples']) ?? 0,
      onlineSamples: toInt(map['onlineSamples']) ?? 0,
    );
  }
}

class NodeCertificateResponse {
  final String nodeId;
  final String primaryCertificatePem;
  final String primaryPrivateKeyPem;
  final String backupCertificatePem;
  final String backupPrivateKeyPem;
  final String caCertificatePem;
  final DateTime primaryExpiry;
  final DateTime backupExpiry;

  NodeCertificateResponse({
    required this.nodeId,
    required this.primaryCertificatePem,
    required this.primaryPrivateKeyPem,
    required this.backupCertificatePem,
    required this.backupPrivateKeyPem,
    required this.caCertificatePem,
    required this.primaryExpiry,
    required this.backupExpiry,
  });

  factory NodeCertificateResponse.fromMap(Map<String, dynamic> map) {
    return NodeCertificateResponse(
      nodeId: map['nodeId']?.toString() ?? '',
      primaryCertificatePem: map['primaryCertificatePem']?.toString() ?? '',
      primaryPrivateKeyPem: map['primaryPrivateKeyPem']?.toString() ?? '',
      backupCertificatePem: map['backupCertificatePem']?.toString() ?? '',
      backupPrivateKeyPem: map['backupPrivateKeyPem']?.toString() ?? '',
      caCertificatePem: map['caCertificatePem']?.toString() ?? '',
      primaryExpiry: parseDate(map['primaryExpiry']) ?? DateTime.now(),
      backupExpiry: parseDate(map['backupExpiry']) ?? DateTime.now(),
    );
  }
}


class RegionRule {
  final int? id;
  final String name;
  final String ruleType;
  final String pattern;
  final String region;
  final int priority;
  final bool isEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RegionRule({
    this.id,
    required this.name,
    required this.ruleType,
    required this.pattern,
    required this.region,
    this.priority = 0,
    this.isEnabled = true,
    this.createdAt,
    this.updatedAt,
  });

  factory RegionRule.fromJson(Map<String, dynamic> json) {
    return RegionRule(
      id: toInt(json['id']),
      name: json['name']?.toString() ?? '',
      ruleType: json['ruleType']?.toString() ?? '',
      pattern: json['pattern']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
      priority: toInt(json['priority']) ?? 0,
      isEnabled: toBool(json['isEnabled']) ?? true,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'ruleType': ruleType,
      'pattern': pattern,
      'region': region,
      'priority': priority,
      'isEnabled': isEnabled,
    };
  }
}
