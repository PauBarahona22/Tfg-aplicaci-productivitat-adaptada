import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../database/task_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_detail_screen.dart';
import '../models/reminder_model.dart';
import '../database/reminder_service.dart';
import 'reminder_detail_screen.dart';
import '../models/challenge_model.dart';
import '../database/challenge_service.dart';
import 'challenge_detail_screen.dart';

class DayDetailScreen extends StatefulWidget {
  final DateTime selectedDay;

  const DayDetailScreen({
    super.key,
    required this.selectedDay,
  });
  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  final TaskService _taskService = TaskService();
  final ReminderService _reminderService = ReminderService();
  final ChallengeService _challengeService = ChallengeService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd/MM/yyyy', 'ca').format(widget.selectedDay);

    return Scaffold(
      backgroundColor: Color(0xFFBAD1C2),
      appBar: AppBar(
        backgroundColor: Color(0xFF4FA095),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Dia: $formattedDate',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF25766B),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Color(0xFFD4E7D9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => Container(
              padding: EdgeInsets.all(16),
              child: Wrap(
                children: [
                  ListTile(
                    leading: Icon(Icons.checklist, color: Color(0xFF25766B)),
                    title: Text(
                      'Nova Tasca',
                      style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600),
                    ),
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
                    title: Text(
                      'Nou Recordatori',
                      style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600),
                    ),
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
                    title: Text(
                      'Nou Repte',
                      style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600),
                    ),
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
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _taskService.streamTasks(_uid),
        builder: (context, taskSnapshot) {
          if (taskSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)));
          }

          if (taskSnapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${taskSnapshot.error}',
                style: TextStyle(color: Color(0xFF25766B)),
              ),
            );
          }

          final List<TaskModel> dayTasks = [];
          if (taskSnapshot.hasData && taskSnapshot.data!.isNotEmpty) {
            dayTasks.addAll(taskSnapshot.data!.where((task) {
              final selectedDate = DateTime(
                widget.selectedDay.year,
                widget.selectedDay.month,
                widget.selectedDay.day,
              );

              if (task.dueDate != null) {
                final taskDate = DateTime(
                  task.dueDate!.year,
                  task.dueDate!.month,
                  task.dueDate!.day,
                );

                if (taskDate.isAtSameMomentAs(selectedDate)) {
                  return true;
                }
              }

              return task.assignedDates.any((date) {
                final assignedDate = DateTime(
                  date.year,
                  date.month,
                  date.day,
                );
                return assignedDate.isAtSameMomentAs(selectedDate);
              });
            }));
          }

          return StreamBuilder<List<ReminderModel>>(
            stream: _reminderService.streamReminders(_uid),
            builder: (context, reminderSnapshot) {
              if (reminderSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)));
              }

              if (reminderSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${reminderSnapshot.error}',
                    style: TextStyle(color: Color(0xFF25766B)),
                  ),
                );
              }

              final List<ReminderModel> dayReminders = [];
              if (reminderSnapshot.hasData && reminderSnapshot.data!.isNotEmpty) {
                dayReminders.addAll(reminderSnapshot.data!.where((reminder) {
                  final selectedDate = DateTime(
                    widget.selectedDay.year,
                    widget.selectedDay.month,
                    widget.selectedDay.day,
                  );

                  if (reminder.reminderTime != null) {
                    final reminderDate = DateTime(
                      reminder.reminderTime!.year,
                      reminder.reminderTime!.month,
                      reminder.reminderTime!.day,
                    );

                    if (reminderDate.isAtSameMomentAs(selectedDate)) {
                      return true;
                    }
                  }

                  if (reminder.dueDate != null) {
                    final dueDate = DateTime(
                      reminder.dueDate!.year,
                      reminder.dueDate!.month,
                      reminder.dueDate!.day,
                    );

                    if (dueDate.isAtSameMomentAs(selectedDate)) {
                      return true;
                    }
                  }

                  return reminder.assignedDates.any((date) {
                    final assignedDate = DateTime(
                      date.year,
                      date.month,
                      date.day,
                    );
                    return assignedDate.isAtSameMomentAs(selectedDate);
                  });
                }));
              }

              return StreamBuilder<List<ChallengeModel>>(
                stream: _challengeService.streamChallenges(_uid),
                builder: (context, challengeSnapshot) {
                  if (challengeSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)));
                  }

                  if (challengeSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${challengeSnapshot.error}',
                        style: TextStyle(color: Color(0xFF25766B)),
                      ),
                    );
                  }

                  final List<ChallengeModel> dayChallenges = [];
                  if (challengeSnapshot.hasData && challengeSnapshot.data!.isNotEmpty) {
                    dayChallenges.addAll(challengeSnapshot.data!.where((challenge) {
                      final selectedDate = DateTime(
                        widget.selectedDay.year,
                        widget.selectedDay.month,
                        widget.selectedDay.day,
                      );

                      if (challenge.dueDate != null) {
                        final dueDate = DateTime(
                          challenge.dueDate!.year,
                          challenge.dueDate!.month,
                          challenge.dueDate!.day,
                        );

                        if (dueDate.isAtSameMomentAs(selectedDate)) {
                          return true;
                        }
                      }

                      return false;
                    }));
                  }

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                        child: Text(
                          'Tasques del dia:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF25766B),
                          ),
                        ),
                      ),
                      if (dayTasks.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'No hi ha tasques per aquest dia',
                            style: TextStyle(
                              color: Color(0xFF3A8B80),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        ...dayTasks.map((task) => Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(61, 35, 224, 161),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
                          ),
                          child: ListTile(
                            title: Text(
                              task.title,
                              style: TextStyle(
                                color: Color(0xFF25766B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              task.type,
                              style: TextStyle(
                                color: Color(0xFF3A8B80),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: task.isDone
                                  ? Colors.green
                                  : (task.dueDate != null && task.dueDate!.isBefore(DateTime.now())
                                      ? Colors.red
                                      : Colors.blue),
                              radius: 12,
                            ),
                            trailing: task.dueDate != null
                                ? Text(
                                    DateFormat('HH:mm', 'ca').format(task.dueDate!),
                                    style: TextStyle(
                                      color: Color(0xFF3A8B80),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
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
                        )).toList(),

                      Padding(
                        padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                        child: Text(
                          'Recordatoris del dia:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF25766B),
                          ),
                        ),
                      ),
                      if (dayReminders.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'No hi ha recordatoris per aquest dia',
                            style: TextStyle(
                              color: Color(0xFF3A8B80),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        ...dayReminders.map((reminder) => Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(61, 35, 224, 161),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
                          ),
                          child: ListTile(
                            title: Text(
                              reminder.title,
                              style: TextStyle(
                                color: Color(0xFF25766B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              reminder.reminderTime != null
                                  ? DateFormat('HH:mm', 'ca').format(reminder.reminderTime!)
                                  : 'Sense hora',
                              style: TextStyle(
                                color: Color(0xFF3A8B80),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            leading: Icon(
                              reminder.isDone
                                  ? Icons.check_circle
                                  : Icons.notifications,
                              color: reminder.isDone
                                  ? Colors.green
                                  : (reminder.dueDate != null && reminder.dueDate!.isBefore(DateTime.now())
                                      ? Colors.red
                                      : Colors.blue),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReminderDetailScreen(reminder: reminder),
                                ),
                              );
                            },
                          ),
                        )).toList(),

                      Padding(
                        padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                        child: Text(
                          'Reptes del dia:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF25766B),
                          ),
                        ),
                      ),
                      if (dayChallenges.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'No hi ha reptes per aquest dia',
                            style: TextStyle(
                              color: Color(0xFF3A8B80),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        ...dayChallenges.map((challenge) => Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(61, 35, 224, 161),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
                          ),
                          child: ListTile(
                            title: Text(
                              challenge.title,
                              style: TextStyle(
                                color: Color(0xFF25766B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${challenge.currentCount}/${challenge.targetCount}',
                              style: TextStyle(
                                color: Color(0xFF3A8B80),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: (challenge.isCompleted
                                  ? Colors.green
                                  : (challenge.dueDate != null && challenge.dueDate!.isBefore(DateTime.now())
                                      ? Colors.red
                                      : Colors.blue)).withOpacity(0.2),
                              child: Icon(
                                challenge.isPredefined ? Icons.auto_awesome : Icons.emoji_events,
                                color: challenge.isCompleted
                                  ? Colors.green
                                  : (challenge.dueDate != null && challenge.dueDate!.isBefore(DateTime.now())
                                      ? Colors.red
                                      : Colors.blue),
                                size: 16,
                              ),
                            ),
                            trailing: challenge.dueDate != null
                                ? Text(
                                    DateFormat('HH:mm', 'ca').format(challenge.dueDate!),
                                    style: TextStyle(
                                      color: Color(0xFF3A8B80),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : null,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChallengeDetailScreen(challenge: challenge),
                                ),
                              );
                            },
                          ),
                        )).toList(),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}