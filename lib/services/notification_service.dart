import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const _alarmChannelId = 'habit_alarm_v2';
const _alarmChannelName = 'Habit alarms';
const _alarmChannelDescription = 'Sounding daily alarms for your habits';
const _snoozeActionId = 'remind_later';

Future<void> _setDeviceTimezone() async {
  try {
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
  } catch (_) {
    // Keep the timezone package default if the native timezone cannot be read.
  }
}

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  if (response.actionId != _snoozeActionId) return;

  tz.initializeTimeZones();
  await _setDeviceTimezone();

  final plugin = FlutterLocalNotificationsPlugin();
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await plugin.initialize(settings);

  final id = response.id;
  final habitName = (response.payload ?? '').trim();
  if (id == null || habitName.isEmpty) return;

  final scheduled = tz.TZDateTime.now(tz.local).add(
    const Duration(minutes: 10),
  );
  final details = _alarmDetails();

  try {
    await plugin.zonedSchedule(
      id,
      habitName,
      'Daily habit reminder',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: habitName,
    );
  } catch (_) {
    await plugin.zonedSchedule(
      id,
      habitName,
      'Daily habit reminder',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: habitName,
    );
  }
}

NotificationDetails _alarmDetails() {
  return const NotificationDetails(
    android: AndroidNotificationDetails(
      _alarmChannelId,
      _alarmChannelName,
      channelDescription: _alarmChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _snoozeActionId,
          'Remind me later',
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'dismiss',
          'Dismiss',
          cancelNotification: true,
        ),
      ],
    ),
  );
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    await _setDeviceTimezone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _initialized = true;
  }

  Future<void> scheduleDaily({
    required int id,
    required String habitName,
    required int hour,
    required int minute,
  }) async {
    await initialize();
    await cancel(id);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final details = _alarmDetails();

    try {
      await _plugin.zonedSchedule(
        id,
        habitName,
        'Daily habit reminder',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: habitName,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id,
        habitName,
        'Daily habit reminder',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: habitName,
      );
    }
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> showTestNotification() async {
    await initialize();
    await _plugin.show(
      999999,
      'Habit alarm test',
      'Sound and alarm actions are working.',
      _alarmDetails(),
    );
  }
}
