import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

/// Keeps the Render free-tier backend awake so a worker never hits the
/// 15-30s cold-start "stuck on thinking" on the first request of a session.
///
/// Render naps after ~15 min with no traffic. This pings `/health`:
///   • once immediately on start,
///   • every [_interval] (10 min < the ~15 min nap) while the app is in the
///     FOREGROUND,
///   • again the instant the app is resumed.
/// It deliberately does NOT ping while backgrounded — when the app isn't
/// open, server warmth doesn't matter, and we save the worker's battery/data.
///
/// This is the app-side complement to server-side UptimeRobot: UptimeRobot
/// keeps the server warm 24/7 (so even the very first open of the day is
/// fast), while this covers quiet stretches during an active session. Both
/// are cheap; together they remove cold-start stalls.
class ServerHeartbeat with WidgetsBindingObserver {
  ServerHeartbeat._();
  static final ServerHeartbeat instance = ServerHeartbeat._();

  // 10 min keeps us comfortably under Render's ~15 min idle-nap threshold.
  static const _interval = Duration(minutes: 10);
  Timer? _timer;
  bool _started = false;

  /// Health URL derived from the API base (strips the trailing `/api`).
  Uri get _healthUri {
    final base = ApiConstants.baseUrl;
    final root =
        base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
    return Uri.parse('$root/health');
  }

  /// Begin heartbeating. Safe to call once at app start; no-ops if already on.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _ping();
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _ping());
  }

  Future<void> _ping() async {
    try {
      await http.get(_healthUri).timeout(const Duration(seconds: 6));
    } catch (_) {
      // Best-effort warmth — failures (offline, server waking) are harmless.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ping(); // wake the server the moment the worker returns to the app
      _arm();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _timer?.cancel(); // stop pinging while backgrounded
    }
  }
}
