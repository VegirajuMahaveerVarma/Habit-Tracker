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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
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
  bool onboarding = false;
  int tab = 0;
  DateTime date = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final h = await storage.loadHabits();
    final t = await storage.loadTodos();
    final m = await storage.loadMoods();
    final f = await storage.loadTimerSeconds();
    final p = await storage.loadPin();
    final prefs = await SharedPreferences.getInstance();
    final first = !(prefs.getBool('onboarding_done_v1') ?? false);
    if (!mounted) return;
    setState(() { habits = h; todos = t; moods = m; timers = f; pin = p; locked = p != null; onboarding = first; });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done_v1', true);
    if (mounted) setState(() => onboarding = false);
  }

  Future<void> _saveHabits() => storage.saveHabits(habits);

  Future<void> _toggleHabit(Habit h, DateTime d) async {
    setState(() => h.setDone(d, !h.isDone(d)));
    await _saveHabits();
  }

  Future<void> _saveHabitEdit(HabitEditResult r, {Habit? existing}) async {
    if (r.delete && existing != null) {
      if (await confirmDialog(context, 'Delete habit?', 'This removes the habit and its history.')) {
        setState(() => habits.removeWhere((x) => x.id == existing.id));
        await _saveHabits();
      }
      return;
    }
    if (existing == null) {
      setState(() => habits.add(r.toHabit()));
    } else {
      existing.name = r.name;
      existing.category = r.category;
      existing.goal = r.goal;
      existing.unit = r.unit;
      existing.frequency = r.frequency;
      existing.weekdays = r.weekdays;
      existing.pinned = r.pinned;
      existing.active = r.active;
      existing.icon = r.icon;
      existing.tags = r.tags;
      existing.notes = r.notes;
    }
    await _saveHabits();
    if (mounted) setState(() {});
  }

  Future<void> _addHabit() async {
    final r = await showModalBottomSheet<HabitEditResult>(context: context, isScrollControlled: true, backgroundColor: Colors.white, builder: (_) => const HabitEditor());
    if (!mounted || r == null || r.name.trim().isEmpty) return;
    await _saveHabitEdit(r);
  }

  Future<void> _editHabit(Habit h) async {
    final r = await showModalBottomSheet<HabitEditResult>(context: context, isScrollControlled: true, backgroundColor: Colors.white, builder: (_) => HabitEditor(habit: h));
    if (!mounted || r == null) return;
    await _saveHabitEdit(r, existing: h);
  }

  Future<void> _openHabit(Habit h) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => HabitDetail(habit: h, onChanged: () async { await _saveHabits(); if (mounted) setState(() {}); })));
    if (mounted) setState(() {});
  }

  Future<void> _addTodo() async {
    final r = await showDialog<TodoResult>(context: context, builder: (_) => const TodoEditor());
    if (!mounted || r == null || r.title.trim().isEmpty) return;
    setState(() => todos.add({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'title': r.title.trim(), 'done': false, 'priority': r.priority, 'category': r.category, 'due': r.due == null ? '' : Habit.key(r.due!)}));
    await storage.saveTodos(todos);
  }

  Future<void> _editTodo(int i) async {
    final r = await showDialog<TodoResult>(context: context, builder: (_) => TodoEditor(initial: todos[i]));
    if (!mounted || r == null) return;
    if (r.delete) {
      setState(() => todos.removeAt(i));
    } else {
      setState(() { todos[i]['title'] = r.title.trim(); todos[i]['priority'] = r.priority; todos[i]['category'] = r.category; todos[i]['due'] = r.due == null ? '' : Habit.key(r.due!); });
    }
    await storage.saveTodos(todos);
  }

  Future<void> _toggleTodo(int i) async {
    setState(() => todos[i]['done'] = todos[i]['done'] != true);
    await storage.saveTodos(todos);
  }

  Future<void> _setMood(int value) async {
    setState(() => moods[Habit.key(date)] = value);
    await storage.saveMoods(moods);
  }

  Future<void> _openTimer() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => FocusTimer(storage: storage, date: date, initial: timers[Habit.key(date)] ?? 0, onSaved: (v) => setState(() => timers[Habit.key(date)] = v))));
  }

  Future<void> _setPin() async {
    final v = await showDialog<String>(context: context, builder: (_) => const PinDialog());
    if (v == null) return;
    pin = v.isEmpty ? null : v;
    await storage.savePin(pin);
    if (mounted) setState(() => locked = false);
  }

  Future<void> _showTemplates() async {
    final template = await showModalBottomSheet<List<String>>(context: context, backgroundColor: Colors.white, builder: (_) => const TemplateSheet());
    if (!mounted || template == null) return;
    final existing = habits.map((h) => h.name.toLowerCase()).toSet();
    final additions = template.where((x) => !existing.contains(x.toLowerCase())).map((x) => Habit(id: DateTime.now().microsecondsSinceEpoch.toString() + x, name: x, category: 'Routine')).toList();
    setState(() => habits.addAll(additions));
    await _saveHabits();
  }

  @override
  Widget build(BuildContext context) {
    if (onboarding) return Onboarding(onDone: _finishOnboarding, onCreate: _addHabit);
    if (locked && pin != null) return LockScreen(pin: pin!, onUnlock: () => setState(() => locked = false));
    final pages = [
      Dashboard(habits: habits, todos: todos, moods: moods, date: date, onToggle: _toggleHabit, onAdd: _addHabit, onEdit: _editHabit, onOpen: _openHabit, onMood: _setMood, onTimer: _openTimer),
      Daily(habits: habits, date: date, onDate: (v) => setState(() => date = v), onToggle: _toggleHabit, onAdd: _addHabit, onEdit: _editHabit, onOpen: _openHabit),
      Analytics(habits: habits, moods: moods, todos: todos, timers: timers, onOpen: _openHabit),
      Todos(todos: todos, onAdd: _addTodo, onEdit: _editTodo, onToggle: _toggleTodo),
      Profile(habits: habits, onPin: _setPin, onTimer: _openTimer, onTemplates: _showTemplates),
    ];
    return Scaffold(body: SafeArea(child: IndexedStack(index: tab, children: pages)), bottomNavigationBar: NavigationBar(selectedIndex: tab, indicatorColor: AppColors.blueSoft, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Habits'),
      NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Stats'),
      NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'To-Do'),
      NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
    ]));
  }
}

class Header extends StatelessWidget {
  final String title; final String? subtitle; final Widget? trailing;
  const Header({super.key, required this.title, this.subtitle, this.trailing});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 14), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: AppColors.text)), if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted))])), if (trailing != null) trailing!]));
}

class CardBox extends StatelessWidget {
  final Widget child; const CardBox({super.key, required this.child});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(blurRadius: 18, offset: Offset(0, 7), color: Color(0x08000000))]), child: child);
}

class Section extends StatelessWidget {
  final String title; final VoidCallback? action; final String actionText;
  const Section({super.key, required this.title, this.action, this.actionText = '＋ Add'});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 10), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))), if (action != null) TextButton(onPressed: action, child: Text(actionText))]));
}

class Dashboard extends StatefulWidget {
  final List<Habit> habits; final List<Map<String,dynamic>> todos; final Map<String,int> moods; final DateTime date;
  final Future<void> Function(Habit,DateTime) onToggle; final VoidCallback onAdd,onTimer; final Future<void> Function(Habit) onEdit,onOpen; final Future<void> Function(int) onMood;
  const Dashboard({super.key,required this.habits,required this.todos,required this.moods,required this.date,required this.onToggle,required this.onAdd,required this.onEdit,required this.onOpen,required this.onMood,required this.onTimer});
  @override State<Dashboard> createState()=>_DashboardState();
}
class _DashboardState extends State<Dashboard>{String search='';String filter='All';String sort='Pinned';
  @override Widget build(BuildContext context){
    final active=widget.habits.where((h)=>h.active).toList();
    var visible=active.where((h){final q=search.toLowerCase().trim();final match=q.isEmpty||h.name.toLowerCase().contains(q)||h.category.toLowerCase().contains(q)||h.tags.any((t)=>t.toLowerCase().contains(q));final f=filter=='All'||(filter=='Pinned'&&h.pinned)||(filter=='Completed'&&h.isDone(widget.date))||(filter=='Missed'&&h.isScheduled(widget.date)&&!h.isDone(widget.date));return match&&f;}).toList();
    visible.sort((a,b){if(sort=='Name')return a.name.toLowerCase().compareTo(b.name.toLowerCase());if(sort=='Streak')return b.currentStreak(widget.date).compareTo(a.currentStreak(widget.date));if(sort=='Progress')return b.completionRate(widget.date).compareTo(a.completionRate(widget.date));return a.pinned==b.pinned?0:(a.pinned?-1:1);});
    final done=active.where((h)=>h.isDone(widget.date)).length;final progress=active.isEmpty?0.0:done/active.length;final best=active.fold<int>(0,(m,h)=>h.currentStreak(widget.date)>m?h.currentStreak(widget.date):m);final mood=widget.moods[Habit.key(widget.date)];
    return SingleChildScrollView(padding:const EdgeInsets.only(bottom:25),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Header(title:'Good day 👋',subtitle:DateFormat('EEEE, d MMMM').format(widget.date),trailing:IconButton(onPressed:widget.onTimer,icon:const Icon(Icons.timer_outlined))),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search habits, categories or tags'))),
      const SizedBox(height:10),
      SizedBox(height:42,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:20),children:['All','Pinned','Completed','Missed'].map((x)=>Padding(padding:const EdgeInsets.only(right:7),child:ChoiceChip(label:Text(x),selected:filter==x,onSelected:(_)=>setState(()=>filter=x)))).toList())),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Row(children:[const Text('Sort:',style:TextStyle(color:AppColors.muted)),const SizedBox(width:8),DropdownButton<String>(value:sort,items:['Pinned','Name','Streak','Progress'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>sort=v!))])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(children:[SizedBox(width:80,height:80,child:Stack(fit:StackFit.expand,children:[CircularProgressIndicator(value:progress,strokeWidth:9,backgroundColor:AppColors.blueSoft,color:AppColors.blue),Center(child:Text('${(progress*100).round()}%',style:const TextStyle(fontWeight:FontWeight.w900)))])),const SizedBox(width:18),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(done==active.length&&active.isNotEmpty?'All done!':'Today’s progress',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text('$done of ${active.length} habits completed',style:const TextStyle(color:AppColors.muted)),const SizedBox(height:9),LinearProgressIndicator(value:progress,minHeight:7,backgroundColor:AppColors.blueSoft)]))]))),
      Section(title:'Quick stats'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Row(children:[Expanded(child:CardBox(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.local_fire_department_outlined,color:AppColors.blue),const SizedBox(height:6),const Text('Best streak',style:TextStyle(color:AppColors.muted)),Text('$best days',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))]))),const SizedBox(width:10),Expanded(child:CardBox(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.list_alt_outlined,color:AppColors.blue),const SizedBox(height:6),const Text('Open tasks',style:TextStyle(color:AppColors.muted)),Text('${widget.todos.where((x)=>x['done']!=true).length}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))])))])),
      Section(title:'How are you feeling today?'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:List.generate(5,(i){final v=i+1;return InkWell(onTap:()=>widget.onMood(v),child:Opacity(opacity:mood==v?1:.55,child:Padding(padding:const EdgeInsets.all(8),child:Text(['😫','😕','😐','🙂','😄'][i],style:const TextStyle(fontSize:25)))));})))),
      Section(title:search.isEmpty?'Today’s habits':'Search results',action:widget.onAdd),
      if(visible.isEmpty)const Padding(padding:EdgeInsets.all(30),child:Center(child:Text('No matching habits.',style:TextStyle(color:AppColors.muted)))) else ...visible.map((h)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),child:HabitTile(habit:h,date:widget.date,onToggle:()=>widget.onToggle(h,widget.date),onEdit:()=>widget.onEdit(h),onOpen:()=>widget.onOpen(h)))),
    ]));
  }
}

class HabitTile extends StatelessWidget {final Habit habit;final DateTime date;final VoidCallback onToggle,onEdit,onOpen;const HabitTile({super.key,required this.habit,required this.date,required this.onToggle,required this.onEdit,required this.onOpen});
  @override Widget build(BuildContext context){final done=habit.isDone(date);final rate=habit.completionRate(date).clamp(0.0,1.0).toDouble();return GestureDetector(onLongPress:onEdit,onTap:onOpen,child:CardBox(child:Row(children:[GestureDetector(onTap:onToggle,child:Container(width:42,height:42,decoration:BoxDecoration(shape:BoxShape.circle,color:done?AppColors.blue:AppColors.blueSoft),child:Icon(done?Icons.check:Icons.check_circle_outline,color:done?Colors.white:AppColors.blue))),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(habit.name,style:TextStyle(fontWeight:FontWeight.w900,decoration:done?TextDecoration.lineThrough:null))),if(habit.pinned)const Icon(Icons.push_pin,size:16,color:AppColors.orange)]),Wrap(spacing:4,children:[Chip(label:Text(habit.category),visualDensity:VisualDensity.compact),Chip(label:Text('${habit.goal} ${habit.unit}'),visualDensity:VisualDensity.compact),if(habit.currentStreak(date)>0)Text('🔥${habit.currentStreak(date)}',style:const TextStyle(fontWeight:FontWeight.w800))]),LinearProgressIndicator(value:rate,minHeight:5,backgroundColor:AppColors.blueSoft)]))])));}
}

class Daily extends StatelessWidget {final List<Habit> habits;final DateTime date;final ValueChanged<DateTime> onDate;final Future<void> Function(Habit,DateTime) onToggle;final VoidCallback onAdd;final Future<void> Function(Habit) onEdit,onOpen;const Daily({super.key,required this.habits,required this.date,required this.onDate,required this.onToggle,required this.onAdd,required this.onEdit,required this.onOpen});
  @override Widget build(BuildContext context){final days=List.generate(DateTime(date.year,date.month+1,0).day,(i)=>DateTime(date.year,date.month,i+1));final active=habits.where((h)=>h.active&&h.isScheduled(date)).toList();final complete=active.where((h)=>h.isDone(date)).length;return Column(children:[Header(title:'Daily',subtitle:DateFormat('MMMM yyyy').format(date)),SizedBox(height:82,child:ListView.separated(padding:const EdgeInsets.symmetric(horizontal:20),scrollDirection:Axis.horizontal,itemCount:days.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(_,i){final d=days[i];final selected=Habit.key(d)==Habit.key(date);final count=habits.where((h)=>h.active&&h.isScheduled(d)&&h.isDone(d)).length;return InkWell(onTap:()=>onDate(d),child:Container(width:48,padding:const EdgeInsets.symmetric(vertical:8),decoration:BoxDecoration(color:selected?AppColors.blue:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:selected?AppColors.blue:AppColors.border)),child:Column(children:[Text(DateFormat('E').format(d).substring(0,1),style:TextStyle(color:selected?Colors.white:AppColors.muted)),Text('${d.day}',style:TextStyle(fontWeight:FontWeight.w900,color:selected?Colors.white:AppColors.text)),Text('$count',style:TextStyle(fontSize:11,color:selected?Colors.white:AppColors.blue))])));}),),Section(title:'${DateFormat('EEE, d MMMM').format(date)} · $complete/${active.length} complete',action:onAdd),Expanded(child:ListView(children:active.map((h)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),child:HabitTile(habit:h,date:date,onToggle:()=>onToggle(h,date),onEdit:()=>onEdit(h),onOpen:()=>onOpen(h)))).toList()))]);}
}

class Analytics extends StatelessWidget {final List<Habit> habits;final Map<String,int> moods;final List<Map<String,dynamic>> todos;final Map<String,int> timers;final Future<void> Function(Habit) onOpen;const Analytics({super.key,required this.habits,required this.moods,required this.todos,required this.timers,required this.onOpen});
  @override Widget build(BuildContext context){final now=DateTime.now();final active=habits.where((h)=>h.active).toList();final overall=active.isEmpty?0.0:active.map((h)=>h.completionRate(now)).reduce((a,b)=>a+b)/active.length;final total=habits.fold<int>(0,(s,h)=>s+h.totalCompletions());final best=habits.fold<int>(0,(m,h)=>h.bestStreak()>m?h.bestStreak():m);final avg=moods.isEmpty?0.0:moods.values.reduce((a,b)=>a+b)/moods.length;final days=List.generate(7,(i)=>DateTime(now.year,now.month,now.day-6+i));final monthDays=DateTime(now.year,now.month+1,0).day;final monthDone=active.fold<int>(0,(s,h)=>s+h.completedInMonth(now));final focus=timers.values.fold<int>(0,(s,v)=>s+v);return SingleChildScrollView(padding:const EdgeInsets.only(bottom:25),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Header(title:'Analytics',subtitle:'Consistency, patterns and progress'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(children:[SizedBox(width:78,height:78,child:Stack(fit:StackFit.expand,children:[CircularProgressIndicator(value:overall,strokeWidth:8,backgroundColor:AppColors.blueSoft,color:AppColors.blue),Center(child:Text('${(overall*100).round()}%',style:const TextStyle(fontWeight:FontWeight.w900)))])),const SizedBox(width:18),Expanded(child:Text('${active.length} active habits\n$total total completions\n$best best streak\n${todos.where((x)=>x['done']!=true).length} open tasks\nAverage mood: ${avg==0?'—':'${avg.toStringAsFixed(1)}/5'}',style:const TextStyle(color:AppColors.muted,height:1.5)))]))),Section(title:'Last 7 days'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:days.map((d){final n=active.where((h)=>h.isDone(d)).length;final height=active.isEmpty?8.0:(80.0*n/active.length).clamp(8.0,80.0).toDouble();return Expanded(child:Column(children:[Text('$n',style:const TextStyle(fontSize:11)),const SizedBox(height:4),Container(height:height,margin:const EdgeInsets.symmetric(horizontal:4),decoration:BoxDecoration(color:AppColors.blue,borderRadius:BorderRadius.circular(8))),const SizedBox(height:4),Text(DateFormat('E').format(d).substring(0,1),style:const TextStyle(color:AppColors.muted))]));}).toList()))),Section(title:'This month'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[StatMini(label:'Completed',value:'$monthDone'),StatMini(label:'Possible',value:'${active.fold<int>(0,(s,h)=>s+h.scheduledInMonth(now))}'),StatMini(label:'Focus',value:formatMinutes(focus))]))),Section(title:'Habit performance'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Column(children:active.map((h){final r=h.completionRate(now).clamp(0.0,1.0).toDouble();return InkWell(onTap:()=>onOpen(h),child:Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[Expanded(child:Text(h.name,style:const TextStyle(fontWeight:FontWeight.w800))),Text('${(r*100).round()}%'),const SizedBox(width:8),SizedBox(width:65,child:LinearProgressIndicator(value:r))])));}).toList()))),Section(title:'Activity heatmap'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Wrap(spacing:4,runSpacing:4,children:List.generate(monthDays,(i){final d=DateTime(now.year,now.month,i+1);final n=active.where((h)=>h.isDone(d)).length;return Tooltip(message:'${DateFormat('d MMM').format(d)} · $n done',child:Container(width:18,height:18,decoration:BoxDecoration(color:n==0?AppColors.bg:Color.lerp(AppColors.blueSoft,AppColors.blue,n.clamp(1,active.length==0?1:active.length)/ (active.isEmpty?1:active.length)),borderRadius:BorderRadius.circular(4))));}))),Section(title:'Weekly review'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Best streak: $best days'),Text('Total completions: $total'),Text('Average mood: ${avg==0?'no entries':'${avg.toStringAsFixed(1)}/5'}'),Text('Focus time: ${formatMinutes(focus)}'),const SizedBox(height:8),Text(active.isEmpty?'Create a habit to start your review.':reviewText(active,now),style:const TextStyle(color:AppColors.muted))])))]));}
}

class StatMini extends StatelessWidget {final String label,value;const StatMini({super.key,required this.label,required this.value});@override Widget build(BuildContext context)=>Column(children:[Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(color:AppColors.muted))]);}

class Todos extends StatelessWidget {final List<Map<String,dynamic>> todos;final VoidCallback onAdd;final Future<void> Function(int) onEdit,onToggle;const Todos({super.key,required this.todos,required this.onAdd,required this.onEdit,required this.onToggle});
  @override Widget build(BuildContext context){final done=todos.where((x)=>x['done']==true).length;final open=todos.where((x)=>x['done']!=true).toList();final completed=todos.where((x)=>x['done']==true).toList();return Column(children:[Header(title:'To-Do',subtitle:'$done completed · ${todos.length-done} remaining',trailing:IconButton(onPressed:onAdd,icon:const Icon(Icons.add))),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Column(children:[LinearProgressIndicator(value:todos.isEmpty?0:done/todos.length,minHeight:8,backgroundColor:AppColors.blueSoft),const SizedBox(height:10),Text(todos.isEmpty?'No tasks yet':'$done of ${todos.length} tasks complete')]))),Expanded(child:todos.isEmpty?const Center(child:Text('Tap + to create a task.',style:TextStyle(color:AppColors.muted))):ListView(padding:const EdgeInsets.all(20),children:[if(open.isNotEmpty) ...[const Text('Open',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),...todos.asMap().entries.where((e)=>e.value['done']!=true).map((e)=>TodoTile(data:e.value,onTap:()=>onEdit(e.key),onToggle:()=>onToggle(e.key)))],if(completed.isNotEmpty) ...[const SizedBox(height:18),const Text('Completed',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),...todos.asMap().entries.where((e)=>e.value['done']==true).map((e)=>TodoTile(data:e.value,onTap:()=>onEdit(e.key),onToggle:()=>onToggle(e.key)))]]))]);}
}
class TodoTile extends StatelessWidget {final Map<String,dynamic> data;final VoidCallback onTap,onToggle;const TodoTile({super.key,required this.data,required this.onTap,required this.onToggle});@override Widget build(BuildContext context){final d=data['due'];final due=d==null||d==''?null:DateTime.tryParse('$d');final overdue=due!=null&&due.isBefore(DateTime.now())&&data['done']!=true;return Card(child:ListTile(onTap:onTap,leading:Checkbox(value:data['done']==true,onChanged:(_)=>onToggle()),title:Text('${data['title']}',style:TextStyle(fontWeight:FontWeight.w800,decoration:data['done']==true?TextDecoration.lineThrough:null)),subtitle:Text('${data['category']??'General'} · ${priorityName((data['priority'] as num?)?.toInt()??1)}${due==null?'':' · ${overdue?'Overdue · ':''}${DateFormat('d MMM').format(due)}'}',style:TextStyle(color:overdue?AppColors.red:null)),trailing:const Icon(Icons.chevron_right)));}}

class Profile extends StatelessWidget {final List<Habit> habits;final VoidCallback onPin,onTimer,onTemplates;const Profile({super.key,required this.habits,required this.onPin,required this.onTimer,required this.onTemplates});
  @override Widget build(BuildContext context){final total=habits.fold<int>(0,(s,h)=>s+h.totalCompletions());final best=habits.fold<int>(0,(m,h)=>h.bestStreak()>m?h.bestStreak():m);final achievements=achievementCount(habits);return SingleChildScrollView(padding:const EdgeInsets.only(bottom:25),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Header(title:'Profile',subtitle:'Your private offline habit space'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(children:[const CircleAvatar(radius:34,backgroundColor:Color(0xFF102A43),child:Icon(Icons.person,color:Colors.white)),const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${habits.length} habits',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text('$total completions · $best best streak',style:const TextStyle(color:AppColors.muted))]))])),Section(title:'Achievements'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(children:[const Icon(Icons.emoji_events_outlined,color:AppColors.orange,size:34),const SizedBox(width:12),Text('$achievements badges unlocked',style:const TextStyle(fontWeight:FontWeight.w900)),const Spacer(),TextButton(onPressed:()=>showAchievements(context,habits),child:const Text('View'))]))),Section(title:'Tools'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Column(children:[ListTile(onTap:onTemplates,leading:const Icon(Icons.auto_awesome_outlined,color:AppColors.blue),title:const Text('Habit templates'),subtitle:const Text('Build a routine quickly'),trailing:const Icon(Icons.chevron_right)),ListTile(onTap:onTimer,leading:const Icon(Icons.timer_outlined,color:AppColors.blue),title:const Text('Focus timer'),subtitle:const Text('Track focused time'),trailing:const Icon(Icons.chevron_right)),ListTile(onTap:onPin,leading:const Icon(Icons.lock_outline,color:AppColors.blue),title:const Text('App lock'),subtitle:const Text('Set or remove local PIN'),trailing:const Icon(Icons.chevron_right)),const ListTile(leading:Icon(Icons.wifi_off_outlined,color:AppColors.blue),title:Text('Offline first'),subtitle:Text('Data stays on this device'))])),Section(title:'About'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:const Text('Simple, private habit tracking with local storage. No account or cloud service is required.',style:TextStyle(color:AppColors.muted,height:1.5)) ))]));}
}

class HabitDetail extends StatefulWidget {final Habit habit;final Future<void> Function() onChanged;const HabitDetail({super.key,required this.habit,required this.onChanged});@override State<HabitDetail> createState()=>_HabitDetailState();}
class _HabitDetailState extends State<HabitDetail>{late DateTime month;final measurement=TextEditingController();
  @override void initState(){super.initState();month=DateTime.now();}
  @override void dispose(){measurement.dispose();super.dispose();}
  Future<void> setDone(DateTime d)async{setState(()=>widget.habit.setDone(d,!widget.habit.isDone(d)));await widget.onChanged();}
  Future<void> addMeasurement(DateTime d)async{final v=double.tryParse(measurement.text.trim());if(v==null)return;setState(()=>widget.habit.measurements[Habit.key(d)]=v);measurement.clear();await widget.onChanged();}
  @override Widget build(BuildContext context){final h=widget.habit;final days=DateTime(month.year,month.month+1,0).day;final rate=h.completionRate(month).clamp(0.0,1.0).toDouble();final measurements=h.measurements.entries.toList()..sort((a,b)=>b.key.compareTo(a.key));return Scaffold(appBar:AppBar(title:Text(h.name),actions:[IconButton(onPressed:()=>showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:Colors.white,builder:(_)=>HabitInfoSheet(habit:h)),icon:const Icon(Icons.info_outline))]),body:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CardBox(child:Row(children:[SizedBox(width:82,height:82,child:Stack(fit:StackFit.expand,children:[CircularProgressIndicator(value:rate,strokeWidth:8,backgroundColor:AppColors.blueSoft,color:AppColors.blue),Center(child:Text('${(rate*100).round()}%'))])),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('🔥 ${h.currentStreak()} day streak',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text('Best: ${h.bestStreak()} days',style:const TextStyle(color:AppColors.muted)),Text('${h.totalCompletions()} total completions',style:const TextStyle(color:AppColors.muted))]))])),Section(title:'Calendar'),CardBox(child:Column(children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[IconButton(onPressed:()=>setState(()=>month=DateTime(month.year,month.month-1,1)),icon:const Icon(Icons.chevron_left)),Text(DateFormat('MMMM yyyy').format(month),style:const TextStyle(fontWeight:FontWeight.w900)),IconButton(onPressed:()=>setState(()=>month=DateTime(month.year,month.month+1,1)),icon:const Icon(Icons.chevron_right))]),GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:days,itemBuilder:(_,i){final d=DateTime(month.year,month.month,i+1);final scheduled=h.isScheduled(d);final done=h.isDone(d);return InkWell(onTap:scheduled?()=>setDone(d):null,child:Container(margin:const EdgeInsets.all(3),decoration:BoxDecoration(color:done?AppColors.blue:(scheduled?Colors.white:AppColors.bg),borderRadius:BorderRadius.circular(9),border:Border.all(color:scheduled?AppColors.border:Colors.transparent)),child:Center(child:Text('${i+1}',style:TextStyle(fontWeight:FontWeight.w800,color:done?Colors.white:scheduled?AppColors.text:AppColors.muted)))));},gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7))])),Section(title:'Measurements',actionText:'Add value',action:()=>addMeasurementDialog(context,widget.habit,()=>setState((){}),widget.onChanged)),CardBox(child:measurements.isEmpty?const Text('No measurements yet.',style:TextStyle(color:AppColors.muted)):Column(children:measurements.take(12).map((e)=>ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.show_chart,color:AppColors.blue),title:Text('${e.value} ${h.unit}'),subtitle:Text(e.key),trailing:Text(DateFormat('d MMM').format(DateTime.parse(e.key)))).toList())),Section(title:'Journal / notes'),CardBox(child:Text(h.notes.isEmpty?'No notes yet.':h.notes,style:const TextStyle(height:1.5))),const SizedBox(height:20),FilledButton.icon(onPressed:()=>setDone(DateTime.now()),icon:Icon(h.isDone(DateTime.now())?Icons.undo:Icons.check),label:Text(h.isDone(DateTime.now())?'Mark today incomplete':'Mark today complete'),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52))) ])));}
}

class HabitInfoSheet extends StatelessWidget {final Habit habit;const HabitInfoSheet({super.key,required this.habit});@override Widget build(BuildContext context)=>SafeArea(child:Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(habit.name,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text('Goal: ${habit.goal} ${habit.unit}'),Text('Frequency: ${habit.frequency}'),Text('Category: ${habit.category}'),if(habit.tags.isNotEmpty)Text('Tags: ${habit.tags.join(', ')}'),if(habit.notes.isNotEmpty)Text('Notes: ${habit.notes}'),const SizedBox(height:16)])));
}

class HabitEditResult {final String name,category,unit,frequency,notes,icon;final int goal;final List<int> weekdays;final bool pinned,delete,active;final List<String> tags;const HabitEditResult({required this.name,required this.category,required this.goal,required this.unit,required this.frequency,required this.weekdays,required this.pinned,required this.tags,required this.notes,required this.icon,required this.active,this.delete=false});Habit toHabit()=>Habit(id:DateTime.now().microsecondsSinceEpoch.toString(),name:name,category:category,goal:goal,unit:unit,frequency:frequency,weekdays:weekdays,pinned:pinned,tags:tags,notes:notes,icon:icon,active:active);}

class HabitEditor extends StatefulWidget {final Habit? habit;const HabitEditor({super.key,this.habit});@override State<HabitEditor> createState()=>_HabitEditorState();}
class _HabitEditorState extends State<HabitEditor>{late final TextEditingController name,goal,tags,notes;late String category,unit,frequency,icon;late List<int> weekdays;late bool pinned,active;
  @override void initState(){super.initState();final h=widget.habit;name=TextEditingController(text:h?.name??'');goal=TextEditingController(text:'${h?.goal??1}');tags=TextEditingController(text:h?.tags.join(', ')??'');notes=TextEditingController(text:h?.notes??'');const cats=['Personal','Health','Mind & Body','Productivity','Learning','Goals','Finance','Routine','Other'];category=cats.contains(h?.category)?h!.category:'Personal';unit=h?.unit??'times';frequency=h?.frequency??'Every day';weekdays=List<int>.from(h?.weekdays??[1,2,3,4,5,6,7]);pinned=h?.pinned??false;active=h?.active??true;icon=h?.icon??'check_circle';}
  @override void dispose(){name.dispose();goal.dispose();tags.dispose();notes.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(20,10,20,MediaQuery.of(context).viewInsets.bottom+20),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.habit==null?'Create habit':'Edit habit',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:14),TextField(controller:name,autofocus:true,decoration:const InputDecoration(labelText:'Habit name')),const SizedBox(height:10),Row(children:[Expanded(child:DropdownButtonFormField<String>(value:category,items:['Personal','Health','Mind & Body','Productivity','Learning','Goals','Finance','Routine','Other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>category=v!))),const SizedBox(width:10),Expanded(child:DropdownButtonFormField<String>(value:unit,items:['times','minutes','hours','pages','litres','km','steps','reps','kg'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>unit=v!)))]),const SizedBox(height:10),TextField(controller:goal,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Daily target')),const SizedBox(height:10),const Text('Frequency',style:TextStyle(fontWeight:FontWeight.w800)),Wrap(spacing:7,children:['Every day','Weekdays','Custom'].map((x)=>ChoiceChip(label:Text(x),selected:frequency==x,onSelected:(_)=>setState(()=>frequency=x))).toList()),if(frequency=='Custom')Wrap(spacing:4,children:List.generate(7,(i){final d=i+1;return FilterChip(label:Text(['M','T','W','T','F','S','S'][i]),selected:weekdays.contains(d),onSelected:(v)=>setState((){if(v){if(!weekdays.contains(d))weekdays.add(d);}else{weekdays.remove(d);}}));})),const SizedBox(height:8),TextField(controller:tags,decoration:const InputDecoration(labelText:'Tags, comma separated')),const SizedBox(height:8),TextField(controller:notes,maxLines:3,decoration:const InputDecoration(labelText:'Journal / notes')),SwitchListTile(contentPadding:EdgeInsets.zero,value:pinned,onChanged:(v)=>setState(()=>pinned=v),title:const Text('Pin to top')),SwitchListTile(contentPadding:EdgeInsets.zero,value:active,onChanged:(v)=>setState(()=>active=v),title:const Text('Active habit')),const SizedBox(height:4),const Text('Icon',style:TextStyle(fontWeight:FontWeight.w800)),Wrap(spacing:4,children:{'check_circle':Icons.check_circle,'fitness_center':Icons.fitness_center,'menu_book':Icons.menu_book,'water_drop':Icons.water_drop,'self_improvement':Icons.self_improvement,'bedtime':Icons.bedtime,'work':Icons.work,'directions_walk':Icons.directions_walk}.entries.map((e)=>ChoiceChip(label:Icon(e.value,size:18),selected:icon==e.key,onSelected:(_)=>setState(()=>icon=e.key))).toList()),const SizedBox(height:12),if(widget.habit!=null)TextButton.icon(onPressed:()=>Navigator.pop(context,const HabitEditResult(name:'',category:'',goal:1,unit:'times',frequency:'Every day',weekdays:[1,2,3,4,5,6,7],pinned:false,tags:[],notes:'',icon:'check_circle',active:false,delete:true)),icon:const Icon(Icons.delete_outline),label:const Text('Delete habit')),FilledButton(onPressed:()=>Navigator.pop(context,HabitEditResult(name:name.text.trim(),category:category,goal:(int.tryParse(goal.text)??1).clamp(1,1000000),unit:unit,frequency:frequency,weekdays:weekdays.isEmpty?[1,2,3,4,5,6,7]:weekdays,pinned:pinned,tags:tags.text.split(',').map((x)=>x.trim()).where((x)=>x.isNotEmpty).toList(),notes:notes.text.trim(),icon:icon,active:active)),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)),child:Text(widget.habit==null?'Create habit':'Save changes'))]))));
}

class TodoResult {final String title,category;final int priority;final DateTime? due;final bool delete;const TodoResult({required this.title,required this.category,required this.priority,this.due,this.delete=false});}
class TodoEditor extends StatefulWidget {final Map<String,dynamic>? initial;const TodoEditor({super.key,this.initial});@override State<TodoEditor> createState()=>_TodoEditorState();}
class _TodoEditorState extends State<TodoEditor>{late final TextEditingController title;late String category;late int priority;DateTime? due;@override void initState(){super.initState();final x=widget.initial;title=TextEditingController(text:'${x?['title']??''}');category='${x?['category']??'General'}';priority=(x?['priority'] as num?)?.toInt()??1;final d='${x?['due']??''}';due=d.isEmpty?null:DateTime.tryParse(d);}@override void dispose(){title.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.initial==null?'New task':'Edit task'),content:SingleChildScrollView(child:Column(children:[TextField(controller:title,autofocus:true,decoration:const InputDecoration(labelText:'Task')),const SizedBox(height:8),DropdownButtonFormField<String>(value:['General','College','Work','Personal'].contains(category)?category:'General',items:['General','College','Work','Personal'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>category=v!)),const SizedBox(height:8),DropdownButtonFormField<int>(value:priority.clamp(1,3).toInt(),items:const[DropdownMenuItem(value:1,child:Text('Low')),DropdownMenuItem(value:2,child:Text('Medium')),DropdownMenuItem(value:3,child:Text('High'))],onChanged:(v)=>setState(()=>priority=v??1)),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.event_outlined),title:Text(due==null?'No due date':'Due ${DateFormat('d MMM yyyy').format(due!)}'),onTap:()async{final picked=await showDatePicker(context:context,initialDate:due??DateTime.now(),firstDate:DateTime(2020),lastDate:DateTime(2100));if(picked!=null&&mounted)setState(()=>due=picked);})])),actions:[if(widget.initial!=null)TextButton(onPressed:()=>Navigator.pop(context,const TodoResult(title:'',category:'',priority:1,delete:true)),child:const Text('Delete')),TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,TodoResult(title:title.text,category:category,priority:priority,due:due)),child:const Text('Save'))]);}

class FocusTimer extends StatefulWidget {final StorageService storage;final DateTime date;final int initial;final ValueChanged<int> onSaved;const FocusTimer({super.key,required this.storage,required this.date,required this.initial,required this.onSaved});@override State<FocusTimer> createState()=>_FocusTimerState();}
class _FocusTimerState extends State<FocusTimer>{late int seconds;Timer? timer;bool running=false;@override void initState(){super.initState();seconds=widget.initial;}@override void dispose(){timer?.cancel();super.dispose();}void toggle(){if(running){timer?.cancel();setState(()=>running=false);}else{timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>seconds++);});setState(()=>running=true);}}Future<void> save()async{final data=await widget.storage.loadTimerSeconds();data[Habit.key(widget.date)]=seconds;await widget.storage.saveTimerSeconds(data);widget.onSaved(seconds);if(mounted)Navigator.pop(context);}String fmt(int s)=>'${(s~/3600).toString().padLeft(2,'0')}:${((s%3600)~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}';@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Focus Timer')),body:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.timer_outlined,size:60,color:AppColors.blue),const SizedBox(height:20),Text(fmt(seconds),style:const TextStyle(fontSize:48,fontWeight:FontWeight.w900)),const SizedBox(height:20),FilledButton.icon(onPressed:toggle,icon:Icon(running?Icons.pause:Icons.play_arrow),label:Text(running?'Pause':'Start')),const SizedBox(height:10),OutlinedButton(onPressed:save,child:const Text('Save today’s focus time'))])));
}

class PinDialog extends StatefulWidget {const PinDialog({super.key});@override State<PinDialog> createState()=>_PinDialogState();}
class _PinDialogState extends State<PinDialog>{final c=TextEditingController();@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:const Text('App lock'),content:TextField(controller:c,obscureText:true,keyboardType:TextInputType.number,maxLength:6,decoration:const InputDecoration(labelText:'4–6 digit PIN')),actions:[TextButton(onPressed:()=>Navigator.pop(context,''),child:const Text('Remove')),FilledButton(onPressed:()=>c.text.length>=4?Navigator.pop(context,c.text):null,child:const Text('Save'))]);}
class LockScreen extends StatelessWidget {final String pin;final VoidCallback onUnlock;const LockScreen({super.key,required this.pin,required this.onUnlock});@override Widget build(BuildContext context)=>_LockBody(pin:pin,onUnlock:onUnlock);}
class _LockBody extends StatefulWidget {final String pin;final VoidCallback onUnlock;const _LockBody({required this.pin,required this.onUnlock});@override State<_LockBody> createState()=>_LockBodyState();}
class _LockBodyState extends State<_LockBody>{final c=TextEditingController();String error='';@override void dispose(){c.dispose();super.dispose();}void unlock(){if(c.text==widget.pin)widget.onUnlock();else setState(()=>error='Incorrect PIN');}@override Widget build(BuildContext context)=>Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(30),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.lock_outline,size:64,color:AppColors.blue),const SizedBox(height:18),const Text('Habit Tracker locked',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:15),TextField(controller:c,obscureText:true,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'PIN',errorText:error.isEmpty?null:error)),const SizedBox(height:15),FilledButton(onPressed:unlock,child:const Text('Unlock'))]))));}

class Onboarding extends StatefulWidget {final VoidCallback onDone,onCreate;const Onboarding({super.key,required this.onDone,required this.onCreate});@override State<Onboarding> createState()=>_OnboardingState();}
class _OnboardingState extends State<Onboarding>{int page=0;final items=[('Build better days','Track habits, routines and goals in one simple place.',Icons.auto_awesome),('See your progress','Streaks, calendars, analytics, measurements and weekly reviews.',Icons.insights),('Private by default','Your data is stored locally on this device. No account required.',Icons.lock_outline)];@override Widget build(BuildContext context){final x=items[page];return Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.all(28),child:Column(children:[const Spacer(),CircleAvatar(radius:58,backgroundColor:AppColors.blueSoft,child:Icon(Icons.check_circle,size:70,color:AppColors.blue)),const SizedBox(height:38),Text(x.$1,textAlign:TextAlign.center,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:15),Text(x.$2,textAlign:TextAlign.center,style:const TextStyle(fontSize:16,color:AppColors.muted,height:1.5)),const SizedBox(height:25),Icon(x.$3,size:42,color:AppColors.blue),const Spacer(),Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(items.length,(i)=>Container(width:i==page?26:8,height:8,margin:const EdgeInsets.all(4),decoration:BoxDecoration(color:i==page?AppColors.blue:AppColors.border,borderRadius:BorderRadius.circular(8))))),const SizedBox(height:20),SizedBox(width:double.infinity,child:FilledButton(onPressed:()async{if(page<items.length-1)setState(()=>page++);else await showFirstHabit(context,onDone,onCreate);},style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)),child:Text(page<items.length-1?'Next':'Get started'))),TextButton(onPressed:onDone,child:const Text('Skip'))]))));}}

class TemplateSheet extends StatelessWidget {const TemplateSheet({super.key});static const templates={'Morning routine':['Wake up early','Drink Water','Exercise','Meditate','Plan Tomorrow'],'Study routine':['Reading / Learning','Day Planning','Project Work','Goal Journaling'],'Healthy day':['Drink Water','Gym','10k Steps','Cold Shower','Sleep on Time']};@override Widget build(BuildContext context)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Habit templates',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:10),...templates.entries.map((e)=>ListTile(onTap:()=>Navigator.pop(context,e.value),leading:const Icon(Icons.auto_awesome,color:AppColors.blue),title:Text(e.key,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${e.value.length} habits'),trailing:const Icon(Icons.chevron_right)))])));
}

Future<void> showFirstHabit(BuildContext context,VoidCallback done,VoidCallback create)async{final choice=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Ready to start?'),content:const Text('Create your first habit now, or explore the app first.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Explore')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Create habit'))]));if(choice==true)await create();done();}

Future<void> addMeasurementDialog(BuildContext context,Habit habit,VoidCallback refresh,Future<void> Function() saved)async{final c=TextEditingController();DateTime day=DateTime.now();await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setState)=>AlertDialog(title:Text('Add ${habit.unit}'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'Value (${habit.unit})')),const SizedBox(height:8),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.event),title:Text('Date'),subtitle:Text(DateFormat('d MMM yyyy').format(day)),onTap:()async{final d=await showDatePicker(context:ctx,initialDate:day,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null)setState(()=>day=d);})]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:(){final v=double.tryParse(c.text);if(v!=null){habit.measurements[Habit.key(day)]=v;refresh();saved();Navigator.pop(ctx);}},child:const Text('Save'))])));c.dispose();}

void showAchievements(BuildContext context,List<Habit> habits){showModalBottomSheet(context:context,backgroundColor:Colors.white,isScrollControlled:true,builder:(_)=>Achievements(habits:habits));}
class Achievements extends StatelessWidget {final List<Habit> habits;const Achievements({super.key,required this.habits});@override Widget build(BuildContext context){final total=habits.fold<int>(0,(s,h)=>s+h.totalCompletions());final best=habits.fold<int>(0,(m,h)=>h.bestStreak()>m?h.bestStreak():m);final list=[('🌱','First habit',habits.isNotEmpty),('🔥','7 day streak',best>=7),('🏆','30 day streak',best>=30),('💯','100 completions',total>=100),('📅','Perfect week',hasPerfectWeek(habits)),('⭐','5 habits',habits.length>=5),('🚀','10 habits',habits.length>=10)];return SafeArea(child:Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Achievements',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:12),...list.map((x)=>ListTile(leading:Text(x.$1,style:const TextStyle(fontSize:26)),title:Text(x.$2,style:const TextStyle(fontWeight:FontWeight.w800)),trailing:Icon(x.$3?Icons.check_circle:Icons.lock_outline,color:x.$3?AppColors.green:AppColors.muted)))])));}}

int achievementCount(List<Habit> habits){final total=habits.fold<int>(0,(s,h)=>s+h.totalCompletions());final best=habits.fold<int>(0,(m,h)=>h.bestStreak()>m?h.bestStreak():m);return [habits.isNotEmpty,best>=7,best>=30,total>=100,hasPerfectWeek(habits),habits.length>=5,habits.length>=10].where((x)=>x).length;}
bool hasPerfectWeek(List<Habit> habits){final active=habits.where((h)=>h.active).toList();if(active.isEmpty)return false;final n=DateTime.now();for(var i=0;i<7;i++){final d=n.subtract(Duration(days=i));if(active.any((h)=>h.isScheduled(d)&&!h.isDone(d)))return false;}return true;}
String reviewText(List<Habit> habits,DateTime now){final best=habits.reduce((a,b)=>a.completionRate(now)>b.completionRate(now)?a:b);return '${best.name} is currently your strongest habit. Keep reviewing missed days and notes each week.';}
String formatMinutes(int seconds){final m=seconds~/60;final h=m~/60;final min=m%60;return h>0?'${h}h ${min}m':'${min}m';}
String priorityName(int v)=>v==3?'High':v==2?'Medium':'Low';
Future<bool> confirmDialog(BuildContext context,String title,String message)async=>await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:Text(message),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Delete'))]))??false;
