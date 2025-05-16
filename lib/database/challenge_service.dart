import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/challenge_model.dart';
import '../models/task_model.dart';
class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Stream para obtener todos los retos de un usuario
  Stream<List<ChallengeModel>> streamChallenges(String ownerId) {
    return _firestore
        .collection('challenges')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChallengeModel.fromDoc(d)).toList());
  }
  // Agregar un nuevo reto
  Future<DocumentReference<Map<String, dynamic>>> addChallenge(ChallengeModel challenge) {
    return _firestore.collection('challenges').add(challenge.toMap());
  }
  // Actualizar un reto existente
  Future<void> updateChallenge(ChallengeModel challenge) {
    return _firestore
        .collection('challenges')
        .doc(challenge.id)
        .update(challenge.toMap());
  }
  // Eliminar un reto
  Future<void> deleteChallenge(String id) {
    return _firestore.collection('challenges').doc(id).delete();
  }
  
  // Actualizar el progreso de un reto manualmente
  Future<void> incrementChallengeProgress(String challengeId) async {
    final docRef = _firestore.collection('challenges').doc(challengeId);
    
    // Obtener el documento actual
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;
    
    final challenge = ChallengeModel.fromDoc(docSnap);
    
    // No permitir modificar retos predefinidos manualmente
    if (challenge.isPredefined) return;
    
    // Incrementar contador
    int newCount = challenge.currentCount + 1;
    if (newCount > challenge.targetCount) newCount = challenge.targetCount;
    
    // Verificar si se ha completado el reto
    final bool isCompleted = newCount >= challenge.targetCount;
    
    // Actualizar el contador y el estado
    await docRef.update({
      'currentCount': newCount,
      'isCompleted': isCompleted,
    });
  }
  
  // Actualizar progreso basado en tareas completadas
  Future<void> updatePredefinedChallengesProgress(TaskModel completedTask) async {
    // Esta función se llamaría cada vez que se completa una tarea
    // Buscar todos los retos predefinidos de la misma categoría que la tarea
    final snapshot = await _firestore
        .collection('challenges')
        .where('ownerId', isEqualTo: completedTask.ownerId)
        .where('isPredefined', isEqualTo: true)
        .where('category', isEqualTo: completedTask.type)
        .where('isCompleted', isEqualTo: false)
        .get();
    
    // Por cada reto predefinido, incrementar su progreso
    for (final doc in snapshot.docs) {
      final challenge = ChallengeModel.fromDoc(doc);
      
      // Incrementar contador
      int newCount = challenge.currentCount + 1;
      
      // Verificar si se ha completado el reto
      final bool isCompleted = newCount >= challenge.targetCount;
      
      // Actualizar el contador y el estado
      await doc.reference.update({
        'currentCount': newCount,
        'isCompleted': isCompleted,
      });
    }
  }
  
  // Crear retos predefinidos para un nuevo usuario
  Future<void> createPredefinedChallenges(String userId) async {
    final List<Map<String, dynamic>> predefinedChallenges = [
      {
        'title': 'Completa 10 tasques acadèmiques',
        'description': 'Completa 10 tasques de tipus acadèmic',
        'type': 'General',
        'category': 'Acadèmica',
        'targetCount': 10,
      },
      {
        'title': 'Completa 30 tasques acadèmiques',
        'description': 'Completa 30 tasques de tipus acadèmic',
        'type': 'General',
        'category': 'Acadèmica',
        'targetCount': 30,
      },
      {
        'title': 'Completa 10 tasques deportives',
        'description': 'Completa 10 tasques de tipus deportiu',
        'type': 'General',
        'category': 'Deportiva',
        'targetCount': 10,
      },
      // Se pueden añadir más retos predefinidos aquí
    ];
    
    for (final predefinedData in predefinedChallenges) {
      final challenge = ChallengeModel(
        id: 'temp',
        ownerId: userId,
        title: predefinedData['title'],
        description: predefinedData['description'],
        createdAt: DateTime.now(),
        type: predefinedData['type'],
        category: predefinedData['category'],
        targetCount: predefinedData['targetCount'],
        isPredefined: true,
      );
      
      await addChallenge(challenge);
    }
  }
  
  // Verificar retos expirados y marcarlos
  Future<void> checkExpiredChallenges(String ownerId) async {
    final now = DateTime.now();
    
    // Obtener retos con fecha límite que no están completados ni marcados como expirados
    final snapshot = await _firestore
        .collection('challenges')
        .where('ownerId', isEqualTo: ownerId)
        .where('isCompleted', isEqualTo: false)
        .where('isExpired', isEqualTo: false)
        .where('dueDate', isLessThan: now.toIso8601String())
        .get();
    
    // Marcar como expirados los retos con fecha vencida
    for (final doc in snapshot.docs) {
      await doc.reference.update({'isExpired': true});
    }
  }
  
  // Eliminar retos expirados después de 30 días
  Future<void> deleteExpiredChallenges(String ownerId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    // Obtener retos expirados hace más de 30 días
    final snapshot = await _firestore
        .collection('challenges')
        .where('ownerId', isEqualTo: ownerId)
        .where('isExpired', isEqualTo: true)
        .where('dueDate', isLessThan: thirtyDaysAgo.toIso8601String())
        .get();
    
    // Eliminar los retos expirados
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}