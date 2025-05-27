import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/challenge_model.dart';
import '../models/task_model.dart';

class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  

  Stream<List<ChallengeModel>> streamChallenges(String ownerId) {
    return _firestore
        .collection('challenges')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChallengeModel.fromDoc(d)).toList());
  }
  

  Future<DocumentReference<Map<String, dynamic>>> addChallenge(ChallengeModel challenge) {
    return _firestore.collection('challenges').add(challenge.toMap());
  }
  

  Future<void> updateChallenge(ChallengeModel challenge) {
    return _firestore
        .collection('challenges')
        .doc(challenge.id)
        .update(challenge.toMap());
  }
  

  Future<void> deleteChallenge(String id) {
    return _firestore.collection('challenges').doc(id).delete();
  }
  

  Future<void> incrementChallengeProgress(String challengeId) async {
    final docRef = _firestore.collection('challenges').doc(challengeId);
    

    final docSnap = await docRef.get();
    if (!docSnap.exists) return;
    
    final challenge = ChallengeModel.fromDoc(docSnap);
    

    if (challenge.isPredefined) return;
    

    int newCount = challenge.currentCount + 1;
    if (newCount > challenge.targetCount) newCount = challenge.targetCount;
    

    final bool wasCompleted = challenge.isCompleted;
    final bool isNowCompleted = newCount >= challenge.targetCount;
    

    await docRef.update({
      'currentCount': newCount,
      'isCompleted': isNowCompleted,
    });
    
 
    if (!wasCompleted && isNowCompleted) {
      await updateUserMedals(
        challenge.ownerId,
        challenge.category,
        challenge.isPredefined,
      );
    }
  }
  

  Future<void> updatePredefinedChallengesProgress(TaskModel completedTask) async {

    final snapshot = await _firestore
        .collection('challenges')
        .where('ownerId', isEqualTo: completedTask.ownerId)
        .where('isPredefined', isEqualTo: true)
        .where('category', isEqualTo: completedTask.type)
        .where('isCompleted', isEqualTo: false)
        .get();
    

    for (final doc in snapshot.docs) {
      final challenge = ChallengeModel.fromDoc(doc);
      

      int newCount = challenge.currentCount + 1;
      

      final bool wasCompleted = challenge.isCompleted;
      final bool isNowCompleted = newCount >= challenge.targetCount;
      

      await doc.reference.update({
        'currentCount': newCount,
        'isCompleted': isNowCompleted,
      });
      

      if (!wasCompleted && isNowCompleted) {
        await updateUserMedals(
          challenge.ownerId,
          challenge.category,
          challenge.isPredefined,
        );
      }
    }
  }
  

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
  

  Future<void> checkExpiredChallenges(String ownerId) async {
    final now = DateTime.now();
    

    final snapshot = await _firestore
        .collection('challenges')
        .where('ownerId', isEqualTo: ownerId)
        .where('isCompleted', isEqualTo: false)
        .where('isExpired', isEqualTo: false)
        .where('dueDate', isLessThan: now.toIso8601String())
        .get();
    

    for (final doc in snapshot.docs) {
      await doc.reference.update({'isExpired': true});
    }
  }
  

  Future<void> deleteExpiredChallenges(String ownerId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    

    final snapshot = await _firestore
        .collection('challenges')
        .where('ownerId', isEqualTo: ownerId)
        .where('isExpired', isEqualTo: true)
        .where('dueDate', isLessThan: thirtyDaysAgo.toIso8601String())
        .get();
    

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
  

  Future<void> updateUserMedals(String userId, String category, bool isPredefined) async {

  print('Updating medals for user: $userId, category: $category, isPredefined: $isPredefined');
  
  final userRef = _firestore.collection('users').doc(userId);
  
  try {

    final userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      print('User document does not exist');
      return;
    }
    

    Map<String, dynamic>? currentData = userDoc.data();
    Map<String, dynamic> currentMedals = {};
    
    if (currentData != null && currentData.containsKey('medals')) {
      currentMedals = Map<String, dynamic>.from(currentData['medals']);
    } else {

      currentMedals = {
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
    

    int currentCount = currentMedals[category] ?? 0;
    currentMedals[category] = currentCount + 1;
    

    if (isPredefined) {
      int predefinedCount = currentMedals['Predefined'] ?? 0;
      currentMedals['Predefined'] = predefinedCount + 1;
    }
    

    print('Updated medals: $currentMedals');
    

    await userRef.set({'medals': currentMedals}, SetOptions(merge: true));
    

    final verifyDoc = await userRef.get();
    final verifyData = verifyDoc.data();
    if (verifyData != null && verifyData.containsKey('medals')) {
      print('Verification - Updated medals: ${verifyData['medals']}');
    }
    
  } catch (e) {
    print('Error updating medals: $e');
  }
}
  

  Future<void> updateChallengeAndMedals(ChallengeModel challenge, {bool forceCompleted = false}) async {
    final bool wasCompleted = challenge.isCompleted;
    final bool isNowCompleted = forceCompleted || challenge.currentCount >= challenge.targetCount;
    

    if (!wasCompleted && isNowCompleted) {
      await updateUserMedals(
        challenge.ownerId, 
        challenge.category,
        challenge.isPredefined
      );
    }
    

    await updateChallenge(challenge.copyWith(
      isCompleted: isNowCompleted,
    ));
  }
  

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
  

  Future<void> ensureAllPredefinedChallenges(String userId, List<ChallengeModel> existingChallenges) async {
    final predefinedChallenges = getPredefinedChallengesList();
    

    for (final predefined in predefinedChallenges) {
      final title = predefined['title'];
      final category = predefined['category'];
      

      final exists = existingChallenges.any((c) => 
          c.isPredefined && 
          c.title == title && 
          c.category == category);
      

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