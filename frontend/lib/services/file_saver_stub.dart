import 'dart:async';

Future<void> saveTextFile(String filename, String text,
    {String mimeType = 'text/plain'}) {
  return Future.error(
    UnsupportedError('Saving files is not supported on this platform yet.'),
  );
}