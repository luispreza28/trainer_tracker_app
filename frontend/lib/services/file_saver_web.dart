import 'dart:convert';
import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter, deprecated_member_use


Future<void> saveTextFile(String filename, String text,
    {String mimeType = 'text/plain'}) async {
  final bytes = utf8.encode(text);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = filename;
  // Ensure it's attached long enough to click in some browsers
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}