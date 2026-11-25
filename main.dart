import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const forest = Color(0xFF183F35);
const forestLight = Color(0xFF2F6655);
const cream = Color(0xFFF7F4EA);
const paper = Color(0xFFFFFEFA);
const muted = Color(0xFF78827B);
const orange = Color(0xFFC8894B);
const red = Color(0xFFB85D52);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JinDuApp());
}

String money(num value) {
  final s = value.round().toString();
  final out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    out.write(s[i]);
    final remaining = s.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) out.write(',');
  }
  return 'NT\$${out.toString()}';
}

class Txn {
  Txn({required this.title, required this.amount, required this.date,
    required this.type, this.category = '其他', this.received = true});
  String title, type, category;
  double amount;
  DateTime date;
  bool received;
  Map<String, dynamic> toJson() => {
    'title': title, 'amount': amount, 'date': date.toIso8601String(),
    'type': type, 'category': category, 'received': received,
  };
  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
    title: j['title'] ?? '', amount: (j['amount'] as num).toDouble(),
    date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
    type: j['type'] ?? '支出', category: j['category'] ?? '其他',
    received: j['received'] ?? true,
  );
}

class Debt {
  Debt({required this.name, required this.balance, required this.rate,
    required this.monthly, required this.note});
  String name, note;
  double balance, rate, monthly;
  Map<String, dynamic> toJson() => {'name':name,'balance':balance,'rate':rate,'monthly':monthly,'note':note};
  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
    name:j['name'], balance:(j['balance'] as num).toDouble(),
    rate:(j['rate'] as num).toDouble(), monthly:(j['monthly'] as num).toDouble(),
    note:j['note'] ?? '');
}

class Goal {
  Goal({required this.name, required this.target, required this.saved});
  String name;
  double target, saved;
  Map<String, dynamic> toJson() => {'name':name,'target':target,'saved':saved};
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    name:j['name'], target:(j['target'] as num).toDouble(), saved:(j['saved'] as num).toDouble());
}

class FinanceData {
  List<Txn> txns = [];
  List<Debt> debts = [];
  List<Goal> goals = [];
  double cash = 0;
  double monthlyBudget = 10000;
  bool initialized = false;

  Map<String, dynamic> toJson() => {
    'txns': txns.map((e)=>e.toJson()).toList(),
    'debts': debts.map((e)=>e.toJson()).toList(),
    'goals': goals.map((e)=>e.toJson()).toList(),
    'cash': cash, 'monthlyBudget': monthlyBudget, 'initialized': true,
  };

  void load(Map<String, dynamic> j) {
    txns = (j['txns'] as List? ?? []).map((e)=>Txn.fromJson(Map<String,dynamic>.from(e))).toList();
    debts = (j['debts'] as List? ?? []).map((e)=>Debt.fromJson(Map<String,dynamic>.from(e))).toList();
    goals = (j['goals'] as List? ?? []).map((e)=>Goal.fromJson(Map<String,dynamic>.from(e))).toList();
    cash = (j['cash'] as num?)?.toDouble() ?? 0;
    monthlyBudget = (j['monthlyBudget'] as num?)?.toDouble() ?? 10000;
    initialized = j['initialized'] == true;
  }

  void seed() {
    // 初始資料依照使用者提供的概況建立；存款為 0，實際數字可在債務頁編輯。
    cash = 0;
    monthlyBudget = 10000;
    debts = [
      Debt(name:'信貸', balance:600000, rate:7, monthly:7749, note:'剩餘期數約 113 期，請以銀行帳單為準'),
      Debt(name:'學貸', balance:337650, rate:0, monthly:4500, note:'利率尚未確認，請自行補上'),
    ];
    goals = [
      Goal(name:'第一筆緊急預備金', target:10000, saved:0),
      Goal(name:'緊急預備金階段目標', target:30000, saved:0),
      Goal(name:'三個月基本支出', target:93747, saved:0),
      Goal(name:'第一間房基金', target:1000000, saved:0),
    ];
    txns = [];
    initialized = true;
  }
}

class JinDuApp extends StatefulWidget {
  const JinDuApp({super.key});
  @override State<JinDuApp> createState() => _JinDuAppState();
}

class _JinDuAppState extends State<JinDuApp> {
  final FinanceData data = FinanceData();
  bool ready = false;
  int tab = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('jin_du_finance_v1');
    if (raw != null) {
      try { data.load(jsonDecode(raw)); } catch (_) { data.seed(); }
    } else { data.seed(); }
    if (mounted) setState(() => ready = true);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jin_du_finance_v1', jsonEncode(data.toJson()));
  }

  double get monthIncome => data.txns.where((t)=>t.type=='收入' && t.received && _sameMonth(t.date)).fold(0.0, (a,b)=>a+b.amount);
  double get monthExpense => data.txns.where((t)=>t.type=='支出' && _sameMonth(t.date)).fold(0.0, (a,b)=>a+b.amount);
  double get pendingIncome => data.txns.where((t)=>t.type=='收入' && !t.received).fold(0.0, (a,b)=>a+b.amount);
  double get totalDebt => data.debts.fold(0.0,(a,b)=>a+b.balance);
  bool _sameMonth(DateTime d) => d.year == DateTime.now().year && d.month == DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '💰進度',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(seedColor: forest, surface: cream),
        appBarTheme: const AppBarTheme(backgroundColor: cream, foregroundColor: forest, elevation: 0),
        cardTheme: CardThemeData(color: paper, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        fontFamily: null,
      ),
      home: !ready ? const Scaffold(body: Center(child:CircularProgressIndicator())) :
        Scaffold(
          appBar: AppBar(title: const Text('💰進度', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5)),
            actions: [IconButton(onPressed: _editCash, icon: const Icon(Icons.account_balance_wallet_outlined), tooltip:'設定現金餘額')]),
          body: IndexedStack(index:tab, children:[
            _overview(), _records(), _debts(), _goals(), _analysis(),
          ]),
          floatingActionButton: tab == 1 ? FloatingActionButton.extended(
            backgroundColor: forest, foregroundColor: Colors.white,
            onPressed: _addTxn, icon: const Icon(Icons.add), label: const Text('新增紀錄')) : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex:tab, onDestinationSelected:(v)=>setState(()=>tab=v),
            backgroundColor: paper, indicatorColor: const Color(0xFFDDE8DF),
            destinations: const [
              NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'總覽'),
              NavigationDestination(icon:Icon(Icons.receipt_long_outlined),selectedIcon:Icon(Icons.receipt_long),label:'記帳'),
              NavigationDestination(icon:Icon(Icons.account_balance_outlined),selectedIcon:Icon(Icons.account_balance),label:'債務'),
              NavigationDestination(icon:Icon(Icons.savings_outlined),selectedIcon:Icon(Icons.savings),label:'目標'),
              NavigationDestination(icon:Icon(Icons.insights_outlined),selectedIcon:Icon(Icons.insights),label:'分析'),
            ]),
        ),
    );
  }

  Widget _overview() {
    final available = data.cash - monthExpense;
    return ListView(padding: const EdgeInsets.fromLTRB(18,8,18,28), children:[
      Container(padding:const EdgeInsets.all(22), decoration:BoxDecoration(
        gradient:const LinearGradient(colors:[forest,forestLight],begin:Alignment.topLeft,end:Alignment.bottomRight),
        borderRadius:BorderRadius.circular(24)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          const Text('本月已入帳收入',style:TextStyle(color:Colors.white70,fontSize:13)),
          const SizedBox(height:8),
          Text(money(monthIncome),style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w800)),
          const SizedBox(height:20),
          Row(children:[
            _heroMetric('本月支出',money(monthExpense)),
            const SizedBox(width:26),
            _heroMetric('待入帳佣金',money(pendingIncome)),
          ])
        ])),
      const SizedBox(height:18),
      Row(children:[
        Expanded(child:_metric('目前現金',money(data.cash),Icons.wallet_outlined)),
        const SizedBox(width:12),
        Expanded(child:_metric('本月扣除支出後',money(available),Icons.payments_outlined)),
      ]),
      const SizedBox(height:12),
      Row(children:[
        Expanded(child:_metric('總負債',money(totalDebt),Icons.account_balance_outlined)),
        const SizedBox(width:12),
        Expanded(child:_metric('本月預算',money(data.monthlyBudget),Icons.tune)),
      ]),
      const SizedBox(height:22),
      _sectionTitle('近期紀錄', trailing:TextButton(onPressed:()=>setState(()=>tab=1),child:const Text('查看全部'))),
      if(data.txns.isEmpty) _empty('還沒有記帳紀錄','點選下方「記帳」開始記錄每一筆收支')
      else ...data.txns.reversed.take(4).map(_txnTile),
      const SizedBox(height:20),
      _sectionTitle('目前財務提醒'),
      _notice('先建立現金緩衝','目前設定的現金餘額為 ${money(data.cash)}。收入不固定時，先累積第一筆 1 萬元緊急預備金。',Icons.lightbulb_outline),
      _notice('待入帳收入不列入現金','待入帳佣金 ${money(pendingIncome)} 會獨立顯示，不會加進目前現金。',Icons.schedule),
    ]);
  }

  Widget _heroMetric(String label,String value)=>Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(label,style:const TextStyle(color:Colors.white70,fontSize:12)),
    const SizedBox(height:5),Text(value,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:17))
  ]));
  Widget _metric(String label,String value,IconData icon)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(icon,color:forestLight),const SizedBox(height:12),
    Text(label,style:const TextStyle(color:muted,fontSize:12)),
    const SizedBox(height:5),FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text(value,style:const TextStyle(color:forest,fontWeight:FontWeight.w800,fontSize:18)))
  ])));

  Widget _records() => ListView(padding:const EdgeInsets.fromLTRB(18,8,18,100),children:[
    _sectionTitle('收支紀錄'),
    Text('收入與支出分開統計；佣金可標示為待入帳。',style:TextStyle(color:muted,fontSize:13)),
    const SizedBox(height:12),
    if(data.txns.isEmpty) _empty('目前沒有紀錄','按右下角新增收入或支出')
    else ...data.txns.reversed.map(_txnTile),
  ]);

  Widget _txnTile(Txn t) => Card(child:ListTile(
    contentPadding:const EdgeInsets.symmetric(horizontal:15,vertical:5),
    leading:CircleAvatar(backgroundColor:t.type=='收入'?const Color(0xFFE3EEE5):const Color(0xFFF4E6DF),
      child:Icon(t.type=='收入'?Icons.south_west:Icons.north_east,color:t.type=='收入'?forestLight:red)),
    title:Text(t.title,style:const TextStyle(fontWeight:FontWeight.w700,color:forest)),
    subtitle:Text('${t.category} · ${t.date.month}/${t.date.day}${t.type=='收入'&&!t.received?' · 待入帳':''}',style:const TextStyle(color:muted,fontSize:12)),
    trailing:Text('${t.type=='收入'?'+':'−'}${money(t.amount)}',style:TextStyle(fontWeight:FontWeight.w800,color:t.type=='收入'?forestLight:red)),
    onLongPress:()=>_deleteTxn(t),
  ));

  Widget _debts() => ListView(padding:const EdgeInsets.fromLTRB(18,8,18,28),children:[
    _sectionTitle('債務管理'),
    Text('點選項目可修改本金、利率與每月還款金額。',style:TextStyle(color:muted,fontSize:13)),
    const SizedBox(height:12),
    Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('目前總負債',style:TextStyle(color:muted)),
      const SizedBox(height:5),Text(money(totalDebt),style:const TextStyle(fontSize:28,fontWeight:FontWeight.w800,color:forest)),
      const SizedBox(height:5),Text('每月固定還款 ${money(data.debts.fold(0.0,(a,b)=>a+b.monthly))}',style:const TextStyle(color:muted)),
    ]))),
    ...data.debts.map((d)=>Card(child:ListTile(
      onTap:()=>_editDebt(d),
      leading:const CircleAvatar(backgroundColor:Color(0xFFE3EEE5),child:Icon(Icons.account_balance,color:forest)),
      title:Text(d.name,style:const TextStyle(fontWeight:FontWeight.w800,color:forest)),
      subtitle:Text('年利率 ${d.rate.toStringAsFixed(2)}% · 月付 ${money(d.monthly)}\n${d.note}',style:const TextStyle(color:muted,fontSize:12)),
      isThreeLine:true,
      trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[
        Text(money(d.balance),style:const TextStyle(fontWeight:FontWeight.w800,color:forest)),
        const Text('剩餘本金',style:TextStyle(fontSize:10,color:muted))
      ]),
    ))),
    const SizedBox(height:8),
    _notice('提醒','信貸與學貸利率、期數請以銀行最新明細為準。第一版不會自動向銀行扣款或同步餘額。',Icons.info_outline),
  ]);

  Widget _goals() => ListView(padding:const EdgeInsets.fromLTRB(18,8,18,28),children:[
    _sectionTitle('存款目標',trailing:TextButton.icon(onPressed:_addGoal,icon:const Icon(Icons.add),label:const Text('新增'))),
    const Text('先建立安全緩衝，再逐步累積買房基金。',style:TextStyle(color:muted,fontSize:13)),
    const SizedBox(height:12),
    ...data.goals.map((g){
      final double p = g.target<=0?0.0:(g.saved/g.target).clamp(0.0,1.0).toDouble();
      return Card(child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Expanded(child:Text(g.name,style:const TextStyle(fontWeight:FontWeight.w800,color:forest))),Text('${(p*100).round()}%',style:const TextStyle(color:forestLight,fontWeight:FontWeight.w800))]),
        const SizedBox(height:10),ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:p,minHeight:9,backgroundColor:const Color(0xFFE9E7DE),color:forestLight)),
        const SizedBox(height:9),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          Text('已存 ${money(g.saved)}',style:const TextStyle(color:muted,fontSize:12)),
          Text('目標 ${money(g.target)}',style:const TextStyle(color:muted,fontSize:12)),
        ]),
        Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>_addToGoal(g),icon:const Icon(Icons.add_circle_outline),label:const Text('存入金額')))
      ])));
    }),
  ]);

  Widget _analysis() {
    final allIn=data.txns.where((t)=>t.type=='收入'&&t.received).fold(0.0,(a,b)=>a+b.amount);
    final allOut=data.txns.where((t)=>t.type=='支出').fold(0.0,(a,b)=>a+b.amount);
    final net=allIn-allOut;
    return ListView(padding:const EdgeInsets.fromLTRB(18,8,18,28),children:[
      _sectionTitle('財務分析'),
      const Text('依照你在 App 中輸入的紀錄統計。',style:TextStyle(color:muted,fontSize:13)),
      const SizedBox(height:12),
      _analysisRow('累計已入帳收入',money(allIn),forestLight),
      _analysisRow('累計支出',money(allOut),red),
      _analysisRow('累計收支差額',money(net),net>=0?forestLight:red),
      _analysisRow('目前總負債',money(totalDebt),orange),
      _analysisRow('待入帳佣金（不計入現金）',money(pendingIncome),muted),
      const SizedBox(height:16),
      _notice('如何看待可用餘額','總覽的「本月扣除支出後」是目前現金減去本月已記錄支出，尚未扣除未來帳單預留。請把已知帳單納入預算並定期更新現金餘額。',Icons.analytics_outlined),
      const SizedBox(height:10),
      OutlinedButton.icon(onPressed:_editBudget,icon:const Icon(Icons.edit_outlined),label:const Text('調整每月生活預算')),
      OutlinedButton.icon(onPressed:_exportData,icon:const Icon(Icons.ios_share),label:const Text('匯出資料 JSON（複製到剪貼簿功能待接入）')),
    ]);
  }

  Widget _analysisRow(String label,String value,Color c)=>Card(child:ListTile(title:Text(label,style:const TextStyle(color:muted,fontSize:13)),trailing:Text(value,style:TextStyle(color:c,fontWeight:FontWeight.w800))));
  Widget _sectionTitle(String title,{Widget? trailing})=>Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
    Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:forest)),if(trailing!=null)trailing
  ]);
  Widget _empty(String title,String sub)=>Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:paper,borderRadius:BorderRadius.circular(18)),child:Column(children:[
    const Icon(Icons.receipt_long_outlined,size:34,color:muted),const SizedBox(height:8),
    Text(title,style:const TextStyle(fontWeight:FontWeight.w700,color:forest)),const SizedBox(height:4),
    Text(sub,textAlign:TextAlign.center,style:const TextStyle(color:muted,fontSize:12))
  ]));
  Widget _notice(String title,String body,IconData icon)=>Card(child:Padding(padding:const EdgeInsets.all(15),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(icon,color:orange),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(fontWeight:FontWeight.w800,color:forest)),const SizedBox(height:4),
      Text(body,style:const TextStyle(color:muted,fontSize:12,height:1.45))
    ]))
  ])));

  Future<void> _addTxn() async {
    final title=TextEditingController(), amount=TextEditingController();
    String type='支出', category='生活', status='已入帳';
    await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      backgroundColor:paper, title:const Text('新增收支紀錄'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        SegmentedButton<String>(segments:const [ButtonSegment(value:'收入',label:Text('收入')),ButtonSegment(value:'支出',label:Text('支出'))],selected:{type},onSelectionChanged:(s)=>setD(()=>type=s.first)),
        const SizedBox(height:12),TextField(controller:title,decoration:const InputDecoration(labelText:'項目名稱',hintText:'例如：保險佣金、午餐')),
        TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'金額（元）')),
        const SizedBox(height:8),
        DropdownButtonFormField<String>(value:category,decoration:const InputDecoration(labelText:'分類'),items:(type=='收入'?['佣金','薪資','獎金','其他']:['生活','餐飲','交通','保險','貸款','娛樂','其他']).map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setD(()=>category=v??'其他')),
        if(type=='收入') DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'入帳狀態'),items:const [DropdownMenuItem(value:'已入帳',child:Text('已入帳')),DropdownMenuItem(value:'待入帳',child:Text('待入帳'))],onChanged:(v)=>setD(()=>status=v??'已入帳')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('取消')),FilledButton(onPressed:(){
        final n=double.tryParse(amount.text.replaceAll(',',''));
        if(title.text.trim().isEmpty||n==null||n<=0)return;
        data.txns.add(Txn(title:title.text.trim(),amount:n,date:DateTime.now(),type:type,category:category,received:type=='支出'||status=='已入帳'));
        if(type=='收入'&&status=='已入帳')data.cash+=n;
        if(type=='支出')data.cash-=n;
        save();setState((){});Navigator.pop(ctx);
      },child:const Text('儲存'))]
    )));
  }

  Future<void> _deleteTxn(Txn t) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('刪除這筆紀錄？'),content:Text(t.title),actions:[
      TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('取消')),
      FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('刪除'))
    ]));
    if(ok==true){data.txns.remove(t);save();setState((){});}
  }

  Future<void> _editDebt(Debt d) async {
    final b=TextEditingController(text:d.balance.toStringAsFixed(0)),r=TextEditingController(text:d.rate.toString()),m=TextEditingController(text:d.monthly.toStringAsFixed(0)),n=TextEditingController(text:d.note);
    await showDialog(context:context,builder:(c)=>AlertDialog(title:Text('編輯${d.name}'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:b,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'剩餘本金')),
      TextField(controller:r,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'年利率（%）')),
      TextField(controller:m,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'每月還款')),
      TextField(controller:n,decoration:const InputDecoration(labelText:'備註')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('取消')),FilledButton(onPressed:(){
      d.balance=double.tryParse(b.text)??d.balance;d.rate=double.tryParse(r.text)??d.rate;d.monthly=double.tryParse(m.text)??d.monthly;d.note=n.text;
      save();setState((){});Navigator.pop(c);
    },child:const Text('儲存'))]));
  }

  Future<void> _editCash() async {
    final c=TextEditingController(text:data.cash.toStringAsFixed(0));
    await showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('設定目前現金餘額'),content:TextField(controller:c,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'銀行帳戶＋手邊現金（元）')),actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('取消')),
      FilledButton(onPressed:(){data.cash=double.tryParse(c.text)??data.cash;save();setState((){});Navigator.pop(ctx);},child:const Text('儲存'))
    ]));
  }

  Future<void> _editBudget() async {
    final c=TextEditingController(text:data.monthlyBudget.toStringAsFixed(0));
    await showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('每月生活預算'),content:TextField(controller:c,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'預算金額（元）')),actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('取消')),
      FilledButton(onPressed:(){data.monthlyBudget=double.tryParse(c.text)??data.monthlyBudget;save();setState((){});Navigator.pop(ctx);},child:const Text('儲存'))
    ]));
  }

  Future<void> _addGoal() async {
    final n=TextEditingController(),v=TextEditingController();
    await showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('新增存款目標'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:n,decoration:const InputDecoration(labelText:'目標名稱')),
      TextField(controller:v,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'目標金額'))
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('取消')),FilledButton(onPressed:(){
      final amount=double.tryParse(v.text);if(n.text.trim().isEmpty||amount==null||amount<=0)return;
      data.goals.add(Goal(name:n.text.trim(),target:amount,saved:0));save();setState((){});Navigator.pop(c);
    },child:const Text('新增'))]));
  }

  Future<void> _addToGoal(Goal g) async {
    final c=TextEditingController();
    await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('存入：${g.name}'),content:TextField(controller:c,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'存入金額')),actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('取消')),
      FilledButton(onPressed:(){final v=double.tryParse(c.text);if(v==null||v<=0)return;g.saved+=v;data.cash-=v;save();setState((){});Navigator.pop(ctx);},child:const Text('確認存入'))
    ]));
  }

  Future<void> _exportData() async {
    // 第一版先提供可檢視的 JSON 匯出預覽；正式分享檔案可於下一階段接入 share_plus。
    final encoded=const JsonEncoder.withIndent('  ').convert(data.toJson());
    if(!mounted)return;
    await showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('資料備份內容'),content:SizedBox(width:500,child:SingleChildScrollView(child:SelectableText(encoded,style:const TextStyle(fontSize:11)))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('關閉'))]));
  }
}
