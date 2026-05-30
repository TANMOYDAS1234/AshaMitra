import 'package:flutter/foundation.dart';

/// Logger that's silent in release builds.
///
/// `debugPrint` runs in BOTH debug and release — only the `kDebugMode`
/// gate actually strips output for production APKs. Use [AppLogger]
/// instead of `print` everywhere to avoid leaking patient data into
/// logcat when the app ships.
///
/// For events that MUST surface in release (auth failures, fatal
/// exceptions you'd send to crash reporting), use [AppLogger.prod].
class AppLogger {
  static void d(String msg) {
    if (kDebugMode) debugPrint('[DEBUG] $msg');
  }

  static void i(String msg) {
    if (kDebugMode) debugPrint('[INFO] $msg');
  }

  static void e(String msg, [Object? err, StackTrace? st]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $msg${err != null ? ' :: $err' : ''}');
      if (st != null) debugPrint(st.toString());
    }
  }

  /// Always logs, even in release. Reserve for genuine errors that
  /// should reach crash reporting later. Never include patient PII.
  static void prod(String msg) => debugPrint('[PROD] $msg');
}
