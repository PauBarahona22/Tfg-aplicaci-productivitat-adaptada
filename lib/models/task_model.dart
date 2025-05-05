import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String ownerId;
  final String title;
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool isDone;
  final int priority;
  final String type;
  final bool remind;
  final List<String> subtasks;

  TaskModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.createdAt,
    this.dueDate,
    this.isDone = false,
    this.priority = 0,
    this.type = '',
    this.remind = false,
    this.subtasks = const [],
  });

  TaskModel copyWith({
    String? id,
    String? ownerId,
    String? title,
    DateTime? createdAt,
    DateTime? dueDate,
    bool? isDone,
    int? priority,
    String? type,
    bool? remind,
    List<String>? subtasks,
  }) {
    return TaskModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      isDone: isDone ?? this.isDone,
      priority: priority ?? this.priority,
      type: type ?? this.type,
      remind: remind ?? this.remind,
      subtasks: subtasks ?? this.subtasks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'isDone': isDone,
      'priority': priority,
      'type': type,
      'remind': remind,
      'subtasks': subtasks,
    };
  }

  factory TaskModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TaskModel(
      id: doc.id,
      ownerId: data['ownerId'] as String,
      title: data['title'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      dueDate: data['dueDate'] != null
          ? DateTime.parse(data['dueDate'] as String)
          : null,
      isDone: data['isDone'] as bool? ?? false,
      priority: data['priority'] as int? ?? 0,
      type: data['type'] as String? ?? '',
      remind: data['remind'] as bool? ?? false,
      subtasks: List<String>.from(data['subtasks'] as List<dynamic>? ?? []),
    );
  }
}
