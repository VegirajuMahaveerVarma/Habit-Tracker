import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/habit.dart';
import 'services/storage_service.dart';

void main() => runApp(const HabitTrackerApp());

class AppColors {
  static const blue = Color(0xFF1769FF);
  static const blueSoft = Color(0xFFEAF1FF);
  static const bg = Color(0xFFF5F7FB);
  static const text = Color(0xFF142033);
  static const muted = Color(0xFF718096);
  static const border = Color(0xFFE6EAF0);
  static const orange = Color(0xFFF59E0B);
  static const green = Color(0xFF16A36A);
  static const red = Color(0xFFE05252);
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Habit Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
        scaffoldBackgroundColor: AppColors.bg,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
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
  Map<String, int> moods = {};
  Map<String, int> timers = {};
  String? pin;
  bool locked = false;
  bool onboarding = false;
  int tab = 0;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await storage.loadHabits();
    final t = await storage.loadTodos();
    final m = await storage.loadMoods();
    final f = await storage.loadTimerSeconds();
    final p = await storage.loadPin();
    final prefs = await SharedPreferences.getInstance();
    final firstLaunch = !(prefs.getBool('onboarding_done_v1') ?? false);
    if (!mounted) return;
    setState(() {
      habits = h;
      todos = t;
      moods = m;
      timers = f;
      pin = p;
      locked = p != null;
      onboarding = firstLaunch;
    });
  }

  Future<void> finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done_v1', true);
    if (mounted) setState(() => onboarding = false);
  }

  Future<void> saveHabits() => storage.saveHabits(habits);

  Future<void> toggleHabit(Habit habit, DateTime day) async {
    setState(() => habit.setDone(day, !habit.isDone(day)));
    await saveHabits();
  }

  Future<void> addHabit() async {
    final result = await showModalBottomSheet<HabitEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => const HabitEditor(),
    );
    if (!mounted || result == null || result.name.trim().isEmpty) return;
    setState(() => habits.add(result.toHabit()));
    await saveHabits();
  }

  Future<void> editHabit(Habit habit) async {
    final result = await showModalBottomSheet<HabitEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => HabitEditor(habit: habit),
    );
    if (!mounted || result == null) return;
    if (result.delete) {
      final yes = await confirmDialog(context, 'Delete habit?', 'Delete this habit and its history?');
      if (yes) {
        setState(() => habits.removeWhere((h) => h.id == habit.id));
        await saveHabits();
      }
      return;
    }
    habit.name = result.name;
    habit.category = result.category;
    habit.goal = result.goal;
    habit.unit = result.unit;
    habit.frequency = result.frequency;
    habit.weekdays = result.weekdays;
    habit.pinned = result.pinned;
    habit.active = result.active;
    habit.icon = result.icon;
    habit.tags = result.tags;
    habit.notes = result.notes;
    setState(() {});
    await saveHabits();
  }

  Future<void> openHabit(Habit habit) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HabitDetail(
          habit: habit,
          onChanged: () async {
            await saveHabits();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> addTodo() async {
    final result = await showDialog<TodoResult>(
      context: context,
      builder: (_) => const TodoEditor(),
    );
    if (!mounted || result == null || result.title.trim().isEmpty) return;
    final item = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': result.title.trim(),
      'done': false,
      'priority': result.priority,
      'category': result.category,
      'due': result.due == null ? '' : Habit.key(result.due!),
    };
    setState(() => todos.add(item));
    await storage.saveTodos(todos);
  }

  Future<void> editTodo(int index) async {
    final result = await showDialog<TodoResult>(
      context: context,
      builder: (_) => TodoEditor(initial: todos[index]),
    );
    if (!mounted || result == null) return;
    if (result.delete) {
      setState(() => todos.removeAt(index));
    } else {
      setState(() {
        todos[index]['title'] = result.title.trim();
        todos[index]['priority'] = result.priority;
        todos[index]['category'] = result.category;
        todos[index]['due'] = result.due == null ? '' : Habit.key(result.due!);
      });
    }
    await storage.saveTodos(todos);
  }

  Future<void> toggleTodo(int index) async {
    setState(() => todos[index]['done'] = todos[index]['done'] != true);
    await storage.saveTodos(todos);
  }

  Future<void> setMood(int value) async {
    setState(() => moods[Habit.key(selectedDate)] = value);
    await storage.saveMoods(moods);
  }

  Future<void> openTimer() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FocusTimer(
          storage: storage,
          date: selectedDate,
          initial: timers[Habit.key(selectedDate)] ?? 0,
          onSaved: (value) => setState(() => timers[Habit.key(selectedDate)] = value),
        ),
      ),
    );
  }

  Future<void> setPin() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const PinDialog(),
    );
    if (value == null) return;
    final newPin = value.isEmpty ? null : value;
    await storage.savePin(newPin);
    if (mounted) setState(() { pin = newPin; locked = false; });
  }

  Future<void> showTemplates() async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => const TemplateSheet(),
    );
    if (!mounted || selected == null) return;
    final names = habits.map((h) => h.name.toLowerCase()).toSet();
    final additions = <Habit>[];
    for (final name in selected) {
      if (!names.contains(name.toLowerCase())) {
        additions.add(Habit(
          id: '${DateTime.now().microsecondsSinceEpoch}_$name',
          name: name,
          category: 'Routine',
        ));
      }
    }
    setState(() => habits.addAll(additions));
    await saveHabits();
  }

  @override
  Widget build(BuildContext context) {
    if (onboarding) {
      return Onboarding(onDone: finishOnboarding, onCreate: addHabit);
    }
    if (locked && pin != null) {
      return LockScreen(pin: pin!, onUnlock: () => setState(() => locked = false));
    }

    final pages = <Widget>[
      Dashboard(
        habits: habits,
        todos: todos,
        moods: moods,
        date: selectedDate,
        onToggle: toggleHabit,
        onAdd: addHabit,
        onEdit: editHabit,
        onOpen: openHabit,
        onMood: setMood,
        onTimer: openTimer,
      ),
      Daily(
        habits: habits,
        date: selectedDate,
        onDate: (d) => setState(() => selectedDate = d),
        onToggle: toggleHabit,
        onAdd: addHabit,
        onEdit: editHabit,
        onOpen: openHabit,
      ),
      Analytics(
        habits: habits,
        moods: moods,
        todos: todos,
        timers: timers,
        onOpen: openHabit,
      ),
      Todos(todos: todos, onAdd: addTodo, onEdit: editTodo, onToggle: toggleTodo),
      Profile(habits: habits, onPin: setPin, onTimer: openTimer, onTemplates: showTemplates),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        indicatorColor: AppColors.blueSoft,
        onDestinationSelected: (value) => setState(() => tab = value),
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

class Header extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const Header({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: AppColors.text)),
                if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class CardBox extends StatelessWidget {
  final Widget child;
  const CardBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(blurRadius: 18, offset: Offset(0, 7), color: Color(0x08000000))],
      ),
      child: child,
    );
  }
}

class Section extends StatelessWidget {
  final String title;
  final VoidCallback? action;
  final String actionText;
  const Section({super.key, required this.title, this.action, this.actionText = '＋ Add'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
          if (action != null) TextButton(onPressed: action, child: Text(actionText)),
        ],
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  final List<Habit> habits;
  final List<Map<String, dynamic>> todos;
  final Map<String, int> moods;
  final DateTime date;
  final Future<void> Function(Habit, DateTime) onToggle;
  final VoidCallback onAdd;
  final Future<void> Function(Habit) onEdit;
  final Future<void> Function(Habit) onOpen;
  final Future<void> Function(int) onMood;
  final VoidCallback onTimer;

  const Dashboard({super.key, required this.habits, required this.todos, required this.moods, required this.date, required this.onToggle, required this.onAdd, required this.onEdit, required this.onOpen, required this.onMood, required this.onTimer});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String search = '';
  String filter = 'All';
  String sort = 'Pinned';

  @override
  Widget build(BuildContext context) {
    final active = widget.habits.where((h) => h.active).toList();
    var visible = active.where((h) {
      final q = search.trim().toLowerCase();
      final matchesSearch = q.isEmpty || h.name.toLowerCase().contains(q) || h.category.toLowerCase().contains(q) || h.tags.any((tag) => tag.toLowerCase().contains(q));
      var matchesFilter = true;
      if (filter == 'Pinned') matchesFilter = h.pinned;
      if (filter == 'Completed') matchesFilter = h.isDone(widget.date);
      if (filter == 'Missed') matchesFilter = h.isScheduled(widget.date) && !h.isDone(widget.date);
      return matchesSearch && matchesFilter;
    }).toList();

    visible.sort((a, b) {
      if (sort == 'Name') return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (sort == 'Streak') return b.currentStreak(widget.date).compareTo(a.currentStreak(widget.date));
      if (sort == 'Progress') return b.completionRate(widget.date).compareTo(a.completionRate(widget.date));
      return a.pinned == b.pinned ? 0 : (a.pinned ? -1 : 1);
    });

    final done = active.where((h) => h.isDone(widget.date)).length;
    final progress = active.isEmpty ? 0.0 : done / active.length;
    var best = 0;
    for (final h in active) {
      final streak = h.currentStreak(widget.date);
      if (streak > best) best = streak;
    }
    final mood = widget.moods[Habit.key(widget.date)];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Header(title: 'Good day 👋', subtitle: DateFormat('EEEE, d MMMM').format(widget.date), trailing: IconButton(onPressed: widget.onTimer, icon: const Icon(Icons.timer_outlined))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(onChanged: (v) => setState(() => search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search habits, categories or tags')),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: ['All', 'Pinned', 'Completed', 'Missed'].map((x) => Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(x), selected: filter == x, onSelected: (_) => setState(() => filter = x)))).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [const Text('Sort:', style: TextStyle(color: AppColors.muted)), const SizedBox(width: 8), DropdownButton<String>(value: sort, items: ['Pinned', 'Name', 'Streak', 'Progress'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) { if (v != null) setState(() => sort = v); })]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CardBox(
              child: Row(
                children: [
                  SizedBox(width: 80, height: 80, child: Stack(fit: StackFit.expand, children: [CircularProgressIndicator(value: progress, strokeWidth: 9, backgroundColor: AppColors.blueSoft, color: AppColors.blue), Center(child: Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)))])),
                  const SizedBox(width: 18),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(done == active.length && active.isNotEmpty ? 'All done!' : 'Today’s progress', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), Text('$done of ${active.length} habits completed', style: const TextStyle(color: AppColors.muted)), const SizedBox(height: 9), LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: AppColors.blueSoft)])),
                ],
              ),
            ),
          ),
          Section(title: 'Quick stats'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [Expanded(child: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.local_fire_department_outlined, color: AppColors.blue), const SizedBox(height: 6), const Text('Best streak', style: TextStyle(color: AppColors.muted)), Text('$best days', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]))), const SizedBox(width: 10), Expanded(child: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.list_alt_outlined, color: AppColors.blue), const SizedBox(height: 6), const Text('Open tasks', style: TextStyle(color: AppColors.muted)), Text('${widget.todos.where((x) => x['done'] != true).length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))])))]),
          ),
          Section(title: 'How are you feeling today?'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CardBox(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(5, (i) { final value = i + 1; return InkWell(onTap: () => widget.onMood(value), child: Opacity(opacity: mood == value ? 1 : 0.55, child: Padding(padding: const EdgeInsets.all(8), child: Text(['😫', '😕', '😐', '🙂', '😄'][i], style: const TextStyle(fontSize: 25))))); }))),
          ),
          Section(title: search.isEmpty ? 'Today’s habits' : 'Search results', action: widget.onAdd),
          if (visible.isEmpty)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No matching habits.', style: TextStyle(color: AppColors.muted))))
          else
            ...visible.map((h) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), child: HabitTile(habit: h, date: widget.date, onToggle: () => widget.onToggle(h, widget.date), onEdit: () => widget.onEdit(h), onOpen: () => widget.onOpen(h)))),
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
  final VoidCallback onOpen;
  const HabitTile({super.key, required this.habit, required this.date, required this.onToggle, required this.onEdit, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final done = habit.isDone(date);
    final rate = habit.completionRate(date).clamp(0.0, 1.0).toDouble();
    return GestureDetector(
      onTap: onOpen,
      onLongPress: onEdit,
      child: CardBox(
        child: Row(
          children: [
            GestureDetector(onTap: onToggle, child: Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: done ? AppColors.blue : AppColors.blueSoft), child: Icon(done ? Icons.check : Icons.check_circle_outline, color: done ? Colors.white : AppColors.blue))),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(habit.name, style: TextStyle(fontWeight: FontWeight.w900, decoration: done ? TextDecoration.lineThrough : null))), if (habit.pinned) const Icon(Icons.push_pin, size: 16, color: AppColors.orange)]), Wrap(spacing: 4, children: [Chip(label: Text(habit.category), visualDensity: VisualDensity.compact), Chip(label: Text('${habit.goal} ${habit.unit}'), visualDensity: VisualDensity.compact), if (habit.currentStreak(date) > 0) Text('🔥${habit.currentStreak(date)}', style: const TextStyle(fontWeight: FontWeight.w800))]), LinearProgressIndicator(value: rate, minHeight: 5, backgroundColor: AppColors.blueSoft)])),
          ],
        ),
      ),
    );
  }
}

class Daily extends StatelessWidget {
  final List<Habit> habits;
  final DateTime date;
  final ValueChanged<DateTime> onDate;
  final Future<void> Function(Habit, DateTime) onToggle;
  final VoidCallback onAdd;
  final Future<void> Function(Habit) onEdit;
  final Future<void> Function(Habit) onOpen;
  const Daily({super.key, required this.habits, required this.date, required this.onDate, required this.onToggle, required this.onAdd, required this.onEdit, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final count = DateTime(date.year, date.month + 1, 0).day;
    final days = List.generate(count, (i) => DateTime(date.year, date.month, i + 1));
    final active = habits.where((h) => h.active && h.isScheduled(date)).toList();
    final complete = active.where((h) => h.isDone(date)).length;
    return Column(children: [
      Header(title: 'Daily', subtitle: DateFormat('MMMM yyyy').format(date)),
      SizedBox(height: 82, child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 20), scrollDirection: Axis.horizontal, itemCount: days.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) { final d = days[i]; final selected = Habit.key(d) == Habit.key(date); final done = habits.where((h) => h.active && h.isScheduled(d) && h.isDone(d)).length; return InkWell(onTap: () => onDate(d), child: Container(width: 48, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: selected ? AppColors.blue : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? AppColors.blue : AppColors.border)), child: Column(children: [Text(DateFormat('E').format(d).substring(0, 1), style: TextStyle(color: selected ? Colors.white : AppColors.muted)), Text('${d.day}', style: TextStyle(fontWeight: FontWeight.w900, color: selected ? Colors.white : AppColors.text)), Text('$done', style: TextStyle(fontSize: 11, color: selected ? Colors.white : AppColors.blue))]))); }),
      ),
      Section(title: '${DateFormat('EEE, d MMMM').format(date)} · $complete/${active.length} complete', action: onAdd),
      Expanded(child: active.isEmpty ? const Center(child: Text('No habits scheduled today.', style: TextStyle(color: AppColors.muted))) : ListView(children: active.map((h) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), child: HabitTile(habit: h, date: date, onToggle: () => onToggle(h, date), onEdit: () => onEdit(h), onOpen: () => onOpen(h)))).toList())),
    ]);
  }
}

class Analytics extends StatelessWidget {
  final List<Habit> habits;
  final Map<String, int> moods;
  final List<Map<String, dynamic>> todos;
  final Map<String, int> timers;
  final Future<void> Function(Habit) onOpen;
  const Analytics({super.key, required this.habits, required this.moods, required this.todos, required this.timers, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = habits.where((h) => h.active).toList();
    var overall = 0.0;
    if (active.isNotEmpty) { for (final h in active) { overall += h.completionRate(now); } overall /= active.length; }
    var total = 0;
    var best = 0;
    for (final h in habits) { total += h.totalCompletions(); final b = h.bestStreak(); if (b > best) best = b; }
    var moodAverage = 0.0;
    if (moods.isNotEmpty) { for (final v in moods.values) moodAverage += v; moodAverage /= moods.length; }
    var focusSeconds = 0;
    for (final v in timers.values) focusSeconds += v;
    final last7 = List.generate(7, (i) => DateTime(now.year, now.month, now.day - 6 + i));
    final monthDays = DateTime(now.year, now.month + 1, 0).day;
    var monthDone = 0;
    for (final h in active) monthDone += h.completedInMonth(now);
    var monthPossible = 0;
    for (final h in active) monthPossible += h.scheduledInMonth(now);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Header(title: 'Analytics', subtitle: 'Consistency, patterns and progress'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Row(children: [SizedBox(width: 78, height: 78, child: Stack(fit: StackFit.expand, children: [CircularProgressIndicator(value: overall, strokeWidth: 8, backgroundColor: AppColors.blueSoft, color: AppColors.blue), Center(child: Text('${(overall * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)))])), const SizedBox(width: 18), Expanded(child: Text('${active.length} active habits\n$total total completions\n$best best streak\n${todos.where((x) => x['done'] != true).length} open tasks\nAverage mood: ${moodAverage == 0 ? '—' : '${moodAverage.toStringAsFixed(1)}/5'}', style: const TextStyle(color: AppColors.muted, height: 1.5)))]))),
        Section(title: 'Last 7 days'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: last7.map((day) { final n = active.where((h) => h.isDone(day)).length; final height = active.isEmpty ? 8.0 : (80.0 * n / active.length).clamp(8.0, 80.0).toDouble(); return Expanded(child: Column(children: [Text('$n', style: const TextStyle(fontSize: 11)), const SizedBox(height: 4), Container(height: height, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8))), const SizedBox(height: 4), Text(DateFormat('E').format(day).substring(0, 1), style: const TextStyle(color: AppColors.muted))])); }).toList()))),
        Section(title: 'This month'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [StatMini(label: 'Completed', value: '$monthDone'), StatMini(label: 'Possible', value: '$monthPossible'), StatMini(label: 'Focus', value: formatMinutes(focusSeconds))]))),
        Section(title: 'Habit performance'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Column(children: active.map((h) { final rate = h.completionRate(now).clamp(0.0, 1.0).toDouble(); return InkWell(onTap: () => onOpen(h), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Expanded(child: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w800))), Text('${(rate * 100).round()}%'), const SizedBox(width: 8), SizedBox(width: 65, child: LinearProgressIndicator(value: rate))]))); }).toList()))),
        Section(title: 'Activity heatmap'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Wrap(spacing: 4, runSpacing: 4, children: List.generate(monthDays, (i) { final day = DateTime(now.year, now.month, i + 1); final n = active.where((h) => h.isDone(day)).length; final ratio = active.isEmpty ? 0.0 : n / active.length; final fill = n == 0 ? AppColors.bg : (Color.lerp(AppColors.blueSoft, AppColors.blue, ratio) ?? AppColors.blue); return Tooltip(message: '${DateFormat('d MMM').format(day)} · $n done', child: Container(width: 18, height: 18, decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(4)))); })))),
        Section(title: 'Weekly review'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Best streak: $best days'), Text('Total completions: $total'), Text('Average mood: ${moodAverage == 0 ? 'no entries' : '${moodAverage.toStringAsFixed(1)}/5'}'), Text('Focus time: ${formatMinutes(focusSeconds)}'), const SizedBox(height: 8), Text(active.isEmpty ? 'Create a habit to start your review.' : reviewText(active, now), style: const TextStyle(color: AppColors.muted))]))),
      ]),
    );
  }
}

class StatMini extends StatelessWidget {
  final String label;
  final String value;
  const StatMini({super.key, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: AppColors.muted))]);
}

class Todos extends StatelessWidget {
  final List<Map<String, dynamic>> todos;
  final VoidCallback onAdd;
  final Future<void> Function(int) onEdit;
  final Future<void> Function(int) onToggle;
  const Todos({super.key, required this.todos, required this.onAdd, required this.onEdit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final completed = todos.where((x) => x['done'] == true).length;
    final open = todos.where((x) => x['done'] != true).toList();
    final finished = todos.where((x) => x['done'] == true).toList();
    return Column(children: [
      Header(title: 'To-Do', subtitle: '$completed completed · ${todos.length - completed} remaining', trailing: IconButton(onPressed: onAdd, icon: const Icon(Icons.add))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Column(children: [LinearProgressIndicator(value: todos.isEmpty ? 0 : completed / todos.length, minHeight: 8, backgroundColor: AppColors.blueSoft), const SizedBox(height: 10), Text(todos.isEmpty ? 'No tasks yet' : '$completed of ${todos.length} tasks complete')]))),
      Expanded(child: todos.isEmpty ? const Center(child: Text('Tap + to create a task.', style: TextStyle(color: AppColors.muted))) : ListView(padding: const EdgeInsets.all(20), children: [if (open.isNotEmpty) ...[const Text('Open', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), ...todos.asMap().entries.where((e) => e.value['done'] != true).map((e) => TodoTile(data: e.value, onTap: () => onEdit(e.key), onToggle: () => onToggle(e.key)))], if (finished.isNotEmpty) ...[const SizedBox(height: 18), const Text('Completed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), ...todos.asMap().entries.where((e) => e.value['done'] == true).map((e) => TodoTile(data: e.value, onTap: () => onEdit(e.key), onToggle: () => onToggle(e.key)))]])),
    ]);
  }
}

class TodoTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  const TodoTile({super.key, required this.data, required this.onTap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final rawDue = '${data['due'] ?? ''}';
    final due = rawDue.isEmpty ? null : DateTime.tryParse(rawDue);
    final overdue = due != null && due.isBefore(DateTime.now()) && data['done'] != true;
    final priority = (data['priority'] as num?)?.toInt() ?? 1;
    return Card(child: ListTile(onTap: onTap, leading: Checkbox(value: data['done'] == true, onChanged: (_) => onToggle()), title: Text('${data['title']}', style: TextStyle(fontWeight: FontWeight.w800, decoration: data['done'] == true ? TextDecoration.lineThrough : null)), subtitle: Text('${data['category'] ?? 'General'} · ${priorityName(priority)}${due == null ? '' : ' · ${overdue ? 'Overdue · ' : ''}${DateFormat('d MMM').format(due)}'}', style: TextStyle(color: overdue ? AppColors.red : null)), trailing: const Icon(Icons.chevron_right)));
  }
}

class Profile extends StatelessWidget {
  final List<Habit> habits;
  final VoidCallback onPin;
  final VoidCallback onTimer;
  final VoidCallback onTemplates;
  const Profile({super.key, required this.habits, required this.onPin, required this.onTimer, required this.onTemplates});

  @override
  Widget build(BuildContext context) {
    var total = 0;
    var best = 0;
    for (final h in habits) { total += h.totalCompletions(); final b = h.bestStreak(); if (b > best) best = b; }
    final unlocked = achievementCount(habits);
    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 25), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Header(title: 'Profile', subtitle: 'Your private offline habit space'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Row(children: [const CircleAvatar(radius: 34, backgroundColor: Color(0xFF102A43), child: Icon(Icons.person, color: Colors.white)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${habits.length} habits', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), Text('$total completions · $best best streak', style: const TextStyle(color: AppColors.muted))]))]))),
      Section(title: 'Achievements'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Row(children: [const Icon(Icons.emoji_events_outlined, color: AppColors.orange, size: 34), const SizedBox(width: 12), Text('$unlocked badges unlocked', style: const TextStyle(fontWeight: FontWeight.w900)), const Spacer(), TextButton(onPressed: () => showAchievements(context, habits), child: const Text('View'))]))),
      Section(title: 'Tools'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [ListTile(onTap: onTemplates, leading: const Icon(Icons.auto_awesome_outlined, color: AppColors.blue), title: const Text('Habit templates'), subtitle: const Text('Build a routine quickly'), trailing: const Icon(Icons.chevron_right)), ListTile(onTap: onTimer, leading: const Icon(Icons.timer_outlined, color: AppColors.blue), title: const Text('Focus timer'), subtitle: const Text('Track focused time'), trailing: const Icon(Icons.chevron_right)), ListTile(onTap: onPin, leading: const Icon(Icons.lock_outline, color: AppColors.blue), title: const Text('App lock'), subtitle: const Text('Set or remove local PIN'), trailing: const Icon(Icons.chevron_right)), const ListTile(leading: Icon(Icons.wifi_off_outlined, color: AppColors.blue), title: Text('Offline first'), subtitle: Text('Data stays on this device'))])),
      Section(title: 'About'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: const Text('Simple, private habit tracking with local storage. No account or cloud service is required.', style: TextStyle(color: AppColors.muted, height: 1.5)))),
    ]));
  }
}

class HabitDetail extends StatefulWidget {
  final Habit habit;
  final Future<void> Function() onChanged;
  const HabitDetail({super.key, required this.habit, required this.onChanged});
  @override
  State<HabitDetail> createState() => _HabitDetailState();
}

class _HabitDetailState extends State<HabitDetail> {
  late DateTime month;
  final measurementController = TextEditingController();

  @override
  void initState() { super.initState(); month = DateTime.now(); }
  @override
  void dispose() { measurementController.dispose(); super.dispose(); }

  Future<void> toggleDay(DateTime day) async {
    setState(() => widget.habit.setDone(day, !widget.habit.isDone(day)));
    await widget.onChanged();
  }

  Future<void> addMeasurement() async {
    final value = await showDialog<double>(context: context, builder: (_) => MeasurementDialog(unit: widget.habit.unit));
    if (value == null) return;
    setState(() => widget.habit.measurements[Habit.key(DateTime.now())] = value);
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.habit;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rate = h.completionRate(month).clamp(0.0, 1.0).toDouble();
    final measurements = h.measurements.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return Scaffold(
      appBar: AppBar(title: Text(h.name), actions: [IconButton(onPressed: () => showModalBottomSheet(context: context, backgroundColor: Colors.white, builder: (_) => HabitInfoSheet(habit: h)), icon: const Icon(Icons.info_outline))]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardBox(child: Row(children: [SizedBox(width: 82, height: 82, child: Stack(fit: StackFit.expand, children: [CircularProgressIndicator(value: rate, strokeWidth: 8, backgroundColor: AppColors.blueSoft, color: AppColors.blue), Center(child: Text('${(rate * 100).round()}%'))])), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('🔥 ${h.currentStreak()} day streak', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text('Best: ${h.bestStreak()} days', style: const TextStyle(color: AppColors.muted)), Text('${h.totalCompletions()} total completions', style: const TextStyle(color: AppColors.muted))]))])),
        Section(title: 'Calendar'),
        CardBox(child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1, 1)), icon: const Icon(Icons.chevron_left)), Text(DateFormat('MMMM yyyy').format(month), style: const TextStyle(fontWeight: FontWeight.w900)), IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1, 1)), icon: const Icon(Icons.chevron_right))]), GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: days, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7), itemBuilder: (_, i) { final day = DateTime(month.year, month.month, i + 1); final scheduled = h.isScheduled(day); final done = h.isDone(day); return InkWell(onTap: scheduled ? () => toggleDay(day) : null, child: Container(margin: const EdgeInsets.all(3), decoration: BoxDecoration(color: done ? AppColors.blue : (scheduled ? Colors.white : AppColors.bg), borderRadius: BorderRadius.circular(9), border: Border.all(color: scheduled ? AppColors.border : Colors.transparent)), child: Center(child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: done ? Colors.white : scheduled ? AppColors.text : AppColors.muted))))); })),
        ])),
        Section(title: 'Measurements', action: addMeasurement, actionText: 'Add value'),
        CardBox(child: measurements.isEmpty ? const Text('No measurements yet.', style: TextStyle(color: AppColors.muted)) : Column(children: measurements.take(12).map((entry) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.show_chart, color: AppColors.blue), title: Text('${entry.value} ${h.unit}'), subtitle: Text(entry.key)).toList())),
        Section(title: 'Journal / notes'),
        CardBox(child: Text(h.notes.isEmpty ? 'No notes yet.' : h.notes, style: const TextStyle(height: 1.5))),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: () => toggleDay(DateTime.now()), icon: Icon(h.isDone(DateTime.now()) ? Icons.undo : Icons.check), label: Text(h.isDone(DateTime.now()) ? 'Mark today incomplete' : 'Mark today complete'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      ])),
    );
  }
}

class HabitInfoSheet extends StatelessWidget {
  final Habit habit;
  const HabitInfoSheet({super.key, required this.habit});
  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(habit.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text('Goal: ${habit.goal} ${habit.unit}'), Text('Frequency: ${habit.frequency}'), Text('Category: ${habit.category}'), if (habit.tags.isNotEmpty) Text('Tags: ${habit.tags.join(', ')}'), if (habit.notes.isNotEmpty) Text('Notes: ${habit.notes}'), const SizedBox(height: 16)])));
}

class HabitEditResult {
  final String name;
  final String category;
  final int goal;
  final String unit;
  final String frequency;
  final List<int> weekdays;
  final bool pinned;
  final List<String> tags;
  final String notes;
  final String icon;
  final bool active;
  final bool delete;
  const HabitEditResult({required this.name, required this.category, required this.goal, required this.unit, required this.frequency, required this.weekdays, required this.pinned, required this.tags, required this.notes, required this.icon, required this.active, this.delete = false});
  Habit toHabit() => Habit(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name, category: category, goal: goal, unit: unit, frequency: frequency, weekdays: weekdays, pinned: pinned, tags: tags, notes: notes, icon: icon, active: active);
}

class HabitEditor extends StatefulWidget {
  final Habit? habit;
  const HabitEditor({super.key, this.habit});
  @override State<HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends State<HabitEditor> {
  late final TextEditingController nameController;
  late final TextEditingController goalController;
  late final TextEditingController tagsController;
  late final TextEditingController notesController;
  late String category;
  late String unit;
  late String frequency;
  late List<int> weekdays;
  late bool pinned;
  late bool active;
  late String icon;

  static const categories = ['Personal', 'Health', 'Mind & Body', 'Productivity', 'Learning', 'Goals', 'Finance', 'Routine', 'Other'];
  static const units = ['times', 'minutes', 'hours', 'pages', 'litres', 'km', 'steps', 'reps', 'kg'];

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    nameController = TextEditingController(text: h?.name ?? '');
    goalController = TextEditingController(text: '${h?.goal ?? 1}');
    tagsController = TextEditingController(text: h?.tags.join(', ') ?? '');
    notesController = TextEditingController(text: h?.notes ?? '');
    category = categories.contains(h?.category) ? h!.category : 'Personal';
    unit = units.contains(h?.unit) ? h!.unit : 'times';
    frequency = h?.frequency ?? 'Every day';
    weekdays = List<int>.from(h?.weekdays ?? [1, 2, 3, 4, 5, 6, 7]);
    pinned = h?.pinned ?? false;
    active = h?.active ?? true;
    icon = h?.icon ?? 'check_circle';
  }

  @override
  void dispose() { nameController.dispose(); goalController.dispose(); tagsController.dispose(); notesController.dispose(); super.dispose(); }

  void submit() {
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final tags = tagsController.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    Navigator.pop(context, HabitEditResult(name: name, category: category, goal: (int.tryParse(goalController.text) ?? 1).clamp(1, 1000000), unit: unit, frequency: frequency, weekdays: weekdays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : weekdays, pinned: pinned, tags: tags, notes: notesController.text.trim(), icon: icon, active: active));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.habit == null ? 'Create habit' : 'Edit habit', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(labelText: 'Habit name')),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: DropdownButtonFormField<String>(value: category, items: categories.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) { if (v != null) setState(() => category = v); })), const SizedBox(width: 10), Expanded(child: DropdownButtonFormField<String>(value: unit, items: units.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) { if (v != null) setState(() => unit = v); }))]),
      const SizedBox(height: 10),
      TextField(controller: goalController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target')),
      const SizedBox(height: 10),
      const Text('Frequency', style: TextStyle(fontWeight: FontWeight.w800)),
      Wrap(spacing: 7, children: ['Every day', 'Weekdays', 'Custom'].map((x) => ChoiceChip(label: Text(x), selected: frequency == x, onSelected: (_) => setState(() => frequency = x))).toList()),
      if (frequency == 'Custom') Wrap(spacing: 4, children: List.generate(7, (i) { final day = i + 1; return FilterChip(label: Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][i]), selected: weekdays.contains(day), onSelected: (value) => setState(() { if (value) { if (!weekdays.contains(day)) weekdays.add(day); } else { weekdays.remove(day); } })); })),
      const SizedBox(height: 8),
      TextField(controller: tagsController, decoration: const InputDecoration(labelText: 'Tags, comma separated')),
      const SizedBox(height: 8),
      TextField(controller: notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Journal / notes')),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: pinned, onChanged: (v) => setState(() => pinned = v), title: const Text('Pin to top')),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setState(() => active = v), title: const Text('Active habit')),
      const Text('Icon', style: TextStyle(fontWeight: FontWeight.w800)),
      Wrap(spacing: 4, children: {'check_circle': Icons.check_circle, 'fitness_center': Icons.fitness_center, 'menu_book': Icons.menu_book, 'water_drop': Icons.water_drop, 'self_improvement': Icons.self_improvement, 'bedtime': Icons.bedtime, 'work': Icons.work, 'directions_walk': Icons.directions_walk}.entries.map((e) => ChoiceChip(label: Icon(e.value, size: 18), selected: icon == e.key, onSelected: (_) => setState(() => icon = e.key))).toList()),
      const SizedBox(height: 12),
      if (widget.habit != null) TextButton.icon(onPressed: () => Navigator.pop(context, const HabitEditResult(name: '', category: '', goal: 1, unit: 'times', frequency: 'Every day', weekdays: [1, 2, 3, 4, 5, 6, 7], pinned: false, tags: [], notes: '', icon: 'check_circle', active: false, delete: true)), icon: const Icon(Icons.delete_outline), label: const Text('Delete habit')),
      FilledButton(onPressed: submit, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: Text(widget.habit == null ? 'Create habit' : 'Save changes')),
    ]))));
  }
}

class TodoResult {
  final String title;
  final String category;
  final int priority;
  final DateTime? due;
  final bool delete;
  const TodoResult({required this.title, required this.category, required this.priority, this.due, this.delete = false});
}

class TodoEditor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const TodoEditor({super.key, this.initial});
  @override State<TodoEditor> createState() => _TodoEditorState();
}

class _TodoEditorState extends State<TodoEditor> {
  late final TextEditingController titleController;
  late String category;
  late int priority;
  DateTime? due;

  @override
  void initState() {
    super.initState();
    final data = widget.initial;
    titleController = TextEditingController(text: '${data?['title'] ?? ''}');
    category = '${data?['category'] ?? 'General'}';
    priority = (data?['priority'] as num?)?.toInt() ?? 1;
    final raw = '${data?['due'] ?? ''}';
    due = raw.isEmpty ? null : DateTime.tryParse(raw);
  }

  @override
  void dispose() { titleController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'New task' : 'Edit task'),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'Task')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: ['General', 'College', 'Work', 'Personal'].contains(category) ? category : 'General', items: ['General', 'College', 'Work', 'Personal'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) { if (v != null) setState(() => category = v); }),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(value: priority.clamp(1, 3).toInt(), items: const [DropdownMenuItem(value: 1, child: Text('Low')), DropdownMenuItem(value: 2, child: Text('Medium')), DropdownMenuItem(value: 3, child: Text('High'))], onChanged: (v) => setState(() => priority = v ?? 1)),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_outlined), title: Text(due == null ? 'No due date' : 'Due ${DateFormat('d MMM yyyy').format(due!)}'), onTap: () async { final picked = await showDatePicker(context: context, initialDate: due ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100)); if (picked != null && mounted) setState(() => due = picked); }),
      ])),
      actions: [
        if (widget.initial != null) TextButton(onPressed: () => Navigator.pop(context, const TodoResult(title: '', category: '', priority: 1, delete: true)), child: const Text('Delete')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, TodoResult(title: titleController.text, category: category, priority: priority, due: due)), child: const Text('Save')),
      ],
    );
  }
}

class FocusTimer extends StatefulWidget {
  final StorageService storage;
  final DateTime date;
  final int initial;
  final ValueChanged<int> onSaved;
  const FocusTimer({super.key, required this.storage, required this.date, required this.initial, required this.onSaved});
  @override State<FocusTimer> createState() => _FocusTimerState();
}

class _FocusTimerState extends State<FocusTimer> {
  late int seconds;
  Timer? timer;
  bool running = false;
  @override void initState() { super.initState(); seconds = widget.initial; }
  @override void dispose() { timer?.cancel(); super.dispose(); }
  void toggle() { if (running) { timer?.cancel(); setState(() => running = false); } else { timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => seconds++); }); setState(() => running = true); } }
  Future<void> save() async { final data = await widget.storage.loadTimerSeconds(); data[Habit.key(widget.date)] = seconds; await widget.storage.saveTimerSeconds(data); widget.onSaved(seconds); if (mounted) Navigator.pop(context); }
  String format(int value) { final h = value ~/ 3600; final m = (value % 3600) ~/ 60; final s = value % 60; return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'; }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Focus Timer')), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.timer_outlined, size: 60, color: AppColors.blue), const SizedBox(height: 20), Text(format(seconds), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)), const SizedBox(height: 20), FilledButton.icon(onPressed: toggle, icon: Icon(running ? Icons.pause : Icons.play_arrow), label: Text(running ? 'Pause' : 'Start')), const SizedBox(height: 10), OutlinedButton(onPressed: save, child: const Text('Save today’s focus time'))]));
}

class PinDialog extends StatefulWidget {
  const PinDialog({super.key});
  @override State<PinDialog> createState() => _PinDialogState();
}
class _PinDialogState extends State<PinDialog> {
  final controller = TextEditingController();
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('App lock'), content: TextField(controller: controller, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '4–6 digit PIN')), actions: [TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Remove')), FilledButton(onPressed: () { if (controller.text.length >= 4) Navigator.pop(context, controller.text); }, child: const Text('Save'))]);
}

class LockScreen extends StatelessWidget {
  final String pin;
  final VoidCallback onUnlock;
  const LockScreen({super.key, required this.pin, required this.onUnlock});
  @override Widget build(BuildContext context) => _LockBody(pin: pin, onUnlock: onUnlock);
}
class _LockBody extends StatefulWidget {
  final String pin;
  final VoidCallback onUnlock;
  const _LockBody({required this.pin, required this.onUnlock});
  @override State<_LockBody> createState() => _LockBodyState();
}
class _LockBodyState extends State<_LockBody> {
  final controller = TextEditingController();
  String error = '';
  @override void dispose() { controller.dispose(); super.dispose(); }
  void unlock() { if (controller.text == widget.pin) { widget.onUnlock(); } else { setState(() => error = 'Incorrect PIN'); } }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.lock_outline, size: 64, color: AppColors.blue), const SizedBox(height: 18), const Text('Habit Tracker locked', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 15), TextField(controller: controller, obscureText: true, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'PIN', errorText: error.isEmpty ? null : error)), const SizedBox(height: 15), FilledButton(onPressed: unlock, child: const Text('Unlock'))]))));
}

class Onboarding extends StatefulWidget {
  final Future<void> Function() onDone;
  final Future<void> Function() onCreate;
  const Onboarding({super.key, required this.onDone, required this.onCreate});
  @override State<Onboarding> createState() => _OnboardingState();
}
class _OnboardingState extends State<Onboarding> {
  int page = 0;
  final items = const [
    ['Build better days', 'Track habits, routines and goals in one simple place.', Icons.auto_awesome],
    ['See your progress', 'Streaks, calendars, analytics, measurements and reviews.', Icons.insights],
    ['Private by default', 'Your data stays on this device. No account required.', Icons.lock_outline],
  ];
  Future<void> finish() async { if (page < items.length - 1) { setState(() => page++); } else { await widget.onDone(); } }
  @override Widget build(BuildContext context) { final item = items[page]; return Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [const Spacer(), CircleAvatar(radius: 58, backgroundColor: AppColors.blueSoft, child: Icon(Icons.check_circle, size: 70, color: AppColors.blue)), const SizedBox(height: 38), Text(item[0] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)), const SizedBox(height: 15), Text(item[1] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AppColors.muted, height: 1.5)), const SizedBox(height: 25), Icon(item[2] as IconData, size: 42, color: AppColors.blue), const Spacer(), Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(items.length, (i) => Container(width: i == page ? 26 : 8, height: 8, margin: const EdgeInsets.all(4), decoration: BoxDecoration(color: i == page ? AppColors.blue : AppColors.border, borderRadius: BorderRadius.circular(8))))), const SizedBox(height: 20), SizedBox(width: double.infinity, child: FilledButton(onPressed: finish, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: Text(page < items.length - 1 ? 'Next' : 'Get started'))), TextButton(onPressed: widget.onDone, child: const Text('Skip'))])))); }
}

class TemplateSheet extends StatelessWidget {
  const TemplateSheet({super.key});
  static const templates = <String, List<String>>{
    'Morning routine': ['Wake up early', 'Drink Water', 'Exercise', 'Meditate', 'Plan Tomorrow'],
    'Study routine': ['Reading / Learning', 'Day Planning', 'Project Work', 'Goal Journaling'],
    'Healthy day': ['Drink Water', 'Gym', '10k Steps', 'Cold Shower', 'Sleep on Time'],
  };
  @override Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Habit templates', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 10), ...templates.entries.map((entry) => ListTile(onTap: () => Navigator.pop(context, entry.value), leading: const Icon(Icons.auto_awesome, color: AppColors.blue), title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${entry.value.length} habits'), trailing: const Icon(Icons.chevron_right)))])));
}

class MeasurementDialog extends StatefulWidget {
  final String unit;
  const MeasurementDialog({super.key, required this.unit});
  @override State<MeasurementDialog> createState() => _MeasurementDialogState();
}
class _MeasurementDialogState extends State<MeasurementDialog> {
  final controller = TextEditingController();
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: Text('Add ${widget.unit}'), content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Value (${widget.unit})')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { final value = double.tryParse(controller.text.trim()); if (value != null) Navigator.pop(context, value); }, child: const Text('Save'))]);
}

void showAchievements(BuildContext context, List<Habit> habits) {
  showModalBottomSheet(context: context, backgroundColor: Colors.white, builder: (_) => Achievements(habits: habits));
}
class Achievements extends StatelessWidget {
  final List<Habit> habits;
  const Achievements({super.key, required this.habits});
  @override Widget build(BuildContext context) { var total = 0; var best = 0; for (final h in habits) { total += h.totalCompletions(); final b = h.bestStreak(); if (b > best) best = b; } final badges = [('🌱', 'First habit', habits.isNotEmpty), ('🔥', '7 day streak', best >= 7), ('🏆', '30 day streak', best >= 30), ('💯', '100 completions', total >= 100), ('📅', 'Perfect week', hasPerfectWeek(habits)), ('⭐', '5 habits', habits.length >= 5), ('🚀', '10 habits', habits.length >= 10)]; return SafeArea(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Achievements', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 12), ...badges.map((badge) => ListTile(leading: Text(badge.$1, style: const TextStyle(fontSize: 26)), title: Text(badge.$2, style: const TextStyle(fontWeight: FontWeight.w800)), trailing: Icon(badge.$3 ? Icons.check_circle : Icons.lock_outline, color: badge.$3 ? AppColors.green : AppColors.muted)))]))); }
}

int achievementCount(List<Habit> habits) {
  var total = 0;
  var best = 0;
  for (final h in habits) { total += h.totalCompletions(); final b = h.bestStreak(); if (b > best) best = b; }
  return [habits.isNotEmpty, best >= 7, best >= 30, total >= 100, hasPerfectWeek(habits), habits.length >= 5, habits.length >= 10].where((x) => x).length;
}

bool hasPerfectWeek(List<Habit> habits) {
  final active = habits.where((h) => h.active).toList();
  if (active.isEmpty) return false;
  final today = DateTime.now();
  for (var i = 0; i < 7; i++) {
    final day = today.subtract(Duration(days: i));
    for (final habit in active) {
      if (habit.isScheduled(day) && !habit.isDone(day)) return false;
    }
  }
  return true;
}

String reviewText(List<Habit> habits, DateTime date) {
  Habit strongest = habits.first;
  for (final h in habits) { if (h.completionRate(date) > strongest.completionRate(date)) strongest = h; }
  return '${strongest.name} is currently your strongest habit. Review missed days and notes each week.';
}

String formatMinutes(int seconds) {
  final minutes = seconds ~/ 60;
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  return hours > 0 ? '${hours}h ${remaining}m' : '${remaining}m';
}

String priorityName(int value) => value == 3 ? 'High' : value == 2 ? 'Medium' : 'Low';

Future<bool> confirmDialog(BuildContext context, String title, String message) async {
  return await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))])) ?? false;
}
