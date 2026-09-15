import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/habit.dart';
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
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.blue);
    return MaterialApp(
      title: 'Habit Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: AppColors.bg,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.blue),
          ),
        ),
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

  Future<void> _toggle(Habit habit, [DateTime? date]) async {
    final day = date ?? selectedDate;
    setState(() => habit.setDone(day, !habit.isDone(day)));
    await storage.saveHabits(habits);
  }

  Future<void> _addHabit() async {
    final result = await showModalBottomSheet<HabitEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => const HabitEditorSheet(),
    );
    if (!mounted || result == null || result.delete) return;
    final name = result.name.trim();
    if (name.isEmpty) return;
    setState(() {
      habits.add(Habit(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        category: result.category,
        goal: result.goal,
      ));
    });
    await storage.saveHabits(habits);
  }

  Future<void> _editHabit(Habit habit) async {
    final result = await showModalBottomSheet<HabitEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => HabitEditorSheet(habit: habit),
    );
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
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const AddTodoDialog(),
    );
    if (!mounted || title == null || title.isEmpty) return;
    setState(() => todos.add({'title': title, 'done': false}));
    await storage.saveTodos(todos);
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
      body: SafeArea(
        child: IndexedStack(index: tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: tab,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.blueSoft,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
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

class AddTodoDialog extends StatefulWidget {
  const AddTodoDialog({super.key});

  @override
  State<AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends State<AddTodoDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text(
          'Add task',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: 'What needs to be done?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('Add'),
          ),
        ],
      );
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

  @override
  Widget build(BuildContext context) {
    final editing = widget.habit != null;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      editing ? 'Edit habit' : 'Create a habit',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Habit name',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
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
                  if (value != null) {
                    setState(() => category = value);
                  }
                },
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Monthly goal',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${goal.round()} days',
                          style: const TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: goal,
                      min: 1,
                      max: 31,
                      divisions: 30,
                      onChanged: (value) => setState(() => goal = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (editing) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(
                          context,
                          const HabitEditResult(delete: true),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: Text(
                        editing ? 'Save changes' : 'Create habit',
                      ),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              blurRadius: 20,
              offset: Offset(0, 8),
              color: Color(0x08000000),
            ),
          ],
        ),
        child: child,
      );
}

class DashboardPage extends StatelessWidget {
  final List<Habit> habits;
  final DateTime date;
  final Future<void> Function(Habit, [DateTime?]) onToggle;
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
    final done = habits.where((h) => h.isDone(date)).length;
    final progress = habits.isEmpty ? 0.0 : done / habits.length;
    final monthDone = habits.fold<int>(
      0,
      (sum, h) => sum + h.completedInMonth(date),
    );
    final totalGoal = habits.fold<int>(0, (sum, h) => sum + h.goal);
    final goalProgress = totalGoal == 0
        ? 0.0
        : (monthDone / totalGoal).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Good day 👋',
            subtitle: DateFormat('EEEE, d MMMM').format(date),
            trailing: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: AppColors.navy,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SurfaceCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 82,
                    height: 82,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 9,
                          backgroundColor: AppColors.blueSoft,
                          color: AppColors.blue,
                        ),
                        Center(
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          done == habits.length && habits.isNotEmpty
                              ? 'All done!'
                              : 'Today’s progress',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$done of ${habits.length} habits completed',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 7,
                            backgroundColor: AppColors.blueSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.calendar_month_outlined,
                    label: 'This month',
                    value: '$monthDone days',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.flag_outlined,
                    label: 'Goal progress',
                    value: '${(goalProgress * 100).round()}%',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Today's habits",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 19),
                  label: const Text('Add habit'),
                ),
              ],
            ),
          ),
          if (habits.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: _EmptyState(
                icon: Icons.add_task,
                title: 'No habits yet',
                message: 'Create your first habit and start building consistency.',
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
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue, size: 21),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
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
    final monthDone = habit.completedInMonth(date);
    final ratio = habit.goal == 0
        ? 0.0
        : (monthDone / habit.goal).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onToggle,
          onLongPress: onEdit,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: done
                    ? AppColors.blue.withAlpha(70)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: done ? AppColors.blue : AppColors.blueSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    done ? Icons.check : Icons.circle_outlined,
                    color: done ? Colors.white : AppColors.blue,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          color: done ? AppColors.muted : AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              habit.category,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 5,
                                backgroundColor: AppColors.bg,
                                color: AppColors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$monthDone/${habit.goal}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.more_horiz,
                      size: 19,
                      color: AppColors.muted,
                    ),
                  ],
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
  final Future<void> Function(Habit, [DateTime?]) onToggle;
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
    final days = DateTime(date.year, date.month + 1, 0).day;

    return Column(
      children: [
        PageHeader(
          title: 'Daily habits',
          subtitle: DateFormat('MMMM yyyy').format(date),
          trailing: IconButton.filledTonal(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
          ),
        ),
        SizedBox(
          height: 86,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: days,
            itemBuilder: (_, index) {
              final d = DateTime(date.year, date.month, index + 1);
              final selected = DateUtils.isSameDay(d, date);

              return GestureDetector(
                onTap: () => onDateChanged(d),
                child: Container(
                  width: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.blue : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: selected ? AppColors.blue : AppColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(d).substring(0, 2),
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.white70 : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: selected ? Colors.white : AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: habits.isEmpty
              ? const _EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No habits',
                  message: 'Add a habit to begin tracking.',
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  children: habits
                      .map(
                        (h) => HabitTile(
                          habit: h,
                          date: date,
                          onToggle: () => onToggle(h, date),
                          onEdit: () => onEdit(h),
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final last7 = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - (6 - i)),
    );
    final daily = last7
        .map((day) => habits.where((h) => h.isDone(day)).length)
        .toList();
    final max = habits.isEmpty ? 1 : habits.length;
    final totalDone = habits.fold<int>(
      0,
      (sum, h) => sum + h.completedInMonth(now),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Insights',
            subtitle: 'Your consistency at a glance',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.local_fire_department_outlined,
                    title: 'Monthly completions',
                    value: '$totalDone',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    icon: Icons.track_changes,
                    title: 'Active habits',
                    value: '${habits.length}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last 7 days',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 150,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (i) {
                        final value = daily[i];
                        final height = 16 + 100 * value / max;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '$value',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  height: height,
                                  decoration: BoxDecoration(
                                    color: i == 6
                                        ? AppColors.blue
                                        : AppColors.blueSoft,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(9),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  DateFormat('EEE')
                                      .format(last7[i])
                                      .substring(0, 2),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top habits',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  if (habits.isEmpty)
                    const Text(
                      'Start tracking habits to see your leaders.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  else
                    ...habits.map((h) {
                      final value = h.completedInMonth(now);
                      final ratio = h.goal == 0
                          ? 0.0
                          : (value / h.goal).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    h.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$value/${h.goal}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: AppColors.bg,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: AppColors.blue, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      );
}

class TodoPage extends StatefulWidget {
  final List<Map<String, dynamic>> todos;
  final Future<void> Function() onAdd;
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
    final done = widget.todos.where((t) => t['done'] == true).length;
    final progress = widget.todos.isEmpty ? 0.0 : done / widget.todos.length;

    return Column(
      children: [
        PageHeader(
          title: 'To-Do list',
          subtitle: '$done of ${widget.todos.length} completed',
          trailing: IconButton.filledTonal(
            onPressed: widget.onAdd,
            icon: const Icon(Icons.add),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SurfaceCard(
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        backgroundColor: AppColors.blueSoft,
                        color: AppColors.blue,
                      ),
                      Center(
                        child: Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stay on top of it',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.todos.isEmpty
                            ? 'Add your first task.'
                            : 'Keep moving — small wins count.',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: widget.todos.isEmpty
              ? const _EmptyState(
                  icon: Icons.task_alt,
                  title: 'Nothing here yet',
                  message: 'Add tasks and check them off as you go.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: widget.todos.length,
                  itemBuilder: (_, index) {
                    final todo = widget.todos[index];
                    final isDone = todo['done'] == true;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Dismissible(
                        key: ValueKey('${todo['title']}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                        onDismissed: (_) async {
                          setState(() => widget.todos.removeAt(index));
                          await widget.onChanged();
                        },
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            leading: IconButton(
                              onPressed: () async {
                                setState(() => todo['done'] = !isDone);
                                await widget.onChanged();
                              },
                              icon: Icon(
                                isDone
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isDone
                                    ? AppColors.green
                                    : AppColors.muted,
                              ),
                            ),
                            title: Text(
                              '${todo['title']}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isDone
                                    ? AppColors.muted
                                    : AppColors.text,
                              ),
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
    final completed = habits.fold<int>(
      0,
      (sum, h) => sum + h.completedInMonth(DateTime.now()),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Habit Builder',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Build better days, one habit at a time.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.check_circle_outline,
                    title: 'Habits',
                    value: '${habits.length}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    icon: Icons.done_all,
                    title: 'This month',
                    value: '$completed',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SurfaceCard(
              child: Column(
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.lock_outline,
                      color: AppColors.green,
                    ),
                    title: Text(
                      'Private & offline',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Your habit data stays on this device.',
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.tips_and_updates_outlined),
                    title: Text(
                      'Tip',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Long-press a habit to edit or delete it.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: AppColors.blue, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
}
