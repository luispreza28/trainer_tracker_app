// Conditional import wrapper to keep Android builds happy later.
import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart' as impl;

Future<void> saveTextFile(String filename, String text,
    {String mimeType = 'text/plain'}) {
  return impl.saveTextFile(filename, text, mimeType: mimeType);
}