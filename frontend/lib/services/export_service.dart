import 'dart:convert';

class ExportService {
  /// CSV: one row per meal for [date] in [tz].
  /// Columns: date,tz,id,food_name,brand,grams,calories,protein,carbs,fat,fiber,sugar,sodium,meal_time,notes
  static String csvForDay({
    required String date,
    required String tz,
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> meals,
  }) {
    const headers = [
      'date',
      'tz',
      'id',
      'food_name',
      'brand',
      'grams',
      'calories',
      'protein',
      'carbs',
      'fat',
      'fiber',
      'sugar',
      'sodium',
      'meal_time',
      'notes',
    ];
    final lines = <String>[];
    lines.add(headers.join(','));
    for (final m in meals) {
      final totals = (m['totals'] as Map?) ?? const {};
      String esc(dynamic v) {
        final s = (v == null) ? '' : v.toString();
        return _csvEscape(s);
      }
      lines.add([
        esc(date),
        esc(tz),
        esc(m['id']),
        esc(m['food_name']),
        esc(m['brand']),
        esc(m['quantity']),
        esc(totals['calories']),
        esc(totals['protein']),
        esc(totals['carbs']),
        esc(totals['fat']),
        esc(totals['fiber']),
        esc(totals['sugar']),
        esc(totals['sodium']),
        esc(m['meal_time']),
        esc(m['notes']),
      ].join(','));
    }
    return lines.join('\r\n');
  }

  /// JSON: bundles summary and meals for [date] in [tz].
  static String jsonForDay({
    required String date,
    required String tz,
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> meals,
  }) {
    final payload = {
      'date': date,
      'tz': tz,
      'summary': summary, // includes totals/units/entries from API
      'meals': meals,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static String _csvEscape(String s) {
    // Double quotes and wrap if field contains comma/quote/newline
    final needsWrap = s.contains(RegExp(r'[",\r\n]'));
    final body = s.replaceAll('"', '""');
    return needsWrap ? '"$body"' : body;
  }
}