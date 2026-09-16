import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/habit.dart';
import 'services/storage_service.dart';

class AppColors {
  static const blue = Color(0xFF1769FF);
  static const soft = Color(0xFFEAF1FF);
  static const bg = Color(0xFFF5F7FB);
  static const text = Color(0xFF142033);
  static const muted = Color(0xFF718096);
  static const border = Color(0xFFE6EAF0);
  static const green = Color(0xFF16A36A);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFE05252);
}

class HabitApp extends StatelessWidget {
  const HabitApp({super.key});
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final store = StorageService();
  List<Habit> habits = [];
  List<Map<String, dynamic>> todos = [];
  Map<String, int> moods = {};
  Map<String, int> focus = {};
  String? pin;
  bool loading = true;
  bool locked = false;
  int tab = 0;
  DateTime selected = DateTime.now();

  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    habits = await store.loadHabits();
    todos = await store.loadTodos();
    moods = await store.loadMoods();
    focus = await store.loadTimerSeconds();
    pin = await store.loadPin();
    locked = pin != null && pin!.isNotEmpty;
    if (mounted) setState(() => loading = false);
  }

  Future<void> saveHabits() => store.saveHabits(habits);

  Future<void> addHabit() async {
    final result = await showModalBottomSheet<HabitEdit>(context: context, isScrollControlled: true, backgroundColor: Colors.white, builder: (_) => const HabitEditor());
    if (!mounted || result == null || result.name.trim().isEmpty) return;
    setState(() => habits.add(result.toHabit()));
    await saveHabits();
  }

  Future<void> editHabit(Habit habit) async {
    final result = await showModalBottomSheet<HabitEdit>(context: context, isScrollControlled: true, backgroundColor: Colors.white, builder: (_) => HabitEditor(habit: habit));
    if (!mounted || result == null) return;
    if (result.delete) {
      habits.removeWhere((item) => item.id == habit.id);
    } else {
      habit.name = result.name;
      habit.category = result.category;
      habit.goal = result.goal;
      habit.unit = result.unit;
      habit.frequency = result.frequency;
      habit.weekdays = result.weekdays;
      habit.pinned = result.pinned;
      habit.active = result.active;
      habit.tags = result.tags;
      habit.notes = result.notes;
    }
    setState(() {});
    await saveHabits();
  }

  Future<void> toggleHabit(Habit habit, DateTime day) async {
    setState(() => habit.setDone(day, !habit.isDone(day)));
    await saveHabits();
  }

  Future<void> openHabit(Habit habit) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => HabitDetail(habit: habit, onChanged: saveHabits)));
    if (mounted) setState(() {});
  }

  Future<void> addTodo() async {
    final result = await showDialog<TodoEdit>(context: context, builder: (_) => const TodoEditor());
    if (!mounted || result == null || result.title.trim().isEmpty) return;
    todos.add({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'title': result.title.trim(), 'done': false, 'priority': result.priority, 'category': result.category, 'due': result.due == null ? '' : Habit.key(result.due!)});
    setState(() {});
    await store.saveTodos(todos);
  }

  Future<void> editTodo(int index) async {
    final result = await showDialog<TodoEdit>(context: context, builder: (_) => TodoEditor(existing: todos[index]));
    if (!mounted || result == null) return;
    todos[index]['title'] = result.title.trim();
    todos[index]['priority'] = result.priority;
    todos[index]['category'] = result.category;
    todos[index]['due'] = result.due == null ? '' : Habit.key(result.due!);
    setState(() {});
    await store.saveTodos(todos);
  }

  Future<void> toggleTodo(int index) async { todos[index]['done'] = todos[index]['done'] != true; setState(() {}); await store.saveTodos(todos); }
  Future<void> deleteTodo(int index) async { todos.removeAt(index); setState(() {}); await store.saveTodos(todos); }

  Future<void> openTimer() async {
    final key = Habit.key(selected);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => FocusTimer(storage: store, date: selected, initial: focus[key] ?? 0, onSaved: (value) => setState(() => focus[key] = value))));
  }

  Future<void> setPin() async {
    final result = await showDialog<String>(context: context, builder: (_) => PinDialog(current: pin));
    if (result == null) return;
    await store.savePin(result);
    if (mounted) setState(() { pin = result.isEmpty ? null : result; locked = false; });
  }

  Future<void> unlock() async {
    final ok = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => LockDialog(pin: pin!));
    if (ok == true && mounted) setState(() => locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (locked && pin != null) return LockScreen(onUnlock: unlock);
    final pages = <Widget>[
      Dashboard(habits: habits, moods: moods, date: selected, onAdd: addHabit, onToggle: toggleHabit, onOpen: openHabit, onEdit: editHabit, onMood: (value) async { moods[Habit.key(selected)] = value; setState(() {}); await store.saveMoods(moods); }, onTimer: openTimer),
      Daily(habits: habits, date: selected, onDate: (value) => setState(() => selected = value), onToggle: toggleHabit, onOpen: openHabit, onEdit: editHabit, onAdd: addHabit),
      Stats(habits: habits, moods: moods, onOpen: openHabit),
      TodoPage(todos: todos, onAdd: addTodo, onEdit: editTodo, onToggle: toggleTodo, onDelete: deleteTodo),
      Profile(habits: habits, onTimer: openTimer, onPin: setPin, hasPin: pin != null),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: tab, children: pages)),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, indicatorColor: AppColors.soft, onDestinationSelected: (value) => setState(() => tab = value), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Habits'),
        NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Stats'),
        NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'To-Do'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      ]),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const PageHeader({super.key, required this.title, required this.subtitle, this.action});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 14), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.text)), Text(subtitle, style: const TextStyle(color: AppColors.muted))])), if (action != null) action!]));
}

class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  @override Widget build(BuildContext context) => Container(padding: padding, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: child);
}

class SectionTitle extends StatelessWidget {
  final String title, label;
  final VoidCallback? onAdd;
  const SectionTitle({super.key, required this.title, this.onAdd, this.label = 'Add'});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 10), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))), if (onAdd != null) TextButton(onPressed: onAdd, child: Text(label))]));
}

class MiniStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const MiniStat({super.key, required this.value, required this.label, required this.icon});
  @override Widget build(BuildContext context) => CardBox(padding: const EdgeInsets.all(14), child: Row(children: [Icon(icon, color: AppColors.blue), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted))]))]));
}

class Dashboard extends StatefulWidget {
  final List<Habit> habits;
  final Map<String, int> moods;
  final DateTime date;
  final VoidCallback onAdd, onTimer;
  final Future<void> Function(Habit, DateTime) onToggle;
  final Future<void> Function(Habit) onOpen, onEdit;
  final Future<void> Function(int) onMood;
  const Dashboard({super.key, required this.habits, required this.moods, required this.date, required this.onAdd, required this.onTimer, required this.onToggle, required this.onOpen, required this.onEdit, required this.onMood});
  @override State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String search = '', filter = 'All';
  @override Widget build(BuildContext context) {
    final active = widget.habits.where((h) => h.active).toList();
    final scheduled = active.where((h) => h.isScheduled(widget.date)).toList();
    final done = scheduled.where((h) => h.isDone(widget.date)).length;
    final progress = scheduled.isEmpty ? 0.0 : done / scheduled.length;
    final visible = active.where((h) {
      final q = search.toLowerCase();
      final matchText = q.isEmpty || h.name.toLowerCase().contains(q) || h.category.toLowerCase().contains(q) || h.tags.any((tag) => tag.toLowerCase().contains(q));
      final matchFilter = filter == 'All' || (filter == 'Pinned' && h.pinned) || (filter == 'Completed' && h.isDone(widget.date)) || (filter == 'Missed' && h.isScheduled(widget.date) && !h.isDone(widget.date));
      return matchText && matchFilter;
    }).toList();
    visible.sort((a, b) => a.pinned == b.pinned ? 0 : (a.pinned ? -1 : 1));
    final streak = active.fold<int>(0, (max, h) => h.currentStreak(widget.date) > max ? h.currentStreak(widget.date) : max);
    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeader(title: 'Good day 👋', subtitle: DateFormat('EEEE, d MMMM').format(widget.date), action: IconButton(onPressed: widget.onTimer, icon: const Icon(Icons.timer_outlined))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: TextField(onChanged: (v) => setState(() => search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search habits or tags'))),
      const SizedBox(height: 8),
      SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: ['All', 'Pinned', 'Completed', 'Missed'].map((item) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(item), selected: filter == item, onSelected: (_) => setState(() => filter = item)))).toList())),
      Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child: CardBox(child: Row(children: [SizedBox(width: 82, height: 82, child: Stack(fit: StackFit.expand, children: [CircularProgressIndicator(value: progress, strokeWidth: 9, backgroundColor: AppColors.soft, color: AppColors.blue), Center(child: Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)))])), const SizedBox(width: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Today's progress", style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), Text('$done of ${scheduled.length} scheduled', style: const TextStyle(color: AppColors.muted)), const SizedBox(height: 8), LinearProgressIndicator(value: progress, backgroundColor: AppColors.soft)]))]))),
      Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Row(children: [Expanded(child: MiniStat(value: '$streak', label: 'Current streak', icon: Icons.local_fire_department)), const SizedBox(width: 10), Expanded(child: MiniStat(value: '${active.length}', label: 'Active habits', icon: Icons.checklist))])),
      SectionTitle(title: "Today's habits", onAdd: widget.onAdd, label: '＋ Add'),
      if (visible.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No matching habits.', style: TextStyle(color: AppColors.muted)))) else ...visible.map((h) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), child: HabitTile(habit: h, date: widget.date, onToggle: () => widget.onToggle(h, widget.date), onOpen: () => widget.onOpen(h), onEdit: () => widget.onEdit(h)))),
      const SectionTitle(title: 'Mood'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(5, (index) {
        final value = index + 1;
        final selected = widget.moods[Habit.key(widget.date)] == value;
        return InkWell(onTap: () => widget.onMood(value), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: selected ? AppColors.soft : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Text(['😫', '😕', '😐', '🙂', '😄'][index], style: const TextStyle(fontSize: 28))));
      })))),
    ]));
  }
}

class HabitTile extends StatelessWidget {
  final Habit habit;
  final DateTime date;
  final VoidCallback onToggle, onOpen, onEdit;
  const HabitTile({super.key, required this.habit, required this.date, required this.onToggle, required this.onOpen, required this.onEdit});
  @override Widget build(BuildContext context) {
    final done = habit.isDone(date);
    return GestureDetector(onTap: onOpen, onLongPress: onEdit, child: CardBox(child: Row(children: [GestureDetector(onTap: onToggle, child: CircleAvatar(radius: 21, backgroundColor: done ? AppColors.blue : AppColors.soft, child: Icon(done ? Icons.check : Icons.circle_outlined, color: done ? Colors.white : AppColors.blue))), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(habit.name, style: TextStyle(fontWeight: FontWeight.w900, decoration: done ? TextDecoration.lineThrough : null))), if (habit.pinned) const Icon(Icons.push_pin, size: 15, color: AppColors.blue)]), Text('${habit.category} · ${habit.goal} ${habit.unit} · 🔥 ${habit.currentStreak(date)}', style: const TextStyle(color: AppColors.muted, fontSize: 12))]))])));
  }
}

class Daily extends StatelessWidget {
  final List<Habit> habits;
  final DateTime date;
  final ValueChanged<DateTime> onDate;
  final Future<void> Function(Habit, DateTime) onToggle;
  final Future<void> Function(Habit) onOpen, onEdit;
  final VoidCallback onAdd;
  const Daily({super.key, required this.habits, required this.date, required this.onDate, required this.onToggle, required this.onOpen, required this.onEdit, required this.onAdd});
  @override Widget build(BuildContext context) {
    final count = DateTime(date.year, date.month + 1, 0).day;
    final list = habits.where((h) => h.active && h.isScheduled(date)).toList();
    final done = list.where((h) => h.isDone(date)).length;
    return Column(children: [
      PageHeader(title: 'Daily', subtitle: '$done of ${list.length} completed', action: IconButton(onPressed: onAdd, icon: const Icon(Icons.add))),
      SizedBox(height: 82, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: count, padding: const EdgeInsets.symmetric(horizontal: 14), itemBuilder: (_, index) {
        final day = DateTime(date.year, date.month, index + 1);
        final selected = Habit.key(day) == Habit.key(date);
        return GestureDetector(onTap: () => onDate(day), child: Container(width: 52, margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8), decoration: BoxDecoration(color: selected ? AppColors.blue : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? AppColors.blue : AppColors.border)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(DateFormat('EEE').format(day).substring(0, 2), style: TextStyle(color: selected ? Colors.white : AppColors.muted, fontSize: 11)), const SizedBox(height: 4), Text('${day.day}', style: TextStyle(color: selected ? Colors.white : AppColors.text, fontWeight: FontWeight.w900))])));
      })),
      Expanded(child: list.isEmpty ? const Center(child: Text('No habits scheduled today.', style: TextStyle(color: AppColors.muted))) : ListView.builder(padding: const EdgeInsets.fromLTRB(20, 10, 20, 20), itemCount: list.length, itemBuilder: (_, index) { final h = list[index]; return Padding(padding: const EdgeInsets.only(bottom: 10), child: HabitTile(habit: h, date: date, onToggle: () => onToggle(h, date), onOpen: () => onOpen(h), onEdit: () => onEdit(h))); })),
    ]);
  }
}

class Stats extends StatefulWidget {
  final List<Habit> habits;
  final Map<String, int> moods;
  final Future<void> Function(Habit) onOpen;
  const Stats({super.key, required this.habits, required this.moods, required this.onOpen});
  @override State<Stats> createState() => _StatsState();
}

class _StatsState extends State<Stats> {
  String range = '30D';
  int year = DateTime.now().year;
  String selectedHabit = 'All habits';
  int get rangeDays => range == '7D' ? 7 : range == '90D' ? 90 : range == '1Y' ? 365 : 30;
  List<Habit> get active => widget.habits.where((h) => h.active).toList();

  double rate(DateTime start, DateTime end) {
    var done = 0, scheduled = 0;
    for (final h in active) {
      for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
        if (h.isScheduled(day)) { scheduled++; if (h.isDone(day)) done++; }
      }
    }
    return scheduled == 0 ? 0 : done / scheduled;
  }

  int completionCount(DateTime start, DateTime end) {
    var total = 0;
    for (final h in active) {
      for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1))) { if (h.isDone(day)) total++; }
    }
    return total;
  }

  @override Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: rangeDays - 1));
    final completion = rate(start, today);
    final total = completionCount(start, today);
    final current = active.fold<int>(0, (max, h) => h.currentStreak() > max ? h.currentStreak() : max);
    final best = active.fold<int>(0, (max, h) => h.bestStreak() > max ? h.bestStreak() : max);
    final names = <String>['All habits', ...active.map((h) => h.name)];
    if (!names.contains(selectedHabit)) selectedHabit = 'All habits';
    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 30), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PageHeader(title: 'Analytics', subtitle: 'Your habit history and patterns'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Wrap(spacing: 7, children: ['7D', '30D', '90D', '1Y'].map((item) => ChoiceChip(label: Text(item), selected: range == item, onSelected: (_) => setState(() => range = item))).toList())),
      Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.7, children: [MiniStat(value: '${(completion * 100).round()}%', label: 'Completion rate', icon: Icons.percent), MiniStat(value: '$current', label: 'Current streak', icon: Icons.local_fire_department), MiniStat(value: '$best', label: 'Best streak', icon: Icons.emoji_events_outlined), MiniStat(value: '$total', label: 'Completions', icon: Icons.check_circle_outline)])),
      const SectionTitle(title: 'Completion trend'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: TrendChart(habits: active, days: rangeDays))),
      const SectionTitle(title: 'Contribution activity'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('Activity heatmap', style: TextStyle(fontWeight: FontWeight.w900)), const Spacer(), SizedBox(width: 145, child: DropdownButton<String>(isExpanded: true, value: selectedHabit, items: names.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) setState(() => selectedHabit = value); }))]),
        const SizedBox(height: 10),
        ActivityHeatmap(habits: active, year: year, habitName: selectedHabit),
        const SizedBox(height: 10),
        Row(children: [const Text('Less', style: TextStyle(fontSize: 11, color: AppColors.muted)), ...List.generate(5, (i) => Container(width: 14, height: 14, margin: const EdgeInsets.only(left: 5), decoration: BoxDecoration(color: heatColor(i), borderRadius: BorderRadius.circular(3)))), const Text('  More', style: TextStyle(fontSize: 11, color: AppColors.muted))]),
      ]))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [IconButton(onPressed: year > 2020 ? () => setState(() => year--) : null, icon: const Icon(Icons.chevron_left)), Expanded(child: Center(child: Text('$year heatmap', style: const TextStyle(fontWeight: FontWeight.w800)))), IconButton(onPressed: () => setState(() => year++), icon: const Icon(Icons.chevron_right))])),
      const SectionTitle(title: 'Day-of-week consistency'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: WeekdayAnalysis(habits: active))),
      const SectionTitle(title: 'Habit performance'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Column(children: active.map((h) { final value = h.completionRate(now); return ListTile(contentPadding: EdgeInsets.zero, onTap: () => widget.onOpen(h), title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: LinearProgressIndicator(value: value.clamp(0.0, 1.0).toDouble(), backgroundColor: AppColors.soft)), trailing: Text('${(value * 100).round()}%')); }).toList()))),
      const SectionTitle(title: 'Streak history'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: StreakHistory(habits: active))),
      const SectionTitle(title: 'Needs attention'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: NeedsAttention(habits: active))),
      const SectionTitle(title: 'Weekly review'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: WeeklyReview(habits: active, moods: widget.moods))),
    ]));
  }
}

class TrendChart extends StatelessWidget {
  final List<Habit> habits;
  final int days;
  const TrendChart({super.key, required this.habits, required this.days});
  List<double> values() {
    final result = <double>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var offset = days - 1; offset >= 0; offset--) {
      final day = today.subtract(Duration(days: offset));
      var total = 0, done = 0;
      for (final h in habits) { if (h.isScheduled(day)) { total++; if (h.isDone(day)) done++; } }
      result.add(total == 0 ? 0.0 : done / total);
    }
    return result;
  }
  @override Widget build(BuildContext context) => SizedBox(height: 190, child: CustomPaint(painter: TrendPainter(values()), child: const SizedBox.expand()));
}

class TrendPainter extends CustomPainter {
  final List<double> data;
  TrendPainter(this.data);
  @override void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final line = Paint()..color = AppColors.blue..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fill = Paint()..color = AppColors.soft..style = PaintingStyle.fill;
    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1 ? 0.0 : size.width * i / (data.length - 1);
      final y = size.height - 25 - data[i] * (size.height - 55);
      points.add(Offset(x, y));
    }
    final area = Path()..moveTo(points.first.dx, size.height - 25);
    for (final p in points) { area.lineTo(p.dx, p.dy); }
    area.lineTo(points.last.dx, size.height - 25); area.close();
    canvas.drawPath(area, fill);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) { path.lineTo(points[i].dx, points[i].dy); }
    canvas.drawPath(path, line);
    for (final p in points) { canvas.drawCircle(p, 3, Paint()..color = AppColors.blue); }
    final axis = Paint()..color = AppColors.border..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 25), Offset(size.width, size.height - 25), axis);
  }
  @override bool shouldRepaint(covariant TrendPainter oldDelegate) => true;
}

class ActivityHeatmap extends StatelessWidget {
  final List<Habit> habits;
  final int year;
  final String habitName;
  const ActivityHeatmap({super.key, required this.habits, required this.year, required this.habitName});
  int level(DateTime day) {
    Habit? target;
    if (habitName != 'All habits') {
      for (final h in habits) { if (h.name == habitName) { target = h; break; } }
    }
    var scheduled = 0, done = 0;
    if (target != null) {
      if (target!.isScheduled(day)) { scheduled = 1; if (target!.isDone(day)) done = 1; }
    } else {
      for (final h in habits) { if (h.isScheduled(day)) { scheduled++; if (h.isDone(day)) done++; } }
    }
    if (scheduled == 0) return 0;
    return ((done / scheduled) * 4).ceil().clamp(0, 4).toInt();
  }
  @override Widget build(BuildContext context) {
    final first = DateTime(year, 1, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final weeks = <Widget>[];
    for (var week = 0; week < 53; week++) {
      final cells = <Widget>[];
      for (var row = 0; row < 7; row++) {
        final day = start.add(Duration(days: week * 7 + row));
        cells.add(Tooltip(message: '${DateFormat('d MMM yyyy').format(day)} · ${level(day)}/4', child: Container(width: 12, height: 12, margin: const EdgeInsets.only(bottom: 3), decoration: BoxDecoration(color: day.year == year ? heatColor(level(day)) : Colors.transparent, borderRadius: BorderRadius.circular(3)))));
      }
      weeks.add(Padding(padding: const EdgeInsets.only(right: 3), child: Column(children: cells)));
    }
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: weeks));
  }
}

Color heatColor(int level) { switch (level) { case 1: return const Color(0xFFD7E4FF); case 2: return const Color(0xFFAFC9FF); case 3: return const Color(0xFF6F9FFF); case 4: return AppColors.blue; default: return const Color(0xFFEDEFF3); } }

class WeekdayAnalysis extends StatelessWidget {
  final List<Habit> habits;
  const WeekdayAnalysis({super.key, required this.habits});
  @override Widget build(BuildContext context) => Column(children: List.generate(7, (index) {
    final weekday = index + 1;
    var done = 0, total = 0;
    for (var offset = 0; offset < 90; offset++) {
      final day = DateTime.now().subtract(Duration(days: offset));
      if (day.weekday != weekday) continue;
      for (final h in habits) { if (h.isScheduled(day)) { total++; if (h.isDone(day)) done++; } }
    }
    final value = total == 0 ? 0.0 : done / total;
    final label = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index];
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [SizedBox(width: 34, child: Text(label, style: const TextStyle(fontSize: 12))), Expanded(child: LinearProgressIndicator(value: value, minHeight: 9, backgroundColor: AppColors.soft)), const SizedBox(width: 10), SizedBox(width: 38, child: Text('${(value * 100).round()}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)))]));
  }));
}

class StreakHistory extends StatelessWidget {
  final List<Habit> habits;
  const StreakHistory({super.key, required this.habits});
  @override Widget build(BuildContext context) {
    if (habits.isEmpty) return const Text('Create a habit to build streak history.', style: TextStyle(color: AppColors.muted));
    return Column(children: habits.map((h) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.local_fire_department_outlined, color: AppColors.amber), title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Current ${h.currentStreak()} days · Longest ${h.bestStreak()} days')).toList());
  }
}

class NeedsAttention extends StatelessWidget {
  final List<Habit> habits;
  const NeedsAttention({super.key, required this.habits});
  @override Widget build(BuildContext context) {
    final now = DateTime.now();
    final items = habits.where((h) => h.totalCompletions() > 0 && h.completionRate(now) < .6).toList();
    if (items.isEmpty) return const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.check_circle, color: AppColors.green), title: Text('Everything is on track'), subtitle: Text('Keep your current rhythm going.'));
    return Column(children: items.take(4).map((h) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.trending_down, color: AppColors.red), title: Text(h.name), subtitle: Text('${(h.completionRate(now) * 100).round()}% this month')).toList());
  }
}

class WeeklyReview extends StatelessWidget {
  final List<Habit> habits;
  final Map<String, int> moods;
  const WeeklyReview({super.key, required this.habits, required this.moods});
  @override Widget build(BuildContext context) {
    var done = 0, total = 0;
    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime.now().subtract(Duration(days: offset));
      for (final h in habits) { if (h.isScheduled(day)) { total++; if (h.isDone(day)) done++; } }
    }
    final value = total == 0 ? 0.0 : done / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Last 7 days: ${(value * 100).round()}% completion', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6), LinearProgressIndicator(value: value, backgroundColor: AppColors.soft), const SizedBox(height: 10), Text('Mood entries this week: ${moods.length}')]);
  }
}

class TodoPage extends StatefulWidget {
  final List<Map<String, dynamic>> todos;
  final VoidCallback onAdd;
  final Future<void> Function(int) onEdit, onToggle, onDelete;
  const TodoPage({super.key, required this.todos, required this.onAdd, required this.onEdit, required this.onToggle, required this.onDelete});
  @override State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  String search = '', filter = 'All';
  @override Widget build(BuildContext context) {
    final entries = widget.todos.asMap().entries.where((entry) {
      final item = entry.value;
      final q = search.toLowerCase();
      final textMatch = q.isEmpty || '${item['title']}'.toLowerCase().contains(q) || '${item['category']}'.toLowerCase().contains(q);
      final filterMatch = filter == 'All' || (filter == 'Open' && item['done'] != true) || (filter == 'Completed' && item['done'] == true) || (filter == 'High' && item['priority'] == 3);
      return textMatch && filterMatch;
    }).toList();
    final done = widget.todos.where((item) => item['done'] == true).length;
    final progress = widget.todos.isEmpty ? 0.0 : done / widget.todos.length;
    return Column(children: [
      PageHeader(title: 'To-Do', subtitle: '$done completed · ${widget.todos.length - done} remaining', action: IconButton(onPressed: widget.onAdd, icon: const Icon(Icons.add))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: TextField(onChanged: (v) => setState(() => search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search tasks'))),
      const SizedBox(height: 8),
      SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: ['All', 'Open', 'Completed', 'High'].map((item) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(item), selected: filter == item, onSelected: (_) => setState(() => filter = item)))).toList())),
      Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child: CardBox(child: Column(children: [LinearProgressIndicator(value: progress, backgroundColor: AppColors.soft), const SizedBox(height: 8), Text(widget.todos.isEmpty ? 'No tasks yet' : '$done of ${widget.todos.length} complete')]))),
      Expanded(child: entries.isEmpty ? const Center(child: Text('No tasks match your filter.', style: TextStyle(color: AppColors.muted))) : ListView.builder(padding: const EdgeInsets.all(20), itemCount: entries.length, itemBuilder: (_, index) {
        final entry = entries[index];
        final item = entry.value;
        return Dismissible(key: ValueKey(item['id']), background: Container(color: AppColors.red, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), child: const Icon(Icons.delete, color: Colors.white)), onDismissed: (_) => widget.onDelete(entry.key), child: Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(onTap: () => widget.onEdit(entry.key), leading: Checkbox(value: item['done'] == true, onChanged: (_) => widget.onToggle(entry.key)), title: Text('${item['title']}', style: TextStyle(fontWeight: FontWeight.w800, decoration: item['done'] == true ? TextDecoration.lineThrough : null)), subtitle: Text('${item['category'] ?? 'General'} · ${priorityName((item['priority'] as num?)?.toInt() ?? 1)}'), trailing: const Icon(Icons.edit_outlined, size: 18))));
      })),
    ]);
  }
}

String priorityName(int value) => value == 3 ? 'High' : value == 2 ? 'Medium' : 'Low';

class Profile extends StatelessWidget {
  final List<Habit> habits;
  final VoidCallback onTimer, onPin;
  final bool hasPin;
  const Profile({super.key, required this.habits, required this.onTimer, required this.onPin, required this.hasPin});
  @override Widget build(BuildContext context) {
    final total = habits.fold<int>(0, (sum, h) => sum + h.totalCompletions());
    final best = habits.fold<int>(0, (max, h) => h.bestStreak() > max ? h.bestStreak() : max);
    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 30), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PageHeader(title: 'Profile', subtitle: 'Your private habit space'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Row(children: [const CircleAvatar(radius: 34, backgroundColor: AppColors.soft, child: Icon(Icons.person, color: AppColors.blue, size: 34)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Habit Builder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('${habits.length} habits · $total completions', style: const TextStyle(color: AppColors.muted))]))]))),
      Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Row(children: [Expanded(child: MiniStat(value: '$best', label: 'Best streak', icon: Icons.local_fire_department)), const SizedBox(width: 10), Expanded(child: MiniStat(value: '$total', label: 'Completions', icon: Icons.check_circle_outline))])),
      const SectionTitle(title: 'Achievements'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Achievements(habits: habits)),
      const SectionTitle(title: 'Tools'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Column(children: [ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.timer_outlined, color: AppColors.blue), title: const Text('Focus timer'), subtitle: const Text('Track focused work locally'), onTap: onTimer), ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.lock_outline, color: AppColors.blue), title: Text(hasPin ? 'Change app PIN' : 'Set app PIN'), subtitle: const Text('Protect the app on this device'), onTap: onPin)]))),
      const SectionTitle(title: 'Privacy'),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Row(children: [Icon(Icons.offline_bolt_outlined, color: AppColors.green), SizedBox(width: 12), Expanded(child: Text('Your habit data stays on this device. No account or cloud backup is required.', style: TextStyle(height: 1.4)))]))),
    ]));
  }
}

class Achievements extends StatelessWidget {
  final List<Habit> habits;
  const Achievements({super.key, required this.habits});
  @override Widget build(BuildContext context) {
    final total = habits.fold<int>(0, (sum, h) => sum + h.totalCompletions());
    final streak = habits.fold<int>(0, (max, h) => h.bestStreak() > max ? h.bestStreak() : max);
    final data = <List<Object>>[['🌱', 'First step', total >= 1], ['🔥', '7 day streak', streak >= 7], ['🏆', '30 day streak', streak >= 30], ['💯', '100 completions', total >= 100]];
    return CardBox(child: Wrap(spacing: 8, runSpacing: 8, children: data.map((item) { final unlocked = item[2] as bool; return Container(width: 140, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: unlocked ? AppColors.soft : AppColors.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Row(children: [Text(item[0] as String, style: const TextStyle(fontSize: 22)), const SizedBox(width: 7), Expanded(child: Text(item[1] as String, style: TextStyle(fontWeight: FontWeight.w800, color: unlocked ? AppColors.text : AppColors.muted)))])); }).toList()));
  }
}

class HabitDetail extends StatefulWidget {
  final Habit habit;
  final Future<void> Function() onChanged;
  const HabitDetail({super.key, required this.habit, required this.onChanged});
  @override State<HabitDetail> createState() => _HabitDetailState();
}

class _HabitDetailState extends State<HabitDetail> {
  late DateTime month;
  @override void initState() { super.initState(); final now = DateTime.now(); month = DateTime(now.year, now.month, 1); }
  Future<void> toggle(DateTime day) async { setState(() => widget.habit.setDone(day, !widget.habit.isDone(day))); await widget.onChanged(); }
  Future<void> addMeasurement() async { final value = await showDialog<double>(context: context, builder: (_) => MeasurementDialog(unit: widget.habit.unit)); if (value == null) return; widget.habit.measurements[Habit.key(DateTime.now())] = value; setState(() {}); await widget.onChanged(); }
  Future<void> editJournal() async {
    final key = Habit.key(DateTime.now());
    final controller = TextEditingController(text: widget.habit.journal[key] ?? '');
    final result = await showDialog<String>(context: context, builder: (_) => AlertDialog(title: const Text("Today's journal"), content: TextField(controller: controller, maxLines: 6), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save'))]));
    controller.dispose();
    if (result == null) return;
    widget.habit.journal[key] = result.trim(); setState(() {}); await widget.onChanged();
  }
  Future<void> editNotes() async {
    final controller = TextEditingController(text: widget.habit.notes);
    final result = await showDialog<String>(context: context, builder: (_) => AlertDialog(title: const Text('Habit notes'), content: TextField(controller: controller, maxLines: 6), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save'))]));
    controller.dispose();
    if (result == null) return;
    widget.habit.notes = result.trim(); setState(() {}); await widget.onChanged();
  }
  @override Widget build(BuildContext context) {
    final h = widget.habit;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rate = h.completionRate(month).clamp(0.0, 1.0).toDouble();
    final measurements = h.measurements.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    final journals = h.journal.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return Scaffold(appBar: AppBar(title: Text(h.name)), body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CardBox(child: Row(children: [SizedBox(width: 72, height: 72, child: CircularProgressIndicator(value: rate, strokeWidth: 8, backgroundColor: AppColors.soft, color: AppColors.blue)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('🔥 ${h.currentStreak()} day streak', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text('Best: ${h.bestStreak()} days'), Text('${(rate * 100).round()}% this month', style: const TextStyle(color: AppColors.muted))]))])),
      SectionTitle(title: 'Goal'), CardBox(child: Text('${h.goal} ${h.unit} · ${h.frequency}', style: const TextStyle(fontWeight: FontWeight.w800))),
      SectionTitle(title: 'Calendar'),
      CardBox(child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1, 1)), icon: const Icon(Icons.chevron_left)), Text(DateFormat('MMMM yyyy').format(month), style: const TextStyle(fontWeight: FontWeight.w900)), IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1, 1)), icon: const Icon(Icons.chevron_right))]), GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: days, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7), itemBuilder: (_, index) { final day = DateTime(month.year, month.month, index + 1); final scheduled = h.isScheduled(day); final done = h.isDone(day); return InkWell(onTap: scheduled ? () => toggle(day) : null, child: Container(margin: const EdgeInsets.all(3), decoration: BoxDecoration(color: done ? AppColors.blue : scheduled ? Colors.white : AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: scheduled ? AppColors.border : Colors.transparent)), child: Center(child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: done ? Colors.white : AppColors.text))))); })])),
      SectionTitle(title: 'Measurements', onAdd: addMeasurement, label: '＋ Add value'), CardBox(child: measurements.isEmpty ? const Text('No measurements yet.', style: TextStyle(color: AppColors.muted)) : Column(children: measurements.take(10).map((e) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.show_chart, color: AppColors.blue), title: Text('${e.value} ${h.unit}'), subtitle: Text(e.key))).toList())),
      SectionTitle(title: 'Journal', onAdd: editJournal, label: '＋ Today'), CardBox(child: journals.isEmpty ? const Text('No journal entries yet.', style: TextStyle(color: AppColors.muted)) : Column(children: journals.take(7).map((e) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.menu_book_outlined, color: AppColors.blue), title: Text(e.key), subtitle: Text(e.value, maxLines: 3, overflow: TextOverflow.ellipsis)).toList())),
      SectionTitle(title: 'Notes', onAdd: editNotes, label: 'Edit'), CardBox(child: Text(h.notes.isEmpty ? 'No notes yet.' : h.notes, style: const TextStyle(color: AppColors.muted, height: 1.5))),
      const SizedBox(height: 20), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => toggle(DateTime.now()), icon: Icon(h.isDone(DateTime.now()) ? Icons.undo : Icons.check), label: Text(h.isDone(DateTime.now()) ? 'Mark today incomplete' : 'Mark today complete'))),
    ])));
  }
}

class HabitEdit {
  String name, category, unit, frequency, notes;
  int goal;
  List<int> weekdays, tagsDummy;
  bool pinned, active, delete;
  List<String> tags;
  HabitEdit({this.name = '', this.category = 'Daily', this.goal = 1, this.unit = 'times', this.frequency = 'Every day', List<int>? weekdays, this.pinned = false, this.active = true, List<String>? tags, this.notes = '', this.delete = false}) : weekdays = weekdays ?? [1, 2, 3, 4, 5, 6, 7], tags = tags ?? [], tagsDummy = [];
  Habit toHabit() => Habit(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name.trim(), category: category, goal: goal, unit: unit, frequency: frequency, weekdays: weekdays, pinned: pinned, active: active, tags: tags, notes: notes);
}

class HabitEditor extends StatefulWidget {
  final Habit? habit;
  const HabitEditor({super.key, this.habit});
  @override State<HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends State<HabitEditor> {
  late TextEditingController name, goal, unit, category, tags, notes;
  late String frequency;
  late List<int> weekdays;
  late bool pinned, active;
  @override void initState() { super.initState(); final h = widget.habit; name = TextEditingController(text: h?.name ?? ''); goal = TextEditingController(text: '${h?.goal ?? 1}'); unit = TextEditingController(text: h?.unit ?? 'times'); category = TextEditingController(text: h?.category ?? 'Daily'); tags = TextEditingController(text: h?.tags.join(', ') ?? ''); notes = TextEditingController(text: h?.notes ?? ''); frequency = h?.frequency ?? 'Every day'; weekdays = List<int>.from(h?.weekdays ?? [1,2,3,4,5,6,7]); pinned = h?.pinned ?? false; active = h?.active ?? true; }
  @override void dispose() { name.dispose(); goal.dispose(); unit.dispose(); category.dispose(); tags.dispose(); notes.dispose(); super.dispose(); }
  void submit() { final value = (int.tryParse(goal.text.trim()) ?? 1).clamp(1, 1000000).toInt(); Navigator.pop(context, HabitEdit(name: name.text, category: category.text.trim().isEmpty ? 'Daily' : category.text.trim(), goal: value, unit: unit.text.trim().isEmpty ? 'times' : unit.text.trim(), frequency: frequency, weekdays: weekdays, pinned: pinned, active: active, tags: tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(), notes: notes.text.trim())); }
  @override Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.habit == null ? 'New habit' : 'Edit habit', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 16),
      TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Habit name')), const SizedBox(height: 10),
      Row(children: [Expanded(child: TextField(controller: goal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Goal'))), const SizedBox(width: 10), Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit')))]), const SizedBox(height: 10),
      TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')), const SizedBox(height: 10),
      DropdownButtonFormField<String>(value: frequency, decoration: const InputDecoration(labelText: 'Frequency'), items: const [DropdownMenuItem(value: 'Every day', child: Text('Every day')), DropdownMenuItem(value: 'Weekdays', child: Text('Weekdays')), DropdownMenuItem(value: 'Custom', child: Text('Custom weekdays'))], onChanged: (v) => setState(() => frequency = v ?? 'Every day')),
      if (frequency == 'Custom') Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 5, children: List.generate(7, (index) { final day = index + 1; final selected = weekdays.contains(day); return FilterChip(label: Text(['Mo','Tu','We','Th','Fr','Sa','Su'][index]), selected: selected, onSelected: (yes) { setState(() { if (yes && !weekdays.contains(day)) weekdays.add(day); if (!yes) weekdays.remove(day); }); }); }))),
      const SizedBox(height: 10), TextField(controller: tags, decoration: const InputDecoration(labelText: 'Tags', hintText: 'health, study, work')), const SizedBox(height: 10), TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: pinned, onChanged: (v) => setState(() => pinned = v), title: const Text('Pin habit')), SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setState(() => active = v), title: const Text('Active')),
      Row(children: [if (widget.habit != null) Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, HabitEdit(delete: true)), child: const Text('Delete'))), if (widget.habit != null) const SizedBox(width: 10), Expanded(child: FilledButton(onPressed: submit, child: const Text('Save habit')))]),
    ]))));
  }
}

class TodoEdit { String title, category; int priority; DateTime? due; TodoEdit({this.title = '', this.priority = 1, this.category = 'General', this.due}); }

class TodoEditor extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const TodoEditor({super.key, this.existing});
  @override State<TodoEditor> createState() => _TodoEditorState();
}
class _TodoEditorState extends State<TodoEditor> {
  late TextEditingController title, category;
  late int priority;
  DateTime? due;
  @override void initState() { super.initState(); final x = widget.existing; title = TextEditingController(text: '${x?['title'] ?? ''}'); category = TextEditingController(text: '${x?['category'] ?? 'General'}'); priority = (x?['priority'] as num?)?.toInt() ?? 1; final raw = '${x?['due'] ?? ''}'; due = raw.isEmpty ? null : DateTime.tryParse(raw); }
  @override void dispose() { title.dispose(); category.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: Text(widget.existing == null ? 'Add task' : 'Edit task'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Task')), const SizedBox(height: 10), TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')), const SizedBox(height: 10), DropdownButtonFormField<int>(value: priority, decoration: const InputDecoration(labelText: 'Priority'), items: const [DropdownMenuItem(value: 1, child: Text('Low')), DropdownMenuItem(value: 2, child: Text('Medium')), DropdownMenuItem(value: 3, child: Text('High'))], onChanged: (v) => setState(() => priority = v ?? 1)), const SizedBox(height: 10), OutlinedButton.icon(onPressed: () async { final value = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: due ?? DateTime.now()); if (value != null) setState(() => due = value); }, icon: const Icon(Icons.event_outlined), label: Text(due == null ? 'Add due date' : DateFormat('d MMM yyyy').format(due!))) ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, TodoEdit(title: title.text, category: category.text, priority: priority, due: due)), child: const Text('Save'))]);
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
  @override void initState() { super.initState(); seconds = widget.initial; }
  @override void dispose() { timer?.cancel(); super.dispose(); }
  void toggle() { if (timer != null) { timer!.cancel(); timer = null; } else { timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => seconds++); }); } setState(() {}); }
  Future<void> save() async { final data = await widget.storage.loadTimerSeconds(); data[Habit.key(widget.date)] = seconds; await widget.storage.saveTimerSeconds(data); widget.onSaved(seconds); }
  @override Widget build(BuildContext context) { final h = seconds ~/ 3600; final m = (seconds % 3600) ~/ 60; final s = seconds % 60; final text = '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}'; return Scaffold(appBar: AppBar(title: const Text('Focus timer')), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(text, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900)), const SizedBox(height: 24), FilledButton.icon(onPressed: toggle, icon: Icon(timer == null ? Icons.play_arrow : Icons.pause), label: Text(timer == null ? 'Start' : 'Pause')), const SizedBox(height: 10), OutlinedButton(onPressed: save, child: const Text('Save session'))]))); }
}

class MeasurementDialog extends StatefulWidget {
  final String unit;
  const MeasurementDialog({super.key, required this.unit});
  @override State<MeasurementDialog> createState() => _MeasurementDialogState();
}
class _MeasurementDialogState extends State<MeasurementDialog> {
  final controller = TextEditingController();
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: Text('Add measurement (${widget.unit})'), content: TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: 'Value')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(controller.text.trim())), child: const Text('Save'))]);
}

class PinDialog extends StatefulWidget {
  final String? current;
  const PinDialog({super.key, this.current});
  @override State<PinDialog> createState() => _PinDialogState();
}
class _PinDialogState extends State<PinDialog> {
  final controller = TextEditingController();
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: Text(widget.current == null ? 'Set app PIN' : 'Change PIN'), content: TextField(controller: controller, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(hintText: '4–6 digits')), actions: [if (widget.current != null) TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Disable')), TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save'))]);
}

class LockDialog extends StatefulWidget {
  final String pin;
  const LockDialog({super.key, required this.pin});
  @override State<LockDialog> createState() => _LockDialogState();
}
class _LockDialogState extends State<LockDialog> {
  final controller = TextEditingController();
  String? error;
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('Enter PIN'), content: TextField(controller: controller, obscureText: true, keyboardType: TextInputType.number, onChanged: (_) => setState(() => error = null), decoration: InputDecoration(errorText: error)), actions: [FilledButton(onPressed: () { if (controller.text.trim() == widget.pin) { Navigator.pop(context, true); } else { setState(() => error = 'Incorrect PIN'); } }, child: const Text('Unlock'))]);
}

class LockScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  const LockScreen({super.key, required this.onUnlock});
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircleAvatar(radius: 42, child: Icon(Icons.lock_outline, size: 40)), const SizedBox(height: 18), const Text('Habit Tracker is locked', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 12), FilledButton.icon(onPressed: onUnlock, icon: const Icon(Icons.lock_open), label: const Text('Unlock'))])));
}
