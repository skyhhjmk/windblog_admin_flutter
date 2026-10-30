import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:windblog_admin_flutter/utils/editor_draft_store.dart';

const String _baseUrl = 'https://blog.example.com';

EditorDraft _draft({
  int? postId = 7,
  String baseUrl = _baseUrl,
  String title = '标题',
  String content = '正文',
  DateTime? savedAt,
}) {
  return EditorDraft(
    baseUrl: baseUrl,
    postId: postId,
    savedAt: savedAt ?? DateTime(2026, 10, 30, 12),
    slug: 'slug',
    title: title,
    summary: '摘要',
    content: content,
    seoTitle: 'SEO 标题',
    seoDescription: 'SEO 描述',
    seoKeywords: 'a,b',
    status: 1,
    visibility: 2,
    renderType: 6,
    editorType: 6,
    aiSummaryStatus: 1,
    categoryId: 3,
    categoryIds: const [3, 4],
    tagIds: const [5],
    visibilityRegions: const ['cn'],
    contentDeclarations: const ['CC_BY_NC_4_0'],
    repostPolicyCode: 'CC_BY_NC_4_0',
    pointsPrice: '10',
    freeLines: '2',
    titles: const {'zh-cn': '标题', 'en': 'Title'},
    summaries: const {'zh-cn': '摘要'},
    contents: const {'zh-cn': '正文', 'en': 'Body'},
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('draft survives a JSON round trip', () {
    final original = _draft();
    final restored = EditorDraft.fromJson(original.toJson());

    expect(restored, isNotNull);
    expect(restored!.baseUrl, original.baseUrl);
    expect(restored.postId, original.postId);
    expect(restored.savedAt, original.savedAt);
    expect(restored.slug, 'slug');
    expect(restored.title, '标题');
    expect(restored.summary, '摘要');
    expect(restored.content, '正文');
    expect(restored.seoTitle, 'SEO 标题');
    expect(restored.seoDescription, 'SEO 描述');
    expect(restored.seoKeywords, 'a,b');
    expect(restored.status, 1);
    expect(restored.visibility, 2);
    expect(restored.renderType, 6);
    expect(restored.editorType, 6);
    expect(restored.aiSummaryStatus, 1);
    expect(restored.categoryId, 3);
    expect(restored.categoryIds, [3, 4]);
    expect(restored.tagIds, [5]);
    expect(restored.visibilityRegions, ['cn']);
    expect(restored.contentDeclarations, ['CC_BY_NC_4_0']);
    expect(restored.repostPolicyCode, 'CC_BY_NC_4_0');
    expect(restored.pointsPrice, '10');
    expect(restored.freeLines, '2');
    expect(restored.titles, {'zh-cn': '标题', 'en': 'Title'});
    expect(restored.summaries, {'zh-cn': '摘要'});
    expect(restored.contents, {'zh-cn': '正文', 'en': 'Body'});
  });

  test('store keeps one draft per article and returns the newest', () async {
    await EditorDraftStore.save(
      _draft(postId: 7, title: '旧标题', savedAt: DateTime(2026, 10, 30, 9)),
    );
    await EditorDraftStore.save(
      _draft(postId: 8, title: '另一篇', savedAt: DateTime(2026, 10, 30, 10)),
    );
    await EditorDraftStore.save(
      _draft(postId: 7, title: '新标题', savedAt: DateTime(2026, 10, 30, 11)),
    );

    final sameArticle = await EditorDraftStore.load(
      baseUrl: _baseUrl,
      postId: 7,
    );
    expect(sameArticle?.title, '新标题');

    final latest = await EditorDraftStore.loadLatest(baseUrl: _baseUrl);
    expect(latest?.postId, 7);
    expect(latest?.title, '新标题');

    expect(
      await EditorDraftStore.loadLatest(baseUrl: 'https://other.example.com'),
      isNull,
    );
  });

  test('new article drafts use a separate slot', () async {
    await EditorDraftStore.save(_draft(postId: null, title: '未创建'));
    await EditorDraftStore.save(_draft(postId: 7, title: '已创建'));

    expect(
      (await EditorDraftStore.load(baseUrl: _baseUrl, postId: null))?.title,
      '未创建',
    );
    expect(
      (await EditorDraftStore.load(baseUrl: _baseUrl, postId: 7))?.title,
      '已创建',
    );

    await EditorDraftStore.clear(baseUrl: _baseUrl, postId: null);
    expect(
      await EditorDraftStore.load(baseUrl: _baseUrl, postId: null),
      isNull,
    );
    expect(
      (await EditorDraftStore.load(baseUrl: _baseUrl, postId: 7))?.title,
      '已创建',
    );
  });

  test('expired drafts are ignored and removed', () async {
    await EditorDraftStore.save(
      _draft(
        postId: 9,
        savedAt: DateTime.now().subtract(
          EditorDraft.maxAge + const Duration(days: 1),
        ),
      ),
    );

    expect(
      await EditorDraftStore.load(baseUrl: _baseUrl, postId: 9),
      isNull,
    );
    expect(await EditorDraftStore.loadLatest(baseUrl: _baseUrl), isNull);
  });

  test('malformed payloads do not throw', () async {
    SharedPreferences.setMockInitialValues({
      'admin_editor_drafts': '{"https://blog.example.com|7": "not a map"}',
    });
    expect(
      await EditorDraftStore.load(baseUrl: _baseUrl, postId: 7),
      isNull,
    );
    expect(await EditorDraftStore.loadLatest(baseUrl: _baseUrl), isNull);
  });
}
