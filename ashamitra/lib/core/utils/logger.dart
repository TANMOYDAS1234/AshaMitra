import 'package:flutter/foundation.dart';

class AppLogger {
  static void d(String msg) => debugPrint('[DEBUG] $msg');
  static void e(String msg) => debugPrint('[ERROR] $msg');
  static void i(String msg) => debugPrint('[INFO] $msg');
}
