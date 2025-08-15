// frontend/lib/services/api_client.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

import '../models/food.dart';
import 'auth_service.dart';

/// Base API exception used by the client.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}

/// Thrown when the server returns 404 for a resource.
class NotFoundException extends ApiException {
  NotFoundException(String message) : super(message);
}

class ApiClient {
  /// Base URL like `http://127.0.0.1:8000/api` (web/desktop)
  /// or `http://10.0.2.2:8000/api` (Android emulator).
  final String baseUrl;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? detectBaseUrl();

  /// Pick a sensible default without importing `dart:io`
  /// so the code remains web-compatible.
  static String detectBaseUrl() {
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator loopback:
      return 'http://10.0.2.2:8000/api';
    }
    // iOS sim, desktop, or real device (works with `adb reverse`)
    return 'http://127.0.0.1:8000/api';
  }

  /// Build common headers, including token if present.
  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Token $token',
    };
  }

  /// Import (or create) a Food by barcode via the backend proxy.
  ///
  /// POST {baseUrl}/foods/import/barcode/<code>/
  /// 200 => returns Food JSON
  /// 404 => product not found
  /// other => throws ApiException with status/body
  Future<Food> importByBarcode(String code) async {
    final uri = Uri.parse('$baseUrl/foods/import/barcode/$code/'); // ← note trailing slash
    final headers = await _headers();

    http.Response resp;
    try {
      resp = await http
          .post(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw ApiException('Network timeout');
    } catch (e) {
      throw ApiException('Network error: $e');
    }

    final status = resp.statusCode;
    if (status == 200 || status == 201) {
      final data = json.decode(resp.body) as Map<String, dynamic>;
      return Food.fromJson(data);
    } else if (status == 404) {
      throw NotFoundException('Product not found');
    } else {
      throw ApiException('HTTP $status: ${resp.body}');
    }
  }

  Future<void> addMeal({
    required int foodId,
    required double grams,
    String? mealType,
    DateTime? consumedAt,
  }) async {
    final uri = Uri.parse('$baseUrl/meals/');
    final headers = await _headers();
    final body = <String, dynamic>{
      'food': foodId,
      'grams': grams,
      if (mealType != null) 'meal_type': mealType,
      if (consumedAt != null) 'consumed_at': consumedAt.toIso8601String(),
    };
    http.Response resp;
    try {
      resp = await http
          .post(uri, headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw ApiException('Network timeout');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
    final status = resp.statusCode;
    if (status == 201 || status == 200) {
      return;
    } else {
      throw ApiException('HTTP $status: ${resp.body}');
    }
  }
}
