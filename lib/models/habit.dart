class Habit {
  final String id;
  String _name;
  String category;
  int goal;
  bool active;
  bool reminderEnabled;
  int reminderHour;
  int reminderMinute;
  final Map<String, bool> completions;

  Habit({
    required this.id,
    required String name,
    this.category = 'Daily',
    this.goal = 30,
    this.active = true,
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    Map<String, bool>? completions,
  })  : _name = name,
        completions = completions ?? {};

  String get name => _name;
  String get displayName {
    final streak = currentStreak();
    if (streak <= 0) return _name;
    return '$_name  🔥 $streak ${streak == 1 ? 'day' : 'days'}';
  }

  set name(String value) => _name = value.trim();

  int completedInMonth(DateTime month) {
    var count = 0;
    final days = DateTime(month.year, month.month + 1, 0).day;
    for (var d = 1; d <= days; d++) {
      if (isDone(DateTime(month.year, month.month, d))) count++;
    }
    return count;
  }

  int currentStreak([DateTime? from]) {
    var day = _dateOnly(from ?? DateTime.now());
    if (!isDone(day)) day = day.subtract(const Duration(days: 1));
    var streak = 0;
    while (isDone(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int bestStreak([DateTime? through]) {
    final end = _dateOnly(through ?? DateTime.now());
    var best = 0;
    var running = 0;
    for (var i = 0; i <= 365; i++) {
      final day = end.subtract(Duration(days: 365 - i));
      if (isDone(day)) {
        running++;
        if (running > best) best = running;
      } else {
        running = 0;
      }
    }
    return best;
  }

  bool isDone(DateTime date) => completions[key(date)] == true;
  void setDone(DateTime date, bool value) => completions[key(date)] = value;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': _name,
        'category': category,
        'goal': goal,
        'active': active,
        'reminderEnabled': reminderEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'completions': completions,
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? 'Daily',
        goal: json['goal'] as int? ?? 30,
        active: json['active'] as bool? ?? true,
        reminderEnabled: json['reminderEnabled'] as bool? ?? false,
        reminderHour: json['reminderHour'] as int? ?? 20,
        reminderMinute: json['reminderMinute'] as int? ?? 0,
        completions: Map<String, bool>.from(json['completions'] as Map? ?? {}),
      );

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  static String key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
