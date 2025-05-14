import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/reminder_model.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Inicializa zona horaria, canal y permisos de notificación.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1) Timezone
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 2) Inicialización del plugin
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 3) Crear canal Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'reminders_channel',
        'Recordatoris',
        description: 'Notificacions dels recordatoris',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 4) PEDIR PERMISO EN ANDROID 13+
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  /// Handler al pulsar la notificación
  void _onNotificationTapped(NotificationResponse response) {
    print('Notificación tocada, payload: ${response.payload}');
  }

  /// Devuelve un stream de recordatorios del usuario
  Stream<List<ReminderModel>> streamReminders(String ownerId) {
    return _firestore
        .collection('reminders')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ReminderModel.fromDoc(d)).toList());
  }

  Future<String> addReminder(ReminderModel reminder) async {
    final docRef =
        await _firestore.collection('reminders').add(reminder.toMap());
    final withId = reminder.copyWith(id: docRef.id);
    if (withId.notificationsEnabled && withId.reminderTime != null) {
      await scheduleNotification(withId);
    }
    return docRef.id;
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    await _firestore
        .collection('reminders')
        .doc(reminder.id)
        .update(reminder.toMap());
    await cancelNotification(reminder.id.hashCode);
    if (reminder.notificationsEnabled && reminder.reminderTime != null) {
      await scheduleNotification(reminder);
    }
  }

  Future<void> deleteReminder(String id) async {
    await _firestore.collection('reminders').doc(id).delete();
    await cancelNotification(id.hashCode);
  }

  /// Programa la notificación (o la muestra inmediatamente si la hora ya pasó)
  Future<void> scheduleNotification(ReminderModel reminder) async {
    await initialize();
    if (!reminder.notificationsEnabled || reminder.reminderTime == null) return;

    final id = reminder.id.hashCode;
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime.from(reminder.reminderTime!, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders_channel',
        'Recordatoris',
        channelDescription: 'Notificacions dels recordatoris',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true,
      ),
    );

    if (scheduled.isBefore(now)) {
      // Si la hora ya pasó, muéstrala inmediatamente
      await _localNotifications.show(
        id,
        'Recordatori',
        reminder.title,
        details,
        payload: reminder.id,
      );
    } else {
      await _localNotifications.zonedSchedule(
        id,
        'Recordatori',
        reminder.title,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents:
            _mapPatternToDateTimeComponents(reminder.repetitionPattern),
        payload: reminder.id,
      );
    }
  }

  /// Mapea el patrón de repetición a DateTimeComponents
  DateTimeComponents? _mapPatternToDateTimeComponents(String pattern) {
    switch (pattern) {
      case 'Diàriament':
        return DateTimeComponents.time;
      case 'Setmanalment':
        return DateTimeComponents.dayOfWeekAndTime;
      case 'Mensualment':
        return DateTimeComponents.dayOfMonthAndTime;
      default:
        return null;
    }
  }

  Future<void> cancelNotification(int id) async {
    await initialize();
    await _localNotifications.cancel(id);
  }

  /// Completar recordatorio desde notificación
  Future<void> completeReminderFromNotification(String reminderId) async {
    final docSnap = await _firestore.collection('reminders').doc(reminderId).get();
    if (!docSnap.exists) return;
    final reminder = ReminderModel.fromDoc(docSnap);
    final updated = reminder.copyWith(isDone: true);
    await updateReminder(updated);
  }

  /// Aplazar recordatorio desde notificación
  Future<void> delayReminderFromNotification(String reminderId, int minutes) async {
    final docSnap = await _firestore.collection('reminders').doc(reminderId).get();
    if (!docSnap.exists) return;
    final reminder = ReminderModel.fromDoc(docSnap);
    if (reminder.reminderTime == null) return;
    final newTime = reminder.reminderTime!.add(Duration(minutes: minutes));
    final updated = reminder.copyWith(reminderTime: newTime);
    await updateReminder(updated);
  }
}
