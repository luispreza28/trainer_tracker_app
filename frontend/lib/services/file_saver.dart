// Conditional import wrapper: web uses dart:html, Android/iOS use IO, others fall back to stub.
import 'file_saver_stub.dart'
  if (dart.library.html) 'file_saver_web.dart'
  if (dart.library.io) 'file_saver_io.dart' as impl;

Future<void> saveTextFile(String filename, String text,
    {String mimeType = 'text/plain'}) {
  return impl.saveTextFile(filename, text, mimeType: mimeType);
}