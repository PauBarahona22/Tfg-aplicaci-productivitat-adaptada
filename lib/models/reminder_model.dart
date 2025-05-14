import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  final String id;
  final String ownerId;
  final String title;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? reminderTime;
  final bool isDone;
  final bool notificationsEnabled;
  final String? taskId;
  final String repetitionPattern;
  final List<DateTime> assignedDates;

  ReminderModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.createdAt,
    this.dueDate,
    this.reminderTime,
    this.isDone = false,
    this.notificationsEnabled = true,
    this.taskId,
    this.repetitionPattern = 'No repetir',
    this.assignedDates = const [],
  });

  ReminderModel copyWith({
    String? id,
    String? ownerId,
    String? title,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? reminderTime,
    bool? isDone,
    bool? notificationsEnabled,
    String? taskId,
    String? repetitionPattern,
    List<DateTime>? assignedDates,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      reminderTime: reminderTime ?? this.reminderTime,
      isDone: isDone ?? this.isDone,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      taskId: taskId ?? this.taskId,
      repetitionPattern: repetitionPattern ?? this.repetitionPattern,
      assignedDates: assignedDates ?? this.assignedDates,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'reminderTime': reminderTime?.toIso8601String(),
      'isDone': isDone,
      'notificationsEnabled': notificationsEnabled,
      'taskId': taskId,
      'repetitionPattern': repetitionPattern,
      'assignedDates': assignedDates.map((date) => date.toIso8601String()).toList(),
    };
  }

  factory ReminderModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    List<DateTime> assignedDates = [];
    if (data['assignedDates'] != null) {
      assignedDates = List<String>.from(data['assignedDates'] as List<dynamic>? ?? [])
          .map((dateStr) => DateTime.parse(dateStr))
          .toList();
    }
    
    return ReminderModel(
      id: doc.id,
      ownerId: data['ownerId'] as String,
      title: data['title'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      dueDate: data['dueDate'] != null
          ? DateTime.parse(data['dueDate'] as String)
          : null,
      reminderTime: data['reminderTime'] != null
          ? DateTime.parse(data['reminderTime'] as String)
          : null,
      isDone: data['isDone'] as bool? ?? false,
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      taskId: data['taskId'] as String?,
      repetitionPattern: data['repetitionPattern'] as String? ?? 'No repetir',
      assignedDates: assignedDates,
    );
  }
}