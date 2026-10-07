// lib/providers/transaction_provider.dart
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/my_transaction.dart';

class TransactionProvider with ChangeNotifier {
  static const String _dbName = 'expenses.db';
  static const String _tableName = 'transactions';
  static const int _dbVersion = 2; // v1 เดิม -> v2 เพิ่มคอลัมน์ note

  Database? _database;
  Future<void>? _initFuture; // กันเปิดฐานข้อมูลซ้ำเมื่อมีหลายคำสั่งเรียกพร้อมกัน
  List<MyTransaction> _transactions = [];
  double _balanceFromSql = 0;

  List<MyTransaction> get transactions => [..._transactions];

  /// ยอดคงเหลือที่คำนวณในฐานข้อมูลด้วย SUM (ความท้าทายข้อ 2)
  double get balanceFromSql => _balanceFromSql;

  /// ยอดคงเหลือที่วนบวกใน Dart (ไว้เทียบกับ SQL)
  double get balanceFromDart => _transactions.fold(
        0.0,
        (sum, t) => t.type == TransactionType.income
            ? sum + t.amount
            : sum - t.amount,
      );

  TransactionProvider() {
    fetchAndSetTransactions();
  }

  // ---------- เปิดฐานข้อมูล ----------
  Future<void> _initDatabase() => _initFuture ??= _open();

  Future<void> _open() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);
      _database = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      debugPrint('Database initialized at $path');
    } catch (e) {
      debugPrint('Error initializing database: $e');
      _initFuture = null; // ให้ลองเปิดใหม่ได้
    }
  }

  // โครงสร้างล่าสุดเสมอ (ต้องได้ผลตรงกับเครื่องที่ไล่ onUpgrade มา)
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('Creating table $_tableName (v$version)...');
    await db.execute('''
      CREATE TABLE $_tableName(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        amount REAL,
        date TEXT,
        type TEXT,
        note TEXT
      )
    ''');

    await _seedSampleData(db);
  }

  // ข้อมูลตัวอย่าง ใส่เฉพาะตอนสร้างฐานข้อมูลครั้งแรก
  Future<void> _seedSampleData(Database db) async {
    final now = DateTime.now();
    final samples = [
      MyTransaction(title: 'เงินเดือน', amount: 25000, date: now.subtract(const Duration(days: 6)), type: TransactionType.income, note: 'เงินเดือนประจำเดือน'),
      MyTransaction(title: 'ค่าอาหารกลางวัน', amount: 120, date: now.subtract(const Duration(days: 5)), type: TransactionType.expense, note: 'ข้าวมันไก่'),
      MyTransaction(title: 'ค่ารถไฟฟ้า', amount: 85, date: now.subtract(const Duration(days: 4)), type: TransactionType.expense),
      MyTransaction(title: 'ฟรีแลนซ์', amount: 3500, date: now.subtract(const Duration(days: 3)), type: TransactionType.income, note: 'งานออกแบบโลโก้'),
      MyTransaction(title: 'ค่าไฟ', amount: 1250, date: now.subtract(const Duration(days: 2)), type: TransactionType.expense, note: 'บิลประจำเดือน'),
      MyTransaction(title: 'กาแฟ', amount: 65, date: now.subtract(const Duration(days: 1)), type: TransactionType.expense),
      MyTransaction(title: 'ซื้อหนังสือ', amount: 390, date: now, type: TransactionType.expense, note: 'หนังสือ Flutter'),
    ];
    final batch = db.batch();
    for (final t in samples) {
      batch.insert(_tableName, t.toMap());
    }
    await batch.commit(noResult: true);
  }

  // ไล่ปรับทีละขั้นด้วย "<" ไม่ใช้ "==" เพื่อรองรับเครื่องที่ข้ามหลายเวอร์ชัน
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading DB $oldVersion -> $newVersion');
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN note TEXT');
    }
    // เวอร์ชันถัดไป: if (oldVersion < 3) { ... }
  }

  // ---------- Create ----------
  Future<void> addTransaction(
    String title,
    double amount,
    DateTime date,
    TransactionType type, {
    String? note,
  }) async {
    await _initDatabase();
    if (_database == null) return;

    final newTransaction = MyTransaction(
      title: title,
      amount: amount,
      date: date,
      type: type,
      note: note,
    );
    final id = await _database!.insert(_tableName, newTransaction.toMap());
    debugPrint('Inserted transaction with id: $id');
    await fetchAndSetTransactions();
  }

  // ---------- Read ----------
  Future<void> fetchAndSetTransactions() async {
    await _initDatabase();
    if (_database == null) return;

    final dataList = await _database!.query(_tableName, orderBy: 'date DESC');
    _transactions = dataList.map((item) => MyTransaction.fromMap(item)).toList();
    await _loadBalanceFromSql();
    debugPrint('Fetched ${_transactions.length} transactions.');
    notifyListeners();
  }

  // ความท้าทายข้อ 2: ให้ฐานข้อมูลรวมยอดเอง
  Future<void> _loadBalanceFromSql() async {
    final result = await _database!.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN type = ? THEN amount ELSE -amount END), 0)
             AS balance
      FROM $_tableName
    ''', [TransactionType.income.name]);
    _balanceFromSql = (result.first['balance'] as num).toDouble();
  }

  // ---------- Update ----------
  Future<void> updateTransaction(int id, MyTransaction newTransaction) async {
    await _initDatabase();
    if (_database == null) return;
    await _database!.update(
      _tableName,
      newTransaction.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    await fetchAndSetTransactions();
  }

  // ---------- Delete ----------
  Future<void> deleteTransaction(int id) async {
    await _initDatabase();
    if (_database == null) return;
    await _database!.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    await fetchAndSetTransactions();
  }

  // ---------- ความท้าทายข้อ 3: นำเข้า 100 รายการ ----------
  List<MyTransaction> _sampleData(int count) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      final isIncome = i % 4 == 0;
      return MyTransaction(
        title: 'ตัวอย่าง #${i + 1}',
        amount: 50.0 + (i % 20) * 10,
        date: now.subtract(Duration(minutes: i)),
        type: isIncome ? TransactionType.income : TransactionType.expense,
        note: 'นำเข้าอัตโนมัติ',
      );
    });
  }

  /// แบบที่ 1: เรียก addTransaction ทีละรายการ (แต่ละรายการ insert + query ใหม่)
  Future<Duration> importOneByOne([int count = 100]) async {
    final sw = Stopwatch()..start();
    for (final t in _sampleData(count)) {
      await addTransaction(t.title, t.amount, t.date, t.type, note: t.note);
    }
    sw.stop();
    return sw.elapsed;
  }

  /// แบบที่ 2: batch ภายใน transaction เดียว แล้วโหลดรายการครั้งเดียว
  Future<Duration> importWithBatch([int count = 100]) async {
    await _initDatabase();
    if (_database == null) return Duration.zero;
    final sw = Stopwatch()..start();
    await _database!.transaction((txn) async {
      final batch = txn.batch(); // ใช้ txn ห้ามใช้ _database ในบล็อกนี้
      for (final t in _sampleData(count)) {
        batch.insert(_tableName, t.toMap());
      }
      await batch.commit(noResult: true);
    });
    await fetchAndSetTransactions();
    sw.stop();
    return sw.elapsed;
  }

  Future<void> deleteAll() async {
    await _initDatabase();
    if (_database == null) return;
    await _database!.delete(_tableName); // ตั้งใจลบทุกแถว จึงไม่มี where
    await fetchAndSetTransactions();
  }
}
