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
    final bool wasCompleted = challenge.isCompleted;
    final bool isNowCompleted = newCount >= challenge.targetCount;
    
    // Actualizar el contador y el estado
    await docRef.update({
      'currentCount': newCount,
      'isCompleted': isNowCompleted,
    });
    
    // Si acaba de completarse, actualizar medallas
    if (!wasCompleted && isNowCompleted) {
      await updateUserMedals(
        challenge.ownerId,
        challenge.category,
        challenge.isPredefined,
      );
    }
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
      final bool wasCompleted = challenge.isCompleted;
      final bool isNowCompleted = newCount >= challenge.targetCount;
      
      // Actualizar el contador y el estado
      await doc.reference.update({
        'currentCount': newCount,
        'isCompleted': isNowCompleted,
      });
      
      // Si acaba de completarse, actualizar medallas
      if (!wasCompleted && isNowCompleted) {
        await updateUserMedals(
          challenge.ownerId,
          challenge.category,
          challenge.isPredefined,
        );
      }
    }
  }
  
  // Método auxiliar para obtener la lista de retos predefinidos
  List<Map<String, dynamic>> getPredefinedChallengesList() {
    return [
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
      {
        'title': 'Organitza 5 tasques musicals',
        'description': 'Completa 5 tasques de tipus musical',
        'type': 'General',
        'category': 'Musical',
        'targetCount': 5,
      },
      {
        'title': 'Planifica 8 tasques familiars',
        'description': 'Completa 8 tasques de tipus familiar',
        'type': 'General',
        'category': 'Familiar',
        'targetCount': 8,
      },
      {
        'title': 'Completa 15 tasques laborals',
        'description': 'Completa 15 tasques de tipus laboral',
        'type': 'General',
        'category': 'Laboral',
        'targetCount': 15,
      },
      {
        'title': 'Realitza 7 tasques artístiques',
        'description': 'Completa 7 tasques de tipus artístic',
        'type': 'General',
        'category': 'Artística',
        'targetCount': 7,
      },
      {
        'title': 'Cuida la teva mascota 10 vegades',
        'description': 'Completa 10 tasques de tipus mascota',
        'type': 'General',
        'category': 'Mascota',
        'targetCount': 10,
      },
      {
        'title': 'Completa 20 tasques generals',
        'description': 'Completa 20 tasques de tipus general',
        'type': 'General',
        'category': 'General',
        'targetCount': 20,
      },
    ];
  }
  
  // Crear retos predefinidos para un nuevo usuario
  Future<void> createPredefinedChallenges(String userId) async {
    final predefinedChallenges = getPredefinedChallengesList();
    
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
  
  // Actualizar medallas del usuario cuando completa un reto
  Future<void> updateUserMedals(String userId, String category, bool isPredefined) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    
    if (!userDoc.exists) return;
    
    // Crear mapa de actualizaciones
    Map<String, dynamic> updates = {};
    
    // Actualizar contador de la categoría específica
    updates['medals.$category'] = FieldValue.increment(1);
    
    // Si es un reto predefinido, también incrementar ese contador
    if (isPredefined) {
      updates['medals.Predefined'] = FieldValue.increment(1);
    }
    
    // Aplicar las actualizaciones
    await userRef.update(updates);
  }
  
  // Método para actualizar reto y medallas
  Future<void> updateChallengeAndMedals(ChallengeModel challenge, {bool forceCompleted = false}) async {
    final bool wasCompleted = challenge.isCompleted;
    final bool isNowCompleted = forceCompleted || challenge.currentCount >= challenge.targetCount;
    
    // Si no estaba completado antes pero ahora sí, actualizar medallas
    if (!wasCompleted && isNowCompleted) {
      await updateUserMedals(
        challenge.ownerId, 
        challenge.category,
        challenge.isPredefined
      );
    }
    
    // Actualizar el reto
    await updateChallenge(challenge.copyWith(
      isCompleted: isNowCompleted,
    ));
  }
  
  // Obtener resumen de medallas de un usuario
  Future<Map<String, int>> getUserMedalsSummary(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    
    if (!userDoc.exists || !userDoc.data()!.containsKey('medals')) {
      return {
        'General': 0,
        'Acadèmica': 0,
        'Deportiva': 0,
        'Musical': 0,
        'Familiar': 0,
        'Laboral': 0,
        'Artística': 0,
        'Mascota': 0,
        'Predefined': 0,
      };
    }
    
    final medalsData = userDoc.data()!['medals'] as Map<String, dynamic>;
    final Map<String, int> result = {};
    
    medalsData.forEach((key, value) {
      result[key] = (value as num).toInt();
    });
    
    return result;
  }
  
  // Método para verificar y crear los retos predefinidos que faltan
  Future<void> ensureAllPredefinedChallenges(String userId, List<ChallengeModel> existingChallenges) async {
    final predefinedChallenges = getPredefinedChallengesList();
    
    // Para cada reto predefinido, verificar si ya existe
    for (final predefined in predefinedChallenges) {
      final title = predefined['title'];
      final category = predefined['category'];
      
      // Verificar si ya existe este reto específico
      final exists = existingChallenges.any((c) => 
          c.isPredefined && 
          c.title == title && 
          c.category == category);
      
      // Si no existe, crearlo
      if (!exists) {
        final challenge = ChallengeModel(
          id: 'temp',
          ownerId: userId,
          title: title,
          description: predefined['description'],
          createdAt: DateTime.now(),
          type: predefined['type'],
          category: category,
          targetCount: predefined['targetCount'],
          isPredefined: true,
        );
        
        await addChallenge(challenge);
      }
    }
  }
}