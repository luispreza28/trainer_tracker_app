// lib/core/api_base.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

const _env = String.fromEnvironment('API_BASE_URL');

String defaultBase() {
  if (kIsWeb) return 'http://localhost:8000';
  // Emulator default. On a phone this would time out (so use --dart-define).
  if (Platform.isAndroid) return 'http://10.0.2.2:8000';
  return 'http://localhost:8000';
}

final String apiBase = _env.isNotEmpty ? _env : defaultBase();
