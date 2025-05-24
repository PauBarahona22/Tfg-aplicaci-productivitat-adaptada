// lib/screens/home_screen.dart
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

  // ✅ OPTIMIZACIÓN SIMPLE: Cache las rutas de imagen
  static const String _mascotDayPath = 'assets/images/mascot_day.png';
  static const String _mascotNightPath = 'assets/images/mascot_night.png';

  // Función para obtener la imagen de la mascota según la hora
  String _getMascotImage() {
    final now = DateTime.now();
    final hour = now.hour;
    
    // De 7:00 a 22:59 = día (despierta)
    // De 23:00 a 6:59 = noche (dormida)
    if (hour >= 7 && hour <= 22) {
      return _mascotDayPath;
    } else {
      return _mascotNightPath;
    }
  }

  // Función para obtener la fecha formateada en catalán
  String _getFormattedDate() {
    final now = DateTime.now();
    final dayFormatter = DateFormat('EEEE', 'ca');
    final dayNumber = now.day;
    final monthFormatter = DateFormat('MMMM', 'ca');
    
    final dayName = dayFormatter.format(now);
    final monthName = monthFormatter.format(now);
    
    return 'Avui, $dayName, $dayNumber de $monthName';
  }

  // Función para filtrar tareas del día actual
  List<TaskModel> _getTasksForToday(List<TaskModel> allTasks) {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    
    return allTasks.where((task) {
      // Verificar fecha de vencimiento
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
      
      // Verificar fechas asignadas
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

  // Función para contar recordatorios del día actual
  int _getRemindersCountForToday(List<ReminderModel> allReminders) {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    
    return allReminders.where((reminder) {
      // Verificar tiempo de recordatorio
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
      
      // Verificar fecha de vencimiento
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
      
      // Verificar fechas asignadas
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

  // Función para contar retos con vencimiento hoy
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Text('Carregant...');
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
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: user.photoUrl.isNotEmpty
                        ? NetworkImage(user.photoUrl)
                        : null,
                    child: user.photoUrl.isEmpty
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Text(user.displayName, style: const TextStyle(fontSize: 18)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.checklist),
                  title: const Text('Nova Tasca'),
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
                  leading: const Icon(Icons.notifications),
                  title: const Text('Nou Recordatori'),
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
                  leading: const Icon(Icons.emoji_events),
                  title: const Text('Nou Repte'),
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
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // SECCIÓN PRINCIPAL - Con bordes arriba y abajo
          Container(
            width: double.infinity,
            height: 180,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                top: BorderSide(color: Colors.blue.shade300, width: 2),
                bottom: BorderSide(color: Colors.blue.shade300, width: 2),
              ),
            ),
            child: Row(
              children: [
                // ✅ IMAGEN OPTIMIZADA CON CACHÉ
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    _getMascotImage(),
                    fit: BoxFit.scaleDown,
                    // ✅ OPTIMIZACIONES SIMPLES
                    cacheWidth: 300,  // Cache específico para este tamaño
                    cacheHeight: 300, // Evita redimensionar cada vez
                    filterQuality: FilterQuality.high, // Balance calidad/velocidad
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.pets,
                          size: 70,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 20),
                // Fecha actual
                Expanded(
                  child: Text(
                    _getFormattedDate(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Sección de tareas con contadores PEGADOS
          Expanded(
            child: StreamBuilder<List<TaskModel>>(
              stream: _taskService.streamTasks(uid!),
              builder: (context, taskSnapshot) {
                if (taskSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (taskSnapshot.hasError) {
                  return Center(child: Text('Error: ${taskSnapshot.error}'));
                }
                
                final todayTasks = taskSnapshot.hasData 
                    ? _getTasksForToday(taskSnapshot.data!)
                    : <TaskModel>[];
                
                return StreamBuilder<List<ReminderModel>>(
                  stream: _reminderService.streamReminders(uid!),
                  builder: (context, reminderSnapshot) {
                    if (reminderSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final remindersCount = reminderSnapshot.hasData 
                        ? _getRemindersCountForToday(reminderSnapshot.data!)
                        : 0;
                    
                    return StreamBuilder<List<ChallengeModel>>(
                      stream: _challengeService.streamChallenges(uid!),
                      builder: (context, challengeSnapshot) {
                        if (challengeSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final challengesCount = challengeSnapshot.hasData 
                            ? _getChallengesCountForToday(challengeSnapshot.data!)
                            : 0;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título de la sección
                            const Padding(
                              padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                              child: Text(
                                'Tasques del dia:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            
                            // Contenido dinámico - tareas O mensaje
                            if (todayTasks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text('Tens el dia lliure'),
                              )
                            else
                              // Lista de tareas
                              ...todayTasks.map((task) => Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                child: ListTile(
                                  title: Text(task.title),
                                  subtitle: Text(task.type),
                                  leading: CircleAvatar(
                                    backgroundColor: task.isDone
                                        ? Colors.green
                                        : (task.dueDate != null && task.dueDate!.isBefore(DateTime.now())
                                            ? Colors.red
                                            : Colors.blue),
                                    radius: 12,
                                  ),
                                  trailing: task.dueDate != null
                                      ? Text(DateFormat('HH:mm', 'ca').format(task.dueDate!))
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
                            
                            // Contadores justo debajo
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16.0, 
                                right: 16.0, 
                                top: 16.0,
                                bottom: 16.0
                              ),
                              child: Row(
                                children: [
                                  // Contador de recordatorios
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
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.notifications,
                                              color: Colors.grey.shade600,
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$remindersCount',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const Text(
                                              'Recordatoris',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Contador de retos
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
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.emoji_events,
                                              color: Colors.grey.shade600,
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$challengesCount',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const Text(
                                              'Reptes',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Spacer para empujar todo hacia arriba
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