class Habit {
  final String id;
  String _name;
  String category;
  int goal;
  String unit;
  String frequency;
  List<int> weekdays;
  bool active;
  bool pinned;
  String icon;
  List<String> tags;
  String notes;
  final Map<String, bool> completions;
  final Map<String, double> measurements;
  final Map<String, String> journal;

  Habit({
    required this.id,
    required String name,
    this.category = 'Daily',
    this.goal = 1,
    this.unit = 'times',
    this.frequency = 'Every day',
    List<int>? weekdays,
    this.active = true,
    this.pinned = false,
    this.icon = 'check_circle',
    List<String>? tags,
    this.notes = '',
    Map<String, bool>? completions,
    Map<String, double>? measurements,
    Map<String, String>? journal,
  }) : _name = name,
       weekdays = weekdays ?? const [1, 2, 3, 4, 5, 6, 7],
       tags = tags ?? [],
       completions = completions ?? {},
       measurements = measurements ?? {},
       journal = journal ?? {};

  String get name => _name;
  set name(String value) => _name = value.trim();

  bool isScheduled(DateTime date) {
    if (frequency == 'Every day') return true;
    if (frequency == 'Weekdays') return date.weekday >= 1 && date.weekday <= 5;
    return weekdays.contains(date.weekday);
  }

  bool isDone(DateTime date) => completions[key(date)] == true;
  void setDone(DateTime date, bool value) => completions[key(date)] = value;

  int completedInMonth(DateTime month) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    var count = 0;
    for (var d = 1; d <= days; d++) {
      if (isDone(DateTime(month.year, month.month, d))) count++;
    }
    return count;
  }

  int scheduledInMonth(DateTime month) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    var count = 0;
    for (var d = 1; d <= days; d++) {
      if (isScheduled(DateTime(month.year, month.month, d))) count++;
    }
    return count;
  }

  double completionRate(DateTime month) {
    final scheduled = scheduledInMonth(month);
    if (scheduled == 0) return 0;
    return completedInMonth(month) / scheduled;
  }

  int currentStreak([DateTime? from]) {
    var day = _dateOnly(from ?? DateTime.now());
    var streak = 0;
    var checked = 0;
    while (checked < 5000) {
      if (isScheduled(day)) {
        if (!isDone(day)) break;
        streak++;
      }
      day = day.subtract(const Duration(days: 1));
      checked++;
    }
    return streak;
  }

  int bestStreak([DateTime? through]) {
    if (completions.isEmpty) return 0;
    final end = _dateOnly(through ?? DateTime.now());
    final keys = completions.entries.where((e) => e.value).map((e) => e.key).toList()..sort();
    DateTime start;
    try { start = DateTime.parse(keys.first); } catch (_) { start = end.subtract(const Duration(days: 365)); }
    var best = 0, running = 0, guard = 0;
    var day = start;
    while (!day.isAfter(end) && guard < 10000) {
      if (!isScheduled(day)) {
        day = day.add(const Duration(days: 1));
        guard++;
        continue;
      }
      if (isDone(day)) { running++; if (running > best) best = running; }
      else { running = 0; }
      day = day.add(const Duration(days: 1));
      guard++;
    }
    return best;
  }

  int totalCompletions() => completions.values.where((v) => v).length;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': _name, 'category': category, 'goal': goal, 'unit': unit,
    'frequency': frequency, 'weekdays': weekdays, 'active': active, 'pinned': pinned,
    'icon': icon, 'tags': tags, 'notes': notes, 'completions': completions,
    'measurements': measurements, 'journal': journal,
  };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
    id: '${json['id']}', name: '${json['name'] ?? 'Habit'}',
    category: '${json['category'] ?? 'Daily'}', goal: (json['goal'] as num?)?.toInt() ?? 1,
    unit: '${json['unit'] ?? 'times'}', frequency: '${json['frequency'] ?? 'Every day'}',
    weekdays: (json['weekdays'] as List?)?.map((e) => (e as num).toInt()).toList(),
    active: json['active'] as bool? ?? true, pinned: json['pinned'] as bool? ?? false,
    icon: '${json['icon'] ?? 'check_circle'}', tags: (json['tags'] as List?)?.map((e) => '$e').toList(),
    notes: '${json['notes'] ?? ''}', completions: Map<String, bool>.from(json['completions'] as Map? ?? {}),
    measurements: Map<String, double>.from((json['measurements'] as Map? ?? {}).map((key, value) => MapEntry('$key', (value as num).toDouble()))),
    journal: Map<String, String>.from((json['journal'] as Map? ?? {}).map((key, value) => MapEntry('$key', '$value'))),
  );

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
  static String key(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
