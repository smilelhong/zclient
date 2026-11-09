import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications for agent completion / pending-confirm (P2).
/// Fires only when the app is not in the foreground — the in-app
/// surfaces (chips, interaction cards) already cover the visible case.
class NotifyService {
  NotifyService._();
  static final instance = NotifyService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _appVisible = true;
  int _id = 1;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {}
  }

  void onLifecycleStateChanged(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
  }

  Future<void> show(String title, String body) async {
    if (!_ready || _appVisible) return;
    try {
      await _plugin.show(
        _id++,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'zclient_events',
            '会话事件',
            channelDescription: 'Agent 完成与待确认提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }
}
