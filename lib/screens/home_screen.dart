import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/reminder_model.dart';
import '../models/challenge_model.dart';
import '../database/task_service.dart';
import '../database/reminder_service.dart';
import '../database/challenge_service.dart';
import 'profile_screen.dart';
import 'task_detail_screen.dart';
import 'day_detail_screen.dart';
import 'reminder_detail_screen.dart';
import 'challenge_detail_screen.dart';
import 'dart:io';
import '../database/local_storage_service.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  final TaskService _taskService = TaskService();
  final ReminderService _reminderService = ReminderService();
  final ChallengeService _challengeService = ChallengeService();
  final uid = FirebaseAuth.instance.currentUser?.uid;
  static const String _mascotDayPath = 'assets/images/mascot_day.png';
  static const String _mascotNightPath = 'assets/images/mascot_night.png';
  String _getMascotImage() {
    final now = DateTime.now();
    final hour = now.hour;
    if (hour >= 7 && hour <= 22) {
      return _mascotDayPath;
    } else {
      return _mascotNightPath;
    }
  }
  String _getFormattedDate() {
    final now = DateTime.now();
    final dayFormatter = DateFormat('EEEE', 'ca');
    final dayNumber = now.day;
    final monthFormatter = DateFormat('MMMM', 'ca');
    final dayName = dayFormatter.format(now);
    final monthName = monthFormatter.format(now);
    return 'Avui, $dayName, $dayNumber de $monthName';
  }
  List<TaskModel> _getTasksForToday(List<TaskModel> allTasks) {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    return allTasks.where((task) {
      if (task.dueDate != null) {
        final taskDate = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );
        if (taskDate.isAtSameMomentAs(todayNormalized)) {
          return true;
        }
      }
      return task.assignedDates.any((date) {
        final assignedDate = DateTime(
          date.year,
          date.month,
          date.day,
        );
        return assignedDate.isAtSameMomentAs(todayNormalized);
      });
    }).toList();
  }
  int _getRemindersCountForToday(List<ReminderModel> allReminders) {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    return allReminders.where((reminder) {
      if (reminder.reminderTime != null) {
        final reminderDate = DateTime(
          reminder.reminderTime!.year,
          reminder.reminderTime!.month,
          reminder.reminderTime!.day,
        );
        if (reminderDate.isAtSameMomentAs(todayNormalized)) {
          return true;
        }
      }
      if (reminder.dueDate != null) {
        final dueDate = DateTime(
          reminder.dueDate!.year,
          reminder.dueDate!.month,
          reminder.dueDate!.day,
        );
        if (dueDate.isAtSameMomentAs(todayNormalized)) {
          return true;
        }
      }
      return reminder.assignedDates.any((date) {
        final assignedDate = DateTime(
          date.year,
          date.month,
          date.day,
        );
        return assignedDate.isAtSameMomentAs(todayNormalized);
      });
    }).length;
  }
  int _getChallengesCountForToday(List<ChallengeModel> allChallenges) {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    return allChallenges.where((challenge) {
      if (challenge.dueDate != null) {
        final dueDate = DateTime(
          challenge.dueDate!.year,
          challenge.dueDate!.month,
          challenge.dueDate!.day,
        );
        return dueDate.isAtSameMomentAs(todayNormalized);
      }
      return false;
    }).length;
  }
  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return Scaffold(
        backgroundColor: Color(0xFFBAD1C2),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4FA095))),
      );
    }
    return Scaffold(
      backgroundColor: Color(0xFFBAD1C2),
      appBar: AppBar(
        backgroundColor: Color(0xFF9BB8A5),
        automaticallyImplyLeading: false,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return Text('Carregant...', style: TextStyle(color: Colors.white));
            final data = snap.data!.data()!;
            final user = UserModel.fromMap(data);
            return Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                  child: FutureBuilder<String?>(
                    future: LocalStorageService.getProfileImagePath(user.uid),
                    builder: (context, snapshot) {
                      final localImagePath = snapshot.data;
                      return CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFF4FA095),
                        backgroundImage: localImagePath != null
                            ? FileImage(File(localImagePath))
                            : (user.photoUrl.isNotEmpty
                                ? NetworkImage(user.photoUrl)
                                : null),
                        child: (localImagePath == null && user.photoUrl.isEmpty)
                            ? Icon(Icons.person, size: 20, color: Colors.white)
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(user.displayName, style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF25766B),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Color(0xFF9BB8A5),
            builder: (context) => Wrap(
              children: [
                ListTile(
                  leading: Icon(Icons.checklist, color: Color(0xFF25766B)),
                  title: Text('Nova Tasca', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TaskDetailScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.notifications, color: Color(0xFF25766B)),
                  title: Text('Nou Recordatori', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReminderDetailScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.emoji_events, color: Color(0xFF25766B)),
                  title: Text('Nou Repte', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChallengeDetailScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 210,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7C9F88), Color(0xFF4FA095)],
              ),
              border: Border(
                top: BorderSide(color: Color(0xFF3A8B80), width: 3),
                bottom: BorderSide(color: Color(0xFF3A8B80), width: 3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 160,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: Image.asset(
                    _getMascotImage(),
                    fit: BoxFit.scaleDown,
                    cacheWidth: 300,
                    cacheHeight: 300,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.pets,
                          size: 70,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    _getFormattedDate(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TaskModel>>(
              stream: _taskService.streamTasks(uid!),
              builder: (context, taskSnapshot) {
                if (taskSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)));
                }
                if (taskSnapshot.hasError) {
                  return Center(child: Text('Error: ${taskSnapshot.error}', style: TextStyle(color: Color(0xFF25766B))));
                }
                final todayTasks = taskSnapshot.hasData
                    ? _getTasksForToday(taskSnapshot.data!)
                    : <TaskModel>[];
                return StreamBuilder<List<ReminderModel>>(
                  stream: _reminderService.streamReminders(uid!),
                  builder: (context, reminderSnapshot) {
                    if (reminderSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)));
                    }
                    final remindersCount = reminderSnapshot.hasData
                        ? _getRemindersCountForToday(reminderSnapshot.data!)
                        : 0;
                    return StreamBuilder<List<ChallengeModel>>(
                      stream: _challengeService.streamChallenges(uid!),
                      builder: (context, challengeSnapshot) {
                        if (challengeSnapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)));
                        }
                        final challengesCount = challengeSnapshot.hasData
                            ? _getChallengesCountForToday(challengeSnapshot.data!)
                            : 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              color: Color(0xFF9BB8A5),
                              padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                              child: Text(
                                'Tasques del dia:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (todayTasks.isEmpty)
                              Container(
                                color: Color(0xFFBAD1C2),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text('Tens el dia lliure', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w500)),
                                ),
                              )
                            else
                              ...todayTasks.map((task) => Card(
                                color: Color.fromARGB(61, 35, 224, 161),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                  side: BorderSide(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
                                ),
                                child: ListTile(
                                  title: Text(task.title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  subtitle: Text(task.type, style: TextStyle(color: Colors.white.withOpacity(0.8))),
                                  leading: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2), 
                                    ),
                                    child: CircleAvatar(
                                      backgroundColor: task.isDone
                                          ? Colors.green        
                                          : (task.dueDate != null && task.dueDate!.isBefore(DateTime.now())
                                              ? Colors.red       
                                              : Colors.blue),    
                                      radius: 12,
                                    ),
                                  ),
                                  trailing: task.dueDate != null
                                      ? Text(DateFormat('HH:mm', 'ca').format(task.dueDate!), style: TextStyle(color: Colors.white.withOpacity(0.9)))
                                      : null,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TaskDetailScreen(task: task),
                                      ),
                                    );
                                  },
                                ),
                              )),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16.0,
                                right: 16.0,
                                top: 16.0,
                                bottom: 16.0
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DayDetailScreen(
                                              selectedDay: DateTime.now(),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF4FA095),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Color(0xFF3A8B80)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFF25766B).withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.notifications,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$remindersCount',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              'Recordatoris',
                                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DayDetailScreen(
                                              selectedDay: DateTime.now(),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF3A8B80),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Color(0xFF25766B)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFF25766B).withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.emoji_events,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$challengesCount',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              'Reptes',
                                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}