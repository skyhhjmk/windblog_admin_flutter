// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter, unnecessary_cast
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mime/mime.dart';

final Set<String> _registeredGrafanaFrames = <String>{};

Widget buildIFrame(String url) {
  final viewType = 'windblog-grafana-${url.hashCode}';
  if (_registeredGrafanaFrames.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      return html.IFrameElement()
        ..src = url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('referrerpolicy', 'same-origin')
        ..setAttribute('allow', 'fullscreen');
    });
  }
  return HtmlElementView(viewType: viewType);
}

/// Web implementation using dart:html.
void disableBrowserContextMenu() {
  SystemChannels.platform.invokeMethod('BrowserContextMenu.disable');
  html.window.document.onContextMenu.listen((event) => event.preventDefault());
}

void enableBrowserContextMenu() {
  SystemChannels.platform.invokeMethod('BrowserContextMenu.enable');
}

typedef PastedFileCallback =
    void Function(Uint8List bytes, String fileName, String mimeType);

/// Reports every file on the clipboard — screenshots, copied documents,
/// archives, 3D models and so on. Clipboard entries without a file are left
/// untouched so Flutter's built-in plain-text paste keeps working.
StreamSubscription? listenToNativePaste(PastedFileCallback onFilePasted) {
  return html.document.onPaste.listen((event) async {
    final clipboardEvent = event as html.ClipboardEvent;
    final data = clipboardEvent.clipboardData;
    if (data == null) return;

    final files = <html.File>[];
    final items = data.items;
    final itemCount = items?.length ?? 0;
    for (var i = 0; i < itemCount; i++) {
      final item = items![i];
      if (item.kind != 'file') continue;
      final file = item.getAsFile();
      if (file != null) files.add(file);
    }
    if (files.isEmpty) {
      // Some browsers only expose files through the FileList.
      final directFiles = data.files;
      final directCount = directFiles?.length ?? 0;
      for (var i = 0; i < directCount; i++) {
        files.add(directFiles![i]);
      }
    }
    if (files.isEmpty) return;

    clipboardEvent.preventDefault();

    // Read every file before reporting so multiple pasted files keep their
    // clipboard order in the document.
    final pasted = <_PastedClipboardFile>[];
    for (final file in files) {
      final bytes = await _readClipboardFileBytes(file);
      if (bytes == null || bytes.isEmpty) continue;
      final fileName = _clipboardFileName(file);
      pasted.add(
        _PastedClipboardFile(
          bytes: bytes,
          fileName: fileName,
          mimeType: _clipboardMimeType(file, fileName),
        ),
      );
    }
    for (final file in pasted) {
      onFilePasted(file.bytes, file.fileName, file.mimeType);
    }
  });
}

Future<Uint8List?> _readClipboardFileBytes(html.File file) async {
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  try {
    await reader.onLoadEnd.first;
  } catch (_) {
    return null;
  }
  final result = reader.result;
  if (result is Uint8List) return result;
  if (result is ByteBuffer) return result.asUint8List();
  return null;
}

String _clipboardFileName(html.File file) {
  final name = file.name.trim();
  if (name.isNotEmpty) return name;
  final extension = extensionFromMime(file.type);
  final suffix = (extension == null || extension.isEmpty) ? 'bin' : extension;
  return 'pasted_file_${DateTime.now().millisecondsSinceEpoch}.$suffix';
}

String _clipboardMimeType(html.File file, String fileName) {
  final declared = file.type.trim().toLowerCase();
  if (declared.isNotEmpty) return declared;
  return lookupMimeType(fileName) ?? 'application/octet-stream';
}

class _PastedClipboardFile {
  const _PastedClipboardFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

void openUrl(String url) {
  html.window.open(url, '_blank');
}

void downloadFile(Uint8List bytes, String fileName, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final blobUrl = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: blobUrl)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body!.children.add(anchor);
  anchor.click();

  Future.delayed(const Duration(milliseconds: 200), () {
    anchor.remove();
    html.Url.revokeObjectUrl(blobUrl);
  });
}

void saveFileWithPicker(Uint8List bytes, String fileName) {
  final blob = html.Blob([bytes], 'application/zip');
  final blobUrl = html.Url.createObjectUrlFromBlob(blob);

  final htmlContent =
      '<!DOCTYPE html><html><body><script>'
      'window.parent._windblogSavePicker("$blobUrl","$fileName");'
      '</script></body></html>';

  final iframe = html.IFrameElement()
    ..style.display = 'none'
    ..srcdoc = htmlContent;

  html.document.body?.children.add(iframe);

  Future.delayed(const Duration(seconds: 60), () {
    html.Url.revokeObjectUrl(blobUrl);
    iframe.remove();
  });
}
