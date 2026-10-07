import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// เดสก์ท็อปต้องสลับไปใช้ FFI ส่วน Android/iOS ใช้ sqflite ปกติ
void initDatabaseFactory() {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
