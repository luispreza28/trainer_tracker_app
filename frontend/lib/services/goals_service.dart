import 'package:shared_preferences/shared_preferences.dart';

class GoalsService {
  static const _keys = [
    'goal_calories',
    'goal_protein',
    'goal_carbs',
    'goal_fat',
    'goal_fiber',
    'goal_sugar',
    'goal_sodium',
  ];

  Future<Map<String, double>> getGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, double> goals = {};
    for (final key in _keys) {
      goals[key] = prefs.getDouble(key) ?? 0.0;
    }
    return goals;
  }

  Future<void> setGoals(Map<String, double> goals) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _keys) {
      await prefs.setDouble(key, goals[key] ?? 0.0);
    }
  }
}
