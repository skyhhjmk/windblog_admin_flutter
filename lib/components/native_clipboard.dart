import 'dart:async';
import 'dart:typed_data';

import 'package:super_clipboard/super_clipboard.dart';

class ClipboardPasteData {
  const ClipboardPasteData({
    this.imageBytes,
    this.fileName,
    this.mimeType,
    this.text,
  });

  final Uint8List? imageBytes;
  final String? fileName;
  final String? mimeType;
  final String? text;
}

class _ClipboardImageFormat {
  const _ClipboardImageFormat(this.format, this.mimeType);

  final FileFormat format;
  final String mimeType;
}

const _clipboardImageFormats = <_ClipboardImageFormat>[
  _ClipboardImageFormat(Formats.png, 'image/png'),
  _ClipboardImageFormat(Formats.jpeg, 'image/jpeg'),
  _ClipboardImageFormat(Formats.gif, 'image/gif'),
  _ClipboardImageFormat(Formats.tiff, 'image/tiff'),
  _ClipboardImageFormat(Formats.webp, 'image/webp'),
  _ClipboardImageFormat(Formats.bmp, 'image/bmp'),
  _ClipboardImageFormat(Formats.heic, 'image/heic'),
  _ClipboardImageFormat(Formats.heif, 'image/heif'),
];

/// Reads an image first so native paste can prefer clipboard pixels over any
/// accompanying text representation. Falls back to plain text when no image
/// format is available.
Future<ClipboardPasteData?> readNativeClipboardData() async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) return null;

  final reader = await clipboard.read();
  for (final imageFormat in _clipboardImageFormats) {
    if (!reader.canProvide(imageFormat.format)) continue;

    final image = await _readClipboardImage(reader, imageFormat);
    if (image != null && image.bytes.isNotEmpty) {
      return ClipboardPasteData(
        imageBytes: image.bytes,
        fileName: image.fileName,
        mimeType: imageFormat.mimeType,
      );
    }
  }

  return ClipboardPasteData(text: await reader.readValue(Formats.plainText));
}

class _ClipboardImage {
  const _ClipboardImage(this.bytes, this.fileName);

  final Uint8List bytes;
  final String? fileName;
}

Future<_ClipboardImage?> _readClipboardImage(
  ClipboardReader reader,
  _ClipboardImageFormat imageFormat,
) async {
  final result = Completer<_ClipboardImage?>();
  final progress = reader.getFile(
    imageFormat.format,
    (file) async {
      try {
        final bytes = await file.readAll();
        if (!result.isCompleted) {
          result.complete(_ClipboardImage(bytes, file.fileName));
        }
      } catch (error, stackTrace) {
        if (!result.isCompleted) result.completeError(error, stackTrace);
      }
    },
    onError: (error) {
      if (!result.isCompleted) result.completeError(error);
    },
  );
  if (progress == null) return null;

  try {
    return await result.future.timeout(const Duration(seconds: 30));
  } catch (_) {
    return null;
  }
}
