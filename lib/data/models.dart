class AdminUser {
  AdminUser({required this.id, required this.username, required this.email});
  final int id;
  final String username;
  final String email;
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
