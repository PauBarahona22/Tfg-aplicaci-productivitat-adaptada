import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../database/challenge_service.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChallengeService _challengeService = ChallengeService();

  Stream<List<TaskModel>> streamTasks(String ownerId) {
    return _firestore
        .collection('tasks')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TaskModel.fromDoc(d)).toList());
  }

  Future<DocumentReference<Map<String, dynamic>>> addTask(TaskModel task) {
    return _firestore.collection('tasks').add(task.toMap());
  }

  Future<void> updateTask(TaskModel task) async {
  // Obtener la tarea anterior para comparar el estado de isDone
  TaskModel? previousTask;
  try {
    final doc = await _firestore.collection('tasks').doc(task.id).get();
    if (doc.exists) {
      previousTask = TaskModel.fromDoc(doc);
    }
  } catch (e) {
    // Si no se puede obtener la tarea anterior, continuar sin comparar
    print('Error obteniendo tarea anterior: $e');
  }
  // Actualizar la tarea en Firestore
  await _firestore
      .collection('tasks')
      .doc(task.id)
      .update(task.toMap());
  // Si la tarea acaba de completarse (cambió de false a true), actualizar retos predefinidos
  if (previousTask != null && 
      !previousTask.isDone && 
      task.isDone) {
    try {
      await _challengeService.updatePredefinedChallengesProgress(task);
    } catch (e) {
      print('Error actualizando retos predefinidos: $e');
    }
  }
}

  Future<void> deleteTask(String id) {
    return _firestore.collection('tasks').doc(id).delete();
  }
  
  Future<void> assignTaskToCalendar(TaskModel task, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    List<DateTime> assignedDates = List.from(task.assignedDates);
    
    bool alreadyAssigned = assignedDates.any((d) => 
      d.year == normalizedDate.year && 
      d.month == normalizedDate.month && 
      d.day == normalizedDate.day
    );
    
    if (!alreadyAssigned) {
      assignedDates.add(normalizedDate);
      
      final updatedTask = task.copyWith(assignedDates: assignedDates);
      await updateTask(updatedTask);
    }
  }
  
  Future<void> removeAssignedDate(TaskModel task, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    List<DateTime> assignedDates = List.from(task.assignedDates);
    assignedDates.removeWhere((d) => 
      d.year == normalizedDate.year && 
      d.month == normalizedDate.month && 
      d.day == normalizedDate.day
    );
    
    final updatedTask = task.copyWith(assignedDates: assignedDates);
    await updateTask(updatedTask);
  }
}