import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../database/task_service.dart';
import '../models/task_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_detail_screen.dart';
import 'day_detail_screen.dart';
import '../database/reminder_service.dart';
import '../models/reminder_model.dart';
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}
class _CalendarScreenState extends State<CalendarScreen> {
  final TaskService _taskService = TaskService();
  final ReminderService _reminderService = ReminderService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  
  // Variables para el calendario
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Para almacenar las tareas obtenidas de Firestore
  Map<DateTime, List<TaskModel>> _events = {};
  Map<DateTime, List<ReminderModel>> _reminderEvents = {};
  Map<DateTime, List<dynamic>> _combinedEvents = {}; // Para combinar tareas y recordatorios
  List<TaskModel> _selectedEvents = [];
  
  // Contadores mensuales
  int _monthlyTaskCount = 0;
  int _monthlyReminderCount = 0;
  int _monthlyChallengeCount = 0;
  
  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }
  
  // Función para determinar qué eventos mostrar para cada día
  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _combinedEvents[normalizedDay] ?? [];
  }
  
  // Actualiza la selección de día y los eventos mostrados
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      // Ahora seleccionamos eventos combinados
      _selectedEvents = _getEventsForDay(selectedDay)
          .where((event) => event is TaskModel)
          .cast<TaskModel>()
          .toList();
    });
  }
  
  // Función para procesar las tareas y organizarlas por fecha
  void _processTasksForCalendar(List<TaskModel> tasks) {
    _events = {};
    
    for (final task in tasks) {
      // Procesar fecha de vencimiento
      if (task.dueDate != null) {
        final dueDateKey = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );
        
        if (_events[dueDateKey] == null) {
          _events[dueDateKey] = [];
        }
        
        // Solo añadir si no está ya (evitar duplicados)
        if (!_events[dueDateKey]!.any((t) => t.id == task.id)) {
          _events[dueDateKey]!.add(task);
        }
      }
      
      // Procesar fechas asignadas manualmente
      for (final assignedDate in task.assignedDates) {
        final dateKey = DateTime(
          assignedDate.year,
          assignedDate.month,
          assignedDate.day,
        );
        
        if (_events[dateKey] == null) {
          _events[dateKey] = [];
        }
        
        // Solo añadir si no está ya (evitar duplicados)
        if (!_events[dateKey]!.any((t) => t.id == task.id)) {
          _events[dateKey]!.add(task);
        }
      }
    }
    
    // Combinamos con los recordatorios para la visualización
    _combinedEvents = {};
    
    // Añadir todas las tareas
    _events.forEach((date, tasks) {
      if (_combinedEvents[date] == null) {
        _combinedEvents[date] = [];
      }
      _combinedEvents[date]!.addAll(tasks);
    });
    
    // Añadir todos los recordatorios
    _reminderEvents.forEach((date, reminders) {
      if (_combinedEvents[date] == null) {
        _combinedEvents[date] = [];
      }
      _combinedEvents[date]!.addAll(reminders);
    });
    
    // Actualizamos los eventos del día seleccionado
    if (_selectedDay != null) {
      _selectedEvents = _getEventsForDay(_selectedDay!)
          .where((event) => event is TaskModel)
          .cast<TaskModel>()
          .toList();
    }
    
    // Calculamos los totales mensuales
    _calculateMonthlyCounts();
  }
  
  // Función para procesar recordatorios para el calendario
  void _processRemindersForCalendar(List<ReminderModel> reminders) {
    _reminderEvents = {};
    
    for (final reminder in reminders) {
      // Procesar tiempo de recordatorio
      if (reminder.reminderTime != null) {
        final reminderTimeKey = DateTime(
          reminder.reminderTime!.year,
          reminder.reminderTime!.month,
          reminder.reminderTime!.day,
        );
        
        if (_reminderEvents[reminderTimeKey] == null) {
          _reminderEvents[reminderTimeKey] = [];
        }
        
        if (!_reminderEvents[reminderTimeKey]!.any((r) => r.id == reminder.id)) {
          _reminderEvents[reminderTimeKey]!.add(reminder);
        }
      }
      
      // Procesar fecha de vencimiento
      if (reminder.dueDate != null) {
        final dueDateKey = DateTime(
          reminder.dueDate!.year,
          reminder.dueDate!.month,
          reminder.dueDate!.day,
        );
        
        if (_reminderEvents[dueDateKey] == null) {
          _reminderEvents[dueDateKey] = [];
        }
        
        if (!_reminderEvents[dueDateKey]!.any((r) => r.id == reminder.id)) {
          _reminderEvents[dueDateKey]!.add(reminder);
        }
      }
      
      // Procesar fechas asignadas
      for (final assignedDate in reminder.assignedDates) {
        final dateKey = DateTime(
          assignedDate.year,
          assignedDate.month,
          assignedDate.day,
        );
        
        if (_reminderEvents[dateKey] == null) {
          _reminderEvents[dateKey] = [];
        }
        
        if (!_reminderEvents[dateKey]!.any((r) => r.id == reminder.id)) {
          _reminderEvents[dateKey]!.add(reminder);
        }
      }
    }
    
    // Combinamos con las tareas para la visualización
    _combinedEvents = {};
    
    // Añadir todas las tareas
    _events.forEach((date, tasks) {
      if (_combinedEvents[date] == null) {
        _combinedEvents[date] = [];
      }
      _combinedEvents[date]!.addAll(tasks);
    });
    
    // Añadir todos los recordatorios
    _reminderEvents.forEach((date, reminders) {
      if (_combinedEvents[date] == null) {
        _combinedEvents[date] = [];
      }
      _combinedEvents[date]!.addAll(reminders);
    });
    
    // Actualizamos los contadores mensuales
    _calculateMonthlyCounts();
  }
  
  // Función para calcular los conteos mensuales
  void _calculateMonthlyCounts() {
    _monthlyTaskCount = 0;
    _monthlyReminderCount = 0;
    
    _events.forEach((date, tasks) {
      if (date.year == _focusedDay.year && date.month == _focusedDay.month) {
        _monthlyTaskCount += tasks.length;
      }
    });
    
    _reminderEvents.forEach((date, reminders) {
      if (date.year == _focusedDay.year && date.month == _focusedDay.month) {
        _monthlyReminderCount += reminders.length;
      }
    });
  }
  
  // Función para determinar el color del marcador según las tareas
  Color _getMarkerColor(List<dynamic> dayEvents) {
    if (dayEvents.isEmpty) return Colors.blue;
    
    bool allCompleted = true;
    bool hasOverdue = false;
    DateTime now = DateTime.now();
    
    for (final event in dayEvents) {
      if (event is TaskModel) {
        if (!event.isDone) {
          allCompleted = false;
          if (event.dueDate != null && event.dueDate!.isBefore(now)) {
            hasOverdue = true;
          }
        }
      } else if (event is ReminderModel) {
        if (!event.isDone) {
          allCompleted = false;
          if (event.dueDate != null && event.dueDate!.isBefore(now)) {
            hasOverdue = true;
          }
        }
      }
    }
    
    if (allCompleted) return Colors.green;
    if (hasOverdue) return Colors.red;
    return Colors.blue;
  }
  
  // Función para obtener el texto del formato correcto
  String _getCalendarFormatText() {
    switch (_calendarFormat) {
      case CalendarFormat.month:
        return 'MES';
      case CalendarFormat.twoWeeks:
        return 'DUES SETMANES';
      case CalendarFormat.week:
        return 'SETMANA';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendari'),
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _taskService.streamTasks(_uid),
        builder: (context, taskSnapshot) {
          if (taskSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return StreamBuilder<List<ReminderModel>>(
            stream: _reminderService.streamReminders(_uid),
            builder: (context, reminderSnapshot) {
              if (reminderSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (taskSnapshot.hasError) {
                return Center(child: Text('Error: ${taskSnapshot.error}'));
              }
              
              // Procesar tareas
              if (!taskSnapshot.hasData || taskSnapshot.data!.isEmpty) {
                _events = {};
              } else {
                _processTasksForCalendar(taskSnapshot.data!);
              }
              
              // Procesar recordatorios
              if (!reminderSnapshot.hasData || reminderSnapshot.data!.isEmpty) {
                _reminderEvents = {};
              } else {
                _processRemindersForCalendar(reminderSnapshot.data!);
              }
              
              // Formateamos el mes y año
              String monthYear = DateFormat('MMMM yyyy', 'ca').format(_focusedDay);
              // Primera letra mayúscula, resto minúsculas
              monthYear = '${monthYear[0].toUpperCase()}${monthYear.substring(1)}';
              
              return Column(
                children: [
                  // Línea divisoria superior
                  const Divider(thickness: 2, height: 1),
                  
                  // 1. Selector de mes y año (simplificado)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          monthYear,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  
                  // 2. Formato actual y fecha actual
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Vista: ${_getCalendarFormatText()}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Data Actual: ${DateFormat('dd/MM/yyyy', 'ca').format(DateTime.now())}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  
                  // 3. Calendario con eventos y marcadores personalizados
                  TableCalendar(
                    locale: 'ca',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    // Definimos correctamente los formatos disponibles
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Mes',
                      CalendarFormat.twoWeeks: 'Dues setmanes',
                      CalendarFormat.week: 'Setmana',
                    },
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDay, day);
                    },
                    onDaySelected: _onDaySelected,
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                        _calculateMonthlyCounts();
                      });
                    },
                    eventLoader: _getEventsForDay,
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) return null;
                        
                        return Positioned(
                          bottom: 1,
                          child: Container(
                            height: 6,
                            width: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getMarkerColor(events),
                            ),
                          ),
                        );
                      },
                    ),
                    calendarStyle: const CalendarStyle(
                      markersMaxCount: 3,
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
                      weekendStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    rowHeight: 46,
                  ),
                  
                  // Línea divisoria inferior
                  const Divider(thickness: 2, height: 1),
                  
                  // 4. Estadísticas mensuales
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Total de tasques mes: ',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '$_monthlyTaskCount',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'Total de recordatoris mes: ',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '$_monthlyReminderCount',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'Total de reptes mes: ',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '$_monthlyChallengeCount',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 5. Botón para ver detalle del día
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: ElevatedButton(
                      onPressed: _selectedDay == null
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DayDetailScreen(selectedDay: _selectedDay!),
                              ),
                            );
                          },
                      child: const Text('Veure detall del dia'),
                    ),
                  ),
                  // 6. Lista de eventos del día seleccionado
                  const SizedBox(height: 8.0),
                  Expanded(
                    child: _selectedEvents.isEmpty
                        ? const Center(child: Text('No hi ha tasques per aquest dia'))
                        : ListView.builder(
                            itemCount: _selectedEvents.length,
                            itemBuilder: (context, index) {
                              final task = _selectedEvents[index];
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
                          ),
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