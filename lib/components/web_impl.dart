import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mime/mime.dart';
import 'package:web/web.dart' as web;

@JS('_windblogSavePicker')
external void _windblogSavePicker(JSString blobUrl, JSString fileName);

const _contextMenuEvents = web.EventStreamProvider<web.MouseEvent>(
  'contextmenu',
);
const _pasteEvents = web.EventStreamProvider<web.ClipboardEvent>('paste');

final Set<String> _registeredGrafanaFrames = <String>{};
StreamSubscription<web.MouseEvent>? _contextMenuSubscription;

Widget buildIFrame(String url) {
  final viewType = 'windblog-grafana-${url.hashCode}';
  if (_registeredGrafanaFrames.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
      iframe.setAttribute('referrerpolicy', 'same-origin');
      iframe.setAttribute('allow', 'fullscreen');
      return iframe;
    });
  }
  return HtmlElementView(viewType: viewType);
}

/// Web implementation using package:web and dart:js_interop (WASM + JS compatible).
void disableBrowserContextMenu() {
  SystemChannels.platform.invokeMethod('BrowserContextMenu.disable');
  _contextMenuSubscription ??= _contextMenuEvents
      .forTarget(web.document)
      .listen((event) => event.preventDefault());
}

void enableBrowserContextMenu() {
  _contextMenuSubscription?.cancel();
  _contextMenuSubscription = null;
  SystemChannels.platform.invokeMethod('BrowserContextMenu.enable');
}

typedef PastedFileCallback =
    void Function(Uint8List bytes, String fileName, String mimeType);

/// Reports every file on the clipboard — screenshots, copied documents,
/// archives, 3D models and so on. Clipboard entries without a file are left
/// untouched so Flutter's built-in plain-text paste keeps working.
StreamSubscription? listenToNativePaste(PastedFileCallback onFilePasted) {
  return _pasteEvents.forTarget(web.document).listen((event) async {
    final data = event.clipboardData;
    if (data == null) return;

    final files = <web.File>[];
    final items = data.items;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.kind != 'file') continue;
      final file = item.getAsFile();
      if (file != null) files.add(file);
    }
    if (files.isEmpty) {
      // Some browsers only expose files through the FileList.
      final directFiles = data.files;
      for (var i = 0; i < directFiles.length; i++) {
        final file = directFiles.item(i);
        if (file != null) files.add(file);
      }
    }
    if (files.isEmpty) return;

    event.preventDefault();

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

Future<Uint8List?> _readClipboardFileBytes(web.File file) async {
  final reader = web.FileReader();
  reader.readAsArrayBuffer(file);
  try {
    await reader.onLoadEnd.first;
  } catch (_) {
    return null;
  }
  final result = reader.result;
  if (result == null) return null;
  if (result.isA<JSArrayBuffer>()) {
    return (result as JSArrayBuffer).toDart.asUint8List();
  }
  return null;
}

String _clipboardFileName(web.File file) {
  final name = file.name.trim();
  if (name.isNotEmpty) return name;
  final extension = extensionFromMime(file.type);
  final suffix = (extension == null || extension.isEmpty) ? 'bin' : extension;
  return 'pasted_file_${DateTime.now().millisecondsSinceEpoch}.$suffix';
}

String _clipboardMimeType(web.File file, String fileName) {
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
  web.window.open(url, '_blank');
}

void downloadFile(Uint8List bytes, String fileName, String mimeType) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final blobUrl = web.URL.createObjectURL(blob);

  final anchor = web.HTMLAnchorElement()
    ..href = blobUrl
    ..download = fileName;
  anchor.style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();

  Future.delayed(const Duration(milliseconds: 200), () {
    anchor.remove();
    web.URL.revokeObjectURL(blobUrl);
  });
}

void saveFileWithPicker(Uint8List bytes, String fileName) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/zip'),
  );
  final blobUrl = web.URL.createObjectURL(blob);

  _windblogSavePicker(blobUrl.toJS, fileName.toJS);

  Future.delayed(const Duration(seconds: 60), () {
    web.URL.revokeObjectURL(blobUrl);
  });
}
