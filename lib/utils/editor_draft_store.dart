import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A local snapshot of the post editor's working copy.
///
/// Android may kill a backgrounded app at any time, and it does not call
/// [State.dispose] first. The editor writes its unsaved values here so that a
/// cold start can reopen the same editing session instead of dropping the
/// user's work. Drafts never leave the device and are cleared as soon as the
/// article is saved or the user discards the changes.
class EditorDraft {
  const EditorDraft({
    required this.baseUrl,
    required this.postId,
    required this.savedAt,
    required this.slug,
    required this.title,
    required this.summary,
    required this.content,
    required this.seoTitle,
    required this.seoDescription,
    required this.seoKeywords,
    required this.status,
    required this.visibility,
    required this.renderType,
    required this.editorType,
    required this.aiSummaryStatus,
    required this.categoryId,
    required this.categoryIds,
    required this.tagIds,
    required this.visibilityRegions,
    required this.contentDeclarations,
    required this.repostPolicyCode,
    required this.pointsPrice,
    required this.freeLines,
    required this.titles,
    required this.summaries,
    required this.contents,
  });

  static const int schemaVersion = 1;

  /// Drafts are only a safety net for a killed process; anything older than
  /// this is more likely stale than useful.
  static const Duration maxAge = Duration(days: 7);

  final String baseUrl;

  /// `null` while the article has not been created on the server yet.
  final int? postId;
  final DateTime savedAt;

  final String slug;
  final String title;
  final String summary;
  final String content;
  final String seoTitle;
  final String seoDescription;
  final String seoKeywords;
  final int status;
  final int visibility;
  final int renderType;
  final int editorType;
  final int aiSummaryStatus;
  final int? categoryId;
  final List<int> categoryIds;
  final List<int> tagIds;
  final List<String> visibilityRegions;
  final List<String> contentDeclarations;
  final String repostPolicyCode;
  final String pointsPrice;
  final String freeLines;
  final Map<String, String> titles;
  final Map<String, String> summaries;
  final Map<String, String> contents;

  bool get isExpired => DateTime.now().difference(savedAt) > maxAge;

  bool matches({required String baseUrl, required int? postId}) {
    return this.baseUrl == baseUrl && this.postId == postId;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': schemaVersion,
      'baseUrl': baseUrl,
      'postId': postId,
      'savedAt': savedAt.toIso8601String(),
      'slug': slug,
      'title': title,
      'summary': summary,
      'content': content,
      'seoTitle': seoTitle,
      'seoDescription': seoDescription,
      'seoKeywords': seoKeywords,
      'status': status,
      'visibility': visibility,
      'renderType': renderType,
      'editorType': editorType,
      'aiSummaryStatus': aiSummaryStatus,
      'categoryId': categoryId,
      'categoryIds': categoryIds,
      'tagIds': tagIds,
      'visibilityRegions': visibilityRegions,
      'contentDeclarations': contentDeclarations,
      'repostPolicyCode': repostPolicyCode,
      'pointsPrice': pointsPrice,
      'freeLines': freeLines,
      'titles': titles,
      'summaries': summaries,
      'contents': contents,
    };
  }

  static EditorDraft? fromJson(Map<String, dynamic> map) {
    if (_asInt(map['version']) != schemaVersion) return null;
    final baseUrl = map['baseUrl']?.toString() ?? '';
    if (baseUrl.isEmpty) return null;
    return EditorDraft(
      baseUrl: baseUrl,
      postId: _asInt(map['postId']),
      savedAt:
          DateTime.tryParse(map['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      slug: map['slug']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      summary: map['summary']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      seoTitle: map['seoTitle']?.toString() ?? '',
      seoDescription: map['seoDescription']?.toString() ?? '',
      seoKeywords: map['seoKeywords']?.toString() ?? '',
      status: _asInt(map['status']) ?? 0,
      visibility: _asInt(map['visibility']) ?? 0,
      renderType: _asInt(map['renderType']) ?? 6,
      editorType: _asInt(map['editorType']) ?? 6,
      aiSummaryStatus: _asInt(map['aiSummaryStatus']) ?? 0,
      categoryId: _asInt(map['categoryId']),
      categoryIds: _asIntList(map['categoryIds']),
      tagIds: _asIntList(map['tagIds']),
      visibilityRegions: _asStringList(map['visibilityRegions']),
      contentDeclarations: _asStringList(map['contentDeclarations']),
      repostPolicyCode: map['repostPolicyCode']?.toString() ?? '',
      pointsPrice: map['pointsPrice']?.toString() ?? '',
      freeLines: map['freeLines']?.toString() ?? '',
      titles: _asStringMap(map['titles']),
      summaries: _asStringMap(map['summaries']),
      contents: _asStringMap(map['contents']),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static List<int> _asIntList(Object? value) {
    if (value is! List) return <int>[];
    return value.map(_asInt).whereType<int>().toList();
  }

  static List<String> _asStringList(Object? value) {
    if (value is! List) return <String>[];
    return value.map((item) => item?.toString() ?? '').toList();
  }

  static Map<String, String> _asStringMap(Object? value) {
    if (value is! Map) return <String, String>{};
    return value.map(
      (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
    );
  }
}

/// Keeps one draft per article (plus one for an unsaved new article) in
/// [SharedPreferences]. Only the most recent [maxDrafts] entries survive.
class EditorDraftStore {
  EditorDraftStore._();

  static const String _prefsKey = 'admin_editor_drafts';
  static const int maxDrafts = 10;

  static String _entryKey({required String baseUrl, required int? postId}) {
    return '$baseUrl|${postId ?? 'new'}';
  }

  /// Saves [draft], replacing any older draft for the same article.
  static Future<void> save(EditorDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = _decode(prefs.getString(_prefsKey));
      all[_entryKey(baseUrl: draft.baseUrl, postId: draft.postId)] = draft
          .toJson();
      final pruned = _prune(all);
      await prefs.setString(_prefsKey, jsonEncode(pruned));
    } catch (_) {
      // Draft persistence is best-effort; editing must keep working.
    }
  }

  /// Returns the draft for one article, if it is still fresh.
  static Future<EditorDraft?> load({
    required String baseUrl,
    required int? postId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = _decode(prefs.getString(_prefsKey));
      final raw = all[_entryKey(baseUrl: baseUrl, postId: postId)];
      if (raw is! Map) return null;
      final draft = EditorDraft.fromJson(Map<String, dynamic>.from(raw));
      if (draft == null) return null;
      if (draft.isExpired) {
        await clear(baseUrl: baseUrl, postId: postId);
        return null;
      }
      return draft;
    } catch (_) {
      return null;
    }
  }

  /// Returns the freshest draft, optionally limited to one server.
  static Future<EditorDraft?> loadLatest({required String baseUrl}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = _decode(prefs.getString(_prefsKey));
      EditorDraft? latest;
      for (final raw in all.values) {
        if (raw is! Map) continue;
        final draft = EditorDraft.fromJson(Map<String, dynamic>.from(raw));
        if (draft == null || draft.isExpired || draft.baseUrl != baseUrl) {
          continue;
        }
        if (latest == null || draft.savedAt.isAfter(latest.savedAt)) {
          latest = draft;
        }
      }
      return latest;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear({
    required String baseUrl,
    required int? postId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = _decode(prefs.getString(_prefsKey));
      if (all.remove(_entryKey(baseUrl: baseUrl, postId: postId)) == null) {
        return;
      }
      if (all.isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, jsonEncode(all));
      }
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  static Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _prune(Map<String, dynamic> all) {
    final entries = <MapEntry<String, EditorDraft>>[];
    for (final entry in all.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      final draft = EditorDraft.fromJson(Map<String, dynamic>.from(raw));
      if (draft == null || draft.isExpired) continue;
      entries.add(MapEntry(entry.key, draft));
    }
    entries.sort((a, b) => b.value.savedAt.compareTo(a.value.savedAt));
    final kept = <String, dynamic>{};
    for (final entry in entries.take(maxDrafts)) {
      kept[entry.key] = entry.value.toJson();
    }
    return kept;
  }
}
