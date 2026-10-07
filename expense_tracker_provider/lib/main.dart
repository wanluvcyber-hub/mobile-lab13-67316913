// lib/main.dart
import 'package:flutter/material.dart';
import 'db_init_io.dart' if (dart.library.js_interop) 'db_init_web.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/transaction_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initDatabaseFactory();
  runApp(
    ChangeNotifierProvider(
      create: (context) => TransactionProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const TransactionListScreen(),
    );
  }
}
