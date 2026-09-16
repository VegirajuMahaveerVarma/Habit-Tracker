from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

replacements = [
("""    for (final habit in habits.where((item) => item.active)) {
      await notifications.scheduleDaily(
        id: _notificationId(habit),
        habitName: habit.name,
        hour: settings.hour,
        minute: settings.minute,
      );
    }""", """    for (final habit in habits.where((item) => item.active && item.reminderEnabled)) {
      await notifications.scheduleDaily(
        id: _notificationId(habit),
        habitName: habit.name,
        hour: habit.reminderHour,
        minute: habit.reminderMinute,
      );
    }"""),
("""          category: result.category,
          goal: result.goal,
        ),""", """          category: result.category,
          goal: result.goal,
          reminderEnabled: result.reminderEnabled,
          reminderHour: result.reminderHour,
          reminderMinute: result.reminderMinute,
        ),"""),
("""    habit.name = result.name.trim();
    habit.category = result.category;
    habit.goal = result.goal;
    setState(() {});""", """    habit.name = result.name.trim();
    habit.category = result.category;
    habit.goal = result.goal;
    habit.reminderEnabled = result.reminderEnabled;
    habit.reminderHour = result.reminderHour;
    habit.reminderMinute = result.reminderMinute;
    setState(() {});"""),
("""class HabitEditResult {
  final String name;
  final String category;
  final int goal;
  final bool delete;

  const HabitEditResult({
    this.name = '',
    this.category = 'Daily',
    this.goal = 30,
    this.delete = false,
  });
}""", """class HabitEditResult {
  final String name;
  final String category;
  final int goal;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool delete;

  const HabitEditResult({
    this.name = '',
    this.category = 'Daily',
    this.goal = 30,
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.delete = false,
  });
}"""),
("""  late String category;
  late double goal;
""", """  late String category;
  late double goal;
  late bool reminderEnabled;
  late TimeOfDay reminderTime;
"""),
("""    goal = (widget.habit?.goal ?? 30).clamp(1, 31).toDouble();
""", """    goal = (widget.habit?.goal ?? 30).clamp(1, 31).toDouble();
    reminderEnabled = widget.habit?.reminderEnabled ?? false;
    reminderTime = TimeOfDay(
      hour: widget.habit?.reminderHour ?? 20,
      minute: widget.habit?.reminderMinute ?? 0,
    );
"""),
("""        category: category,
        goal: goal.round(),
      ),""", """        category: category,
        goal: goal.round(),
        reminderEnabled: reminderEnabled,
        reminderHour: reminderTime.hour,
        reminderMinute: reminderTime.minute,
      ),"""),
("""              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(""", """              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('Daily reminder', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(reminderEnabled ? 'Reminder is on' : 'Reminder is off'),
                      secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.blue),
                      value: reminderEnabled,
                      onChanged: (value) => setState(() => reminderEnabled = value),
                    ),
                    if (reminderEnabled)
                      ListTile(
                        leading: const Icon(Icons.alarm, color: AppColors.blue),
                        title: const Text('Reminder time', style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(reminderTime.format(context)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: reminderTime);
                          if (picked != null) setState(() => reminderTime = picked);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column("""),
("""    final days = DateTime(date.year, date.month + 1, 0).day;

    return Column(""", """    final days = DateTime(date.year, date.month + 1, 0).day;
    final orderedHabits = [...habits]..sort((a, b) {
      if (a.reminderEnabled != b.reminderEnabled) return a.reminderEnabled ? -1 : 1;
      if (a.reminderEnabled) {
        final aMinutes = a.reminderHour * 60 + a.reminderMinute;
        final bMinutes = b.reminderHour * 60 + b.reminderMinute;
        final byTime = aMinutes.compareTo(bMinutes);
        if (byTime != 0) return byTime;
      }
      return 0;
    });

    return Column("""),
("""children: habits
                      .map(
                        (habit) => HabitTile(""", """children: orderedHabits
                      .map(
                        (habit) => HabitTile("""),
("""                      const SizedBox(height: 9),
                      LinearProgressIndicator(""", """                      if (habit.reminderEnabled) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(Icons.alarm, size: 14, color: AppColors.blue),
                            const SizedBox(width: 5),
                            Text(
                              TimeOfDay(hour: habit.reminderHour, minute: habit.reminderMinute).format(context),
                              style: const TextStyle(fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 9),
                      LinearProgressIndicator("""),
("""                    subtitle: Text(
                      reminders.enabled
                          ? 'Daily at ${TimeOfDay(hour: reminders.hour, minute: reminders.minute).format(context)}'
                          : 'Off',
                    ),""", """                    subtitle: Text(
                      reminders.enabled
                          ? 'On · each habit has its own reminder time'
                          : 'Off',
                    ),"""),
("DropdownButtonFormField<String>(\n                value: category,", "DropdownButtonFormField<String>(\n                initialValue: category,"),
]

for old, new in replacements:
    if old not in s:
        raise SystemExit(f'Missing expected main.dart pattern: {old[:80]!r}')
    s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')
print('Habit reminder wiring applied to lib/main.dart')
