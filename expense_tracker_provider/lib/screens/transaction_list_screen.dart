// lib/screens/transaction_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/my_transaction.dart';
import '../providers/transaction_provider.dart';
import 'add_edit_transaction_screen.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  void _openForm(BuildContext context, [MyTransaction? tx]) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditTransactionScreen(transaction: tx)),
    );
  }

  Future<void> _runImport(
    BuildContext context,
    String label,
    Future<Duration> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final elapsed = await action();
    messenger.showSnackBar(
      SnackBar(content: Text('$label ใช้เวลา ${elapsed.inMilliseconds} ms')),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, MyTransaction tx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบรายการ?'),
        content: Text('ต้องการลบ "${tx.title}" ใช่หรือไม่'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ลบ')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายรับ-รายจ่าย'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'one':
                  _runImport(context, 'นำเข้า 100 รายการทีละรายการ',
                      provider.importOneByOne);
                case 'batch':
                  _runImport(context, 'นำเข้า 100 รายการด้วย batch',
                      provider.importWithBatch);
                case 'clear':
                  provider.deleteAll();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'one', child: Text('นำเข้า 100 (ทีละรายการ)')),
              PopupMenuItem(value: 'batch', child: Text('นำเข้า 100 (batch)')),
              PopupMenuItem(value: 'clear', child: Text('ลบทั้งหมด')),
            ],
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, tp, child) {
          final money = NumberFormat('#,##0.00');
          return Column(
            children: [
              // ความท้าทายข้อ 2: ยอดคงเหลือจาก SQL SUM ใต้ AppBar
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.primaryContainer,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('ยอดคงเหลือ'),
                    Text(
                      '${money.format(tp.balanceFromSql)} บาท',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      'เทียบกับคำนวณใน Dart: ${money.format(tp.balanceFromDart)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tp.transactions.isEmpty
                    ? const Center(child: Text('ไม่มีรายการ'))
                    : ListView.builder(
                        itemCount: tp.transactions.length,
                        itemBuilder: (ctx, i) {
                          final tx = tp.transactions[i];
                          final isIncome = tx.type == TransactionType.income;
                          return ListTile(
                            onTap: () => _openForm(context, tx), // แตะเพื่อแก้ไข
                            leading: CircleAvatar(
                              child: Text(isIncome ? 'รับ' : 'จ่าย'),
                            ),
                            title: Text(tx.title),
                            subtitle: Text(
                              [
                                DateFormat.yMMMd().format(tx.date),
                                if (tx.note != null) tx.note!,
                              ].join(' • '),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${money.format(tx.amount)} บาท',
                                  style: TextStyle(
                                    color: isIncome ? Colors.green : Colors.red,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.grey),
                                  onPressed: () async {
                                    if (await _confirmDelete(context, tx)) {
                                      provider.deleteTransaction(tx.id!);
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
