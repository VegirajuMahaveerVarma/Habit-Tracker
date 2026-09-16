import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
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
          ),
        ),
        home: const AppShell(),
      );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final storage = StorageService();
  List<Habit> habits = [];
  List<Map<String, dynamic>> todos = [];
  Map<String, int> moods = {};
  Map<String, int> timers = {};
  String? pin;
  bool locked = false;
  int tab = 0;
  DateTime date = DateTime.now();
  String search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final h = await storage.loadHabits();
    final t = await storage.loadTodos();
    final m = await storage.loadMoods();
    final f = await storage.loadTimerSeconds();
    final p = await storage.loadPin();
    if (!mounted) return;
    setState(() { habits = h; todos = t; moods = m; timers = f; pin = p; locked = p != null; });
  }

  Future<void> _saveHabits() => storage.saveHabits(habits);

  Future<void> _toggleHabit(Habit h, DateTime d) async {
    setState(() => h.setDone(d, !h.isDone(d)));
    await _saveHabits();
  }

  Future<void> _addHabit() async {
    final r = await showModalBottomSheet<HabitEditResult>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      builder: (_) => const HabitEditor(),
    );
    if (!mounted || r == null || r.name.trim().isEmpty) return;
    setState(() => habits.add(r.toHabit()));
    await _saveHabits();
  }

  Future<void> _editHabit(Habit h) async {
    final r = await showModalBottomSheet<HabitEditResult>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      builder: (_) => HabitEditor(habit: h),
    );
    if (!mounted || r == null) return;
    if (r.delete) {
      if (await confirmDialog(context, 'Delete habit?', 'Remove this habit?')) {
        setState(() => habits.removeWhere((x) => x.id == h.id));
        await _saveHabits();
      }
      return;
    }
    h.name = r.name; h.category = r.category; h.goal = r.goal; h.unit = r.unit;
    h.frequency = r.frequency; h.weekdays = r.weekdays; h.pinned = r.pinned;
    h.tags = r.tags; h.notes = r.notes;
    setState(() {});
    await _saveHabits();
  }

  Future<void> _addTodo() async {
    final r = await showDialog<TodoResult>(context: context, builder: (_) => const TodoEditor());
    if (!mounted || r == null || r.title.trim().isEmpty) return;
    setState(() => todos.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': r.title.trim(), 'done': false, 'priority': r.priority,
      'category': r.category, 'due': r.due == null ? '' : Habit.key(r.due!),
    }));
    await storage.saveTodos(todos);
  }

  Future<void> _editTodo(int i) async {
    final r = await showDialog<TodoResult>(context: context, builder: (_) => TodoEditor(initial: todos[i]));
    if (!mounted || r == null) return;
    if (r.delete) {
      setState(() => todos.removeAt(i));
    } else {
      setState(() {
        todos[i]['title'] = r.title.trim();
        todos[i]['priority'] = r.priority;
        todos[i]['category'] = r.category;
        todos[i]['due'] = r.due == null ? '' : Habit.key(r.due!);
      });
    }
    await storage.saveTodos(todos);
  }

  Future<void> _toggleTodo(int i) async {
    setState(() => todos[i]['done'] = todos[i]['done'] != true);
    await storage.saveTodos(todos);
  }

  Future<void> _setMood(int v) async {
    setState(() => moods[Habit.key(date)] = v);
    await storage.saveMoods(moods);
  }

  Future<void> _openTimer() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => FocusTimer(
      storage: storage, date: date, initial: timers[Habit.key(date)] ?? 0,
      onSaved: (v) => setState(() => timers[Habit.key(date)] = v),
    )));
  }

  Future<void> _setPin() async {
    final v = await showDialog<String>(context: context, builder: (_) => const PinDialog());
    if (v == null) return;
    pin = v.isEmpty ? null : v;
    await storage.savePin(pin);
    if (mounted) setState(() => locked = pin != null);
  }

  @override
  Widget build(BuildContext context) {
    if (locked) return LockScreen(pin: pin!, onUnlock: () => setState(() => locked = false));
    final pages = [
      Dashboard(habits: habits, todos: todos, moods: moods, date: date, search: search, onSearch: (v) => setState(() => search = v), onToggle: _toggleHabit, onAdd: _addHabit, onEdit: _editHabit, onMood: _setMood, onTimer: _openTimer),
      Daily(habits: habits, date: date, onDate: (v) => setState(() => date = v), onToggle: _toggleHabit, onAdd: _addHabit, onEdit: _editHabit),
      Analytics(habits: habits, moods: moods, todos: todos),
      Todos(todos: todos, onAdd: _addTodo, onEdit: _editTodo, onToggle: _toggleTodo),
      Profile(habits: habits, onPin: _setPin, onTimer: _openTimer),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab, indicatorColor: AppColors.blueSoft,
        onDestinationSelected: (v) => setState(() => tab = v),
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
  final String title; final String? subtitle; final Widget? trailing;
  const Header({super.key, required this.title, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: AppColors.text)),
        if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted)),
      ])),
      if (trailing != null) trailing!,
    ]),
  );
}

class CardBox extends StatelessWidget {
  final Widget child; const CardBox({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(blurRadius: 18, offset: Offset(0, 7), color: Color(0x08000000))]),
    child: child,
  );
}

class Section extends StatelessWidget {
  final String title; final VoidCallback? onAdd;
  const Section({super.key, required this.title, this.onAdd});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
    child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))), if (onAdd != null) TextButton(onPressed: onAdd, child: const Text('＋ Add'))]),
  );
}

class Dashboard extends StatelessWidget {
  final List<Habit> habits; final List<Map<String,dynamic>> todos; final Map<String,int> moods;
  final DateTime date; final String search; final ValueChanged<String> onSearch;
  final Future<void> Function(Habit,DateTime) onToggle; final VoidCallback onAdd,onTimer;
  final Future<void> Function(Habit) onEdit; final Future<void> Function(int) onMood;
  const Dashboard({super.key,required this.habits,required this.todos,required this.moods,required this.date,required this.search,required this.onSearch,required this.onToggle,required this.onAdd,required this.onEdit,required this.onMood,required this.onTimer});
  @override
  Widget build(BuildContext context) {
    final active = habits.where((h) => h.active).toList()..sort((a,b) => a.pinned == b.pinned ? 0 : (a.pinned ? -1 : 1));
    final q = search.trim().toLowerCase();
    final visible = active.where((h) => q.isEmpty || h.name.toLowerCase().contains(q) || h.category.toLowerCase().contains(q) || h.tags.any((t) => t.toLowerCase().contains(q))).toList();
    final done = active.where((h) => h.isDone(date)).length;
    final progress = active.isEmpty ? 0.0 : done / active.length;
    final best = active.fold<int>(0, (m,h) => h.currentStreak(date) > m ? h.currentStreak(date) : m);
    final mood = moods[Habit.key(date)];
    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 25), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Header(title: 'Good day 👋', subtitle: DateFormat('EEEE, d MMMM').format(date), trailing: IconButton(onPressed: onTimer, icon: const Icon(Icons.timer_outlined))),
      Padding(padding: const EdgeInsets.symmetric(horizontal:20), child: TextField(onChanged:onSearch, decoration:const InputDecoration(prefixIcon:Icon(Icons.search), hintText:'Search habits, categories or tags'))),
      const SizedBox(height:12),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20), child:CardBox(child:Row(children:[
        SizedBox(width:80,height:80,child:Stack(fit:StackFit.expand,children:[CircularProgressIndicator(value:progress,strokeWidth:9,backgroundColor:AppColors.blueSoft,color:AppColors.blue),Center(child:Text('${(progress*100).round()}%',style:const TextStyle(fontWeight:FontWeight.w900)))])),
        const SizedBox(width:18),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(done==active.length&&active.isNotEmpty?'All done!':'Today’s progress',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text('$done of ${active.length} habits completed',style:const TextStyle(color:AppColors.muted)),const SizedBox(height:9),LinearProgressIndicator(value:progress,minHeight:7,backgroundColor:AppColors.blueSoft)])),
      ]))),
      Section(title:'Quick stats'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Row(children:[
        Expanded(child:CardBox(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.local_fire_department_outlined,color:AppColors.blue),const SizedBox(height:6),const Text('Best streak',style:TextStyle(color:AppColors.muted)),Text('$best days',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))]))),
        const SizedBox(width:10),
        Expanded(child:CardBox(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.list_alt_outlined,color:AppColors.blue),const SizedBox(height:6),const Text('Open tasks',style:TextStyle(color:AppColors.muted)),Text('${todos.where((x)=>x['done']!=true).length}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))]))),
      ])),
      Section(title:'How are you feeling today?'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:List.generate(5,(i){final v=i+1;return InkWell(onTap:()=>onMood(v),child:Opacity(opacity:mood==v?1:.55,child:Padding(padding:const EdgeInsets.all(8),child:Text(['😫','😕','😐','🙂','😄'][i],style:const TextStyle(fontSize:25)))));})))),
      Section(title:q.isEmpty?'Today’s habits':'Search results',onAdd:onAdd),
      if(visible.isEmpty) const Padding(padding:EdgeInsets.all(30),child:Center(child:Text('No matching habits.',style:TextStyle(color:AppColors.muted))))
      else ...visible.map((h)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),child:HabitTile(habit:h,date:date,onToggle:()=>onToggle(h,date),onEdit:()=>onEdit(h)))),
    ]));
  }
}

class HabitTile extends StatelessWidget {
  final Habit habit; final DateTime date; final VoidCallback onToggle,onEdit;
  const HabitTile({super.key,required this.habit,required this.date,required this.onToggle,required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final done = habit.isDone(date);
    final rate = habit.completionRate(date).clamp(0.0,1.0).toDouble();
    return GestureDetector(
      onLongPress:onEdit,
      child:CardBox(child:Row(children:[
        GestureDetector(onTap:onToggle,child:Container(width:42,height:42,decoration:BoxDecoration(shape:BoxShape.circle,color:done?AppColors.blue:AppColors.blueSoft),child:Icon(done?Icons.check:Icons.check_circle_outline,color:done?Colors.white:AppColors.blue))),
        const SizedBox(width:13),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text(habit.name,style:TextStyle(fontWeight:FontWeight.w900,decoration:done?TextDecoration.lineThrough:null))),if(habit.pinned)const Icon(Icons.push_pin,size:16,color:AppColors.orange)]),
          Wrap(spacing:4,children:[Chip(label:Text(habit.category),visualDensity:VisualDensity.compact),Chip(label:Text('${habit.goal} ${habit.unit}'),visualDensity:VisualDensity.compact),if(habit.currentStreak(date)>0)Text('🔥${habit.currentStreak(date)}',style:const TextStyle(fontWeight:FontWeight.w800))]),
          LinearProgressIndicator(value:rate,minHeight:5,backgroundColor:AppColors.blueSoft),
        ])),
      ])),
    );
  }
}

class Daily extends StatelessWidget {
  final List<Habit> habits; final DateTime date; final ValueChanged<DateTime> onDate;
  final Future<void> Function(Habit,DateTime) onToggle; final VoidCallback onAdd; final Future<void> Function(Habit) onEdit;
  const Daily({super.key,required this.habits,required this.date,required this.onDate,required this.onToggle,required this.onAdd,required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final days=List.generate(DateTime(date.year,date.month+1,0).day,(i)=>DateTime(date.year,date.month,i+1));
    final active=habits.where((h)=>h.active).toList();
    final complete=active.where((h)=>h.isDone(date)).length;
    return Column(children:[
      Header(title:'Daily',subtitle:DateFormat('MMMM yyyy').format(date)),
      SizedBox(height:82,child:ListView.separated(padding:const EdgeInsets.symmetric(horizontal:20),scrollDirection:Axis.horizontal,itemCount:days.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(_,i){final d=days[i];final selected=Habit.key(d)==Habit.key(date);final count=active.where((h)=>h.isDone(d)).length;return InkWell(onTap:()=>onDate(d),child:Container(width:48,padding:const EdgeInsets.symmetric(vertical:8),decoration:BoxDecoration(color:selected?AppColors.blue:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:selected?AppColors.blue:AppColors.border)),child:Column(children:[Text(DateFormat('E').format(d).substring(0,1),style:TextStyle(color:selected?Colors.white:AppColors.muted)),Text('${d.day}',style:TextStyle(fontWeight:FontWeight.w900,color:selected?Colors.white:AppColors.text)),Text('$count',style:TextStyle(fontSize:11,color:selected?Colors.white:AppColors.blue))])));}),),
      Section(title:'${DateFormat('EEE, d MMMM').format(date)} · $complete/${active.length} complete',onAdd:onAdd),
      Expanded(child:ListView(children:active.map((h)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),child:HabitTile(habit:h,date:date,onToggle:()=>onToggle(h,date),onEdit:()=>onEdit(h)))).toList())),
    ]);
  }
}

class Analytics extends StatelessWidget {
  final List<Habit> habits; final Map<String,int> moods; final List<Map<String,dynamic>> todos;
  const Analytics({super.key,required this.habits,required this.moods,required this.todos});
  @override
  Widget build(BuildContext context) {
    final now=DateTime.now();
    final active=habits.where((h)=>h.active).toList();
    final overall=active.isEmpty?0.0:active.map((h)=>h.completionRate(now)).reduce((a,b)=>a+b)/active.length;
    final total=habits.fold<int>(0,(s,h)=>s+h.totalCompletions());
    final best=habits.fold<int>(0,(m,h)=>h.bestStreak()>m?h.bestStreak():m);
    final avg=moods.isEmpty?0.0:moods.values.reduce((a,b)=>a+b)/moods.length;
    final days=List.generate(7,(i)=>DateTime(now.year,now.month,now.day-6+i));
    return SingleChildScrollView(padding:const EdgeInsets.only(bottom:25),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Header(title:'Analytics',subtitle:'Consistency, patterns and progress'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(children:[
        SizedBox(width:78,height:78,child:Stack(fit:StackFit.expand,children:[CircularProgressIndicator(value:overall,strokeWidth:8,backgroundColor:AppColors.blueSoft,color:AppColors.blue),Center(child:Text('${(overall*100).round()}%',style:const TextStyle(fontWeight:FontWeight.w900)))])),
        const SizedBox(width:18),
        Expanded(child:Text('${active.length} active habits\n$total total completions\n$best best streak\n${todos.where((x)=>x['done']!=true).length} open tasks\nAverage mood: ${avg==0?'—':'${avg.toStringAsFixed(1)}/5'}',style:const TextStyle(color:AppColors.muted,height:1.5))),
      ]))),
      Section(title:'Last 7 days'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:days.map((d){final n=active.where((h)=>h.isDone(d)).length;final height=active.isEmpty?8.0:(80.0*n/active.length).clamp(8.0,80.0).toDouble();return Expanded(child:Column(children:[Text('$n',style:const TextStyle(fontSize:11)),const SizedBox(height:4),Container(height:height,margin:const EdgeInsets.symmetric(horizontal:4),decoration:BoxDecoration(color:AppColors.blue,borderRadius:BorderRadius.circular(8))),const SizedBox(height:4),Text(DateFormat('E').format(d).substring(0,1),style:const TextStyle(color:AppColors.muted))]));}).toList()))),
      Section(title:'Habit performance'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Column(children:active.map((h){final r=h.completionRate(now).clamp(0.0,1.0).toDouble();return Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[Expanded(child:Text(h.name,style:const TextStyle(fontWeight:FontWeight.w800))),Text('${(r*100).round()}%'),const SizedBox(width:8),SizedBox(width:65,child:LinearProgressIndicator(value:r))]));}).toList()))),
      Section(title:'Weekly review'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Best streak: $best days'),Text('Total completions: $total'),Text('Average mood: ${avg==0?'no entries':'${avg.toStringAsFixed(1)}/5'}'),const SizedBox(height:8),const Text('Review missed days and habit notes each week.',style:TextStyle(color:AppColors.muted))]))),
    ]));
  }
}

class Todos extends StatelessWidget {
  final List<Map<String,dynamic>> todos; final VoidCallback onAdd; final Future<void> Function(int) onEdit,onToggle;
  const Todos({super.key,required this.todos,required this.onAdd,required this.onEdit,required this.onToggle});
  @override
  Widget build(BuildContext context){
    final done=todos.where((x)=>x['done']==true).length;
    return Column(children:[
      Header(title:'To-Do',subtitle:'$done completed · ${todos.length-done} remaining',trailing:IconButton(onPressed:onAdd,icon:const Icon(Icons.add))),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Column(children:[LinearProgressIndicator(value:todos.isEmpty?0:done/todos.length,minHeight:8,backgroundColor:AppColors.blueSoft),const SizedBox(height:10),Text(todos.isEmpty?'No tasks yet':'$done of ${todos.length} tasks complete')]))),
      Expanded(child:todos.isEmpty?const Center(child:Text('Tap + to create a task.',style:TextStyle(color:AppColors.muted))):ListView.builder(padding:const EdgeInsets.all(20),itemCount:todos.length,itemBuilder:(_,i){final x=todos[i];final isDone=x['done']==true;return Card(margin:const EdgeInsets.only(bottom:10),child:ListTile(onTap:()=>onEdit(i),leading:Checkbox(value:isDone,onChanged:(_)=>onToggle(i)),title:Text('${x['title']}',style:TextStyle(fontWeight:FontWeight.w800,decoration:isDone?TextDecoration.lineThrough:null)),subtitle:Text('${x['category']??'General'} · ${priorityName((x['priority'] as num?)?.toInt()??1)}${x['due']!=''?' · ${x['due']}':''}'),trailing:const Icon(Icons.chevron_right)));}) ),
    ]);
  }
}

class Profile extends StatelessWidget {
  final List<Habit> habits; final VoidCallback onPin,onTimer;
  const Profile({super.key,required this.habits,required this.onPin,required this.onTimer});
  @override
  Widget build(BuildContext context){
    final total=habits.fold<int>(0,(s,h)=>s+h.totalCompletions());
    final best=habits.fold<int>(0,(m,h)=>h.bestStreak()>m?h.bestStreak():m);
    return SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Header(title:'Profile',subtitle:'Your private offline habit space'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(children:[const CircleAvatar(radius:34,backgroundColor:Color(0xFF102A43),child:Icon(Icons.person,color:Colors.white)),const SizedBox(width:15),Expanded(child:Text('${habits.length} habits · $total completions',style:const TextStyle(fontWeight:FontWeight.w800)))]))),
      Section(title:'Your stats'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Row(children:[Expanded(child:CardBox(child:Text('🔥 Best streak\n$best days',style:const TextStyle(fontWeight:FontWeight.w800)))),const SizedBox(width:10),Expanded(child:CardBox(child:Text('✓ Completions\n$total',style:const TextStyle(fontWeight:FontWeight.w800))))])),
      Section(title:'Tools'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Column(children:[ListTile(onTap:onTimer,leading:const Icon(Icons.timer_outlined,color:AppColors.blue),title:const Text('Focus timer'),subtitle:const Text('Track focused time'),trailing:const Icon(Icons.chevron_right)),ListTile(onTap:onPin,leading:const Icon(Icons.lock_outline,color:AppColors.blue),title:const Text('App lock'),subtitle:const Text('Set or remove local PIN'),trailing:const Icon(Icons.chevron_right)),const ListTile(leading:Icon(Icons.wifi_off_outlined,color:AppColors.blue),title:Text('Offline first'),subtitle:Text('Data stays on this device'))])),
    ]));
  }
}

class HabitEditResult {
  final String name,category,unit,frequency,notes; final int goal; final List<int> weekdays; final bool pinned,delete; final List<String> tags;
  const HabitEditResult({required this.name,required this.category,required this.goal,required this.unit,required this.frequency,required this.weekdays,required this.pinned,required this.tags,required this.notes,this.delete=false});
  Habit toHabit()=>Habit(id:DateTime.now().microsecondsSinceEpoch.toString(),name:name,category:category,goal:goal,unit:unit,frequency:frequency,weekdays:weekdays,pinned:pinned,tags:tags,notes:notes);
}

class HabitEditor extends StatefulWidget {
  final Habit? habit; const HabitEditor({super.key,this.habit});
  @override State<HabitEditor> createState()=>_HabitEditorState();
}
class _HabitEditorState extends State<HabitEditor>{
  late final TextEditingController name,goal,tags,notes; late String category,unit,frequency; late List<int> weekdays; late bool pinned;
  @override void initState(){super.initState();final h=widget.habit;name=TextEditingController(text:h?.name??'');goal=TextEditingController(text:'${h?.goal??1}');tags=TextEditingController(text:h?.tags.join(', ')??'');notes=TextEditingController(text:h?.notes??'');final cats=['Personal','Health','Mind & Body','Productivity','Learning','Goals','Finance','Other'];category=cats.contains(h?.category)?h!.category:'Personal';unit=h?.unit??'times';frequency=h?.frequency??'Every day';weekdays=List<int>.from(h?.weekdays??[1,2,3,4,5,6,7]);pinned=h?.pinned??false;}
  @override void dispose(){name.dispose();goal.dispose();tags.dispose();notes.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(20,10,20,MediaQuery.of(context).viewInsets.bottom+20),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.habit==null?'Create habit':'Edit habit',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:14),TextField(controller:name,autofocus:true,decoration:const InputDecoration(labelText:'Habit name')),const SizedBox(height:10),Row(children:[Expanded(child:DropdownButtonFormField<String>(value:category,items:['Personal','Health','Mind & Body','Productivity','Learning','Goals','Finance','Other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>category=v!))),const SizedBox(width:10),Expanded(child:DropdownButtonFormField<String>(value:unit,items:['times','minutes','hours','pages','litres','km','steps','reps'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>unit=v!)))]),const SizedBox(height:10),TextField(controller:goal,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Daily target')),const SizedBox(height:10),const Text('Frequency',style:TextStyle(fontWeight:FontWeight.w800)),Wrap(spacing:7,children:['Every day','Weekdays','Custom'].map((x)=>ChoiceChip(label:Text(x),selected:frequency==x,onSelected:(_)=>setState(()=>frequency=x))).toList()),if(frequency=='Custom')Wrap(spacing:4,children:List.generate(7,(i){final d=i+1;return FilterChip(label:Text(['M','T','W','T','F','S','S'][i]),selected:weekdays.contains(d),onSelected:(v)=>setState((){if(v){if(!weekdays.contains(d))weekdays.add(d);}else{weekdays.remove(d);}}));})),const SizedBox(height:8),TextField(controller:tags,decoration:const InputDecoration(labelText:'Tags, comma separated')),const SizedBox(height:8),TextField(controller:notes,maxLines:3,decoration:const InputDecoration(labelText:'Journal / notes')),SwitchListTile(contentPadding:EdgeInsets.zero,value:pinned,onChanged:(v)=>setState(()=>pinned=v),title:const Text('Pin to top')),if(widget.habit!=null)TextButton.icon(onPressed:()=>Navigator.pop(context,const HabitEditResult(name:'',category:'',goal:1,unit:'times',frequency:'Every day',weekdays:[1,2,3,4,5,6,7],pinned:false,tags:[],notes:'',delete:true)),icon:const Icon(Icons.delete_outline),label:const Text('Delete habit')),FilledButton(onPressed:()=>Navigator.pop(context,HabitEditResult(name:name.text.trim(),category:category,goal:(int.tryParse(goal.text)??1)<1?1:int.tryParse(goal.text)??1,unit:unit,frequency:frequency,weekdays:weekdays.isEmpty?[1,2,3,4,5,6,7]:weekdays,pinned:pinned,tags:tags.text.split(',').map((x)=>x.trim()).where((x)=>x.isNotEmpty).toList(),notes:notes.text.trim())),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)),child:Text(widget.habit==null?'Create habit':'Save changes'))]))));
}

class TodoResult { final String title,category; final int priority; final DateTime? due; final bool delete; const TodoResult({required this.title,required this.category,required this.priority,this.due,this.delete=false}); }
class TodoEditor extends StatefulWidget { final Map<String,dynamic>? initial; const TodoEditor({super.key,this.initial}); @override State<TodoEditor> createState()=>_TodoEditorState(); }
class _TodoEditorState extends State<TodoEditor>{
  late final TextEditingController title; late String category; late int priority; DateTime? due;
  @override void initState(){super.initState();final x=widget.initial;title=TextEditingController(text:'${x?['title']??''}');category='${x?['category']??'General'}';priority=(x?['priority'] as num?)?.toInt()??1;final d='${x?['due']??''}';due=d.isEmpty?null:DateTime.tryParse(d);}
  @override void dispose(){title.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.initial==null?'New task':'Edit task'),content:SingleChildScrollView(child:Column(children:[TextField(controller:title,autofocus:true,decoration:const InputDecoration(labelText:'Task')),const SizedBox(height:8),DropdownButtonFormField<String>(value:['General','College','Work','Personal'].contains(category)?category:'General',items:['General','College','Work','Personal'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>category=v!)),const SizedBox(height:8),DropdownButtonFormField<int>(value:priority.clamp(1,3).toInt(),items:const[DropdownMenuItem(value:1,child:Text('Low')),DropdownMenuItem(value:2,child:Text('Medium')),DropdownMenuItem(value:3,child:Text('High'))],onChanged:(v)=>setState(()=>priority=v??1)),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.event_outlined),title:Text(due==null?'No due date':'Due ${DateFormat('d MMM yyyy').format(due!)}'),onTap:()async{final picked=await showDatePicker(context:context,initialDate:due??DateTime.now(),firstDate:DateTime(2020),lastDate:DateTime(2100));if(picked!=null&&mounted)setState(()=>due=picked);})])),actions:[if(widget.initial!=null)TextButton(onPressed:()=>Navigator.pop(context,const TodoResult(title:'',category:'',priority:1,delete:true)),child:const Text('Delete')),TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,TodoResult(title:title.text,category:category,priority:priority,due:due)),child:const Text('Save'))]);
}

class FocusTimer extends StatefulWidget { final StorageService storage; final DateTime date; final int initial; final ValueChanged<int> onSaved; const FocusTimer({super.key,required this.storage,required this.date,required this.initial,required this.onSaved}); @override State<FocusTimer> createState()=>_FocusTimerState(); }
class _FocusTimerState extends State<FocusTimer>{late int seconds;Timer? timer;bool running=false;@override void initState(){super.initState();seconds=widget.initial;}@override void dispose(){timer?.cancel();super.dispose();}void toggle(){if(running){timer?.cancel();setState(()=>running=false);}else{timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>seconds++);});setState(()=>running=true);}}Future<void> save()async{final data=await widget.storage.loadTimerSeconds();data[Habit.key(widget.date)]=seconds;await widget.storage.saveTimerSeconds(data);widget.onSaved(seconds);if(mounted)Navigator.pop(context);}String fmt(int s)=>'${(s~/3600).toString().padLeft(2,'0')}:${((s%3600)~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}';@override Widget build(BuildContext context){return Scaffold(appBar:AppBar(title:const Text('Focus Timer')),body:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.timer_outlined,size:60,color:AppColors.blue),const SizedBox(height:20),Text(fmt(seconds),style:const TextStyle(fontSize:48,fontWeight:FontWeight.w900)),const SizedBox(height:20),FilledButton.icon(onPressed:toggle,icon:Icon(running?Icons.pause:Icons.play_arrow),label:Text(running?'Pause':'Start')),const SizedBox(height:10),OutlinedButton(onPressed:save,child:const Text('Save today’s focus time'))])));}}

class PinDialog extends StatefulWidget { const PinDialog({super.key}); @override State<PinDialog> createState()=>_PinDialogState(); }
class _PinDialogState extends State<PinDialog>{final c=TextEditingController();@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:const Text('App lock'),content:TextField(controller:c,obscureText:true,keyboardType:TextInputType.number,maxLength:6,decoration:const InputDecoration(labelText:'4–6 digit PIN')),actions:[TextButton(onPressed:()=>Navigator.pop(context,''),child:const Text('Remove')),FilledButton(onPressed:()=>c.text.length>=4?Navigator.pop(context,c.text):null,child:const Text('Save'))]);}

class LockScreen extends StatelessWidget { final String pin; final VoidCallback onUnlock; const LockScreen({super.key,required this.pin,required this.onUnlock}); @override Widget build(BuildContext context)=>_LockBody(pin:pin,onUnlock:onUnlock); }
class _LockBody extends StatefulWidget { final String pin; final VoidCallback onUnlock; const _LockBody({required this.pin,required this.onUnlock}); @override State<_LockBody> createState()=>_LockBodyState(); }
class _LockBodyState extends State<_LockBody>{final c=TextEditingController();String error='';@override void dispose(){c.dispose();super.dispose();}void unlock(){if(c.text==widget.pin){widget.onUnlock();}else{setState(()=>error='Incorrect PIN');}}@override Widget build(BuildContext context)=>Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(30),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.lock_outline,size:64,color:AppColors.blue),const SizedBox(height:18),const Text('Habit Tracker locked',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:15),TextField(controller:c,obscureText:true,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'PIN',errorText:error.isEmpty?null:error)),const SizedBox(height:15),FilledButton(onPressed:unlock,child:const Text('Unlock'))]))));}

Future<bool> confirmDialog(BuildContext context,String title,String message) async=>await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:Text(message),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Delete'))]))??false;
String priorityName(int v)=>v==3?'High':v==2?'Medium':'Low';
