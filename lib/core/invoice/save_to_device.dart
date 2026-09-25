import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Saves [bytes] to the device, where the person chooses, and says whether it
/// happened.
///
/// This is the "download": the file lands on the device the person is holding
/// and nothing is sent anywhere. Sharing is a separate, deliberate step that
/// the caller offers afterwards.
///
/// The system "save as" sheet does the choosing. On Android and iOS it writes
/// [bytes] itself, through the Storage Access Framework on Android, so no
/// storage permission is needed. On Windows, Linux and macOS it only returns
/// the chosen path, so the bytes are written here. On the web the browser
/// downloads the file.
///
/// Returns where it was saved, or null when the person cancelled the sheet.
Future<String?> saveToDevice({
  required String filename,
  required Uint8List bytes,
  String? dialogTitle,
}) async {
  final target = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle ?? 'Save $filename',
    fileName: filename,
    bytes: bytes,
  );

  // The browser gives no answer to a save; a download that started is saved.
  if (kIsWeb) return filename;
  if (target == null) return null;

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await File(target).writeAsBytes(bytes);
  }
  return target;
}
