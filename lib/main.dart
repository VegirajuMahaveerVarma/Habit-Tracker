import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/habit.dart';
import 'services/storage_service.dart';

void main() => runApp(const HabitTrackerApp());

class AppColors {
  static const navy = Color(0xFF0B2745);
  static const blue = Color(0xFF1456D9);
  static const bg = Color(0xFFF6F8FC);
  static const text = Color(0xFF111827);
  static const muted = Color(0xFF667085);
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
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final storage = StorageService();
  List<Habit> habits = [];
  List<Map<String, dynamic>> todos = [];
  int tab = 0;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loadedHabits = await storage.loadHabits();
    final loadedTodos = await storage.loadTodos();
    if (!mounted) return;
    setState(() {
      habits = loadedHabits;
      todos = loadedTodos;
    });
  }

  Future<void> _toggle(Habit habit) async {
    setState(() => habit.setDone(selectedDate, !habit.isDone(selectedDate)));
    await storage.saveHabits(habits);
  }

  Future<void> _addHabit() async {
    final result = await showModalBottomSheet<HabitEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const HabitEditorSheet(),
    );
    if (!mounted || result == null || result.delete) return;
    final name = result.name.trim();
    if (name.isEmpty) return;
    final habit = Habit(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      category: result.category,
      goal: result.goal,
    );
    setState(() => habits.add(habit));
    await storage.saveHabits(habits);
  }

  Future<void> _editHabit(Habit habit) async {
    final result = await showModalBottomSheet<HabitEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HabitEditorSheet(habit: habit),
    );

    // Important: the modal returns its data first. The parent is updated only
    // after the route has finished closing, avoiding the Flutter
    // '_dependents.isEmpty' deactivation assertion seen during Save.
    if (!mounted || result == null) return;

    if (result.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete habit?'),
          content: Text('Remove "${habit.name}" from your habits?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        setState(() => habits.removeWhere((item) => item.id == habit.id));
        await storage.saveHabits(habits);
      }
      return;
    }

    final name = result.name.trim();
    if (name.isEmpty) return;

    habit.name = name;
    habit.category = result.category;
    habit.goal = result.goal;
    if (!mounted) return;
    setState(() {});
    await storage.saveHabits(habits);
  }

  Future<void> _addTodo() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'What needs to be done?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              setState(() => todos.add({'title': title, 'done': false}));
              await storage.saveTodos(todos);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(
        habits: habits,
        date: selectedDate,
        onToggle: _toggle,
        onAdd: _addHabit,
        onEdit: _editHabit,
      ),
      DailyPage(
        habits: habits,
        date: selectedDate,
        onDateChanged: (date) => setState(() => selectedDate = date),
        onToggle: _toggle,
        onAdd: _addHabit,
        onEdit: _editHabit,
      ),
      AnalyticsPage(habits: habits),
      TodoPage(
        todos: todos,
        onAdd: _addTodo,
        onChanged: () => storage.saveTodos(todos),
      ),
      ProfilePage(habits: habits),
    ];

    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'To-Do',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HabitEditResult {
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
}

class HabitEditorSheet extends StatefulWidget {
  final Habit? habit;

  const HabitEditorSheet({super.key, this.habit});

  @override
  State<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends State<HabitEditorSheet> {
  late final TextEditingController nameController;
  late String category;
  late double goal;

  static const categories = [
    'Daily',
    'Mind & Body',
    'Productivity',
    'Goals',
  ];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.habit?.name ?? '');
    category = categories.contains(widget.habit?.category)
        ? widget.habit!.category
        : 'Daily';
    goal = (widget.habit?.goal ?? 30).clamp(1, 31).toDouble();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      HabitEditResult(
        name: name,
        category: category,
        goal: goal.round(),
      ),
    );
  }

  void _delete() {
    Navigator.of(context).pop(const HabitEditResult(delete: true));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.habit != null;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      editing ? 'Edit habit' : 'Add a habit',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Habit name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => category = value);
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Monthly goal: ${goal.round()} days',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Slider(
                value: goal,
                min: 1,
                max: 31,
                divisions: 30,
                label: '${goal.round()}',
                onChanged: (value) => setState(() => goal = value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (editing) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(editing ? 'Save changes' : 'Create habit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(color: AppColors.muted),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final List<Habit> habits;
  final DateTime date;
  final Future<void> Function(Habit) onToggle;
  final VoidCallback onAdd;
  final Future<void> Function(Habit) onEdit;

  const DashboardPage({
    super.key,
    required this.habits,
    required this.date,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final done = habits.where((habit) => habit.isDone(date)).length;
    final progress = habits.isEmpty ? 0.0 : done / habits.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              const SizedBox(height: 112),
              PageHeader(
                title: 'Good day 👋',
                subtitle: DateFormat('EEEE, d MMMM').format(date),
              ),
              Positioned(
                top: 18,
                right: 20,
                child: Container(
                  width: 70,
                  height: 70,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ProgressCard(
              progress: progress,
              done: done,
              total: habits.length,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Today's habits",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          ...habits.map(
            (habit) => HabitTile(
              habit: habit,
              date: date,
              onToggle: () => onToggle(habit),
              onEdit: () => onEdit(habit),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class ProgressCard extends StatelessWidget {
  final double progress;
  final int done;
  final int total;

  const ProgressCard({
    super.key,
    required this.progress,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.blue],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 94,
            height: 94,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 9,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
                Text(
                  '$done/$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAILY PROGRESS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$done / $total completed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'Small wins build consistency.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HabitTile extends StatelessWidget {
  final Habit habit;
  final DateTime date;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const HabitTile({
    super.key,
    required this.habit,
    required this.date,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final done = habit.isDone(date);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onToggle,
          onLongPress: onEdit,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done ? AppColors.blue : Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: done
                          ? AppColors.blue
                          : const Color(0xFFD0D5DD),
                      width: 2,
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        habit.category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${habit.completedInMonth(date)}/${habit.goal}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DailyPage extends StatelessWidget {
  final List<Habit> habits;
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;
  final Future<void> Function(Habit) onToggle;
  final VoidCallback onAdd;
  final Future<void> Function(Habit) onEdit;

  const DailyPage({
    super.key,
    required this.habits,
    required this.date,
    required this.onDateChanged,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      DateTime(date.year, date.month + 1, 0).day,
      (i) => DateTime(date.year, date.month, i + 1),
    );

    return Column(
      children: [
        PageHeader(
          title: 'Daily Tracking',
          subtitle: DateFormat('MMMM yyyy').format(date),
          trailing: IconButton(
            onPressed: onAdd,
            icon: const Icon(
              Icons.add_circle,
              size: 32,
              color: AppColors.blue,
            ),
          ),
        ),
        SizedBox(
          height: 82,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final day = days[index];
              final selected = day.day == date.day;
              return GestureDetector(
                onTap: () => onDateChanged(day),
                child: Container(
                  width: 52,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.blue : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: selected
                          ? AppColors.blue
                          : const Color(0xFFE4E7EC),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(day).substring(0, 2),
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? Colors.white70
                              : AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 17,
                          color: selected ? Colors.white : AppColors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: habits
                .map(
                  (habit) => HabitTile(
                    habit: habit,
                    date: date,
                    onToggle: () => onToggle(habit),
                    onEdit: () => onEdit(habit),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class AnalyticsPage extends StatelessWidget {
  final List<Habit> habits;

  const AnalyticsPage({super.key, required this.habits});

  int doneOn(DateTime date) =>
      habits.where((habit) => habit.isDone(date)).length;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - 6 + i),
    );
    var total = 0;
    for (final day in days) total += doneOn(day);
    final percent = habits.isEmpty ? 0.0 : total / (habits.length * 7);
    final top = [...habits]
      ..sort(
        (a, b) => b
            .completedInMonth(now)
            .compareTo(a.completedInMonth(now)),
      );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Analytics',
            subtitle: 'See the bigger picture',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'This week',
                    value: '${(percent * 100).round()}%',
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Habits',
                    value: '${habits.length}',
                    icon: Icons.track_changes,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Weekly Progress',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: days.map((day) {
                  final p = habits.isEmpty ? 0.0 : doneOn(day) / habits.length;
                  return Column(
                    children: [
                      SizedBox(
                        height: 130,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 24,
                            height: 12 + 105 * p,
                            decoration: BoxDecoration(
                              color: AppColors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('E').format(day).substring(0, 2),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        '${(p * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Top Habits',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          ...top.take(5).map(
                (habit) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  child: ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: const Icon(Icons.star_rounded),
                    title: Text(habit.name),
                    trailing: Text(
                      '${habit.completedInMonth(now)} days',
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.blue),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class TodoPage extends StatefulWidget {
  final List<Map<String, dynamic>> todos;
  final VoidCallback onAdd;
  final Future<void> Function() onChanged;

  const TodoPage({
    super.key,
    required this.todos,
    required this.onAdd,
    required this.onChanged,
  });

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  @override
  Widget build(BuildContext context) {
    final completed =
        widget.todos.where((todo) => todo['done'] == true).length;
    final progress =
        widget.todos.isEmpty ? 0.0 : completed / widget.todos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'To-Do List',
          subtitle: 'Stay organized and get things done',
          trailing: IconButton(
            onPressed: widget.onAdd,
            icon: const Icon(
              Icons.add_circle,
              size: 32,
              color: AppColors.blue,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Progress',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 7),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: widget.todos.isEmpty
              ? const Center(
                  child: Text(
                    'No tasks yet. Add one to get started.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.builder(
                  itemCount: widget.todos.length,
                  itemBuilder: (_, index) {
                    final todo = widget.todos[index];
                    final done = todo['done'] == true;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      child: Dismissible(
                        key: ValueKey('${todo['title']}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline),
                        ),
                        onDismissed: (_) async {
                          setState(() => widget.todos.removeAt(index));
                          await widget.onChanged();
                        },
                        child: ListTile(
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: Checkbox(
                            value: done,
                            onChanged: (value) async {
                              setState(
                                () => todo['done'] = value ?? false,
                              );
                              await widget.onChanged();
                            },
                          ),
                          title: Text(
                            todo['title'] as String,
                            style: TextStyle(
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  final List<Habit> habits;

  const ProfilePage({super.key, required this.habits});

  @override
  Widget build(BuildContext context) {
    final totalCompleted = habits.fold<int>(
      0,
      (sum, habit) => sum + habit.completedInMonth(DateTime.now()),
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 28),
          const CircleAvatar(
            radius: 42,
            backgroundColor: AppColors.navy,
            child: Icon(Icons.person, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 12),
          const Text(
            'Habit Builder',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Build better. Every day.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Active habits',
                    value: '${habits.length}',
                    icon: Icons.track_changes,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'This month',
                    value: '$totalCompleted',
                    icon: Icons.emoji_events_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Offline & Private'),
                subtitle: Text('Your habit data stays on this device.'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
