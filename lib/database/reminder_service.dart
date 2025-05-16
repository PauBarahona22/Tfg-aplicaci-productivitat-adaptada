import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';
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
    // Cuando se toca una notificación, verifica si necesita programar la siguiente repetición
    if (details.payload != null) {
      _checkAndScheduleNextRepetition(details.payload!);
    }
  }

  /// Verifica y programa la siguiente repetición de un recordatorio recurrente
  Future<void> _checkAndScheduleNextRepetition(String reminderId) async {
    final snap = await _firestore.collection('reminders').doc(reminderId).get();
    if (!snap.exists) return;
    
    final reminder = ReminderModel.fromDoc(snap);
    if (reminder.repetitionPattern == 'No repetir') return;
    
    // Solo verifica repeticiones para notificaciones activas
    if (reminder.notificationsEnabled && reminder.reminderTime != null) {
      // Garantiza que se programe la próxima repetición
      await _scheduleNextRepetition(reminder);
    }
  }

  /// Programa la siguiente repetición basada en el patrón
  Future<void> _scheduleNextRepetition(ReminderModel reminder) async {
    if (reminder.reminderTime == null) return;
    
    DateTime nextTime;
    final now = DateTime.now();
    final currentTime = reminder.reminderTime!;
    
    switch (reminder.repetitionPattern) {
      case 'Diàriament':
        // Siguiente día, misma hora
        nextTime = DateTime(
          now.year, 
          now.month, 
          now.day + 1,
          currentTime.hour, 
          currentTime.minute,
        );
        break;
      case 'Setmanalment':
        // Siguiente semana, mismo día de la semana
        nextTime = DateTime(
          now.year, 
          now.month, 
          now.day + 7,
          currentTime.hour, 
          currentTime.minute,
        );
        break;
      case 'Mensualment':
        // Siguiente mes, mismo día del mes (con ajuste si necesario)
        var nextMonth = now.month + 1;
        var nextYear = now.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        
        // Ajustar el día si el mes siguiente no tiene tantos días
        var day = currentTime.day;
        int daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (day > daysInNextMonth) {
          day = daysInNextMonth;
        }
        
        nextTime = DateTime(
          nextYear, 
          nextMonth, 
          day,
          currentTime.hour, 
          currentTime.minute,
        );
        break;
      default:
        return; // Patrón no reconocido
    }
    
    // Actualizar el recordatorio con el nuevo tiempo
    final updatedReminder = reminder.copyWith(reminderTime: nextTime);
    await updateReminder(updatedReminder);
    
    print('🔄 Próxima repetición programada: $nextTime');
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
    
    // Cancelar cualquier notificación previa
    await cancelNotification(reminder.id.hashCode);
    
    // Solo programar nueva notificación si está habilitada y tiene tiempo
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

    // Notificación simplificada sin acciones
    final androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Recordatoris',
      channelDescription: 'Notificacions dels recordatoris',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'notification_icon',
      color: const Color(0xFF5DC1B9),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
    
    // Marcar como completado
    await updateReminder(r.copyWith(isDone: true));
    
    // Si era un recordatorio recurrente, programar la próxima ocurrencia
    if (r.repetitionPattern != 'No repetir') {
      await _checkAndScheduleNextRepetition(reminderId);
    }
  }

  Future<void> delayReminderFromNotification(String reminderId, int minutes) async {
    final snap = await _firestore.collection('reminders').doc(reminderId).get();
    if (!snap.exists) return;
    final r = ReminderModel.fromDoc(snap);
    
    // Crear un nuevo tiempo basado en el momento actual + minutos
    final newTime = DateTime.now().add(Duration(minutes: minutes));
    print('🕘 Programando nueva notificación para: $newTime');
    
    try {
      // Cancelar la notificación anterior para este ID
      await cancelNotification(r.id.hashCode);
      
      // Programar una notificación simplificada
      final id = r.id.hashCode;
      final scheduled = tz.TZDateTime.from(newTime, tz.local);
      
      final androidDetails = AndroidNotificationDetails(
        'reminders_channel',
        'Recordatoris',
        channelDescription: 'Notificacions dels recordatoris',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'notification_icon',
        color: const Color(0xFF5DC1B9),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
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
        'Recordatori (ajornat)',
        r.title,
        scheduled,
        details,
        androidAllowWhileIdle: true,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: r.id,
      );
      
      print('✅ Notificación aplazada programada exitosamente para $scheduled');
      
      // Actualizar el recordatorio en Firestore (opcional)
      await _firestore.collection('reminders').doc(r.id).update({
        'reminderTime': newTime.toIso8601String()
      });
      
    } catch (e) {
      print('⚠️ Error al programar la notificación aplazada: $e');
    }
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

  Future<void> assignReminderToCalendar(ReminderModel reminder, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    List<DateTime> assignedDates = List.from(reminder.assignedDates);
    
    bool alreadyAssigned = assignedDates.any((d) => 
      d.year == normalizedDate.year && 
      d.month == normalizedDate.month && 
      d.day == normalizedDate.day
    );
    
    if (!alreadyAssigned) {
      assignedDates.add(normalizedDate);
      
      final updatedReminder = reminder.copyWith(assignedDates: assignedDates);
      await updateReminder(updatedReminder);
    }
  }
  
  Future<void> removeAssignedDate(ReminderModel reminder, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    List<DateTime> assignedDates = List.from(reminder.assignedDates);
    assignedDates.removeWhere((d) => 
      d.year == normalizedDate.year && 
      d.month == normalizedDate.month && 
      d.day == normalizedDate.day
    );
    
    final updatedReminder = reminder.copyWith(assignedDates: assignedDates);
    await updateReminder(updatedReminder);
  }
}