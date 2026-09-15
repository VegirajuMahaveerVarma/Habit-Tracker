class Habit {
  final String id;
  String _name;
  String category;
  int goal;
  bool active;
  final Map<String, bool> completions;

  Habit({
    required this.id,
    required String name,
    this.category = 'Daily',
    this.goal = 30,
    this.active = true,
    Map<String, bool>? completions,
  })  : _name = name,
        completions = completions ?? {};

  String get name {
    final streak = currentStreak();
    if (streak <= 0) return _name;
    final unit = streak == 1 ? 'day' : 'days';
    return '$_name  🔥 $streak $unit';
  }

  set name(String value) {
    _name = value.replaceFirst(RegExp(r'\s+🔥\s+\d+\s+(?:day|days)\$'), '');
  }

  int completedInMonth(DateTime month) {
    var count = 0;
    final days = DateTime(month.year, month.month + 1, 0).day;
    for (var d = 1; d <= days; d++) {
      if (completions[key(DateTime(month.year, month.month, d))] == true) {
        count++;
      }
    }
    return count;
  }

  int currentStreak([DateTime? from]) {
    var day = _dateOnly(from ?? DateTime.now());
    if (!isDone(day)) {
      day = day.subtract(const Duration(days: 1));
    }

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
        'completions': completions,
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? 'Daily',
        goal: json['goal'] as int? ?? 30,
        active: json['active'] as bool? ?? true,
        completions: Map<String, bool>.from(json['completions'] as Map? ?? {}),
      );

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
