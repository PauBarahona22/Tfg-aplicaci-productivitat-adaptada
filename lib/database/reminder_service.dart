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

  /// Inicializa timezone, canal y permisos.
  Future<void> initialize() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

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

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'reminders_channel',
        'Recordatoris',
        description: 'Notificacions dels recordatoris',
        importance: Importance.max,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse details) {
    print('🔔 Notificación tocada, payload=${details.payload}');
    
  }

  Stream<List<ReminderModel>> streamReminders(String ownerId) {
    return _firestore
        .collection('reminders')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ReminderModel.fromDoc(d)).toList());
  }

  Future<String> addReminder(ReminderModel reminder) async {
    final doc = await _firestore.collection('reminders').add(reminder.toMap());
    final withId = reminder.copyWith(id: doc.id);
    if (withId.notificationsEnabled && withId.reminderTime != null) {
      await scheduleNotification(withId);
    }
    return doc.id;
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

  Future<void> scheduleNotification(ReminderModel reminder) async {
    await initialize();
    if (!reminder.notificationsEnabled || reminder.reminderTime == null) return;

    final id = reminder.id.hashCode;
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime.from(reminder.reminderTime!, tz.local);

    print('🕒 now=$now  scheduled=$scheduled');
    if (scheduled.isBefore(now)) {
      print('⚠️  Fecha pasada, no programada.');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Recordatoris',
      channelDescription: 'Notificacions dels recordatoris',
      importance: Importance.max,
      priority: Priority.high,
    );
    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      id,
      'Recordatori',
      reminder.title,
      scheduled,
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          _mapPatternToDateTimeComponents(reminder.repetitionPattern),
      payload: reminder.id,
    );
    print('✅ Programada notificación (ID $id) para $scheduled');
  }

  Future<void> cancelNotification(int id) async {
    await initialize();
    await _localNotifications.cancel(id);
    print('🗑  Cancelada notificación ID $id');
  }

  Future<void> completeReminderFromNotification(String reminderId) async {
    final snap =
        await _firestore.collection('reminders').doc(reminderId).get();
    if (!snap.exists) return;
    final r = ReminderModel.fromDoc(snap);
    await updateReminder(r.copyWith(isDone: true));
  }

  Future<void> delayReminderFromNotification(
      String reminderId, int minutes) async {
    final snap =
        await _firestore.collection('reminders').doc(reminderId).get();
    if (!snap.exists) return;
    final r = ReminderModel.fromDoc(snap);
    if (r.reminderTime == null) return;
    final newTime = r.reminderTime!.add(Duration(minutes: minutes));
    await updateReminder(r.copyWith(reminderTime: newTime));
  }

  DateTimeComponents? _mapPatternToDateTimeComponents(String p) {
    switch (p) {
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
}

