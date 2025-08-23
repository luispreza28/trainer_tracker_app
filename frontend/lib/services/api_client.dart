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
  NotFoundException(super.message);
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
  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await AuthService.getToken();
    final h = <String, String>{'Accept': 'application/json'};
    if (json) h['Content-Type'] = 'application/json; charset=utf-8';
    if (token != null && token.trim().isNotEmpty) {
      h['Authorization'] = 'Token ${token.trim()}'; // <- add prefix exactly once
    }
    return h;
  }

  /// Import (or create) a Food by barcode via the backend proxy.
  ///
  /// POST {baseUrl}/foods/import/barcode/<code>/
  /// 200 => returns Food JSON
  /// 404 => product not found
  /// other => throws ApiException with status/body
  Future<Food> importByBarcode(String code) async {
    final uri = Uri.parse('$baseUrl/foods/import/barcode/$code/');
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
      throw ApiException('Product not found');
    } else if (status == 401 || status == 403) {
      throw ApiException('Authentication required. Please enter your API token.');
    } else {
      throw ApiException('HTTP $status: ${resp.body}');
    }
  }

  Future<void> addMeal({
    required int foodId,
    required double quantity,
    DateTime? mealTime,
    String? notes,
  }) async {
    final uri = Uri.parse('$baseUrl/meals/');
    final headers = await _headers();
    final body = <String, dynamic>{
      'food': foodId,
      'quantity': quantity,
      if (mealTime != null) 'meal_time': mealTime.toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
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
    if (status != 201 && status != 200) {
      throw ApiException('HTTP $status: ${resp.body}');
    }
  }

  Future<Map<String, dynamic>> getDailySummary(String date, String tz) async {
    final token = await AuthService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Token $token',
    };
    final uri = Uri.parse('$baseUrl/meals/summary/').replace(queryParameters: {'date': date, 'tz': tz});
    final res = await http.get(uri, headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 404) {
      throw NotFoundException('Summary not found for $date ($tz)');
    }
    throw ApiException('Failed to fetch summary (${res.statusCode}): ${res.body}');
  }

  Future<List<Map<String, dynamic>>> getMealsForDate(String date, {required String tz}) async {
    final token = await AuthService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Token $token',
    };
    final uri = Uri.parse('$baseUrl/meals/').replace(queryParameters: {'date': date, 'tz': tz});
       final res = await http.get(uri, headers: headers);
    if (res.statusCode == 200) {
      final decoded = json.decode(res.body);
      List items;
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['results'] is List) {
        items = decoded['results'] as List;
      } else if (decoded is Map) {
        throw ApiException('Unexpected meals response: $decoded');
      } else {
        throw ApiException('Unexpected meals response type: ${decoded.runtimeType}');
      }
      return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    throw ApiException('Failed to fetch meals (${res.statusCode}): ${res.body}');
  }

  Future<void> deleteMeal(int id) async {
    final uri = Uri.parse('$baseUrl/meals/$id/');
    final r = await http.delete(uri, headers: await _headers()).timeout(const Duration(seconds: 10));
    if (r.statusCode != 204) throw ApiException('HTTP ${r.statusCode}: ${r.body}');
  }

  Future<void> updateMealQuantity(int id, double grams) async {
    final uri = Uri.parse('$baseUrl/meals/$id/');
    final body = json.encode({'quantity': grams});
    final r = await http.patch(uri, headers: await _headers(), body: body).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw ApiException('HTTP ${r.statusCode}: ${r.body}');
  }

  Future<Map<String, dynamic>> getSummary({
    required String date,
    required String tz,
  }) {
    return getDailySummary(date, tz);
  }
  
}
