// lib/core/api_base.dart
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Build-time override: pass with
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000
const _env = String.fromEnvironment('API_BASE_URL');

String _defaultBase() {
  if (kIsWeb) return 'http://localhost:8000'; // dev only
  // Physical Android device during dev: use your machine's LAN IP
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://192.168.1.23:8000';
  return 'http://localhost:8000';
}

/// Final base (no trailing slash). ApiClient will append `/api`.
final String apiBase = (() {
  final raw = _env.isNotEmpty ? _env : _defaultBase();
  return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
})();
