import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:super_clipboard/super_clipboard.dart';

class ClipboardPasteData {
  const ClipboardPasteData({
    this.bytes,
    this.fileName,
    this.mimeType,
    this.text,
  });

  /// Raw contents of a pasted image or file, when the clipboard carries one.
  final Uint8List? bytes;
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
/// accompanying text representation, then falls back to a file copied from the
/// OS file manager (any type: documents, archives, 3D models, ...), and finally
/// to plain text.
Future<ClipboardPasteData?> readNativeClipboardData() async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) return null;

  final reader = await clipboard.read();
  for (final imageFormat in _clipboardImageFormats) {
    if (!reader.canProvide(imageFormat.format)) continue;

    final image = await _readClipboardFile(reader, imageFormat.format);
    if (image != null && image.bytes.isNotEmpty) {
      return ClipboardPasteData(
        bytes: image.bytes,
        fileName: image.fileName,
        mimeType: imageFormat.mimeType,
      );
    }
  }

  final file = await _readClipboardFileUri(reader);
  if (file != null) return file;

  return ClipboardPasteData(text: await reader.readValue(Formats.plainText));
}

/// Reads a file that was copied in the system file manager. Only local
/// `file://` locations are readable; content-provider URIs are skipped.
Future<ClipboardPasteData?> _readClipboardFileUri(
  ClipboardReader reader,
) async {
  if (!reader.canProvide(Formats.fileUri)) return null;

  Uri? uri;
  try {
    uri = await reader.readValue(Formats.fileUri);
  } catch (_) {
    return null;
  }
  if (uri == null || !uri.isScheme('file')) return null;

  try {
    final file = File(uri.toFilePath());
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    final segments = uri.pathSegments;
    final fileName = segments.isEmpty
        ? file.uri.pathSegments.last
        : segments.last;
    return ClipboardPasteData(
      bytes: bytes,
      fileName: fileName,
      mimeType: lookupMimeType(fileName) ?? 'application/octet-stream',
    );
  } catch (_) {
    return null;
  }
}

class _ClipboardImage {
  const _ClipboardImage(this.bytes, this.fileName);

  final Uint8List bytes;
  final String? fileName;
}

Future<_ClipboardImage?> _readClipboardFile(
  ClipboardReader reader,
  FileFormat format,
) async {
  final result = Completer<_ClipboardImage?>();
  final progress = reader.getFile(
    format,
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
