class Habit {
  final String id;
  String name;
  String category;
  int goal;
  bool active;
  final Map<String, bool> completions;

  Habit({
    required this.id,
    required this.name,
    this.category = 'Daily',
    this.goal = 30,
    this.active = true,
    Map<String, bool>? completions,
  }) : completions = completions ?? {};

  int completedInMonth(DateTime month) {
    var count = 0;
    final days = DateTime(month.year, month.month + 1, 0).day;
    for (var d = 1; d <= days; d++) {
      if (completions[key(DateTime(month.year, month.month, d))] == true) count++;
    }
    return count;
  }

  bool isDone(DateTime date) => completions[key(date)] == true;
  void setDone(DateTime date, bool value) => completions[key(date)] = value;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
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

  static String key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
