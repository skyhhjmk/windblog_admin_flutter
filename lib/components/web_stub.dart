import 'dart:async';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';

/// Stub implementation for non-web platforms.
void disableBrowserContextMenu() {
  // No-op on non-web platforms
}

void enableBrowserContextMenu() {
  // No-op on non-web platforms
}

StreamSubscription? listenToNativePaste(
    void Function(Uint8List bytes, String fileName, String mimeType) onImagePasted) {
  return null;
}

void openUrl(String url) {
  launchUrl(Uri.parse(url));
}
