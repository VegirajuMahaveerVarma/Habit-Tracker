import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/habit.dart';
import 'models/reminder_settings.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

void main() => runApp(const HabitTrackerApp());

class AppColors {
  static const navy = Color(0xFF102A43);
  static const blue = Color(0xFF1769FF);
  static const blueSoft = Color(0xFFEAF1FF);
  static const bg = Color(0xFFF5F7FB);
  static const text = Color(0xFF142033);
  static const muted = Color(0xFF718096);
  static const border = Color(0xFFE6EAF0);
  static const green = Color(0xFF16A36A);
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
        scaffoldBackgroundColor: AppColors.bg,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.blue)),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final storage = StorageService();
  final notifications = NotificationService.instance;
  List<Habit> habits = [];
  List<Map<String, dynamic>> todos = [];
  ReminderSettings reminders = const ReminderSettings();
  int tab = 0;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    await notifications.initialize();
    final h = await storage.loadHabits();
    final t = await storage.loadTodos();
    final r = await storage.loadReminderSettings();
    if (!mounted) return;
    setState(() { habits = h; todos = t; reminders = r; });
    if (r.enabled) await _scheduleReminders(r);
  }

  int _notificationId(Habit h) {
    var v = 17;
    for (final c in h.id.codeUnits) { v = (v * 31 + c) & 0x7fffffff; }
    return v % 100000 + 1;
  }

  Future<void> _scheduleReminders(ReminderSettings s) async {
    await notifications.cancelAll();
    if (!s.enabled) return;
    for (final h in habits.where((h) => h.active)) {
      await notifications.scheduleDaily(id: _notificationId(h), habitName: h.name, hour: s.hour, minute: s.minute);
    }
  }

  Future<void> _toggleHabit(Habit h, [DateTime? date]) async {
    final d = date ?? selectedDate;
    setState(() => h.setDone(d, !h.isDone(d)));
    await storage.saveHabits(habits);
  }

  Future<void> _addHabit() async {
    final r = await showModalBottomSheet<HabitEditResult>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      builder: (_) => const HabitEditorSheet(),
    );
    if (!mounted || r == null || r.delete || r.name.trim().isEmpty) return;
    setState(() => habits.add(Habit(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: r.name.trim(), category: r.category, goal: r.goal,
    )));
    await storage.saveHabits(habits);
    if (reminders.enabled) await _scheduleReminders(reminders);
  }

  Future<void> _editHabit(Habit h) async {
    final r = await showModalBottomSheet<HabitEditResult>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      builder: (_) => HabitEditorSheet(habit: h),
    );
    if (!mounted || r == null) return;
    if (r.delete) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete habit?'),
          content: Text('Remove "${h.name}" from your habits?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
          ],
        ),
      );
      if (ok == true && mounted) {
        setState(() => habits.removeWhere((x) => x.id == h.id));
        await storage.saveHabits(habits);
        if (reminders.enabled) await _scheduleReminders(reminders);
      }
      return;
    }
    if (r.name.trim().isEmpty) return;
    h.name = r.name.trim(); h.category = r.category; h.goal = r.goal;
    setState(() {});
    await storage.saveHabits(habits);
    if (reminders.enabled) await _scheduleReminders(reminders);
  }

  Future<void> _addTodo() async {
    final r = await showDialog<TodoEditResult>(context: context, builder: (_) => const TodoEditorDialog());
    if (!mounted || r == null || r.delete || r.title.trim().isEmpty) return;
    setState(() => todos.add({'title': r.title.trim(), 'done': false}));
    await storage.saveTodos(todos);
  }

  Future<void> _editTodo(int i) async {
    final todo = todos[i];
    final r = await showDialog<TodoEditResult>(
      context: context, builder: (_) => TodoEditorDialog(initialTitle: '${todo['title']}'),
    );
    if (!mounted || r == null) return;
    if (r.delete) {
      setState(() => todos.removeAt(i));
    } else if (r.title.trim().isNotEmpty) {
      setState(() => todo['title'] = r.title.trim());
    }
    await storage.saveTodos(todos);
  }

  Future<void> _openReminderSettings() async {
    final r = await showModalBottomSheet<ReminderSettings>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      builder: (_) => ReminderSettingsSheet(initial: reminders),
    );
    if (!mounted || r == null) return;
    setState(() => reminders = r);
    await storage.saveReminderSettings(r);
    await _scheduleReminders(r);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(habits: habits, date: selectedDate, onToggle: _toggleHabit, onAdd: _addHabit, onEdit: _editHabit),
      DailyPage(habits: habits, date: selectedDate, onDateChanged: (d) => setState(() => selectedDate = d), onToggle: _toggleHabit, onAdd: _addHabit, onEdit: _editHabit),
      AnalyticsPage(habits: habits),
      TodoPage(todos: todos, onAdd: _addTodo, onEdit: _editTodo, onChanged: () => storage.saveTodos(todos)),
      ProfilePage(habits: habits, reminders: reminders, onReminders: _openReminderSettings),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        height: 72, selectedIndex: tab, backgroundColor: Colors.white, indicatorColor: AppColors.blueSoft,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Habits'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'To-Do'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title; final String? subtitle; final Widget? trailing;
  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: AppColors.text)),
        if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 14))],
      ])),
      if (trailing != null) trailing!,
    ]),
  );
}

class SurfaceCard extends StatelessWidget {
  final Widget child; final EdgeInsets padding;
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  @override Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(blurRadius: 20, offset: Offset(0, 8), color: Color(0x08000000))]),
    child: child,
  );
}

class MiniStat extends StatelessWidget {
  final IconData icon; final String label, value;
  const MiniStat({super.key, required this.icon, required this.label, required this.value});
  @override Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(14),
    child: Row(children: [Icon(icon, color: AppColors.blue, size: 20), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]))]),
  );
}

class DashboardPage extends StatelessWidget {
  final List<Habit> habits; final DateTime date; final Future<void> Function(Habit, [DateTime?]) onToggle; final VoidCallback onAdd; final Future<void> Function(Habit) onEdit;
  const DashboardPage({super.key, required this.habits, required this.date, required this.onToggle, required this.onAdd, required this.onEdit});
  @override Widget build(BuildContext context) {
    final done = habits.where((h) => h.isDone(date)).length;
    final p = habits.isEmpty ? 0.0 : done / habits.length;
    final monthly = habits.fold<int>(0, (s, h) => s + h.completedInMonth(date));
    final goal = habits.fold<int>(0, (s, h) => s + h.goal);
    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeader(title: 'Good day 👋', subtitle: DateFormat('EEEE, d MMMM').format(date), trailing: CircleAvatar(radius: 27, backgroundColor: AppColors.navy, child: Text('${(p * 100).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SurfaceCard(child: Row(children: [
        SizedBox(width: 82, height: 82, child: Stack(fit: StackFit.expand, children: [CircularProgressIndicator(value: p, strokeWidth: 9, backgroundColor: AppColors.blueSoft, color: AppColors.blue), Center(child: Text('${(p * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)))])),
        const SizedBox(width: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(done == habits.length && habits.isNotEmpty ? 'All done!' : 'Today’s progress', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('$done of ${habits.length} habits completed', style: const TextStyle(color: AppColors.muted)), const SizedBox(height: 12), LinearProgressIndicator(value: p, minHeight: 7, backgroundColor: AppColors.blueSoft)])),
      ]))),
      const SizedBox(height: 14),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [Expanded(child: MiniStat(icon: Icons.calendar_month_outlined, label: 'This month', value: '$monthly days')), const SizedBox(width: 10), Expanded(child: MiniStat(icon: Icons.flag_outlined, label: 'Goal progress', value: goal == 0 ? '0%' : '${(monthly / goal * 100).round()}%'))])),
      const SizedBox(height: 24),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [const Expanded(child: Text("Today's habits", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 19), label: const Text('Add habit'))])),
      if (habits.isEmpty) const EmptyState(icon: Icons.check_circle_outline, title: 'No habits yet', message: 'Add a habit to begin tracking.') else ...habits.map((h) => HabitTile(habit: h, date: date, onToggle: () => onToggle(h), onEdit: () => onEdit(h))),
    ]));
  }
}

class HabitTile extends StatelessWidget {
  final Habit habit; final DateTime date; final VoidCallback onToggle, onEdit;
  const HabitTile({super.key, required this.habit, required this.date, required this.onToggle, required this.onEdit});
  @override Widget build(BuildContext context) {
    final done = habit.isDone(date); final m = habit.completedInMonth(date); final r = habit.goal == 0 ? 0.0 : (m / habit.goal).clamp(0.0, 1.0);
    return Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(16), child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onToggle, onLongPress: onEdit, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Row(children: [
      Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? AppColors.green : AppColors.muted), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(habit.displayName, style: TextStyle(fontWeight: FontWeight.w800, color: done ? AppColors.muted : AppColors.text, decoration: done ? TextDecoration.lineThrough : null))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.blueSoft, borderRadius: BorderRadius.circular(20)), child: Text(habit.category, style: const TextStyle(fontSize: 10, color: AppColors.blue, fontWeight: FontWeight.w700)))]), const SizedBox(height: 9), LinearProgressIndicator(value: r, minHeight: 5, backgroundColor: AppColors.bg), const SizedBox(height: 5), Text('$m/${habit.goal} this month', style: const TextStyle(fontSize: 11, color: AppColors.muted))])), const SizedBox(width: 8), Text('$m/${habit.goal}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.muted)),
    ]))));
  }
}

class DailyPage extends StatelessWidget {
  final List<Habit> habits; final DateTime date; final ValueChanged<DateTime> onDateChanged; final Future<void> Function(Habit, [DateTime?]) onToggle; final VoidCallback onAdd; final Future<void> Function(Habit) onEdit;
  const DailyPage({super.key, required this.habits, required this.date, required this.onDateChanged, required this.onToggle, required this.onAdd, required this.onEdit});
  @override Widget build(BuildContext context) {
    final days = DateTime(date.year, date.month + 1, 0).day;
    return Column(children: [
      PageHeader(title: 'Daily habits', subtitle: DateFormat('MMMM yyyy').format(date), trailing: IconButton.filledTonal(onPressed: onAdd, icon: const Icon(Icons.add))),
      SizedBox(height: 86, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: days, itemBuilder: (_, i) { final d = DateTime(date.year, date.month, i + 1); final selected = DateUtils.isSameDay(d, date); return GestureDetector(onTap: () => onDateChanged(d), child: Container(width: 48, margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6), decoration: BoxDecoration(color: selected ? AppColors.blue : Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: selected ? AppColors.blue : AppColors.border)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(DateFormat('EEE').format(d).substring(0, 2), style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : AppColors.muted)), const SizedBox(height: 5), Text('${d.day}', style: TextStyle(fontWeight: FontWeight.w900, color: selected ? Colors.white : AppColors.text))]))); })),
      Expanded(child: habits.isEmpty ? const EmptyState(icon: Icons.check_circle_outline, title: 'No habits', message: 'Add a habit to begin tracking.') : ListView(padding: const EdgeInsets.only(top: 10, bottom: 20), children: habits.map((h) => HabitTile(habit: h, date: date, onToggle: () => onToggle(h, date), onEdit: () => onEdit(h))).toList())),
    ]);
  }
}

class AnalyticsPage extends StatelessWidget {
  final List<Habit> habits;
  const AnalyticsPage({super.key, required this.habits});
  @override Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day - 6 + i));
    final values = days.map((d) => habits.where((h) => h.isDone(d)).length).toList();
    final maxValue = habits.isEmpty ? 1 : habits.length;
    final total = habits.fold<int>(0, (s, h) => s + h.completedInMonth(now));
    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PageHeader(title: 'Insights', subtitle: 'Your consistency at a glance'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [Expanded(child: StatCard(icon: Icons.local_fire_department_outlined, title: 'Monthly completions', value: '$total')), const SizedBox(width: 10), Expanded(child: StatCard(icon: Icons.track_changes, title: 'Active habits', value: '${habits.length}'))])),
      const SizedBox(height: 18),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Last 7 days', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 20),
        SizedBox(height: 150, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (i) { final v = values[i]; return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Text('$v', style: const TextStyle(fontSize: 11, color: AppColors.muted)), const SizedBox(height: 5), Container(height: 16 + 100 * v / maxValue, decoration: BoxDecoration(color: i == 6 ? AppColors.blue : AppColors.blueSoft, borderRadius: const BorderRadius.vertical(top: Radius.circular(9)))), const SizedBox(height: 7), Text(DateFormat('EEE').format(days[i]).substring(0, 2), style: const TextStyle(fontSize: 10, color: AppColors.muted))]))); }))),
      ]))),
      const SizedBox(height: 18),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Habit progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 12),
        if (habits.isEmpty) const Text('No habit data yet.', style: TextStyle(color: AppColors.muted)) else ...habits.map((h) { final v = h.completedInMonth(now); final r = h.goal == 0 ? 0.0 : (v / h.goal).clamp(0.0, 1.0); return Padding(padding: const EdgeInsets.only(bottom: 13), child: Column(children: [Row(children: [Expanded(child: Text(h.displayName, style: const TextStyle(fontWeight: FontWeight.w700))), Text('$v/${h.goal}', style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w800))]), const SizedBox(height: 7), LinearProgressIndicator(value: r, minHeight: 6, backgroundColor: AppColors.bg)])); }),
      ]))),
    ]));
  }
}

class StatCard extends StatelessWidget {
  final IconData icon; final String title, value;
  const StatCard({super.key, required this.icon, required this.title, required this.value});
  @override Widget build(BuildContext context) => SurfaceCard(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: AppColors.blue, size: 21), const SizedBox(height: 10), Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted))]));
}

class TodoPage extends StatefulWidget {
  final List<Map<String, dynamic>> todos; final Future<void> Function() onAdd; final Future<void> Function(int) onEdit; final Future<void> Function() onChanged;
  const TodoPage({super.key, required this.todos, required this.onAdd, required this.onEdit, required this.onChanged});
  @override State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  @override Widget build(BuildContext context) {
    final done = widget.todos.where((t) => t['done'] == true).length;
    final p = widget.todos.isEmpty ? 0.0 : done / widget.todos.length;
    return Column(children: [
      PageHeader(title: 'To-Do list', subtitle: '$done of ${widget.todos.length} completed', trailing: IconButton.filledTonal(onPressed: widget.onAdd, icon: const Icon(Icons.add))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SurfaceCard(child: Row(children: [
        SizedBox(width: 58, height: 58, child: Stack(fit: StackFit.expand, children: [CircularProgressIndicator(value: p, strokeWidth: 7, backgroundColor: AppColors.blueSoft, color: AppColors.blue), Center(child: Text('${(p * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)))])), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Stay on top of it', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 4), Text(widget.todos.isEmpty ? 'Add your first task.' : 'Long-press a task to edit it.', style: const TextStyle(color: AppColors.muted))])),
      ]))),
      const SizedBox(height: 12),
      Expanded(child: widget.todos.isEmpty ? const EmptyState(icon: Icons.task_alt, title: 'Nothing here yet', message: 'Add tasks and check them off as you go.') : ListView.builder(padding: const EdgeInsets.only(bottom: 20), itemCount: widget.todos.length, itemBuilder: (_, i) {
        final todo = widget.todos[i]; final isDone = todo['done'] == true;
        return Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: Dismissible(
          key: ValueKey('${todo['title']}_$i'), direction: DismissDirection.endToStart,
          background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.delete_outline, color: Colors.red)),
          onDismissed: (_) async { setState(() => widget.todos.removeAt(i)); await widget.onChanged(); },
          child: Material(color: Colors.white, borderRadius: BorderRadius.circular(16), child: ListTile(
            onLongPress: () => widget.onEdit(i),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
            leading: IconButton(onPressed: () async { setState(() => todo['done'] = !isDone); await widget.onChanged(); }, icon: Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? AppColors.green : AppColors.muted)),
            title: Text('${todo['title']}', style: TextStyle(fontWeight: FontWeight.w700, decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? AppColors.muted : AppColors.text)),
          )),
        ));
      })),
    ]);
  }
}

class TodoEditResult {
  final String title; final bool delete;
  const TodoEditResult({this.title = '', this.delete = false});
}

class TodoEditorDialog extends StatefulWidget {
  final String? initialTitle;
  const TodoEditorDialog({super.key, this.initialTitle});
  @override State<TodoEditorDialog> createState() => _TodoEditorDialogState();
}
class _TodoEditorDialogState extends State<TodoEditorDialog> {
  late final TextEditingController controller;
  @override void initState() { super.initState(); controller = TextEditingController(text: widget.initialTitle ?? ''); }
  @override void dispose() { controller.dispose(); super.dispose(); }
  void save() { final title = controller.text.trim(); if (title.isEmpty) return; Navigator.pop(context, TodoEditResult(title: title)); }
  @override Widget build(BuildContext context) {
    final editing = widget.initialTitle != null;
    return AlertDialog(title: Text(editing ? 'Edit task' : 'Add task'), content: TextField(controller: controller, autofocus: true, textInputAction: TextInputAction.done, onSubmitted: (_) => save(), decoration: const InputDecoration(hintText: 'Task name')), actions: [
      if (editing) TextButton(onPressed: () => Navigator.pop(context, const TodoEditResult(delete: true)), child: const Text('Delete')),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: save, child: Text(editing ? 'Save' : 'Add')),
    ]);
  }
}

class HabitEditResult {
  final String name, category; final int goal; final bool delete;
  const HabitEditResult({this.name = '', this.category = 'Daily', this.goal = 30, this.delete = false});
}

class HabitEditorSheet extends StatefulWidget {
  final Habit? habit;
  const HabitEditorSheet({super.key, this.habit});
  @override State<HabitEditorSheet> createState() => _HabitEditorSheetState();
}
class _HabitEditorSheetState extends State<HabitEditorSheet> {
  late final TextEditingController controller; late String category; late double goal;
  static const categories = ['Daily', 'Mind & Body', 'Productivity', 'Goals'];
  @override void initState() { super.initState(); controller = TextEditingController(text: widget.habit?.name ?? ''); category = categories.contains(widget.habit?.category) ? widget.habit!.category : 'Daily'; goal = (widget.habit?.goal ?? 30).clamp(1, 31).toDouble(); }
  @override void dispose() { controller.dispose(); super.dispose(); }
  void save() { final name = controller.text.trim(); if (name.isEmpty) return; Navigator.pop(context, HabitEditResult(name: name, category: category, goal: goal.round())); }
  @override Widget build(BuildContext context) {
    final editing = widget.habit != null;
    return SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 16),
      Row(children: [Expanded(child: Text(editing ? 'Edit habit' : 'Create a habit', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
      TextField(controller: controller, autofocus: true, onSubmitted: (_) => save(), decoration: const InputDecoration(labelText: 'Habit name', prefixIcon: Icon(Icons.flag_outlined))), const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)), items: categories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) { if (v != null) setState(() => category = v); }), const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)), child: Column(children: [Row(children: [const Expanded(child: Text('Monthly goal', style: TextStyle(fontWeight: FontWeight.w800))), Text('${goal.round()} days', style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w900))]), Slider(value: goal, min: 1, max: 31, divisions: 30, onChanged: (v) => setState(() => goal = v))])), const SizedBox(height: 14),
      Row(children: [if (editing) ...[Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(context, const HabitEditResult(delete: true)), icon: const Icon(Icons.delete_outline), label: const Text('Delete'))), const SizedBox(width: 12)], Expanded(child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.check), label: Text(editing ? 'Save changes' : 'Create habit')))]),
    ]))));
  }
}

class ReminderSettingsSheet extends StatefulWidget {
  final ReminderSettings initial;
  const ReminderSettingsSheet({super.key, required this.initial});
  @override State<ReminderSettingsSheet> createState() => _ReminderSettingsSheetState();
}
class _ReminderSettingsSheetState extends State<ReminderSettingsSheet> {
  late bool enabled; late TimeOfDay time;
  @override void initState() { super.initState(); enabled = widget.initial.enabled; time = TimeOfDay(hour: widget.initial.hour, minute: widget.initial.minute); }
  @override Widget build(BuildContext context) => SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 16),
    Row(children: [const Expanded(child: Text('Habit reminders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Daily reminders', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Notify me for active habits every day.'), value: enabled, onChanged: (v) => setState(() => enabled = v)),
    ListTile(enabled: enabled, onTap: enabled ? () async { final picked = await showTimePicker(context: context, initialTime: time); if (picked != null) setState(() => time = picked); } : null, leading: const Icon(Icons.alarm, color: AppColors.blue), title: const Text('Reminder time', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(time.format(context)), trailing: const Icon(Icons.chevron_right)),
    const SizedBox(height: 8), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => NotificationService.instance.showTestNotification(), icon: const Icon(Icons.notifications_active_outlined), label: const Text('Test notification'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(context, ReminderSettings(enabled: enabled, hour: time.hour, minute: time.minute)), icon: const Icon(Icons.check), label: const Text('Save')))]), const SizedBox(height: 8),
    const Text('Runs locally on this device. No account or paid service is required.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
  ])));
}

class ProfilePage extends StatelessWidget {
  final List<Habit> habits; final ReminderSettings reminders; final VoidCallback onReminders;
  const ProfilePage({super.key, required this.habits, required this.reminders, required this.onReminders});
  @override Widget build(BuildContext context) {
    final done = habits.fold<int>(0, (s, h) => s + h.completedInMonth(DateTime.now()));
    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: Column(children: [
      const SizedBox(height: 20), Container(width: 82, height: 82, decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle), child: const Icon(Icons.person, color: Colors.white, size: 40)), const SizedBox(height: 12),
      const Text('Habit Builder', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 4), const Text('Build better days, one habit at a time.', style: TextStyle(color: AppColors.muted)), const SizedBox(height: 24),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [Expanded(child: StatCard(icon: Icons.check_circle_outline, title: 'Habits', value: '${habits.length}')), const SizedBox(width: 10), Expanded(child: StatCard(icon: Icons.done_all, title: 'This month', value: '$done'))])), const SizedBox(height: 18),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SurfaceCard(child: Column(children: [ListTile(contentPadding: EdgeInsets.zero, onTap: onReminders, leading: const Icon(Icons.notifications_active_outlined, color: AppColors.blue), title: const Text('Habit reminders', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(reminders.enabled ? 'Daily at ${TimeOfDay(hour: reminders.hour, minute: reminders.minute).format(context)}' : 'Off'), trailing: const Icon(Icons.chevron_right)), const Divider(height: 1), const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.lock_outline, color: AppColors.green), title: Text('Private & offline', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Your habit data stays on this device.')), const Divider(height: 1), const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.tips_and_updates_outlined), title: Text('Tip', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Long-press habits or To-Do tasks to edit them.'))]))),
    ]));
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon; final String title, message;
  const EmptyState({super.key, required this.icon, required this.title, required this.message});
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.blueSoft, borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: AppColors.blue, size: 30)), const SizedBox(height: 14), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted))])));
}
