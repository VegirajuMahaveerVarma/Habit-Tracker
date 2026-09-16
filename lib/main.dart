import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/habit.dart';
import 'services/storage_service.dart';

void main() => runApp(const HabitApp());

class AppColors {
  static const blue = Color(0xFF1769FF);
  static const soft = Color(0xFFEAF1FF);
  static const bg = Color(0xFFF5F7FB);
  static const text = Color(0xFF142033);
  static const muted = Color(0xFF718096);
  static const border = Color(0xFFE6EAF0);
  static const green = Color(0xFF16A36A);
}

class HabitApp extends StatelessWidget {
  const HabitApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Habit Tracker',
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue), scaffoldBackgroundColor: AppColors.bg),
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
  int tab = 0;
  DateTime selected = DateTime.now();
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    habits = await store.loadHabits();
    todos = await store.loadTodos();
    moods = await store.loadMoods();
    focus = await store.loadTimerSeconds();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _saveHabits() => store.saveHabits(habits);

  Future<void> _addHabit() async {
    final r = await showModalBottomSheet<HabitEdit>(context: context, isScrollControlled: true, backgroundColor: Colors.white, builder: (_) => const HabitEditor());
    if (!mounted || r == null || r.name.trim().isEmpty) return;
    setState(() => habits.add(r.toHabit()));
    await _saveHabits();
  }

  Future<void> _editHabit(Habit h) async {
    final r = await showModalBottomSheet<HabitEdit>(context: context, isScrollControlled: true, backgroundColor: Colors.white, builder: (_) => HabitEditor(habit: h));
    if (!mounted || r == null) return;
    if (r.delete) {
      setState(() => habits.removeWhere((x) => x.id == h.id));
    } else {
      h.name = r.name; h.category = r.category; h.goal = r.goal; h.unit = r.unit; h.frequency = r.frequency; h.weekdays = r.weekdays; h.pinned = r.pinned; h.active = r.active; h.tags = r.tags; h.notes = r.notes;
      setState(() {});
    }
    await _saveHabits();
  }

  Future<void> _toggle(Habit h, DateTime d) async {
    setState(() => h.setDone(d, !h.isDone(d)));
    await _saveHabits();
  }

  Future<void> _open(Habit h) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => HabitDetail(habit: h, onChanged: _saveHabits)));
    if (mounted) setState(() {});
  }

  Future<void> _addTodo() async {
    final r = await showDialog<TodoEdit>(context: context, builder: (_) => const TodoEditor());
    if (!mounted || r == null || r.title.trim().isEmpty) return;
    setState(() => todos.add({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'title': r.title.trim(), 'done': false, 'priority': r.priority, 'category': r.category, 'due': r.due == null ? '' : Habit.key(r.due!)}));
    await store.saveTodos(todos);
  }

  Future<void> _toggleTodo(int i) async { setState(() => todos[i]['done'] = todos[i]['done'] != true); await store.saveTodos(todos); }

  Future<void> _timer() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => FocusTimer(storage: store, date: selected, initial: focus[Habit.key(selected)] ?? 0, onSaved: (v) => setState(() => focus[Habit.key(selected)] = v))));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pages = [
      Dashboard(habits: habits, todos: todos, date: selected, moods: moods, onAdd: _addHabit, onToggle: _toggle, onOpen: _open, onEdit: _editHabit, onMood: (v) async { setState(() => moods[Habit.key(selected)] = v); await store.saveMoods(moods); }, onTimer: _timer),
      Daily(habits: habits, date: selected, onDate: (d) => setState(() => selected = d), onToggle: _toggle, onOpen: _open, onEdit: _editHabit, onAdd: _addHabit),
      Stats(habits: habits, moods: moods, todos: todos, focus: focus, onOpen: _open),
      TodoPage(todos: todos, onAdd: _addTodo, onToggle: _toggleTodo),
      Profile(habits: habits, onTimer: _timer),
    ];
    return Scaffold(body: SafeArea(child: IndexedStack(index: tab, children: pages)), bottomNavigationBar: NavigationBar(selectedIndex: tab, indicatorColor: AppColors.soft, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Habits'),
      NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Stats'),
      NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'To-Do'),
      NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
    ]));
  }
}

class PageHeader extends StatelessWidget {
  final String title; final String subtitle; final Widget? action;
  const PageHeader({super.key, required this.title, required this.subtitle, this.action});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 14), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.text)), Text(subtitle, style: const TextStyle(color: AppColors.muted))])), if (action != null) action!]));
}

class CardBox extends StatelessWidget {
  final Widget child;
  const CardBox({super.key, required this.child});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: child);
}

class SectionTitle extends StatelessWidget {
  final String title; final VoidCallback? onAdd; final String label;
  const SectionTitle({super.key, required this.title, this.onAdd, this.label = 'Add'});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 10), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))), if (onAdd != null) TextButton(onPressed: onAdd, child: Text(label))]));
}

class Dashboard extends StatefulWidget {
  final List<Habit> habits; final List<Map<String,dynamic>> todos; final Map<String,int> moods; final DateTime date;
  final VoidCallback onAdd,onTimer; final Future<void> Function(Habit,DateTime) onToggle; final Future<void> Function(Habit) onOpen,onEdit; final Future<void> Function(int) onMood;
  const Dashboard({super.key,required this.habits,required this.todos,required this.moods,required this.date,required this.onAdd,required this.onTimer,required this.onToggle,required this.onOpen,required this.onEdit,required this.onMood});
  @override State<Dashboard> createState()=>_DashboardState();
}
class _DashboardState extends State<Dashboard> {
  String search=''; String filter='All';
  @override Widget build(BuildContext context) {
    final active=widget.habits.where((h)=>h.active).toList();
    final list=active.where((h){final q=search.toLowerCase();final matches=q.isEmpty||h.name.toLowerCase().contains(q)||h.category.toLowerCase().contains(q)||h.tags.any((t)=>t.toLowerCase().contains(q));final f=filter=='All'||(filter=='Pinned'&&h.pinned)||(filter=='Completed'&&h.isDone(widget.date))||(filter=='Missed'&&h.isScheduled(widget.date)&&!h.isDone(widget.date));return matches&&f;}).toList()..sort((a,b)=>a.pinned==b.pinned?0:(a.pinned?-1:1));
    final done=active.where((h)=>h.isDone(widget.date)).length; final progress=active.isEmpty?0.0:done/active.length;
    return SingleChildScrollView(padding:const EdgeInsets.only(bottom:25),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      PageHeader(title:'Good day 👋',subtitle:DateFormat('EEEE, d MMMM').format(widget.date),action:IconButton(onPressed:widget.onTimer,icon:const Icon(Icons.timer_outlined))),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search habits or tags'))),
      SizedBox(height:48,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:20),children:['All','Pinned','Completed','Missed'].map((x)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(x),selected:filter==x,onSelected:(_)=>setState(()=>filter=x)))).toList())),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(children:[SizedBox(width:82,height:82,child:Stack(fit:StackFit.expand,children:[CircularProgressIndicator(value:progress,strokeWidth:9,backgroundColor:AppColors.soft,color:AppColors.blue),Center(child:Text('${(progress*100).round()}%',style:const TextStyle(fontWeight:FontWeight.w900)))])),const SizedBox(width:18),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Today’s progress',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text('$done of ${active.length} habits completed',style:const TextStyle(color:AppColors.muted)),const SizedBox(height:8),LinearProgressIndicator(value:progress,backgroundColor:AppColors.soft)]))]))),
      SectionTitle(title:'Today’s habits',onAdd:widget.onAdd,label:'＋ Add'),
      if(list.isEmpty) const Padding(padding:EdgeInsets.all(30),child:Center(child:Text('No matching habits.',style:TextStyle(color:AppColors.muted)))) else ...list.map((h)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),child:HabitTile(habit:h,date:widget.date,onToggle:()=>widget.onToggle(h,widget.date),onOpen:()=>widget.onOpen(h),onEdit:()=>widget.onEdit(h)))),
      SectionTitle(title:'How are you feeling?'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:List.generate(5,(i){final v=i+1;return InkWell(onTap:()=>widget.onMood(v),child:Text(['😫','😕','😐','🙂','😄'][i],style:TextStyle(fontSize:28,decoration:widget.moods[Habit.key(widget.date)]==v?TextDecoration.underline:null)));}))))
    ]));
  }
}

class HabitTile extends StatelessWidget {
  final Habit habit; final DateTime date; final VoidCallback onToggle,onOpen,onEdit;
  const HabitTile({super.key,required this.habit,required this.date,required this.onToggle,required this.onOpen,required this.onEdit});
  @override Widget build(BuildContext context){final done=habit.isDone(date);return GestureDetector(onTap:onOpen,onLongPress:onEdit,child:CardBox(child:Row(children:[GestureDetector(onTap:onToggle,child:CircleAvatar(radius:21,backgroundColor:done?AppColors.blue:AppColors.soft,child:Icon(done?Icons.check:Icons.circle_outlined,color:done?Colors.white:AppColors.blue))),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(habit.name,style:TextStyle(fontWeight:FontWeight.w900,decoration:done?TextDecoration.lineThrough:null)),Text('${habit.category} · ${habit.goal} ${habit.unit} · 🔥 ${habit.currentStreak(date)}',style:const TextStyle(color:AppColors.muted,fontSize:12))]))])));}
}

class Daily extends StatelessWidget {
  final List<Habit> habits; final DateTime date; final ValueChanged<DateTime> onDate; final VoidCallback onAdd; final Future<void> Function(Habit,DateTime) onToggle; final Future<void> Function(Habit) onOpen,onEdit;
  const Daily({super.key,required this.habits,required this.date,required this.onDate,required this.onAdd,required this.onToggle,required this.onOpen,required this.onEdit});
  @override Widget build(BuildContext context){final days=DateTime(date.year,date.month+1,0).day;final active=habits.where((h)=>h.active&&h.isScheduled(date)).toList();final done=active.where((h)=>h.isDone(date)).length;return Column(children:[PageHeader(title:'Daily',subtitle:DateFormat('MMMM yyyy').format(date)),SizedBox(height:80,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:20),itemCount:days,separatorBuilder:(_,__)=>const SizedBox(width:7),itemBuilder:(_,i){final d=DateTime(date.year,date.month,i+1);final sel=Habit.key(d)==Habit.key(date);return InkWell(onTap:()=>onDate(d),child:Container(width:48,padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:sel?AppColors.blue:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:AppColors.border)),child:Column(children:[Text(DateFormat('E').format(d).substring(0,1),style:TextStyle(color:sel?Colors.white:AppColors.muted)),Text('${d.day}',style:TextStyle(fontWeight:FontWeight.w900,color:sel?Colors.white:AppColors.text))])));})),SectionTitle(title:'$done/${active.length} complete',onAdd:onAdd,label:'＋ Add'),Expanded(child:active.isEmpty?const Center(child:Text('No habits scheduled today.',style:TextStyle(color:AppColors.muted))):ListView(children:active.map((h)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),child:HabitTile(habit:h,date:date,onToggle:()=>onToggle(h,date),onOpen:()=>onOpen(h),onEdit:()=>onEdit(h)))).toList()))]);}
}

class Stats extends StatelessWidget {
  final List<Habit> habits; final Map<String,int> moods; final List<Map<String,dynamic>> todos; final Map<String,int> focus; final Future<void> Function(Habit) onOpen;
  const Stats({super.key,required this.habits,required this.moods,required this.todos,required this.focus,required this.onOpen});
  @override Widget build(BuildContext context){final now=DateTime.now();final active=habits.where((h)=>h.active).toList();var done=0,total=0,best=0;for(final h in active){done+=h.completedInMonth(now);total+=h.scheduledInMonth(now);if(h.bestStreak()>best)best=h.bestStreak();}final rate=total==0?0.0:done/total;return SingleChildScrollView(padding:const EdgeInsets.only(bottom:25),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const PageHeader(title:'Analytics',subtitle:'Your progress overview'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${(rate*100).round()}% monthly completion',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:8),LinearProgressIndicator(value:rate,minHeight:9,backgroundColor:AppColors.soft),const SizedBox(height:15),Text('$done completed · $total scheduled',style:const TextStyle(color:AppColors.muted)),Text('$best best streak · ${todos.where((x)=>x['done']!=true).length} open tasks',style:const TextStyle(color:AppColors.muted)),Text('Total completions: ${habits.fold<int>(0,(s,h)=>s+h.totalCompletions())}',style:const TextStyle(color:AppColors.muted))]))),SectionTitle(title:'Habit performance'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Column(children:active.map((h){final r=h.completionRate(now).clamp(0.0,1.0).toDouble();return ListTile(onTap:()=>onOpen(h),contentPadding:EdgeInsets.zero,title:Text(h.name),subtitle:LinearProgressIndicator(value:r,backgroundColor:AppColors.soft),trailing:Text('${(r*100).round()}%'));}).toList()))),SectionTitle(title:'Last 7 days'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:List.generate(7,(i){final d=DateTime(now.year,now.month,now.day-6+i);final n=active.where((h)=>h.isDone(d)).length;final height=active.isEmpty?8.0:(80*n/active.length).clamp(8.0,80.0).toDouble();return Expanded(child:Column(children:[Text('$n',style:const TextStyle(fontSize:11)),const SizedBox(height:4),Container(height:height,margin:const EdgeInsets.symmetric(horizontal:3),decoration:BoxDecoration(color:AppColors.blue,borderRadius:BorderRadius.circular(6))),const SizedBox(height:4),Text(DateFormat('E').format(d).substring(0,1),style:const TextStyle(color:AppColors.muted))]));}))))]));}
}

class TodoPage extends StatelessWidget {
  final List<Map<String,dynamic>> todos; final VoidCallback onAdd; final Future<void> Function(int) onToggle;
  const TodoPage({super.key,required this.todos,required this.onAdd,required this.onToggle});
  @override Widget build(BuildContext context){final done=todos.where((x)=>x['done']==true).length;return Column(children:[PageHeader(title:'To-Do',subtitle:'$done completed · ${todos.length-done} remaining',action:IconButton(onPressed:onAdd,icon:const Icon(Icons.add))),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Column(children:[LinearProgressIndicator(value:todos.isEmpty?0:done/todos.length,backgroundColor:AppColors.soft),const SizedBox(height:8),Text(todos.isEmpty?'No tasks yet':'$done of ${todos.length} complete')] ))),Expanded(child:todos.isEmpty?const Center(child:Text('Tap + to add a task.',style:TextStyle(color:AppColors.muted))):ListView(padding:const EdgeInsets.all(20),children:todos.asMap().entries.map((e){final x=e.value;return Card(child:ListTile(leading:Checkbox(value:x['done']==true,onChanged:(_)=>onToggle(e.key)),title:Text('${x['title']}',style:TextStyle(decoration:x['done']==true?TextDecoration.lineThrough:null,fontWeight:FontWeight.w800)),subtitle:Text('${x['category']??'General'} · ${priorityName((x['priority'] as num?)?.toInt()??1)}')));}).toList()))]);}
}

class Profile extends StatelessWidget {
  final List<Habit> habits; final VoidCallback onTimer;
  const Profile({super.key,required this.habits,required this.onTimer});
  @override Widget build(BuildContext context){final total=habits.fold<int>(0,(s,h)=>s+h.totalCompletions());final best=habits.fold<int>(0,(m,h)=>h.bestStreak()>m?h.bestStreak():m);return SingleChildScrollView(padding:const EdgeInsets.only(bottom:25),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const PageHeader(title:'Profile',subtitle:'Private offline habit tracking'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:CardBox(child:Row(children:[const CircleAvatar(radius:34,child:Icon(Icons.person)),const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${habits.length} habits',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text('$total completions · $best best streak',style:const TextStyle(color:AppColors.muted))]))]))),SectionTitle(title:'Tools'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Card(child:Column(children:[ListTile(onTap:onTimer,leading:const Icon(Icons.timer_outlined,color:AppColors.blue),title:const Text('Focus timer')),const ListTile(leading:Icon(Icons.wifi_off_outlined,color:AppColors.blue),title:Text('Offline first'),subtitle:Text('Your data stays on this device'))])))]));}
}

class HabitDetail extends StatefulWidget {
  final Habit habit; final Future<void> Function() onChanged;
  const HabitDetail({super.key,required this.habit,required this.onChanged});
  @override State<HabitDetail> createState()=>_HabitDetailState();
}

class _HabitDetailState extends State<HabitDetail> {
  late DateTime month;
  @override void initState(){super.initState();month=DateTime.now();}
  Future<void> toggle(DateTime day) async { setState(()=>widget.habit.setDone(day,!widget.habit.isDone(day))); await widget.onChanged(); }
  Future<void> addMeasurement() async { final value=await showDialog<double>(context:context,builder:(_)=>MeasurementDialog(unit:widget.habit.unit)); if(value==null)return; setState(()=>widget.habit.measurements[Habit.key(DateTime.now())]=value); await widget.onChanged(); }
  @override Widget build(BuildContext context){
    final h=widget.habit;
    final days=DateTime(month.year,month.month+1,0).day;
    final rate=h.completionRate(month).clamp(0.0,1.0).toDouble();
    final entries=h.measurements.entries.toList()..sort((a,b)=>b.key.compareTo(a.key));
    return Scaffold(
      appBar:AppBar(title:Text(h.name)),
      body:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        CardBox(child:Row(children:[SizedBox(width:80,height:80,child:CircularProgressIndicator(value:rate,strokeWidth:8,backgroundColor:AppColors.soft,color:AppColors.blue)),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('🔥 ${h.currentStreak()} day streak',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text('Best: ${h.bestStreak()} days',style:const TextStyle(color:AppColors.muted)),Text('${h.totalCompletions()} total completions',style:const TextStyle(color:AppColors.muted))]))])),
        SectionTitle(title:'Calendar'),
        CardBox(child:Column(children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[IconButton(onPressed:()=>setState(()=>month=DateTime(month.year,month.month-1,1)),icon:const Icon(Icons.chevron_left)),Text(DateFormat('MMMM yyyy').format(month),style:const TextStyle(fontWeight:FontWeight.w900)),IconButton(onPressed:()=>setState(()=>month=DateTime(month.year,month.month+1,1)),icon:const Icon(Icons.chevron_right))]),GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:days,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7),itemBuilder:(context,index){final day=DateTime(month.year,month.month,index+1);final scheduled=h.isScheduled(day);final done=h.isDone(day);return InkWell(onTap:scheduled?()=>toggle(day):null,child:Container(margin:const EdgeInsets.all(3),decoration:BoxDecoration(color:done?AppColors.blue:(scheduled?Colors.white:AppColors.bg),borderRadius:BorderRadius.circular(9),border:Border.all(color:scheduled?AppColors.border:Colors.transparent)),child:Center(child:Text('${index+1}',style:TextStyle(fontWeight:FontWeight.w800,color:done?Colors.white:(scheduled?AppColors.text:AppColors.muted))))));})])),
        SectionTitle(title:'Measurements',onAdd:addMeasurement,label:'＋ Add value'),
        CardBox(child:entries.isEmpty?const Text('No measurements yet.',style:TextStyle(color:AppColors.muted)):Column(children:entries.take(12).map((e)=>ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.show_chart,color:AppColors.blue),title:Text('${e.value} ${h.unit}'),subtitle:Text(e.key))).toList())),
        SectionTitle(title:'Journal / notes'),
        CardBox(child:Text(h.notes.isEmpty?'No notes yet.':h.notes,style:const TextStyle(color:AppColors.muted,height:1.5))),
        const SizedBox(height:20),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>toggle(DateTime.now()),icon:Icon(h.isDone(DateTime.now())?Icons.undo:Icons.check),label:Text(h.isDone(DateTime.now())?'Mark today incomplete':'Mark today complete')))
      ])));
  }
}

class HabitEdit {
  final String name,category,unit,frequency,notes; final int goal; final List<int> weekdays; final bool pinned,active,delete; final List<String> tags;
  const HabitEdit({required this.name,required this.category,required this.goal,required this.unit,required this.frequency,required this.weekdays,required this.pinned,required this.active,required this.tags,required this.notes,this.delete=false});
  Habit toHabit()=>Habit(id:DateTime.now().microsecondsSinceEpoch.toString(),name:name,category:category,goal:goal,unit:unit,frequency:frequency,weekdays:weekdays,pinned:pinned,active:active,tags:tags,notes:notes);
}

class HabitEditor extends StatefulWidget {
  final Habit? habit;
  const HabitEditor({super.key,this.habit});
  @override State<HabitEditor> createState()=>_HabitEditorState();
}
class _HabitEditorState extends State<HabitEditor>{
  late TextEditingController name,goal,tags,notes; late String category,unit,frequency; late List<int> weekdays; late bool pinned,active;
  final categories=['Personal','Health','Mind & Body','Productivity','Learning','Goals','Finance','Routine','Other'];
  final units=['times','minutes','hours','pages','litres','km','steps','reps','kg'];
  @override void initState(){super.initState();final h=widget.habit;name=TextEditingController(text:h?.name??'');goal=TextEditingController(text:'${h?.goal??1}');tags=TextEditingController(text:h?.tags.join(', ')??'');notes=TextEditingController(text:h?.notes??'');category=categories.contains(h?.category)?h!.category:'Personal';unit=units.contains(h?.unit)?h!.unit:'times';frequency=h?.frequency??'Every day';weekdays=List<int>.from(h?.weekdays??[1,2,3,4,5,6,7]);pinned=h?.pinned??false;active=h?.active??true;}
  @override void dispose(){name.dispose();goal.dispose();tags.dispose();notes.dispose();super.dispose();}
  void save(){final n=name.text.trim();if(n.isEmpty)return;Navigator.pop(context,HabitEdit(name:n,category:category,goal:(int.tryParse(goal.text)??1).clamp(1,1000000),unit:unit,frequency:frequency,weekdays:weekdays.isEmpty?[1,2,3,4,5,6,7]:weekdays,pinned:pinned,active:active,tags:tags.text.split(',').map((x)=>x.trim()).where((x)=>x.isNotEmpty).toList(),notes:notes.text.trim()));}
  @override Widget build(BuildContext context)=>SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(20,10,20,MediaQuery.of(context).viewInsets.bottom+20),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.habit==null?'Create habit':'Edit habit',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:15),TextField(controller:name,decoration:const InputDecoration(labelText:'Habit name')),const SizedBox(height:10),Row(children:[Expanded(child:DropdownButtonFormField<String>(value:category,items:categories.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setState(()=>category=v);})),const SizedBox(width:10),Expanded(child:DropdownButtonFormField<String>(value:unit,items:units.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setState(()=>unit=v);}))]),const SizedBox(height:10),TextField(controller:goal,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Target')),const SizedBox(height:10),const Text('Frequency',style:TextStyle(fontWeight:FontWeight.w800)),Wrap(spacing:5,children:['Every day','Weekdays','Custom'].map((x)=>ChoiceChip(label:Text(x),selected:frequency==x,onSelected:(_)=>setState(()=>frequency=x))).toList()),if(frequency=='Custom')Wrap(spacing:4,children:List.generate(7,(i){final d=i+1;return FilterChip(label:Text(['M','T','W','T','F','S','S'][i]),selected:weekdays.contains(d),onSelected:(v)=>setState(()=>v?weekdays.add(d):weekdays.remove(d)));})),TextField(controller:tags,decoration:const InputDecoration(labelText:'Tags, comma separated')),const SizedBox(height:8),TextField(controller:notes,maxLines:3,decoration:const InputDecoration(labelText:'Journal / notes')),SwitchListTile(contentPadding:EdgeInsets.zero,value:pinned,onChanged:(v)=>setState(()=>pinned=v),title:const Text('Pin to top')),SwitchListTile(contentPadding:EdgeInsets.zero,value:active,onChanged:(v)=>setState(()=>active=v),title:const Text('Active')),if(widget.habit!=null)TextButton.icon(onPressed:()=>Navigator.pop(context,const HabitEdit(name:'',category:'',goal:1,unit:'times',frequency:'Every day',weekdays:[1,2,3,4,5,6,7],pinned:false,active:false,tags:[],notes:'',delete:true)),icon:const Icon(Icons.delete_outline),label:const Text('Delete')),FilledButton(onPressed:save,style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)),child:Text(widget.habit==null?'Create habit':'Save changes'))]))));
}

class TodoEdit { final String title,category; final int priority; final DateTime? due; const TodoEdit({required this.title,required this.category,required this.priority,this.due}); }
class TodoEditor extends StatefulWidget { const TodoEditor({super.key}); @override State<TodoEditor> createState()=>_TodoEditorState(); }
class _TodoEditorState extends State<TodoEditor>{final title=TextEditingController();String category='General';int priority=1;DateTime? due;@override void dispose(){title.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:const Text('New task'),content:SingleChildScrollView(child:Column(children:[TextField(controller:title,decoration:const InputDecoration(labelText:'Task')),const SizedBox(height:8),DropdownButtonFormField<String>(value:category,items:['General','College','Work','Personal'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setState(()=>category=v);}),const SizedBox(height:8),DropdownButtonFormField<int>(value:priority,items:const[DropdownMenuItem(value:1,child:Text('Low')),DropdownMenuItem(value:2,child:Text('Medium')),DropdownMenuItem(value:3,child:Text('High'))],onChanged:(v)=>setState(()=>priority=v??1)),ListTile(contentPadding:EdgeInsets.zero,title:Text(due==null?'No due date':'Due ${DateFormat('d MMM yyyy').format(due!)}'),leading:const Icon(Icons.event),onTap:()async{final d=await showDatePicker(context:context,initialDate:due??DateTime.now(),firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null&&mounted)setState(()=>due=d);})])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,TodoEdit(title:title.text,category:category,priority:priority,due:due)),child:const Text('Save'))]);}

class FocusTimer extends StatefulWidget { final StorageService storage; final DateTime date; final int initial; final ValueChanged<int> onSaved; const FocusTimer({super.key,required this.storage,required this.date,required this.initial,required this.onSaved}); @override State<FocusTimer> createState()=>_FocusTimerState(); }
class _FocusTimerState extends State<FocusTimer>{late int seconds;Timer? timer;bool running=false;@override void initState(){super.initState();seconds=widget.initial;}@override void dispose(){timer?.cancel();super.dispose();}void toggle(){if(running){timer?.cancel();setState(()=>running=false);}else{timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>seconds++);});setState(()=>running=true);}}Future<void> save()async{final data=await widget.storage.loadTimerSeconds();data[Habit.key(widget.date)]=seconds;await widget.storage.saveTimerSeconds(data);widget.onSaved(seconds);if(mounted)Navigator.pop(context);}String format(){final h=seconds~/3600;final m=(seconds%3600)~/60;final s=seconds%60;return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Focus Timer')),body:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.timer_outlined,size:64,color:AppColors.blue),const SizedBox(height:20),Text(format(),style:const TextStyle(fontSize:46,fontWeight:FontWeight.w900)),const SizedBox(height:20),FilledButton.icon(onPressed:toggle,icon:Icon(running?Icons.pause:Icons.play_arrow),label:Text(running?'Pause':'Start')),const SizedBox(height:10),OutlinedButton(onPressed:save,child:const Text('Save today’s focus time'))])));}

class MeasurementDialog extends StatefulWidget { final String unit; const MeasurementDialog({super.key,required this.unit}); @override State<MeasurementDialog> createState()=>_MeasurementDialogState(); }
class _MeasurementDialogState extends State<MeasurementDialog>{final c=TextEditingController();@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:Text('Add ${widget.unit}'),content:TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'Value (${widget.unit})')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:(){final v=double.tryParse(c.text);if(v!=null)Navigator.pop(context,v);},child:const Text('Save'))]);}
String priorityName(int p)=>p==3?'High':p==2?'Medium':'Low';
