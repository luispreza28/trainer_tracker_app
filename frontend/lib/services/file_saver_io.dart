import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Save text to a temp file and open the native share sheet (Android/iOS).
Future<void> saveTextFile(String filename, String text,
    {String mimeType = 'text/plain'}) async {
  // Write to app's temp dir; no storage permission required.
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$filename';
  final file = File(path);
  await file.writeAsString(text, flush: true);

  // Trigger the system share sheet so the user can Save/Send.
  final xfile = XFile(path, mimeType: mimeType, name: filename);
  await Share.shareXFiles([xfile], text: 'Exported $filename');
}
