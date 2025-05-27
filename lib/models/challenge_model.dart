import 'package:cloud_firestore/cloud_firestore.dart';
class ChallengeModel {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool isCompleted;
  final String type; 
  final String category; 
  final int targetCount; 
  final int currentCount; 
  final bool isExpired; 
  final bool isPredefined; 
  ChallengeModel({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description = '',
    required this.createdAt,
    this.dueDate,
    this.isCompleted = false,
    this.type = 'Personal',
    this.category = 'General',
    this.targetCount = 1,
    this.currentCount = 0,
    this.isExpired = false,
    this.isPredefined = false,
  });
  ChallengeModel copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? dueDate,
    bool? isCompleted,
    String? type,
    String? category,
    int? targetCount,
    int? currentCount,
    bool? isExpired,
    bool? isPredefined,
  }) {
    return ChallengeModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      type: type ?? this.type,
      category: category ?? this.category,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      isExpired: isExpired ?? this.isExpired,
      isPredefined: isPredefined ?? this.isPredefined,
    );
  }
  String get medalType {
    switch (category) {
      case 'Acadèmica': return 'Acadèmica';
      case 'Deportiva': return 'Deportiva';
      case 'Musical': return 'Musical';
      case 'Familiar': return 'Familiar';
      case 'Laboral': return 'Laboral';
      case 'Artística': return 'Artística';
      case 'Mascota': return 'Mascota';
      default: return 'General';
    }
  }
  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'isCompleted': isCompleted,
      'type': type,
      'category': category,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'isExpired': isExpired,
      'isPredefined': isPredefined,
    };
  }
  factory ChallengeModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    return ChallengeModel(
      id: doc.id,
      ownerId: data['ownerId'] as String,
      title: data['title'] as String,
      description: data['description'] as String? ?? '',
      createdAt: DateTime.parse(data['createdAt'] as String),
      dueDate: data['dueDate'] != null
          ? DateTime.parse(data['dueDate'] as String)
          : null,
      isCompleted: data['isCompleted'] as bool? ?? false,
      type: data['type'] as String? ?? 'Personal',
      category: data['category'] as String? ?? 'General',
      targetCount: data['targetCount'] as int? ?? 1,
      currentCount: data['currentCount'] as int? ?? 0,
      isExpired: data['isExpired'] as bool? ?? false,
      isPredefined: data['isPredefined'] as bool? ?? false,
    );
  }
}