import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HisabatiApp());
}

class HisabatiApp extends StatelessWidget {
  const HisabatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'حساباتي',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF10141F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3978F6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
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

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      title: json['title'],
      amount: (json['amount'] as num).toDouble(),
      isIncome: json['isIncome'],
      date: DateTime.parse(json['date']),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TransactionItem> transactions = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('hisabati_transactions');

    if (saved != null) {
      final List data = jsonDecode(saved);
      transactions = data
          .map((item) => TransactionItem.fromJson(item))
          .toList();
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'hisabati_transactions',
      jsonEncode(transactions.map((e) => e.toJson()).toList()),
    );
  }

  double get income => transactions
      .where((e) => e.isIncome)
      .fold(0, (sum, e) => sum + e.amount);

  double get expenses => transactions
      .where((e) => !e.isIncome)
      .fold(0, (sum, e) => sum + e.amount);

  double get balance => income - expenses;

  String money(double value) => value.toStringAsFixed(2);

  Future<void> addTransaction(bool isIncome) async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isIncome ? 'إضافة إيراد' : 'إضافة مصروف'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'البيان أو الوصف',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(
                    amountController.text.trim(),
                  );

                  if (titleController.text.trim().isEmpty ||
                      amount == null ||
                      amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('أدخل البيان والمبلغ بشكل صحيح'),
                      ),
                    );
                    return;
                  }

                  transactions.insert(
                    0,
                    TransactionItem(
                      title: titleController.text.trim(),
                      amount: amount,
                      isIncome: isIncome,
                      date: DateTime.now(),
                    ),
                  );

                  Navigator.pop(dialogContext, true);
                },
                child: const Text('حفظ العملية'),
              ),
            ],
          ),
        );
      },
    );

    titleController.dispose();
    amountController.dispose();

    if (result == true && mounted) {
      setState(() {});
      await saveTransactions();
    }
  }

  Future<void> deleteTransaction(int index) async {
    final removed = transactions.removeAt(index);
    setState(() {});
    await saveTransactions();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حذف: ${removed.title}')),
    );
  }

  String dateText(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'حساباتي',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF171E2C),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2465D9),
                          Color(0xFF153C82),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إجمالي الرصيد',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 17,
                          ),
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
                            const Text('رصيدك الحالي'),
                            Text('${transactions.length} عملية'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: summaryCard(
                          'الإيرادات',
                          income,
                          Colors.greenAccent,
                          Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: summaryCard(
                          'المصروفات',
                          expenses,
                          Colors.redAccent,
                          Icons.trending_down,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: actionButton(
                          'إضافة إيراد',
                          Colors.green.shade700,
                          Icons.add,
                          () => addTransaction(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: actionButton(
                          'إضافة مصروف',
                          Colors.red.shade700,
                          Icons.remove,
                          () => addTransaction(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'سجل العمليات',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(35),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 55,
                            color: Colors.white38,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'لا توجد عمليات مالية بعد',
                            style: TextStyle(color: Colors.white60),
                          ),
                          Text(
                            'ابدأ بإضافة إيراد أو مصروف',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(transactions.length, (index) {
                      final item = transactions[index];

                      return Card(
                        color: const Color(0xFF1B2332),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.isIncome
                                ? Colors.green.withAlpha(35)
                                : Colors.red.withAlpha(35),
                            child: Icon(
                              item.isIncome
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: item.isIncome
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(dateText(item.date)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${item.isIncome ? '+' : '-'}${money(item.amount)}',
                                style: TextStyle(
                                  color: item.isIncome
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                onPressed: () => deleteTransaction(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget summaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2332),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 7),
          FittedBox(
            child: Text(
              '${money(amount)} ر.ي',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget actionButton(
    String title,
    Color color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}