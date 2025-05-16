import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../database/task_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_detail_screen.dart';
import '../models/reminder_model.dart';
import '../database/reminder_service.dart';
import 'reminder_detail_screen.dart';
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
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  
  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd/MM/yyyy', 'ca').format(widget.selectedDay);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Dia: $formattedDate'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Botón de añadir como FloatingActionButton
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
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _taskService.streamTasks(_uid),
        builder: (context, taskSnapshot) {
          if (taskSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (taskSnapshot.hasError) {
            return Center(child: Text('Error: ${taskSnapshot.error}'));
          }
          
          // Filtramos las tareas para mostrar solo las del día seleccionado
          final List<TaskModel> dayTasks = [];
          if (taskSnapshot.hasData && taskSnapshot.data!.isNotEmpty) {
            dayTasks.addAll(taskSnapshot.data!.where((task) {
              final selectedDate = DateTime(
                widget.selectedDay.year,
                widget.selectedDay.month,
                widget.selectedDay.day,
              );
              
              // Verificar si es fecha de vencimiento
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
              
              // Verificar si está en fechas asignadas
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
                return const Center(child: CircularProgressIndicator());
              }
              
              if (reminderSnapshot.hasError) {
                return Center(child: Text('Error: ${reminderSnapshot.error}'));
              }
              
              // Filtramos los recordatorios para mostrar solo los del día seleccionado
              final List<ReminderModel> dayReminders = [];
              if (reminderSnapshot.hasData && reminderSnapshot.data!.isNotEmpty) {
                dayReminders.addAll(reminderSnapshot.data!.where((reminder) {
                  final selectedDate = DateTime(
                    widget.selectedDay.year,
                    widget.selectedDay.month,
                    widget.selectedDay.day,
                  );
                  
                  // Verificar si es tiempo de recordatorio
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
                  
                  // Verificar si es fecha de vencimiento
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
                  
                  // Verificar si está en fechas asignadas
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
              
              // Ahora construiremos una única ListView con todas las secciones
              return ListView(
                padding: const EdgeInsets.only(bottom: 80), // Espacio para el botón flotante
                children: [
                  // Sección de tareas
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                    child: Text(
                      'Tasques del dia:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (dayTasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('No hi ha tasques per aquest dia'),
                    )
                  else
                    ...dayTasks.map((task) => Card(
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
                    )).toList(),
                  
                  // Sección de recordatorios
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                    child: Text(
                      'Recordatoris del dia:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (dayReminders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('No hi ha recordatoris per aquest dia'),
                    )
                  else
                    ...dayReminders.map((reminder) => Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: ListTile(
                        title: Text(reminder.title),
                        subtitle: Text(reminder.reminderTime != null 
                            ? DateFormat('HH:mm', 'ca').format(reminder.reminderTime!)
                            : 'Sense hora'),
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
                  
                  // Sección de retos (futura implementación)
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                    child: Text(
                      'Reptes del dia:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('No hi ha reptes per aquest dia'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}