import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<TaskModel>> streamTasks(String ownerId) {
    return _firestore
        .collection('tasks')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => TaskModel.fromDoc(doc)).toList());
  }

  Future<void> addTask(TaskModel task) {
    return _firestore
        .collection('tasks')
        .add(task.toMap());
  }

  Future<void> updateTask(TaskModel task) {
    return _firestore
        .collection('tasks')
        .doc(task.id)
        .update(task.toMap());
  }

  Future<void> deleteTask(String id) {
    return _firestore
        .collection('tasks')
        .doc(id)
        .delete();
  }
}
