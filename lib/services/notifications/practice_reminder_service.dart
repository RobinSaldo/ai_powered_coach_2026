import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PracticeReminderService {
  PracticeReminderService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _notificationId = 9001;
  static const String _channelId = 'practice_reminders_channel';
  static const String _channelName = 'Practice Reminders';
  static const String _channelDescription =
      'Daily reminders for speaking practice';

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) {
      return true;
    }
    await initialize();

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await androidImpl?.requestNotificationsPermission();
    if (androidGranted == false) {
      return false;
    }

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted = await iosImpl?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosGranted == false) {
      return false;
    }

    final macImpl = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final macGranted = await macImpl?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (macGranted == false) {
      return false;
    }

    return true;
  }

  static Future<void> syncReminder({
    required bool enabled,
    required String preferredSessionLength,
  }) async {
    if (!enabled) {
      await cancelReminder();
      return;
    }
    await scheduleDailyReminder(preferredSessionLength: preferredSessionLength);
  }

  static Future<void> scheduleDailyReminder({
    required String preferredSessionLength,
  }) async {
    if (kIsWeb) {
      return;
    }
    await initialize();

    final granted = await requestPermission();
    if (!granted) {
      throw StateError('Notification permission denied.');
    }

    final now = DateTime.now();
    final localTarget = DateTime(now.year, now.month, now.day, 20, 0);
    final nextReminder = localTarget.isAfter(now)
        ? localTarget
        : localTarget.add(const Duration(days: 1));
    final scheduleAt = tz.TZDateTime.from(nextReminder, tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'AI Powered Coach Reminder',
      body: 'Practice your $preferredSessionLength speaking session now.',
      scheduledDate: scheduleAt,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> showTestReminder({
    required String preferredSessionLength,
  }) async {
    if (kIsWeb) {
      return;
    }
    await initialize();

    final granted = await requestPermission();
    if (!granted) {
      throw StateError('Notification permission denied.');
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      id: _notificationId + 1,
      title: 'AI Powered Coach (Test)',
      body: 'This is your $preferredSessionLength practice reminder.',
      notificationDetails: details,
    );
  }

  static Future<void> cancelReminder() async {
    if (kIsWeb) {
      return;
    }
    await initialize();
    await _plugin.cancel(id: _notificationId);
  }
}
