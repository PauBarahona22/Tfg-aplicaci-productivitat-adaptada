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
import '../database/challenge_service.dart';
import '../models/challenge_model.dart';
import 'challenge_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final TaskService _taskService = TaskService();
  final ReminderService _reminderService = ReminderService();
  final ChallengeService _challengeService = ChallengeService(); // Añadido servicio de retos
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  
  // Variables para el calendario
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Para almacenar las tareas obtenidas de Firestore
  Map<DateTime, List<TaskModel>> _events = {};
  Map<DateTime, List<ReminderModel>> _reminderEvents = {};
  Map<DateTime, List<ChallengeModel>> _challengeEvents = {}; // Nuevo mapa para retos
  Map<DateTime, List<dynamic>> _combinedEvents = {}; // Para combinar tareas, recordatorios y retos
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
    
    // Combinar eventos y actualizar contadores
    _combineAllEvents();
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
    
    // Combinar eventos y actualizar contadores
    _combineAllEvents();
    _calculateMonthlyCounts();
  }
  
  // Nueva función para procesar retos en el calendario
  void _processChallengesForCalendar(List<ChallengeModel> challenges) {
    _challengeEvents = {};
    
    for (final challenge in challenges) {
      // Procesar fecha de vencimiento de retos
      if (challenge.dueDate != null) {
        final dueDateKey = DateTime(
          challenge.dueDate!.year,
          challenge.dueDate!.month,
          challenge.dueDate!.day,
        );
        
        if (_challengeEvents[dueDateKey] == null) {
          _challengeEvents[dueDateKey] = [];
        }
        
        // Solo añadir si no está ya (evitar duplicados)
        if (!_challengeEvents[dueDateKey]!.any((c) => c.id == challenge.id)) {
          _challengeEvents[dueDateKey]!.add(challenge);
        }
      }
    }
    
    // Combinar eventos y actualizar contadores
    _combineAllEvents();
    _calculateMonthlyCounts();
  }
  
  // Función para combinar todos los tipos de eventos
  void _combineAllEvents() {
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
    
    // Añadir todos los retos
    _challengeEvents.forEach((date, challenges) {
      if (_combinedEvents[date] == null) {
        _combinedEvents[date] = [];
      }
      _combinedEvents[date]!.addAll(challenges);
    });
    
    // Actualizamos los eventos del día seleccionado
    if (_selectedDay != null) {
      _selectedEvents = _getEventsForDay(_selectedDay!)
          .where((event) => event is TaskModel)
          .cast<TaskModel>()
          .toList();
    }
  }
  
  // Función para calcular los conteos mensuales
  void _calculateMonthlyCounts() {
    _monthlyTaskCount = 0;
    _monthlyReminderCount = 0;
    _monthlyChallengeCount = 0;
    
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
    
    // Conteo de retos mensuales
    _challengeEvents.forEach((date, challenges) {
      if (date.year == _focusedDay.year && date.month == _focusedDay.month) {
        _monthlyChallengeCount += challenges.length;
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
      } else if (event is ChallengeModel) {
        if (!event.isCompleted) {
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
              
              // Añadir StreamBuilder para retos
              return StreamBuilder<List<ChallengeModel>>(
                stream: _challengeService.streamChallenges(_uid),
                builder: (context, challengeSnapshot) {
                  if (challengeSnapshot.connectionState == ConnectionState.waiting) {
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
                  
                  // Procesar retos
                  if (!challengeSnapshot.hasData || challengeSnapshot.data!.isEmpty) {
                    _challengeEvents = {};
                  } else {
                    _processChallengesForCalendar(challengeSnapshot.data!);
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
                      
                      // 3. Calendario propiamente dicho
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
                          });
                          _calculateMonthlyCounts();
                        },
                        eventLoader: _getEventsForDay,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
                          weekendStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          // Estilo para los días del calendario
                          defaultTextStyle: const TextStyle(),
                          weekendTextStyle: const TextStyle(color: Colors.red),
                          outsideTextStyle: const TextStyle(color: Colors.grey),
                          // Decoración para el día seleccionado
                          selectedDecoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          // Decoración para el día actual
                          todayDecoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          // Configuración de marcadores
                          markersMaxCount: 3,
                          markersAnchor: 0.7,
                        ),
                        headerStyle: HeaderStyle(
                          // Estilo del encabezado del calendario
                          formatButtonVisible: true,
                          titleCentered: true,
                          titleTextStyle: const TextStyle(
                            fontSize: 0, // Oculto porque usamos nuestro propio título
                          ),
                          formatButtonDecoration: BoxDecoration(
                            border: Border.all(color: Colors.blue),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          formatButtonTextStyle: const TextStyle(color: Colors.blue),
                          leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.blue),
                          rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.blue),
                          // Nota: Eliminado formatButtonTextMapper y sustituido por:
                          formatButtonShowsNext: false,
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isEmpty) return null;
                            
                            final color = _getMarkerColor(events);
                            return Positioned(
                              bottom: 1,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // 4. Mostrar totales mensuales
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total de tasques mes: $_monthlyTaskCount',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              'Total de recordatoris mes: $_monthlyReminderCount',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              'Total de reptes mes: $_monthlyChallengeCount',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      
                      // 5. Botón para ver detalles del día (más estrecho, centrado y redondeado)
                      Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.7, // 70% del ancho de la pantalla
                          margin: const EdgeInsets.symmetric(vertical: 12.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24), // Bordes más redondeados
                              ),
                              backgroundColor: Colors.blue,
                            ),
                            onPressed: () {
                              if (_selectedDay != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DayDetailScreen(selectedDay: _selectedDay!),
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              'Veure detall del dia',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // 6. Lista de tareas del día seleccionado
                      const SizedBox(height: 16),
                      Expanded(
                        child: _selectedEvents.isEmpty
                            ? Center(
                                child: Text(
                                  'No hi ha tasques per aquest dia',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _selectedEvents.length,
                                itemBuilder: (context, index) {
                                  final task = _selectedEvents[index];
                                  return ListTile(
                                    leading: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: task.isDone ? Colors.green : Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          task.isDone ? Icons.check : Icons.circle,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      task.title,
                                      style: TextStyle(
                                        decoration: task.isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: task.isDone ? Colors.grey : null,
                                      ),
                                    ),
                                    subtitle: Text(task.type), // Usando type en lugar de category
                                    trailing: task.dueDate != null
                                        ? Text(
                                            DateFormat('HH:mm', 'ca').format(task.dueDate!),
                                          )
                                        : null,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TaskDetailScreen(
                                            task: task, // Pasando el task completo
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
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