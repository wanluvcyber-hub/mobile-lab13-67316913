import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// เว็บใช้ SQLite แบบ WASM (ข้อมูลเก็บใน IndexedDB ของเบราว์เซอร์)
void initDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}
