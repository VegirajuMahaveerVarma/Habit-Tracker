import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/habit.dart';
import 'services/storage_service.dart';

void main() => runApp(const HabitTrackerApp());

class C {
  static const blue = Color(0xFF1769FF);
  static const soft = Color(0xFFEAF1FF);
  static const bg = Color(0xFFF5F7FB);
  static const text = Color(0xFF142033);
  static const muted = Color(0xFF718096);
  static const border = Color(0xFFE6EAF0);
  static const green = Color(0xFF16A36A);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFE05252);
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Habit Tracker',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: C.blue),
          scaffoldBackgroundColor: C.bg,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.border)),
          ),
        ),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final store = StorageService();
  List<Habit> habits = [];
  List<Map<String, dynamic>> todos = [];
  Map<String, int> moods = {};
  Map<String, int> focus = {};
  String? pin;
  bool loading = true;
  bool locked = false;
  bool firstRun = false;
  int tab = 0;
  DateTime date = DateTime.now();

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final h = await store.loadHabits();
    final t = await store.loadTodos();
    final m = await store.loadMoods();
    final f = await store.loadTimerSeconds();
    final savedPin = await store.loadPin();
    if (!mounted) return;
    setState(() {
      habits = h; todos = t; moods = m; focus = f; pin = savedPin;
      locked = savedPin != null; firstRun = !(p.getBool('onboarding_done_v1') ?? false); loading = false;
    });
  }

  Future<void> doneOnboarding() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarding_done_v1', true);
    if (mounted) setState(() => firstRun = false);
  }

  Future<void> saveHabits() => store.saveHabits(habits);

  Future<void> addHabit() async {
    final r = await showModalBottomSheet<EditResult>(context: context, isScrollControlled: true, backgroundColor: Colors.white, builder: (_) => const HabitEditor());
    if (!mounted || r == null || r.name.trim().isEmpty) return;
    setState(() => habits.add(r.create()));
    await saveHabits();
  }

  Future<void> editHabit(Habit h) async {
    final r = await showModalBottomSheet<EditResult>(context: context, isScrollControlled: true, backgroundColor: Colors.white, builder: (_) => HabitEditor(habit: h));
    if (!mounted || r == null) return;
    if (r.delete) {
      final ok = await ask(context, 'Delete habit?', 'Its completion history will also be removed.');
      if (ok) { setState(() => habits.removeWhere((x) => x.id == h.id)); await saveHabits(); }
      return;
    }
    h.name = r.name; h.category = r.category; h.goal = r.goal; h.unit = r.unit;
    h.frequency = r.frequency; h.weekdays = r.weekdays; h.pinned = r.pinned;
    h.active = r.active; h.icon = r.icon; h.tags = r.tags; h.notes = r.notes;
    setState(() {}); await saveHabits();
  }

  Future<void> toggleHabit(Habit h, DateTime d) async {
    setState(() => h.setDone(d, !h.isDone(d)));
    await saveHabits();
  }

  Future<void> openHabit(Habit h) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => HabitDetail(habit: h, onChanged: saveHabits)));
    if (mounted) setState(() {});
  }

  Future<void> addTodo() async {
    final r = await showDialog<TodoResult>(context: context, builder: (_) => const TodoEditor());
    if (!mounted || r == null || r.title.trim().isEmpty) return;
    setState(() => todos.add({'id': '${DateTime.now().microsecondsSinceEpoch}', 'title': r.title.trim(), 'done': false, 'priority': r.priority, 'category': r.category, 'due': r.due == null ? '' : Habit.key(r.due!)}));
    await store.saveTodos(todos);
  }

  Future<void> editTodo(int i) async {
    final r = await showDialog<TodoResult>(context: context, builder: (_) => TodoEditor(initial: todos[i]));
    if (!mounted || r == null) return;
    if (r.delete) { setState(() => todos.removeAt(i)); }
    else { setState(() { todos[i]['title'] = r.title.trim(); todos[i]['priority'] = r.priority; todos[i]['category'] = r.category; todos[i]['due'] = r.due == null ? '' : Habit.key(r.due!); }); }
    await store.saveTodos(todos);
  }

  Future<void> toggleTodo(int i) async { setState(() => todos[i]['done'] = todos[i]['done'] != true); await store.saveTodos(todos); }

  Future<void> mood(int value) async { setState(() => moods[Habit.key(date)] = value); await store.saveMoods(moods); }

  Future<void> timer() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => FocusTimer(storage: store, date: date, initial: focus[Habit.key(date)] ?? 0, onSaved: (v) => setState(() => focus[Habit.key(date)] = v))));
  }

  Future<void> setPin() async {
    final value = await showDialog<String>(context: context, builder: (_) => const PinDialog());
    if (value == null) return;
    final newPin = value.isEmpty ? null : value;
    await store.savePin(newPin);
    if (mounted) setState(() { pin = newPin; locked = false; });
  }

  Future<void> templates() async {
    final selected = await showModalBottomSheet<List<String>>(context: context, backgroundColor: Colors.white, builder: (_) => const Templates());
    if (!mounted || selected == null) return;
    final existing = habits.map((h) => h.name.toLowerCase()).toSet();
    final add = selected.where((x) => !existing.contains(x.toLowerCase())).map((x) => Habit(id: '${DateTime.now().microsecondsSinceEpoch}_$x', name: x, category: 'Routine')).toList();
    setState(() => habits.addAll(add)); await saveHabits();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (firstRun) return Onboarding(onDone: doneOnboarding, onCreate: addHabit);
    if (locked && pin != null) return LockScreen(pin: pin!, onUnlock: () => setState(() => locked = false));

    final pages = [
      Dashboard(habits: habits, todos: todos, moods: moods, date: date, onAdd: addHabit, onToggle: toggleHabit, onEdit: editHabit, onOpen: openHabit, onMood: mood, onTimer: timer),
      Daily(habits: habits, date: date, onDate: (d) => setState(() => date = d), onAdd: addHabit, onToggle: toggleHabit, onEdit: editHabit, onOpen: openHabit),
      Stats(habits: habits, moods: moods, todos: todos, focus: focus, onOpen: openHabit),
      TodoPage(todos: todos, onAdd: addTodo, onEdit: editTodo, onToggle: toggleTodo),
      Profile(habits: habits, onPin: setPin, onTimer: timer, onTemplates: templates),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: tab, children: pages)),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, indicatorColor: C.soft, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Habits'),
        NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Stats'),
        NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'To-Do'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      ]),
    );
  }
}

class Header extends StatelessWidget {
  final String title; final String? subtitle; final Widget? trailing;
  const Header({super.key, required this.title, this.subtitle, this.trailing});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 14), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: C.text)), if (subtitle != null) Text(subtitle!, style: const TextStyle(color: C.muted))])), if (trailing != null) trailing!]));
}

class CardBox extends StatelessWidget {
  final Widget child;
  const CardBox({super.key, required this.child});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.border), boxShadow: const [BoxShadow(blurRadius: 18, offset: Offset(0, 7), color: Color(0x08000000))]), child: child);
}

class Section extends StatelessWidget {
  final String title; final VoidCallback? action; final String actionText;
  const Section({super.key, required this.title, this.action, this.actionText = '＋ Add'});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 10), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))), if (action != null) TextButton(onPressed: action, child: Text(actionText))]));
}

class Dashboard extends StatefulWidget {
  final List<Habit> habits; final List<Map<String,dynamic>> todos; final Map<String,int> moods; final DateTime date;
  final VoidCallback onAdd, onTimer; final Future<void> Function(Habit,DateTime) onToggle; final Future<void> Function(Habit) onEdit, onOpen; final Future<void> Function(int) onMood;
  const Dashboard({super.key, required this.habits, required this.todos, required this.moods, required this.date, required this.onAdd, required this.onTimer, required this.onToggle, required this.onEdit, required this.onOpen, required this.onMood});
  @override State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String query = ''; String filter = 'All'; String sort = 'Pinned';
  @override Widget build(BuildContext context) {
    final active = widget.habits.where((h) => h.active).toList();
    final visible = active.where((h) {
      final q = query.trim().toLowerCase();
      final text = h.name.toLowerCase().contains(q) || h.category.toLowerCase().contains(q) || h.tags.any((t) => t.toLowerCase().contains(q));
      final f = filter == 'All' || (filter == 'Pinned' && h.pinned) || (filter == 'Completed' && h.isDone(widget.date)) || (filter == 'Missed' && h.isScheduled(widget.date) && !h.isDone(widget.date));
      return (q.isEmpty || text) && f;
    }).toList();
    visible.sort((a,b) { if (sort == 'Name') return a.name.compareTo(b.name); if (sort == 'Streak') return b.currentStreak(widget.date).compareTo(a.currentStreak(widget.date)); if (sort == 'Progress') return b.completionRate(widget.date).compareTo(a.completionRate(widget.date)); return a.pinned == b.pinned ? 0 : (a.pinned ? -1 : 1); });
    final done = active.where((h) => h.isDone(widget.date)).length;
    final progress = active.isEmpty ? 0.0 : done / active.length;
    var best = 0; for (final h in active) { best = h.currentStreak(widget.date) > best ? h.currentStreak(widget.date) : best; }
    final moodValue = widget.moods[Habit.key(widget.date)];
    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 25), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Header(title: 'Good day 👋', subtitle: DateFormat('EEEE, d MMMM').format(widget.date), trailing: IconButton(onPressed: widget.onTimer, icon: const Icon(Icons.timer_outlined))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search habits, categories or tags'))),
      const SizedBox(height: 10),
      SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: ['All','Pinned','Completed','Missed'].map((x) => Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(x), selected: filter == x, onSelected: (_) => setState(() => filter = x)))).toList())),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [const Text('Sort:', style: TextStyle(color: C.muted)), const SizedBox(width: 8), DropdownButton<String>(value: sort, items: ['Pinned','Name','Streak','Progress'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) { if (v != null) setState(() => sort = v); })])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: CardBox(child: Row(children: [SizedBox(width: 82,height:82,child: Stack(fit: StackFit.expand,children: [CircularProgressIndicator(value: progress,strokeWidth:9,backgroundColor:C.soft,color:C.blue),Center(child: Text('${(progress*100).round()}%',style: const TextStyle(fontWeight: FontWeight.w900)))])),const SizedBox(width:18),Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [Text(done == active.length && active.isNotEmpty ? 'All done!' : 'Today’s progress',style: const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text('$done of ${active.length} habits completed',style: const TextStyle(color:C.muted)),const SizedBox(height:9),LinearProgressIndicator(value:progress,minHeight:7,backgroundColor:C.soft)]))]))),
      Section(title: 'Quick stats'),
      Padding(padding: const EdgeInsets.symmetric(horizontal:20),child: Row(children: [Expanded(child: CardBox(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.local_fire_department_outlined,color:C.blue),const SizedBox(height:6),const Text('Best streak',style:TextStyle(color:C.muted)),Text('$best days',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))]))),const SizedBox(width:10),Expanded(child: CardBox(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.list_alt_outlined,color:C.blue),const SizedBox(height:6),const Text('Open tasks',style:TextStyle(color:C.muted)),Text('${widget.todos.where((x)=>x['done']!=true).length}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))])))])),
      Section(title:'How are you feeling?',action:widget.onTimer,actionText:'Focus timer'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:List.generate(5,(i){final v=i+1;return InkWell(onTap:()=>widget.onMood(v),child:Opacity(opacity:moodValue==v?1:.5,child:Text(['😫','😕','😐','🙂','😄'][i],style:const TextStyle(fontSize:27))));})))),
      Section(title: query.isEmpty ? 'Today’s habits' : 'Search results', action: widget.onAdd),
      if (visible.isEmpty) const Padding(padding:EdgeInsets.all(30),child:Center(child:Text('No matching habits.',style:TextStyle(color:C.muted)))) else ...visible.map((h)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),child: HabitTile(habit:h,date:widget.date,onToggle:()=>widget.onToggle(h,widget.date),onEdit:()=>widget.onEdit(h),onOpen:()=>widget.onOpen(h)))),
    ]));
  }
}

class HabitTile extends StatelessWidget {
  final Habit habit; final DateTime date; final VoidCallback onToggle,onEdit,onOpen;
  const HabitTile({super.key,required this.habit,required this.date,required this.onToggle,required this.onEdit,required this.onOpen});
  @override Widget build(BuildContext context) { final done=habit.isDone(date); final rate=habit.completionRate(date).clamp(0.0,1.0).toDouble(); return GestureDetector(onTap:onOpen,onLongPress:onEdit,child:CardBox(child:Row(children:[GestureDetector(onTap:onToggle,child:Container(width:42,height:42,decoration:BoxDecoration(shape:BoxShape.circle,color:done?C.blue:C.soft),child:Icon(done?Icons.check:Icons.check_circle_outline,color:done?Colors.white:C.blue))),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(habit.name,style:TextStyle(fontWeight:FontWeight.w900,decoration:done?TextDecoration.lineThrough:null))),if(habit.pinned)const Icon(Icons.push_pin,size:16,color:C.orange)]),Text('${habit.category} · ${habit.goal} ${habit.unit} · 🔥 ${habit.currentStreak(date)}',style:const TextStyle(color:C.muted,fontSize:12)),const SizedBox(height:6),LinearProgressIndicator(value:rate,minHeight:5,backgroundColor:C.soft)]))]))); }
}

class Daily extends StatelessWidget {
  final List<Habit> habits; final DateTime date; final ValueChanged<DateTime> onDate; final VoidCallback onAdd; final Future<void> Function(Habit,DateTime) onToggle; final Future<void> Function(Habit) onEdit,onOpen;
  const Daily({super.key,required this.habits,required this.date,required this.onDate,required this.onAdd,required this.onToggle,required this.onEdit,required this.onOpen});
  @override Widget build(BuildContext context) { final days=DateTime(date.year,date.month+1,0).day; final active=habits.where((h)=>h.active&&h.isScheduled(date)).toList(); final done=active.where((h)=>h.isDone(date)).length; return Column(children:[Header(title:'Daily',subtitle:DateFormat('MMMM yyyy').format(date)),SizedBox(height:82,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:20),itemCount:days,separatorBuilder:(_,__)=>const SizedBox(width:7),itemBuilder:(_,i){final d=DateTime(date.year,date.month,i+1);final selected=Habit.key(d)==Habit.key(date);return InkWell(onTap:()=>onDate(d),child:Container(width:48,padding:const EdgeInsets.symmetric(vertical:8),decoration:BoxDecoration(color:selected?C.blue:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:selected?C.blue:C.border)),child:Column(children:[Text(DateFormat('E').format(d).substring(0,1),style:TextStyle(color:selected?Colors.white:C.muted)),Text('${d.day}',style:TextStyle(fontWeight:FontWeight.w900,color:selected?Colors.white:C.text))])));}),),Section(title:'${DateFormat('EEE, d MMMM').format(date)} · $done/${active.length} complete',action:onAdd),Expanded(child:active.isEmpty?const Center(child:Text('No habits scheduled today.',style:TextStyle(color:C.muted))):ListView(children:active.map((h)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),child:HabitTile(habit:h,date:date,onToggle:()=>onToggle(h,date),onEdit:()=>onEdit(h),onOpen:()=>onOpen(h)))).toList()))]); }
}

class Stats extends StatelessWidget {
  final List<Habit> habits; final Map<String,int> moods; final List<Map<String,dynamic>> todos; final Map<String,int> focus; final Future<void> Function(Habit) onOpen;
  const Stats({super.key,required this.habits,required this.moods,required this.todos,required this.focus,required this.onOpen});
  @override Widget build(BuildContext context) { final now=DateTime.now(); final active=habits.where((h)=>h.active).toList(); var total=0,best=0,monthDone=0,possible=0,focusSec=0; for(final h in habits){total+=h.totalCompletions();if(h.bestStreak()>best)best=h.bestStreak();} for(final h in active){monthDone+=h.completedInMonth(now);possible+=h.scheduledInMonth(now);} for(final v in focus.values){focusSec+=v;} var avg=0.0;if(moods.isNotEmpty){for(final v in moods.values){avg+=v;}avg/=moods.length;} var overall=possible==0?0.0:monthDone/possible; final last7=List.generate(7,(i)=>DateTime(now.year,now.month,now.day-6+i)); return SingleChildScrollView(padding:const EdgeInsets.only(bottom:25),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Header(title:'Analytics',subtitle:'Consistency, patterns and progress'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(children:[SizedBox(width:80,height:80,child:CircularProgressIndicator(value:overall,strokeWidth:9,backgroundColor:C.soft,color:C.blue)),const SizedBox(width:18),Expanded(child:Text('${(overall*100).round()}% monthly completion\n$total total completions\n$best best streak\n${todos.where((x)=>x['done']!=true).length} open tasks\nAverage mood: ${avg==0?'—':'${avg.toStringAsFixed(1)}/5'}',style:const TextStyle(color:C.muted,height:1.5)))]))),Section(title:'Last 7 days'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:last7.map((d){final n=active.where((h)=>h.isDone(d)).length;final height=active.isEmpty?8.0:(80*n/active.length).clamp(8.0,80.0).toDouble();return Expanded(child:Column(children:[Text('$n',style:const TextStyle(fontSize:11)),const SizedBox(height:4),Container(height:height,margin:const EdgeInsets.symmetric(horizontal:4),decoration:BoxDecoration(color:C.blue,borderRadius:BorderRadius.circular(7))),const SizedBox(height:4),Text(DateFormat('E').format(d).substring(0,1),style:const TextStyle(color:C.muted))]));}).toList()))),Section(title:'Habit performance'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Column(children:active.map((h){final r=h.completionRate(now).clamp(0.0,1.0).toDouble();return InkWell(onTap:()=>onOpen(h),child:Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[Expanded(child:Text(h.name,style:const TextStyle(fontWeight:FontWeight.w800))),Text('${(r*100).round()}%'),const SizedBox(width:8),SizedBox(width:70,child:LinearProgressIndicator(value:r))])));}).toList()))),Section(title:'Activity heatmap'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Wrap(spacing:4,runSpacing:4,children:List.generate(DateTime(now.year,now.month+1,0).day,(i){final d=DateTime(now.year,now.month,i+1);final n=active.where((h)=>h.isDone(d)).length;final ratio=active.isEmpty?0.0:n/active.length;return Tooltip(message:'${DateFormat('d MMM').format(d)} · $n done',child:Container(width:18,height:18,decoration:BoxDecoration(color:n==0?C.bg:(Color.lerp(C.soft,C.blue,ratio)??C.blue),borderRadius:BorderRadius.circular(4))));})))),Section(title:'Weekly review'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Completed this month: $monthDone / $possible'),Text('Focus time: ${formatTime(focusSec)}'),Text('Average mood: ${avg==0?'no entries':'${avg.toStringAsFixed(1)}/5'}'),const SizedBox(height:8),Text(active.isEmpty?'Create a habit to start your review.':'Keep your strongest routines consistent and review missed days weekly.',style:const TextStyle(color:C.muted))])))])); }
}

class TodoPage extends StatelessWidget {
  final List<Map<String,dynamic>> todos; final VoidCallback onAdd; final Future<void> Function(int) onEdit,onToggle;
  const TodoPage({super.key,required this.todos,required this.onAdd,required this.onEdit,required this.onToggle});
  @override Widget build(BuildContext context){final done=todos.where((x)=>x['done']==true).length;return Column(children:[Header(title:'To-Do',subtitle:'$done completed · ${todos.length-done} remaining',trailing:IconButton(onPressed:onAdd,icon:const Icon(Icons.add))),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Column(children:[LinearProgressIndicator(value:todos.isEmpty?0:done/todos.length,minHeight:8,backgroundColor:C.soft),const SizedBox(height:10),Text(todos.isEmpty?'No tasks yet':'$done of ${todos.length} tasks complete')]))),Expanded(child:todos.isEmpty?const Center(child:Text('Tap + to create a task.',style:TextStyle(color:C.muted))):ListView(padding:const EdgeInsets.all(20),children:todos.asMap().entries.map((e)=>TodoTile(data:e.value,onEdit:()=>onEdit(e.key),onToggle:()=>onToggle(e.key))).toList()))]);}
}

class TodoTile extends StatelessWidget { final Map<String,dynamic> data; final VoidCallback onEdit,onToggle; const TodoTile({super.key,required this.data,required this.onEdit,required this.onToggle}); @override Widget build(BuildContext context){final dueRaw='${data['due']??''}';final due=dueRaw.isEmpty?null:DateTime.tryParse(dueRaw);final overdue=due!=null&&due.isBefore(DateTime.now())&&data['done']!=true;return Card(child:ListTile(onTap:onEdit,leading:Checkbox(value:data['done']==true,onChanged:(_)=>onToggle()),title:Text('${data['title']}',style:TextStyle(fontWeight:FontWeight.w800,decoration:data['done']==true?TextDecoration.lineThrough:null)),subtitle:Text('${data['category']??'General'} · ${priorityName((data['priority'] as num?)?.toInt()??1)}${due==null?'':' · ${overdue?'Overdue · ':''}${DateFormat('d MMM').format(due)}'}',style:TextStyle(color:overdue?C.red:null)),trailing:const Icon(Icons.chevron_right)));}}

class Profile extends StatelessWidget { final List<Habit> habits; final VoidCallback onPin,onTimer,onTemplates; const Profile({super.key,required this.habits,required this.onPin,required this.onTimer,required this.onTemplates}); @override Widget build(BuildContext context){var total=0,best=0;for(final h in habits){total+=h.totalCompletions();if(h.bestStreak()>best)best=h.bestStreak();}return SingleChildScrollView(padding:const EdgeInsets.only(bottom:25),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Header(title:'Profile',subtitle:'Your private offline habit space'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(children:[const CircleAvatar(radius:34,backgroundColor:Color(0xFF102A43),child:Icon(Icons.person,color:Colors.white)),const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${habits.length} habits',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text('$total completions · $best best streak',style:const TextStyle(color:C.muted))]))]))),Section(title:'Achievements'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(children:[const Icon(Icons.emoji_events_outlined,color:C.orange,size:34),const SizedBox(width:12),Expanded(child:Text('${achievementCount(habits)} badges unlocked',style:const TextStyle(fontWeight:FontWeight.w900))),TextButton(onPressed:()=>showAchievements(context,habits),child:const Text('View'))]))),Section(title:'Tools'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Column(children:[ListTile(onTap:onTemplates,leading:const Icon(Icons.auto_awesome_outlined,color:C.blue),title:const Text('Habit templates'),subtitle:const Text('Build a routine quickly')),ListTile(onTap:onTimer,leading:const Icon(Icons.timer_outlined,color:C.blue),title:const Text('Focus timer'),subtitle:const Text('Track focused time')),ListTile(onTap:onPin,leading:const Icon(Icons.lock_outline,color:C.blue),title:const Text('App lock'),subtitle:const Text('Set or remove local PIN')),const ListTile(leading:Icon(Icons.wifi_off_outlined,color:C.blue),title:Text('Offline first'),subtitle:Text('Data stays on this device'))])),Section(title:'About'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:const Text('Simple, private habit tracking with local storage. No account or cloud service is required.',style:TextStyle(color:C.muted,height:1.5))))]));}}

class HabitDetail extends StatefulWidget { final Habit habit; final Future<void> Function() onChanged; const HabitDetail({super.key,required this.habit,required this.onChanged}); @override State<HabitDetail> createState()=>_HabitDetailState(); }
class _HabitDetailState extends State<HabitDetail>{late DateTime month;@override void initState(){super.initState();month=DateTime.now();}Future<void> toggle(DateTime d)async{setState(()=>widget.habit.setDone(d,!widget.habit.isDone(d)));await widget.onChanged();}Future<void> measure()async{final v=await showDialog<double>(context:context,builder:(_)=>MeasurementDialog(unit:widget.habit.unit));if(v==null)return;setState(()=>widget.habit.measurements[Habit.key(DateTime.now())]=v);await widget.onChanged();}@override Widget build(BuildContext context){final h=widget.habit;final days=DateTime(month.year,month.month+1,0).day;final rate=h.completionRate(month).clamp(0.0,1.0).toDouble();final entries=h.measurements.entries.toList()..sort((a,b)=>b.key.compareTo(a.key));return Scaffold(appBar:AppBar(title:Text(h.name),actions:[IconButton(onPressed:()=>showModalBottomSheet(context:context,backgroundColor:Colors.white,builder:(_)=>InfoSheet(habit:h)),icon:const Icon(Icons.info_outline))]),body:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CardBox(child:Row(children:[SizedBox(width:82,height:82,child:CircularProgressIndicator(value:rate,strokeWidth:8,backgroundColor:C.soft,color:C.blue)),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('🔥 ${h.currentStreak()} day streak',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text('Best: ${h.bestStreak()} days',style:const TextStyle(color:C.muted)),Text('${h.totalCompletions()} total completions',style:const TextStyle(color:C.muted))]))])),Section(title:'Calendar'),CardBox(child:Column(children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[IconButton(onPressed:()=>setState(()=>month=DateTime(month.year,month.month-1,1)),icon:const Icon(Icons.chevron_left)),Text(DateFormat('MMMM yyyy').format(month),style:const TextStyle(fontWeight:FontWeight.w900)),IconButton(onPressed:()=>setState(()=>month=DateTime(month.year,month.month+1,1)),icon:const Icon(Icons.chevron_right))]),GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:days,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7),itemBuilder:(_,i){final d=DateTime(month.year,month.month,i+1);final scheduled=h.isScheduled(d);final done=h.isDone(d);return InkWell(onTap:scheduled?()=>toggle(d):null,child:Container(margin:const EdgeInsets.all(3),decoration:BoxDecoration(color:done?C.blue:(scheduled?Colors.white:C.bg),borderRadius:BorderRadius.circular(9),border:Border.all(color:scheduled?C.border:Colors.transparent)),child:Center(child:Text('${i+1}',style:TextStyle(fontWeight:FontWeight.w800,color:done?Colors.white:(scheduled?C.text:C.muted))))));}})])),Section(title:'Measurements',action:measure,actionText:'Add value'),CardBox(child:entries.isEmpty?const Text('No measurements yet.',style:TextStyle(color:C.muted)):Column(children:entries.take(12).map((e)=>ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.show_chart,color:C.blue),title:Text('${e.value} ${h.unit}'),subtitle:Text(e.key)).toList())),Section(title:'Journal / notes'),CardBox(child:Text(h.notes.isEmpty?'No notes yet.':h.notes,style:const TextStyle(height:1.5))),const SizedBox(height:20),FilledButton.icon(onPressed:()=>toggle(DateTime.now()),icon:Icon(h.isDone(DateTime.now())?Icons.undo:Icons.check),label:Text(h.isDone(DateTime.now())?'Mark today incomplete':'Mark today complete'),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52))) ])));}}

class InfoSheet extends StatelessWidget { final Habit habit; const InfoSheet({super.key,required this.habit}); @override Widget build(BuildContext context)=>SafeArea(child:Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(habit.name,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),Text('Goal: ${habit.goal} ${habit.unit}'),Text('Frequency: ${habit.frequency}'),Text('Category: ${habit.category}'),if(habit.tags.isNotEmpty)Text('Tags: ${habit.tags.join(', ')}'),if(habit.notes.isNotEmpty)Text('Notes: ${habit.notes}'),const SizedBox(height:15)])));}

class EditResult { final String name,category,unit,frequency,icon,notes; final int goal; final List<int> weekdays; final bool pinned,active,delete; final List<String> tags; const EditResult({required this.name,required this.category,required this.goal,required this.unit,required this.frequency,required this.weekdays,required this.pinned,required this.active,required this.icon,required this.tags,required this.notes,this.delete=false}); Habit create()=>Habit(id:'${DateTime.now().microsecondsSinceEpoch}',name:name,category:category,goal:goal,unit:unit,frequency:frequency,weekdays:weekdays,pinned:pinned,active:active,icon:icon,tags:tags,notes:notes); }

class HabitEditor extends StatefulWidget { final Habit? habit; const HabitEditor({super.key,this.habit}); @override State<HabitEditor> createState()=>_HabitEditorState(); }
class _HabitEditorState extends State<HabitEditor>{late TextEditingController name,goal,tags,notes;late String category,unit,frequency,icon;late List<int> weekdays;late bool pinned,active;final cats=['Personal','Health','Mind & Body','Productivity','Learning','Goals','Finance','Routine','Other'];final units=['times','minutes','hours','pages','litres','km','steps','reps','kg'];@override void initState(){super.initState();final h=widget.habit;name=TextEditingController(text:h?.name??'');goal=TextEditingController(text:'${h?.goal??1}');tags=TextEditingController(text:h?.tags.join(', ')??'');notes=TextEditingController(text:h?.notes??'');category=cats.contains(h?.category)?h!.category:'Personal';unit=units.contains(h?.unit)?h!.unit:'times';frequency=h?.frequency??'Every day';weekdays=List<int>.from(h?.weekdays??[1,2,3,4,5,6,7]);pinned=h?.pinned??false;active=h?.active??true;icon=h?.icon??'check_circle';}@override void dispose(){name.dispose();goal.dispose();tags.dispose();notes.dispose();super.dispose();}void save(){final n=name.text.trim();if(n.isEmpty)return;Navigator.pop(context,EditResult(name:n,category:category,goal:(int.tryParse(goal.text)??1).clamp(1,1000000),unit:unit,frequency:frequency,weekdays:weekdays.isEmpty?[1,2,3,4,5,6,7]:weekdays,pinned:pinned,active:active,icon:icon,tags:tags.text.split(',').map((x)=>x.trim()).where((x)=>x.isNotEmpty).toList(),notes:notes.text.trim()));}@override Widget build(BuildContext context)=>SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(20,10,20,MediaQuery.of(context).viewInsets.bottom+20),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.habit==null?'Create habit':'Edit habit',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:14),TextField(controller:name,decoration:const InputDecoration(labelText:'Habit name')),const SizedBox(height:10),Row(children:[Expanded(child:DropdownButtonFormField<String>(value:category,items:cats.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setState(()=>category=v);})),const SizedBox(width:10),Expanded(child:DropdownButtonFormField<String>(value:unit,items:units.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setState(()=>unit=v);}))]),const SizedBox(height:10),TextField(controller:goal,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Target')),const SizedBox(height:10),const Text('Frequency',style:TextStyle(fontWeight:FontWeight.w800)),Wrap(spacing:6,children:['Every day','Weekdays','Custom'].map((x)=>ChoiceChip(label:Text(x),selected:frequency==x,onSelected:(_)=>setState(()=>frequency=x))).toList()),if(frequency=='Custom')Wrap(spacing:4,children:List.generate(7,(i){final d=i+1;return FilterChip(label:Text(['M','T','W','T','F','S','S'][i]),selected:weekdays.contains(d),onSelected:(v)=>setState(()=>v?weekdays.add(d):weekdays.remove(d)));})),TextField(controller:tags,decoration:const InputDecoration(labelText:'Tags, comma separated')),const SizedBox(height:8),TextField(controller:notes,maxLines:3,decoration:const InputDecoration(labelText:'Journal / notes')),SwitchListTile(contentPadding:EdgeInsets.zero,value:pinned,onChanged:(v)=>setState(()=>pinned=v),title:const Text('Pin to top')),SwitchListTile(contentPadding:EdgeInsets.zero,value:active,onChanged:(v)=>setState(()=>active=v),title:const Text('Active')),const SizedBox(height:8),if(widget.habit!=null)TextButton.icon(onPressed:()=>Navigator.pop(context,const EditResult(name:'',category:'',goal:1,unit:'times',frequency:'Every day',weekdays:[1,2,3,4,5,6,7],pinned:false,active:false,icon:'check_circle',tags:[],notes:'',delete:true)),icon:const Icon(Icons.delete_outline),label:const Text('Delete habit')),FilledButton(onPressed:save,style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)),child:Text(widget.habit==null?'Create habit':'Save changes'))]))));}
}

class TodoResult { final String title,category; final int priority; final DateTime? due; final bool delete; const TodoResult({required this.title,required this.category,required this.priority,this.due,this.delete=false}); }
class TodoEditor extends StatefulWidget { final Map<String,dynamic>? initial; const TodoEditor({super.key,this.initial}); @override State<TodoEditor> createState()=>_TodoEditorState(); }
class _TodoEditorState extends State<TodoEditor>{late TextEditingController title;late String category;late int priority;DateTime? due;@override void initState(){super.initState();final x=widget.initial;title=TextEditingController(text:'${x?['title']??''}');category='${x?['category']??'General'}';priority=(x?['priority']as num?)?.toInt()??1;final raw='${x?['due']??''}';due=raw.isEmpty?null:DateTime.tryParse(raw);}@override void dispose(){title.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.initial==null?'New task':'Edit task'),content:SingleChildScrollView(child:Column(children:[TextField(controller:title,autofocus:true,decoration:const InputDecoration(labelText:'Task')),const SizedBox(height:8),DropdownButtonFormField<String>(value:['General','College','Work','Personal'].contains(category)?category:'General',items:['General','College','Work','Personal'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setState(()=>category=v);}),const SizedBox(height:8),DropdownButtonFormField<int>(value:priority.clamp(1,3).toInt(),items:const[DropdownMenuItem(value:1,child:Text('Low')),DropdownMenuItem(value:2,child:Text('Medium')),DropdownMenuItem(value:3,child:Text('High'))],onChanged:(v)=>setState(()=>priority=v??1)),ListTile(contentPadding:EdgeInsets.zero,title:Text(due==null?'No due date':'Due ${DateFormat('d MMM yyyy').format(due!)}'),leading:const Icon(Icons.event_outlined),onTap:()async{final d=await showDatePicker(context:context,initialDate:due??DateTime.now(),firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null&&mounted)setState(()=>due=d);})])),actions:[if(widget.initial!=null)TextButton(onPressed:()=>Navigator.pop(context,const TodoResult(title:'',category:'',priority:1,delete:true)),child:const Text('Delete')),TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,TodoResult(title:title.text,category:category,priority:priority,due:due)),child:const Text('Save'))]);}
}

class FocusTimer extends StatefulWidget { final StorageService storage; final DateTime date; final int initial; final ValueChanged<int> onSaved; const FocusTimer({super.key,required this.storage,required this.date,required this.initial,required this.onSaved}); @override State<FocusTimer> createState()=>_FocusTimerState(); }
class _FocusTimerState extends State<FocusTimer>{late int seconds;Timer? ticker;bool running=false;@override void initState(){super.initState();seconds=widget.initial;}@override void dispose(){ticker?.cancel();super.dispose();}void toggle(){if(running){ticker?.cancel();setState(()=>running=false);}else{ticker=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>seconds++);});setState(()=>running=true);}}Future<void> save()async{final data=await widget.storage.loadTimerSeconds();data[Habit.key(widget.date)]=seconds;await widget.storage.saveTimerSeconds(data);widget.onSaved(seconds);if(mounted)Navigator.pop(context);}String fmt(){final h=seconds~/3600;final m=(seconds%3600)~/60;final s=seconds%60;return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Focus Timer')),body:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.timer_outlined,size:60,color:C.blue),const SizedBox(height:20),Text(fmt(),style:const TextStyle(fontSize:48,fontWeight:FontWeight.w900)),const SizedBox(height:20),FilledButton.icon(onPressed:toggle,icon:Icon(running?Icons.pause:Icons.play_arrow),label:Text(running?'Pause':'Start')),const SizedBox(height:10),OutlinedButton(onPressed:save,child:const Text('Save today’s focus time'))])));
}

class PinDialog extends StatefulWidget { const PinDialog({super.key}); @override State<PinDialog> createState()=>_PinDialogState(); }
class _PinDialogState extends State<PinDialog>{final c=TextEditingController();@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:const Text('App lock'),content:TextField(controller:c,obscureText:true,keyboardType:TextInputType.number,maxLength:6,decoration:const InputDecoration(labelText:'4–6 digit PIN')),actions:[TextButton(onPressed:()=>Navigator.pop(context,''),child:const Text('Remove')),FilledButton(onPressed:()=>c.text.length>=4?Navigator.pop(context,c.text):null,child:const Text('Save'))]);}
class LockScreen extends StatefulWidget { final String pin; final VoidCallback onUnlock; const LockScreen({super.key,required this.pin,required this.onUnlock}); @override State<LockScreen> createState()=>_LockState(); }
class _LockState extends State<LockScreen>{final c=TextEditingController();String error='';@override void dispose(){c.dispose();super.dispose();}void unlock(){if(c.text==widget.pin)widget.onUnlock();else setState(()=>error='Incorrect PIN');}@override Widget build(BuildContext context)=>Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(30),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.lock_outline,size:64,color:C.blue),const SizedBox(height:15),const Text('Habit Tracker locked',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:15),TextField(controller:c,obscureText:true,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'PIN',errorText:error.isEmpty?null:error)),const SizedBox(height:15),FilledButton(onPressed:unlock,child:const Text('Unlock'))]))));}

class Onboarding extends StatefulWidget { final Future<void> Function() onDone,onCreate; const Onboarding({super.key,required this.onDone,required this.onCreate}); @override State<Onboarding> createState()=>_OnboardingState(); }
class _OnboardingState extends State<Onboarding>{int page=0;final items=const[('Build better days','Track habits, routines and goals in one place.',Icons.auto_awesome),('See your progress','Streaks, calendars, analytics and measurements.',Icons.insights),('Private by default','Your data stays on this device.',Icons.lock_outline)];@override Widget build(BuildContext context){final x=items[page];return Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.all(28),child:Column(children:[const Spacer(),CircleAvatar(radius:58,backgroundColor:C.soft,child:Icon(Icons.check_circle,size:70,color:C.blue)),const SizedBox(height:35),Text(x.$1,textAlign:TextAlign.center,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w900)),const SizedBox(height:14),Text(x.$2,textAlign:TextAlign.center,style:const TextStyle(fontSize:16,color:C.muted)),const SizedBox(height:25),Icon(x.$3,size:42,color:C.blue),const Spacer(),Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(items.length,(i)=>Container(width:i==page?26:8,height:8,margin:const EdgeInsets.all(4),decoration:BoxDecoration(color:i==page?C.blue:C.border,borderRadius:BorderRadius.circular(8))))),const SizedBox(height:20),SizedBox(width:double.infinity,child:FilledButton(onPressed:()async{if(page<items.length-1){setState(()=>page++);}else{await widget.onCreate();await widget.onDone();}},child:Text(page<items.length-1?'Next':'Get started'))),TextButton(onPressed:widget.onDone,child:const Text('Skip'))]))));}}

class Templates extends StatelessWidget { const Templates({super.key}); static const data={'Morning routine':['Wake up early','Drink Water','Exercise','Meditate','Plan Tomorrow'],'Study routine':['Reading / Learning','Day Planning','Project Work','Goal Journaling'],'Healthy day':['Drink Water','Gym','10k Steps','Cold Shower','Sleep on Time']}; @override Widget build(BuildContext context)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Habit templates',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:10),...data.entries.map((e)=>ListTile(onTap:()=>Navigator.pop(context,e.value),leading:const Icon(Icons.auto_awesome,color:C.blue),title:Text(e.key),subtitle:Text('${e.value.length} habits'),trailing:const Icon(Icons.chevron_right)))]))); }

class MeasurementDialog extends StatefulWidget { final String unit; const MeasurementDialog({super.key,required this.unit}); @override State<MeasurementDialog> createState()=>_MeasurementState(); }
class _MeasurementState extends State<MeasurementDialog>{final c=TextEditingController();@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:Text('Add ${widget.unit}'),content:TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'Value (${widget.unit})')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:(){final v=double.tryParse(c.text);if(v!=null)Navigator.pop(context,v);},child:const Text('Save'))]);}

class Achievements extends StatelessWidget { final List<Habit> habits; const Achievements({super.key,required this.habits}); @override Widget build(BuildContext context){var total=0,best=0;for(final h in habits){total+=h.totalCompletions();if(h.bestStreak()>best)best=h.bestStreak();}final list=[('🌱','First habit',habits.isNotEmpty),('🔥','7 day streak',best>=7),('🏆','30 day streak',best>=30),('💯','100 completions',total>=100),('⭐','5 habits',habits.length>=5),('🚀','10 habits',habits.length>=10)];return SafeArea(child:Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Achievements',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),...list.map((x)=>ListTile(leading:Text(x.$1,style:const TextStyle(fontSize:25)),title:Text(x.$2),trailing:Icon(x.$3?Icons.check_circle:Icons.lock_outline,color:x.$3?C.green:C.muted)))])));}}
void showAchievements(BuildContext context,List<Habit> habits)=>showModalBottomSheet(context:context,backgroundColor:Colors.white,builder:(_)=>Achievements(habits:habits));
int achievementCount(List<Habit> habits){var total=0,best=0;for(final h in habits){total+=h.totalCompletions();if(h.bestStreak()>best)best=h.bestStreak();}return [habits.isNotEmpty,best>=7,best>=30,total>=100,habits.length>=5,habits.length>=10].where((x)=>x).length;}
String formatTime(int seconds){final m=seconds~/60;final h=m~/60;final r=m%60;return h>0?'${h}h ${r}m':'${r}m';}
String priorityName(int p)=>p==3?'High':p==2?'Medium':'Low';
Future<bool> ask(BuildContext context,String title,String message)async=>await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:Text(message),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Delete'))]))??false;
