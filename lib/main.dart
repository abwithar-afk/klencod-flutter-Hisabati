
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HisabatiApp());
}

const _bg = Color(0xFFF4F6FA);
const _navy = Color(0xFF172B4D);
const _blue = Color(0xFF2864DC);
const _green = Color(0xFF16865B);
const _red = Color(0xFFD64B55);

class HisabatiApp extends StatelessWidget {
  const HisabatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'حساباتي',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(seedColor: _blue),
        appBarTheme: const AppBarTheme(
          backgroundColor: _bg,
          foregroundColor: _navy,
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class TransactionItem {
  final String title;
  final double amount;
  final bool isIncome;
  final DateTime date;

  TransactionItem({
    required this.title,
    required this.amount,
    required this.isIncome,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'amount': amount,
        'isIncome': isIncome,
        'date': date.toIso8601String(),
      };

  factory TransactionItem.fromJson(Map<String, dynamic> json) =>
      TransactionItem(
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        isIncome: json['isIncome'] as bool,
        date: DateTime.parse(json['date'] as String),
      );
}

class ClientItem {
  final String name;
  final String phone;
  final DateTime createdAt;

  ClientItem({required this.name, required this.phone, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ClientItem.fromJson(Map<String, dynamic> j) => ClientItem(
        name: j['name'] as String,
        phone: (j['phone'] ?? '') as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class DebtItem {
  final String person;
  final String note;
  final double amount;
  final bool owedToMe;
  final DateTime date;

  DebtItem({
    required this.person,
    required this.note,
    required this.amount,
    required this.owedToMe,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'person': person,
        'note': note,
        'amount': amount,
        'owedToMe': owedToMe,
        'date': date.toIso8601String(),
      };

  factory DebtItem.fromJson(Map<String, dynamic> j) => DebtItem(
        person: j['person'] as String,
        note: (j['note'] ?? '') as String,
        amount: (j['amount'] as num).toDouble(),
        owedToMe: j['owedToMe'] as bool,
        date: DateTime.parse(j['date'] as String),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  bool loading = true;
  List<TransactionItem> transactions = [];
  List<ClientItem> clients = [];
  List<DebtItem> debts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final oldTransactions = prefs.getString('hisabati_transactions');
      final savedClients = prefs.getString('hisabati_clients');
      final savedDebts = prefs.getString('hisabati_debts');
      if (oldTransactions != null) {
        transactions = (jsonDecode(oldTransactions) as List)
            .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (savedClients != null) {
        clients = (jsonDecode(savedClients) as List)
            .map((e) => ClientItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (savedDebts != null) {
        debts = (jsonDecode(savedDebts) as List)
            .map((e) => DebtItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {
      if (mounted) _message('تعذر قراءة بعض البيانات. لا تحذف بيانات التطبيق.');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hisabati_transactions',
        jsonEncode(transactions.map((e) => e.toJson()).toList()));
    await prefs.setString('hisabati_clients',
        jsonEncode(clients.map((e) => e.toJson()).toList()));
    await prefs.setString('hisabati_debts',
        jsonEncode(debts.map((e) => e.toJson()).toList()));
  }

  double get income => transactions
      .where((e) => e.isIncome)
      .fold(0, (s, e) => s + e.amount);
  double get expenses => transactions
      .where((e) => !e.isIncome)
      .fold(0, (s, e) => s + e.amount);
  double get balance => income - expenses;
  double get receivable =>
      debts.where((e) => e.owedToMe).fold(0, (s, e) => s + e.amount);
  double get payable =>
      debts.where((e) => !e.owedToMe).fold(0, (s, e) => s + e.amount);

  String money(double n) => n.toStringAsFixed(2);
  String dateText(DateTime d) => '${d.year}/${d.month}/${d.day}';

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addTransaction(bool isIncome) async {
    final title = TextEditingController();
    final amount = TextEditingController();
    final ok = await _showForm(
      title: isIncome ? 'إضافة إيراد' : 'إضافة مصروف',
      fields: [
        _field(title, 'البيان أو الوصف'),
        const SizedBox(height: 12),
        _field(amount, 'المبلغ', number: true),
      ],
      onSave: () {
        final n = _parseAmount(amount.text);
        if (title.text.trim().isEmpty || n == null || n <= 0) return false;
        transactions.insert(0, TransactionItem(
          title: title.text.trim(),
          amount: n,
          isIncome: isIncome,
          date: DateTime.now(),
        ));
        return true;
      },
    );
    title.dispose();
    amount.dispose();
    if (ok) { setState(() {}); await _save(); }
  }

  Future<void> _addClient() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final ok = await _showForm(
      title: 'إضافة عميل',
      fields: [
        _field(name, 'اسم العميل'),
        const SizedBox(height: 12),
        _field(phone, 'رقم الهاتف')
      ],
      onSave: () {
        if (name.text.trim().isEmpty) return false;
        clients.insert(0, ClientItem(
          name: name.text.trim(),
          phone: phone.text.trim(),
          createdAt: DateTime.now(),
        ));
        return true;
      },
    );
    name.dispose();
    phone.dispose();
    if (ok) {
      setState(() {});
      await _save();
    }
  }

  Future<void> _addDebt() async {
    final person = TextEditingController();
    final note = TextEditingController();
    final amount = TextEditingController();
    bool owedToMe = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة دين أو مستحق'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(person, 'اسم الشخص أو العميل'),
                  const SizedBox(height: 10),
                  _field(note, 'البيان (اختياري)'),
                  const SizedBox(height: 10),
                  _field(amount, 'المبلغ', number: true),
                  const SizedBox(height: 8),
                  RadioListTile<bool>(
                    value: true,
                    groupValue: owedToMe,
                    onChanged: (v) => refresh(() => owedToMe = v!),
                    title: const Text('مبلغ لي عند الآخرين'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<bool>(
                    value: false,
                    groupValue: owedToMe,
                    onChanged: (v) => refresh(() => owedToMe = v!),
                    title: const Text('مبلغ عليّ للآخرين'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final n = _parseAmount(amount.text);
                  if (person.text.trim().isEmpty || n == null || n <= 0) {
                    _message('أدخل الاسم والمبلغ بشكل صحيح');
                    return;
                  }
                  debts.insert(0, DebtItem(
                    person: person.text.trim(),
                    note: note.text.trim(),
                    amount: n,
                    owedToMe: owedToMe,
                    date: DateTime.now(),
                  ));
                  Navigator.pop(ctx, true);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );

    person.dispose();
    note.dispose();
    amount.dispose();

    if (ok == true) {
      setState(() {});
      await _save();
    }
  }

  Future<bool> _showForm({
    required String title,
    required List<Widget> fields,
    required bool Function() onSave,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: fields,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (!onSave()) {
                  _message('يرجى إدخال البيانات والمبلغ بشكل صحيح');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool number = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    );
  }

  double? _parseAmount(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> _deleteTransaction(int index) async {
    final item = transactions.removeAt(index);
    setState(() {});
    await _save();
    _message('تم حذف ${item.title}');
  }

  Future<void> _deleteDebt(int index) async {
    debts.removeAt(index);
    setState(() {});
    await _save();
    _message('تم حذف السجل');
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['الرئيسية', 'العمليات', 'العملاء', 'الديون'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'حساباتي • ${titles[tab]}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'معلومات التطبيق',
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: 'حساباتي',
                applicationVersion: '1.1.0',
                children: const [
                  Text('إدارة مالية محلية تعمل دون إنترنت.')
                ],
              ),
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : _page(),
        floatingActionButton: loading ? null : _fab(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'العمليات',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'العملاء',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'الديون',
            ),
          ],
        ),
      ),
    );
  }

  Widget? _fab() {
    if (tab == 1) {
      return FloatingActionButton.extended(
        onPressed: _chooseTransaction,
        icon: const Icon(Icons.add),
        label: const Text('عملية'),
      );
    }
    if (tab == 2) {
      return FloatingActionButton.extended(
        onPressed: _addClient,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('عميل'),
      );
    }
    if (tab == 3) {
      return FloatingActionButton.extended(
        onPressed: _addDebt,
        icon: const Icon(Icons.add),
        label: const Text('دين'),
      );
    }
    return null;
  }

  Future<void> _chooseTransaction() async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle, color: _green),
                title: const Text('إضافة إيراد'),
                onTap: () => Navigator.pop(ctx, true),
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle, color: _red),
                title: const Text('إضافة مصروف'),
                onTap: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null) _addTransaction(choice);
  }

  Widget _page() {
    if (tab == 1) return _transactionsPage();
    if (tab == 2) return _clientsPage();
    if (tab == 3) return _debtsPage();
    return _dashboard();
  }

  Widget _dashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2864DC), Color(0xFF173B80)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الرصيد الحالي',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                '${money(balance)} ر.ي',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              const Divider(color: Colors.white30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('عدد العمليات',
                      style: TextStyle(color: Colors.white70)),
                  Text('${transactions.length}',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'الإيرادات',
                income,
                _green,
                Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                'المصروفات',
                expenses,
                _red,
                Icons.trending_down,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'مستحقات لي',
                receivable,
                _blue,
                Icons.call_received,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                'مستحقات عليّ',
                payable,
                Colors.orange,
                Icons.call_made,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'الوصول السريع',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: _navy,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickButton(
                'إيراد',
                Icons.add_circle_outline,
                _green,
                () => _addTransaction(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickButton(
                'مصروف',
                Icons.remove_circle_outline,
                _red,
                () => _addTransaction(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _quickButton(
                'عميل جديد',
                Icons.person_add_alt_1,
                _blue,
                _addClient,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickButton(
                'دين جديد',
                Icons.account_balance_wallet,
                Colors.orange,
                _addDebt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'آخر العمليات',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: _navy,
          ),
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          _empty('لا توجد عمليات مالية حتى الآن')
        else
          ...transactions.take(5).map((item) => _transactionTile(item)),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 7),
          FittedBox(
            child: Text(
              '${money(amount)} ر.ي',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback action,
  ) {
    return ElevatedButton.icon(
      onPressed: action,
      icon: Icon(icon, color: color),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _transactionsPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'إجمالي العمليات: ${transactions.length}',
          style: const TextStyle(
            color: _navy,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          _empty('لا توجد عمليات مسجلة')
        else
          ...List.generate(
            transactions.length,
            (index) => _transactionTile(
              transactions[index],
              onDelete: () => _deleteTransaction(index),
            ),
          ),
      ],
    );
  }

  Widget _transactionTile(
    TransactionItem item, {
    VoidCallback? onDelete,
  }) {
    final color = item.isIncome ? _green : _red;
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(25),
          child: Icon(
            item.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: _navy,
          ),
        ),
        subtitle: Text(
          dateText(item.date),
          style: const TextStyle(color: Colors.black54),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${item.isIncome ? '+' : '-'}${money(item.amount)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: _red),
              ),
          ],
        ),
      ),
    );
  }

  Widget _clientsPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'عدد العملاء: ${clients.length}',
          style: const TextStyle(
            color: _navy,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (clients.isEmpty)
          _empty('لم تتم إضافة عملاء بعد')
        else
          ...List.generate(clients.length, (index) {
            final client = clients[index];
            return Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE5EDFF),
                  child: Icon(Icons.person, color: _blue),
                ),
                title: Text(
                  client.name,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  client.phone.isEmpty ? 'لا يوجد رقم هاتف' : client.phone,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: _red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('حذف العميل'),
                        content: Text('هل تريد حذف ${client.name}؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('حذف'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      clients.removeAt(index);
                      setState(() {});
                      await _save();
                    }
                  },
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _debtsPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'لي عند الآخرين',
                receivable,
                _green,
                Icons.call_received,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                'عليّ للآخرين',
                payable,
                _red,
                Icons.call_made,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'سجل الديون والمستحقات',
          style: TextStyle(
            color: _navy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 10),
        if (debts.isEmpty)
          _empty('لا توجد ديون أو مستحقات مسجلة')
        else
          ...List.generate(debts.length, (index) {
            final debt = debts[index];
            final color = debt.owedToMe ? _green : _red;
            return Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withAlpha(25),
                  child: Icon(Icons.account_balance_wallet, color: color),
                ),
                title: Text(
                  debt.person,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${debt.owedToMe ? 'مبلغ لي' : 'مبلغ عليّ'}'
                  '${debt.note.isEmpty ? '' : ' • ${debt.note}'}'
                  '\n${dateText(debt.date)}',
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      money(debt.amount),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: _red,
                      ),
                      onPressed: () => _deleteDebt(index),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _empty(String text) {
    return Container(
      padding: const EdgeInsets.all(35),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
