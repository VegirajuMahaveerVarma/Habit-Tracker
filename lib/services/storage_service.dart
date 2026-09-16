import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';
import '../models/reminder_settings.dart';

class StorageService {
  static const _habitsKey = 'habits_v1';
  static const _todosKey = 'todos_v1';
  static const _reminderKey = 'reminder_settings_v1';

  Future<List<Habit>> loadHabits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_habitsKey);
      if (raw == null) return defaultHabits();
      return (jsonDecode(raw) as List)
          .map((e) => Habit.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return defaultHabits();
    }
  }

  Future<void> saveHabits(List<Habit> habits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_habitsKey, jsonEncode(habits.map((h) => h.toJson()).toList()));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_todosKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTodos(List<Map<String, dynamic>> todos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_todosKey, jsonEncode(todos));
    } catch (_) {}
  }

  Future<ReminderSettings> loadReminderSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_reminderKey);
      if (raw == null) return const ReminderSettings();
      return ReminderSettings.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const ReminderSettings();
    }
  }

  Future<void> saveReminderSettings(ReminderSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_reminderKey, jsonEncode(settings.toJson()));
    } catch (_) {}
  }

  List<Habit> defaultHabits() {
    const names = [
      'Wake up at 05:00', 'Gym', 'Reading / Learning', 'Day Planning',
      'Project Work', 'Social Media Detox', 'Goal Journaling', 'Cold Shower',
      '10k Steps', 'Plan Tomorrow', 'Drink Water', 'Sleep on Time',
    ];
    return List.generate(names.length, (i) => Habit(
      id: 'default_$i', name: names[i],
      category: i < 4 ? 'Mind & Body' : i < 8 ? 'Productivity' : 'Goals',
    ));
  }
}
