import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';

class StorageService {
  static const _habitsKey = 'habits_v2';
  static const _todosKey = 'todos_v2';
  static const _moodsKey = 'moods_v1';
  static const _timerKey = 'focus_seconds_v1';
  static const _pinKey = 'app_pin_v1';
  static const _nameKey = 'profile_name_v1';

  Future<List<Habit>> loadHabits() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_habitsKey) ?? p.getString('habits_v1');
      if (raw == null) return defaultHabits();
      return (jsonDecode(raw) as List).map((e) => Habit.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) { return defaultHabits(); }
  }

  Future<void> saveHabits(List<Habit> habits) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_habitsKey, jsonEncode(habits.map((h) => h.toJson()).toList()));
  }

  Future<List<Map<String, dynamic>>> loadTodos() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_todosKey) ?? p.getString('todos_v1');
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { return []; }
  }

  Future<void> saveTodos(List<Map<String, dynamic>> todos) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_todosKey, jsonEncode(todos));
  }

  Future<Map<String, int>> loadMoods() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_moodsKey);
      if (raw == null) return {};
      return Map<String, int>.from((jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', (v as num).toInt())));
    } catch (_) { return {}; }
  }

  Future<void> saveMoods(Map<String, int> moods) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_moodsKey, jsonEncode(moods));
  }

  Future<Map<String, int>> loadTimerSeconds() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_timerKey);
      if (raw == null) return {};
      return Map<String, int>.from((jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', (v as num).toInt())));
    } catch (_) { return {}; }
  }

  Future<void> saveTimerSeconds(Map<String, int> data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_timerKey, jsonEncode(data));
  }

  Future<String?> loadPin() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_pinKey);
  }

  Future<void> savePin(String? pin) async {
    final p = await SharedPreferences.getInstance();
    if (pin == null || pin.isEmpty) await p.remove(_pinKey); else await p.setString(_pinKey, pin);
  }

  Future<String> loadName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_nameKey) ?? '';
  }

  Future<void> saveName(String name) async {
    final p = await SharedPreferences.getInstance();
    final value = name.trim();
    if (value.isEmpty) {
      await p.remove(_nameKey);
    } else {
      await p.setString(_nameKey, value);
    }
  }

  List<Habit> defaultHabits() {
    const names = ['Wake up at 05:00', 'Gym', 'Reading / Learning', 'Day Planning', 'Project Work', 'Social Media Detox', 'Goal Journaling', 'Cold Shower', '10k Steps', 'Plan Tomorrow', 'Drink Water', 'Sleep on Time'];
    return List.generate(names.length, (i) => Habit(
      id: 'default_$i', name: names[i], goal: i == 8 ? 10000 : 1,
      unit: i == 8 ? 'steps' : 'times',
      category: i < 4 ? 'Mind & Body' : i < 8 ? 'Productivity' : 'Goals',
    ));
  }
}
