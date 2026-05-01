import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
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
    final html.ClipboardEvent clipboardEvent = event as html.ClipboardEvent;
    final items = clipboardEvent.clipboardData?.items;
    if (items == null) return;

    for (int i = 0; i < items.length; i++) {
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
