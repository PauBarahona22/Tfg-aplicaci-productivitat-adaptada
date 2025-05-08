import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../database/task_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_detail_screen.dart';
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
      body: Column(
        children: [
          // Lista de tareas del día
          Expanded(
            child: StreamBuilder<List<TaskModel>>(
              stream: _taskService.streamTasks(_uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hi ha tasques per aquest dia'));
                }
                
                // Filtramos las tareas para mostrar solo las del día seleccionado
                final dayTasks = snapshot.data!.where((task) {
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
                }).toList();
                
                if (dayTasks.isEmpty) {
                  return const Center(child: Text('No hi ha tasques per aquest dia'));
                }
                
                return ListView.builder(
                  itemCount: dayTasks.length,
                  itemBuilder: (context, index) {
                    final task = dayTasks[index];
                    return Card(
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
                    );
                  },
                );
              },
            ),
          ),
          
          // Secciones para futuros recordatorios y retos
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Recordatoris del dia:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('Lliure'),
                SizedBox(height: 8),
                Text(
                  'Reptes del dia:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('Lliure'),
              ],
            ),
          ),
          
          // Botón para añadir elemento
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: () {
                    // Por ahora, solo navegamos a la pantalla de nueva tarea con la fecha preseleccionada
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TaskDetailScreen(),
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}