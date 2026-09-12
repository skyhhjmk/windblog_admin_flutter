import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

/// Stub implementation for non-web platforms (desktop/mobile).
void disableBrowserContextMenu() {
  // No-op on non-web platforms
}

void enableBrowserContextMenu() {
  // No-op on non-web platforms
}

StreamSubscription? listenToNativePaste(
  void Function(Uint8List bytes, String fileName, String mimeType)
  onImagePasted,
) {
  return null;
}

void openUrl(String url) {
  launchUrl(Uri.parse(url));
}

Widget buildIFrame(String url) => Center(child: SelectableText(url));

void downloadFile(Uint8List bytes, String fileName, String mimeType) {
  final downloadsPath = _getDownloadsDirectory();
  if (downloadsPath == null) return;

  final filePath = '$downloadsPath/$fileName';
  final file = File(filePath);
  file.writeAsBytesSync(bytes);
}

Future<void> saveFileWithPicker(Uint8List bytes, String fileName) async {
  final String? result = await FilePicker.saveFile(
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['zip'],
  );

  if (result == null) return;

  final file = File(result);
  file.writeAsBytesSync(bytes);
}

String? _getDownloadsDirectory() {
  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) return null;
    return '$userProfile/Downloads';
  }

  if (Platform.isLinux) {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    return '$home/Downloads';
  }

  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    return '$home/Downloads';
  }

  return null;
}
