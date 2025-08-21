import 'package:shared_preferences/shared_preferences.dart';

class GoalsService {
  static const List<String> _keys = [
    'calories',
    'protein',
    'carbs',
    'fat',
    'fiber',
    'sugar',
    'sodium',
  ];

  Future<Map<String, double>> getGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, double> goals = {};
    for (final k in _keys) {
      final v = prefs.getDouble('goal_$k');
      if (v != null) goals[k] = v;
    }
    return goals;
  }

  Future<void> setGoals(Map<String, double> goals) async {
    final prefs = await SharedPreferences.getInstance();
    for (final e in goals.entries) {
      await prefs.setDouble('goal_${e.key}', e.value);
    }
  }

  Future<void> clearGoals() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in _keys) {
      await prefs.remove('goal_$k');
    }
  }
}