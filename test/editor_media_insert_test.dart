import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/main.dart';

MediaItem _media({
  required String fileName,
  required String mimeType,
  required String url,
  int mediaType = 2,
}) {
  return MediaItem(
    id: 1,
    storageKey: 'stored-file',
    url: url,
    requiresManualOriginal: false,
    fileName: fileName,
    mimeType: mimeType,
    size: 128,
    mediaType: mediaType,
    createdAt: DateTime(2026, 1, 1),
    referenced: false,
    references: const [],
  );
}

void main() {
  test('pasted image stays inline and uses the public /uploads path', () {
    final item = _media(
      fileName: '屏幕 [1].png',
      mimeType: 'image/png',
      url: 'https://admin.example.com/uploads/abc.png',
      mediaType: 0,
    );

    expect(markdownMediaReference(item), r'![屏幕 \[1\].png](/uploads/abc.png)');
  });

  test('office documents and archives become download links', () {
    for (final type in const [
      (
        '报告.docx',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
      (
        '演示.pptx',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      ),
      ('资源.zip', 'application/zip'),
      ('模型.glb', 'model/gltf-binary'),
    ]) {
      final item = _media(
        fileName: type.$1,
        mimeType: type.$2,
        url: 'https://admin.example.com/uploads/uuid.bin',
      );
      expect(markdownMediaReference(item), '[${type.$1}](/uploads/uuid.bin)');
    }
  });

  test('image mime types browsers cannot render fall back to links', () {
    final item = _media(
      fileName: '设计稿.psd',
      mimeType: 'image/vnd.adobe.photoshop',
      url: '/uploads/uuid.psd',
      mediaType: 0,
    );

    expect(markdownMediaReference(item), '[设计稿.psd](/uploads/uuid.psd)');
  });

  test('fallback name is used when the server stored an empty name', () {
    final item = _media(
      fileName: '  ',
      mimeType: 'application/zip',
      url: '/uploads/uuid.zip',
    );

    expect(
      markdownMediaReference(item, fallbackName: '粘贴的压缩包.zip'),
      '[粘贴的压缩包.zip](/uploads/uuid.zip)',
    );
  });

  test('external media urls are kept unchanged', () {
    final item = _media(
      fileName: 'external.bin',
      mimeType: 'application/octet-stream',
      url: 'https://cdn.example.com/files/external.bin',
    );

    expect(
      markdownMediaReference(item),
      '[external.bin](https://cdn.example.com/files/external.bin)',
    );
  });

  test('media without a url inserts nothing', () {
    final item = _media(
      fileName: 'pending.bin',
      mimeType: 'application/octet-stream',
      url: '',
    );

    expect(markdownMediaReference(item), isEmpty);
  });
}
