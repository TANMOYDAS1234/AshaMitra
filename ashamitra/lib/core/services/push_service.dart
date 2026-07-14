import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../theme/app_colors.dart';
import '../utils/logger.dart';
import 'api_service.dart';

/// Firebase Cloud Messaging, app side.
///
/// The backend (see server.js `sendPush`) sends a message with BOTH a
/// `notification` block and `data.link`. That split matters:
///
///   • app backgrounded or closed → Android's system tray renders the
///     notification itself, with no Dart code running. This is the case that
///     actually matters (a RED alert at 2am), and it's why we don't register an
///     `onBackgroundMessage` isolate — it would spin up a second Dart VM per
///     alert to do nothing the OS isn't already doing.
///   • app in the foreground → Android delivers the message to us and shows
///     NOTHING. We surface an in-app banner ourselves ([_showForeground]).
///
/// Permission is requested at *registration* time, not at app start: an ASHA
/// worker who is asked "allow notifications?" before she has even logged in
/// will say no, and Android 13+ never asks again.
class PushService {
  PushService._();

  /// This handset's FCM token, cached after the first fetch. Also what we send
  /// to DELETE /auth/fcm-token on logout.
  static String? _fcmToken;

  static bool _wired = false;

  /// A notification tapped while the app was closed. The tap arrives before
  /// routing is ready, so we park the link and let the splash consume it once
  /// the user is on their home screen — see [takePendingLink].
  static String? _pendingLink;

  /// Routes the server is allowed to send us to. Never `Get.toNamed` a raw
  /// server-supplied string: a bad (or hostile) `link` would otherwise push an
  /// arbitrary route, and an unknown one throws.
  static const _allowedLinks = <String>{
    AppRoutes.home,
    AppRoutes.reports,
    AppRoutes.adminReports,
    AppRoutes.dueList,
    AppRoutes.readinessSummary,
  };

  /// Wire up the listeners. Safe to call before login — it does not prompt for
  /// permission and does not touch the network.
  static Future<void> init() async {
    if (_wired) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // No google-services.json (a clean clone that hasn't dropped it in), or a
      // device with no Play Services. Push is a bonus channel — every alert is
      // ALSO written to the in-app notification list by the backend, so the app
      // must keep working without it.
      AppLogger.prod('[push] Firebase init failed, push disabled: $e');
      return;
    }
    _wired = true;

    // Token rotation: FCM re-issues on reinstall, restore, and app-data clear.
    // A stale token is a silently-undelivered alert, so re-register immediately.
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _fcmToken = t;
      if (ApiService.token != null) {
        unawaited(ApiService.registerFcmToken(t).catchError((_) => false));
      }
    });

    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _openLink(_linkOf(m)));

    // App was terminated and launched BY the notification tap.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _pendingLink = _linkOf(initial);
  }

  /// Ask for permission, fetch the token, attach it to the logged-in account.
  /// Called on login and on a restored session. Fire-and-forget: a failure here
  /// must never block the user from getting into the app.
  ///
  /// Every exit path logs via [AppLogger.prod], i.e. it survives into release
  /// builds. That is deliberate: a handset that fails to register is a handset
  /// that will never ring for a maternal emergency, and there is no UI anywhere
  /// that would reveal it. Debug-only logging here means the failure is
  /// invisible precisely where it matters. No PII is logged.
  static Future<void> registerWithBackend() async {
    if (!_wired) {
      AppLogger.prod('[push] skipped: Firebase not initialised');
      return;
    }
    if (ApiService.token == null) {
      AppLogger.prod('[push] skipped: no session');
      return;
    }
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        AppLogger.prod('[push] notification permission denied by user');
        return;
      }
      final t = _fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (t == null) {
        AppLogger.prod('[push] FCM returned no token for this device');
        return;
      }
      _fcmToken = t;
      final ok = await ApiService.registerFcmToken(t);
      AppLogger.prod(ok
          ? '[push] device registered'
          : '[push] backend refused the token');
    } catch (e) {
      AppLogger.prod('[push] register failed: $e');
    }
  }

  /// Detach this device from the account on logout.
  ///
  /// MUST run before the JWT is cleared — the route is authenticated. There is
  /// deliberately no `await` before the HTTP call is issued: an async body runs
  /// synchronously up to its first await, so the Authorization header is built
  /// while the token is still valid, even though logout() clears it on the very
  /// next line. Fire-and-forget; we don't hold up the logout for a network hop.
  static void detach() {
    final t = _fcmToken;
    if (t == null || ApiService.token == null) return;
    _fcmToken = null;
    unawaited(ApiService.unregisterFcmToken(t).catchError((_) {}));
  }

  /// Consume a tap that launched the app from a terminated state. Returns null
  /// if there wasn't one.
  static String? takePendingLink() {
    final l = _pendingLink;
    _pendingLink = null;
    return l;
  }

  static String? _linkOf(RemoteMessage m) {
    final l = m.data['link']?.toString();
    return (l != null && _allowedLinks.contains(l)) ? l : null;
  }

  static void _openLink(String? link) {
    if (link == null) return;
    if (ApiService.token == null) return; // logged out — don't deep-link past login
    Get.toNamed(link);
  }

  /// Foreground: Android hands us the message and draws nothing, so we do.
  static void _showForeground(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    final link = _linkOf(m);
    Get.snackbar(
      n.title ?? 'ASHA Mitra',
      n.body ?? '',
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.emergencyRed,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 14,
      duration: const Duration(seconds: 6),
      icon: const Icon(Icons.notifications_active, color: Colors.white),
      shouldIconPulse: true,
      onTap: link == null ? null : (_) => _openLink(link),
      mainButton: link == null
          ? null
          : TextButton(
              onPressed: () {
                if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
                _openLink(link);
              },
              child: const Text('দেখুন',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
    );
  }
}
