// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter, unnecessary_cast
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/services.dart';

/// Web implementation using dart:html.
void disableBrowserContextMenu() {
  SystemChannels.platform.invokeMethod('BrowserContextMenu.disable');
  html.window.document.onContextMenu.listen((event) => event.preventDefault());
}

void enableBrowserContextMenu() {
  SystemChannels.platform.invokeMethod('BrowserContextMenu.enable');
}

StreamSubscription? listenToNativePaste(
    void Function(Uint8List bytes, String fileName, String mimeType) onImagePasted) {
  return html.document.onPaste.listen((event) {
    final clipboardEvent = event as html.ClipboardEvent;
    final items = clipboardEvent.clipboardData?.items;
    if (items == null) return;

    final count = items.length ?? 0;
    for (int i = 0; i < count; i++) {
      final item = items[i];
      if (item.type != null && item.type!.startsWith('image/')) {
        final blob = item.getAsFile();
        if (blob != null) {
          clipboardEvent.preventDefault();

          final reader = html.FileReader();
          reader.readAsArrayBuffer(blob);
          reader.onLoadEnd.first.then((_) {
            final bytes = reader.result as Uint8List;
            final fileName = blob.name.isNotEmpty
                ? blob.name
                : 'pasted_image_${DateTime
                .now()
                .millisecondsSinceEpoch}.png';
            onImagePasted(bytes, fileName, blob.type);
          });
          break;
        }
      }
    }
  });
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

  final htmlContent = '<!DOCTYPE html><html><body><script>'
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