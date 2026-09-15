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
  static const green = Color(0xFF12B76A);
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Habit Tracker', debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: AppColors.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue)),
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
  int tab = 0;
  DateTime selectedDate = DateTime.now();

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    habits = await storage.loadHabits(); todos = await storage.loadTodos();
    if (mounted) setState(() {});
  }
  void _toggle(Habit h) { setState(() => h.setDone(selectedDate, !h.isDone(selectedDate))); storage.saveHabits(habits); }

  void _addHabit() {
    final c = TextEditingController(); var category = 'Daily'; var goal = 30;
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => StatefulBuilder(
      builder: (context, sheet) => Padding(padding: EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(context).viewInsets.bottom+20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add a habit', style: TextStyle(fontSize: 24,fontWeight: FontWeight.w800)), const SizedBox(height: 16),
          TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Habit name')),
          const SizedBox(height: 12), DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Category'),
            items: ['Daily','Mind & Body','Productivity','Goals'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(), onChanged:(v)=>sheet(()=>category=v??category)),
          const SizedBox(height: 8), Text('Monthly goal: $goal days',style:const TextStyle(fontWeight:FontWeight.w600)),
          Slider(value:goal.toDouble(),min:1,max:31,divisions:30,label:'$goal',onChanged:(v)=>sheet(()=>goal=v.round())),
          SizedBox(width:double.infinity,child:FilledButton(onPressed:(){if(c.text.trim().isEmpty)return;setState(()=>habits.add(Habit(id:DateTime.now().microsecondsSinceEpoch.toString(),name:c.text.trim(),category:category,goal:goal)));storage.saveHabits(habits);Navigator.pop(context);},child:const Text('Create habit'))),
        ])),
    ));
  }

  void _addTodo() {
    final c=TextEditingController(); showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('Add task'),content:TextField(controller:c,autofocus:true),actions:[
      TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')), FilledButton(onPressed:(){if(c.text.trim().isNotEmpty){setState(()=>todos.add({'title':c.text.trim(),'done':false}));storage.saveTodos(todos);}Navigator.pop(context);},child:const Text('Add'))]));
  }

  @override Widget build(BuildContext context) {
    final pages=[
      DashboardPage(habits:habits,date:selectedDate,onToggle:_toggle,onAdd:_addHabit),
      DailyPage(habits:habits,date:selectedDate,onDateChanged:(d)=>setState(()=>selectedDate=d),onToggle:_toggle,onAdd:_addHabit),
      AnalyticsPage(habits:habits),
      TodoPage(todos:todos,onAdd:_addTodo,onChanged:()=>storage.saveTodos(todos)),
      ProfilePage(habits:habits),
    ];
    return Scaffold(body:SafeArea(child:pages[tab]),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[
      NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'Home'),
      NavigationDestination(icon:Icon(Icons.checklist_outlined),selectedIcon:Icon(Icons.checklist),label:'Habits'),
      NavigationDestination(icon:Icon(Icons.bar_chart_outlined),selectedIcon:Icon(Icons.bar_chart),label:'Stats'),
      NavigationDestination(icon:Icon(Icons.task_alt_outlined),selectedIcon:Icon(Icons.task_alt),label:'To-Do'),
      NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profile'),
    ]));
  }
}

class PageHeader extends StatelessWidget {
  final String title; final String? subtitle; final Widget? trailing;
  const PageHeader({super.key,required this.title,this.subtitle,this.trailing});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.fromLTRB(20,18,20,12),child:Row(children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:AppColors.text)),if(subtitle!=null)Text(subtitle!,style:const TextStyle(color:AppColors.muted))])),if(trailing!=null)trailing! ]));
}

class DashboardPage extends StatelessWidget {
  final List<Habit> habits; final DateTime date; final void Function(Habit) onToggle; final VoidCallback onAdd;
  const DashboardPage({super.key,required this.habits,required this.date,required this.onToggle,required this.onAdd});
  @override Widget build(BuildContext context){final done=habits.where((h)=>h.isDone(date)).length;final p=habits.isEmpty?0.0:done/habits.length;return SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    PageHeader(title:'Good day 👋',subtitle:DateFormat('EEEE, d MMMM').format(date),trailing:CircleAvatar(backgroundColor:AppColors.navy,child:Text('${(p*100).round()}%',style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold)))),
    Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:ProgressCard(progress:p,done:done,total:habits.length)),const SizedBox(height:20),
    Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Row(children:[const Expanded(child:Text("Today's habits",style:TextStyle(fontSize:20,fontWeight:FontWeight.w800))),TextButton.icon(onPressed:onAdd,icon:const Icon(Icons.add),label:const Text('Add'))])),
    ...habits.map((h)=>HabitTile(habit:h,date:date,onToggle:()=>onToggle(h))),const SizedBox(height:20)]));}
}

class ProgressCard extends StatelessWidget { final double progress;final int done,total;const ProgressCard({super.key,required this.progress,required this.done,required this.total});
 @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppColors.navy,AppColors.blue]),borderRadius:BorderRadius.circular(26)),child:Row(children:[
  SizedBox(width:94,height:94,child:Stack(alignment:Alignment.center,children:[CircularProgressIndicator(value:progress,strokeWidth:9,backgroundColor:Colors.white24,color:Colors.white),Text('${(progress*100).round()}%',style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900))])),const SizedBox(width:20),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('DAILY PROGRESS',style:TextStyle(color:Colors.white70,fontSize:11,fontWeight:FontWeight.w700,letterSpacing:1.2)),const SizedBox(height:8),Text('$done / $total completed',style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),const Text('Small wins build consistency.',style:TextStyle(color:Colors.white70))]))])); }

class HabitTile extends StatelessWidget { final Habit habit;final DateTime date;final VoidCallback onToggle;const HabitTile({super.key,required this.habit,required this.date,required this.onToggle});
 @override Widget build(BuildContext context){final done=habit.isDone(date);return Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),child:Material(color:Colors.white,borderRadius:BorderRadius.circular(17),child:InkWell(onTap:onToggle,borderRadius:BorderRadius.circular(17),child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
  Container(width:28,height:28,decoration:BoxDecoration(color:done?AppColors.blue:Colors.white,borderRadius:BorderRadius.circular(9),border:Border.all(color:done?AppColors.blue:const Color(0xFFD0D5DD),width:2)),child:done?const Icon(Icons.check,size:18,color:Colors.white):null),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(habit.name,style:TextStyle(fontWeight:FontWeight.w700,decoration:done?TextDecoration.lineThrough:null)),Text(habit.category,style:const TextStyle(fontSize:12,color:AppColors.muted))])),Text('${habit.completedInMonth(date)}/${habit.goal}',style:const TextStyle(fontWeight:FontWeight.w800,color:AppColors.blue))])))));}}

class DailyPage extends StatelessWidget {final List<Habit> habits;final DateTime date;final ValueChanged<DateTime> onDateChanged;final void Function(Habit) onToggle;final VoidCallback onAdd;const DailyPage({super.key,required this.habits,required this.date,required this.onDateChanged,required this.onToggle,required this.onAdd});
 @override Widget build(BuildContext context){final days=List.generate(DateTime(date.year,date.month+1,0).day,(i)=>DateTime(date.year,date.month,i+1));return Column(children:[PageHeader(title:'Daily Tracking',subtitle:DateFormat('MMMM yyyy').format(date),trailing:IconButton(onPressed:onAdd,icon:const Icon(Icons.add_circle,size:32,color:AppColors.blue))),SizedBox(height:82,child:ListView.separated(padding:const EdgeInsets.symmetric(horizontal:20),scrollDirection:Axis.horizontal,itemCount:days.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(_,i){final d=days[i],sel=d.day==date.day;return GestureDetector(onTap:()=>onDateChanged(d),child:Container(width:52,decoration:BoxDecoration(color:sel?AppColors.blue:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:sel?AppColors.blue:const Color(0xFFE4E7EC))),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(DateFormat('EEE').format(d).substring(0,2),style:TextStyle(fontSize:11,color:sel?Colors.white70:AppColors.muted,fontWeight:FontWeight.w700)),Text('${d.day}',style:TextStyle(fontSize:17,color:sel?Colors.white:AppColors.text,fontWeight:FontWeight.w900))]))); })),const SizedBox(height:12),Expanded(child:ListView(padding:const EdgeInsets.only(bottom:20),children:habits.map((h)=>HabitTile(habit:h,date:date,onToggle:()=>onToggle(h)).toList()))]);}}

class AnalyticsPage extends StatelessWidget {final List<Habit> habits;const AnalyticsPage({super.key,required this.habits});int doneOn(DateTime d)=>habits.where((h)=>h.isDone(d)).length;
 @override Widget build(BuildContext context){final now=DateTime.now();final ds=List.generate(7,(i)=>DateTime(now.year,now.month,now.day-6+i));var total=0;for(final d in ds)total+=doneOn(d);final pct=habits.isEmpty?0.0:total/(habits.length*7);final top=[...habits]..sort((a,b)=>b.completedInMonth(now).compareTo(a.completedInMonth(now)));return SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const PageHeader(title:'Analytics',subtitle:'See the bigger picture'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Row(children:[Expanded(child:StatCard(label:'This week',value:'${(pct*100).round()}%',icon:Icons.trending_up)),const SizedBox(width:12),Expanded(child:StatCard(label:'Habits',value:'${habits.length}',icon:Icons.track_changes))])),const SizedBox(height:18),const Padding(padding:EdgeInsets.symmetric(horizontal:20),child:Text('Weekly Progress',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800))),const SizedBox(height:12),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22)),child:Row(crossAxisAlignment:CrossAxisAlignment.end,mainAxisAlignment:MainAxisAlignment.spaceAround,children:ds.map((d){final p=habits.isEmpty?0.0:doneOn(d)/habits.length;return Column(children:[SizedBox(height:130,child:Align(alignment:Alignment.bottomCenter,child:Container(width:24,height:12+105*p,decoration:BoxDecoration(color:AppColors.blue,borderRadius:BorderRadius.circular(8))))),Text(DateFormat('E').format(d).substring(0,2),style:const TextStyle(fontSize:11,color:AppColors.muted)),Text('${(p*100).round()}%',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800))]);}).toList()))),const SizedBox(height:18),const Padding(padding:EdgeInsets.symmetric(horizontal:20),child:Text('Top Habits',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800))),...top.take(5).map((h)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),child:ListTile(tileColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),leading:const Icon(Icons.star_rounded,color:Color(0xFFFFB800)),title:Text(h.name),trailing:Text('${h.completedInMonth(now)} days',style:const TextStyle(color:AppColors.blue,fontWeight:FontWeight.w800)))))]));}}

class StatCard extends StatelessWidget {final String label,value;final IconData icon;const StatCard({super.key,required this.label,required this.value,required this.icon});@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:AppColors.blue),const SizedBox(height:16),Text(value,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(color:AppColors.muted))]));}

class TodoPage extends StatefulWidget {final List<Map<String,dynamic>> todos;final VoidCallback onAdd;final Future<void> Function() onChanged;const TodoPage({super.key,required this.todos,required this.onAdd,required this.onChanged});@override State<TodoPage> createState()=>_TodoPageState();}
class _TodoPageState extends State<TodoPage>{@override Widget build(BuildContext context){final done=widget.todos.where((t)=>t['done']==true).length;final p=widget.todos.isEmpty?0.0:done/widget.todos.length;return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[PageHeader(title:'To-Do List',subtitle:'Stay organized and get things done',trailing:IconButton(onPressed:widget.onAdd,icon:const Icon(Icons.add_circle,size:32,color:AppColors.blue))),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Progress',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:7),LinearProgressIndicator(value:p,minHeight:8,borderRadius:BorderRadius.circular(8))])),const SizedBox(width:16),Text('${(p*100).round()}%',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:AppColors.blue))]))),const SizedBox(height:12),Expanded(child:widget.todos.isEmpty?const Center(child:Text('No tasks yet. Add one to get started.',style:TextStyle(color:AppColors.muted))):ListView.builder(itemCount:widget.todos.length,itemBuilder:(_,i){final t=widget.todos[i];return Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),child:Dismissible(key:ValueKey('${t['title']}_$i'),onDismissed:(_){setState(()=>widget.todos.removeAt(i));widget.onChanged();},child:ListTile(tileColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),leading:Checkbox(value:t['done']==true,onChanged:(v){setState(()=>t['done']=v??false);widget.onChanged();}),title:Text(t['title'] as String,style:TextStyle(decoration:t['done']==true?TextDecoration.lineThrough:null,fontWeight:FontWeight.w600)))));}))]);}}

class ProfilePage extends StatelessWidget {final List<Habit> habits;const ProfilePage({super.key,required this.habits});@override Widget build(BuildContext context)=>ListView(children:[const PageHeader(title:'Profile',subtitle:'Your consistency journey'),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:AppColors.navy,borderRadius:BorderRadius.circular(24)),child:const Row(children:[CircleAvatar(radius:30,backgroundColor:Colors.white,child:Icon(Icons.person,color:AppColors.navy)),SizedBox(width:16),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Habit Builder',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),Text('Build better. Every day.',style:TextStyle(color:Colors.white70))])]))),const SizedBox(height:18),ProfileItem(icon:Icons.track_changes,title:'Active habits',value:'${habits.length}'),const ProfileItem(icon:Icons.offline_bolt,title:'Offline-first',value:'Enabled'),const ProfileItem(icon:Icons.notifications_none,title:'Reminders',value:'Coming soon'),const ProfileItem(icon:Icons.cloud_outlined,title:'Cloud sync',value:'Optional later'),const Padding(padding:EdgeInsets.all(20),child:Text('Version 1.0.0 • Built with Flutter',style:TextStyle(color:AppColors.muted)))]);}
class ProfileItem extends StatelessWidget {final IconData icon;final String title,value;const ProfileItem({super.key,required this.icon,required this.title,required this.value});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),child:ListTile(tileColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17)),leading:Icon(icon,color:AppColors.blue),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),trailing:Text(value,style:const TextStyle(color:AppColors.muted,fontWeight:FontWeight.w600))));}
