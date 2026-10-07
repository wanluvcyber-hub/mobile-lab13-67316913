// lib/screens/add_edit_transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/my_transaction.dart';
import '../providers/transaction_provider.dart';

/// ฟอร์มเพิ่ม/แก้ไขรายการ ถ้าส่ง [transaction] มาจะเป็นโหมดแก้ไข
class AddEditTransactionScreen extends StatefulWidget {
  final MyTransaction? transaction;
  const AddEditTransactionScreen({super.key, this.transaction});

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _date;
  late TransactionType _type;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _titleController = TextEditingController(text: t?.title ?? '');
    _amountController =
        TextEditingController(text: t != null ? t.amount.toString() : '');
    _noteController = TextEditingController(text: t?.note ?? '');
    _date = t?.date ?? DateTime.now();
    _type = t?.type ?? TransactionType.expense;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TransactionProvider>();
    final navigator = Navigator.of(context);
    final title = _titleController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    if (_isEditing) {
      await provider.updateTransaction(
        widget.transaction!.id!,
        MyTransaction(
          id: widget.transaction!.id,
          title: title,
          amount: amount,
          date: _date,
          type: _type,
          note: note,
        ),
      );
    } else {
      await provider.addTransaction(title, amount, _date, _type, note: note);
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'แก้ไขรายการ' : 'เพิ่มรายการ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('รายจ่าย'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('รายรับ'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อรายการ',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อรายการ' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'จำนวนเงิน (บาท)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final value = double.tryParse((v ?? '').trim());
                  if (value == null) return 'กรุณากรอกตัวเลข';
                  if (value <= 0) return 'จำนวนเงินต้องมากกว่า 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'บันทึกเพิ่มเติม (ไม่บังคับ)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat.yMMMd().format(_date)),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: const Text('เลือกวันที่'),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text(_isEditing ? 'บันทึกการแก้ไข' : 'บันทึก'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
