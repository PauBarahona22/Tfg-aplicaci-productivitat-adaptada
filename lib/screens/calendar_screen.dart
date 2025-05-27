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
  final ChallengeService _challengeService = ChallengeService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<TaskModel>> _events = {};
  Map<DateTime, List<ReminderModel>> _reminderEvents = {};
  Map<DateTime, List<ChallengeModel>> _challengeEvents = {};
  Map<DateTime, List<dynamic>> _combinedEvents = {};
  List<TaskModel> _selectedEvents = [];

  int _monthlyTaskCount = 0;
  int _monthlyReminderCount = 0;
  int _monthlyChallengeCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _combinedEvents[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;

      _selectedEvents = _getEventsForDay(selectedDay)
          .where((event) => event is TaskModel)
          .cast<TaskModel>()
          .toList();
    });
  }

  void _processTasksForCalendar(List<TaskModel> tasks) {
    _events = {};

    for (final task in tasks) {
      if (task.dueDate != null) {
        final dueDateKey = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );

        if (_events[dueDateKey] == null) {
          _events[dueDateKey] = [];
        }

        if (!_events[dueDateKey]!.any((t) => t.id == task.id)) {
          _events[dueDateKey]!.add(task);
        }
      }

      for (final assignedDate in task.assignedDates) {
        final dateKey = DateTime(
          assignedDate.year,
          assignedDate.month,
          assignedDate.day,
        );

        if (_events[dateKey] == null) {
          _events[dateKey] = [];
        }

        if (!_events[dateKey]!.any((t) => t.id == task.id)) {
          _events[dateKey]!.add(task);
        }
      }
    }

    _combineAllEvents();
    _calculateMonthlyCounts();
  }

  void _processRemindersForCalendar(List<ReminderModel> reminders) {
    _reminderEvents = {};

    for (final reminder in reminders) {
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

    _combineAllEvents();
    _calculateMonthlyCounts();
  }

  void _processChallengesForCalendar(List<ChallengeModel> challenges) {
    _challengeEvents = {};

    for (final challenge in challenges) {
      if (challenge.dueDate != null) {
        final dueDateKey = DateTime(
          challenge.dueDate!.year,
          challenge.dueDate!.month,
          challenge.dueDate!.day,
        );

        if (_challengeEvents[dueDateKey] == null) {
          _challengeEvents[dueDateKey] = [];
        }

        if (!_challengeEvents[dueDateKey]!.any((c) => c.id == challenge.id)) {
          _challengeEvents[dueDateKey]!.add(challenge);
        }
      }
    }

    _combineAllEvents();
    _calculateMonthlyCounts();
  }

  void _combineAllEvents() {
    _combinedEvents = {};

    _events.forEach((date, tasks) {
      if (_combinedEvents[date] == null) {
        _combinedEvents[date] = [];
      }
      _combinedEvents[date]!.addAll(tasks);
    });

    _reminderEvents.forEach((date, reminders) {
      if (_combinedEvents[date] == null) {
        _combinedEvents[date] = [];
      }
      _combinedEvents[date]!.addAll(reminders);
    });

    _challengeEvents.forEach((date, challenges) {
      if (_combinedEvents[date] == null) {
        _combinedEvents[date] = [];
      }
      _combinedEvents[date]!.addAll(challenges);
    });

    if (_selectedDay != null) {
      _selectedEvents = _getEventsForDay(_selectedDay!)
          .where((event) => event is TaskModel)
          .cast<TaskModel>()
          .toList();
    }
  }

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

    _challengeEvents.forEach((date, challenges) {
      if (date.year == _focusedDay.year && date.month == _focusedDay.month) {
        _monthlyChallengeCount += challenges.length;
      }
    });
  }

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
      backgroundColor: Color(0xFFBAD1C2),
      appBar: AppBar(
        backgroundColor: Color(0xFF4FA095),
        title: Text(
          'Calendari',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _taskService.streamTasks(_uid),
        builder: (context, taskSnapshot) {
          if (taskSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)));
          }

          return StreamBuilder<List<ReminderModel>>(
            stream: _reminderService.streamReminders(_uid),
            builder: (context, reminderSnapshot) {
              if (reminderSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)));
              }

              return StreamBuilder<List<ChallengeModel>>(
                stream: _challengeService.streamChallenges(_uid),
                builder: (context, challengeSnapshot) {
                  if (challengeSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)));
                  }

                  if (taskSnapshot.hasError) {
                    return Center(child: Text('Error: ${taskSnapshot.error}', style: TextStyle(color: Color(0xFF25766B))));
                  }

                  if (!taskSnapshot.hasData || taskSnapshot.data!.isEmpty) {
                    _events = {};
                  } else {
                    _processTasksForCalendar(taskSnapshot.data!);
                  }

                  if (!reminderSnapshot.hasData || reminderSnapshot.data!.isEmpty) {
                    _reminderEvents = {};
                  } else {
                    _processRemindersForCalendar(reminderSnapshot.data!);
                  }

                  if (!challengeSnapshot.hasData || challengeSnapshot.data!.isEmpty) {
                    _challengeEvents = {};
                  } else {
                    _processChallengesForCalendar(challengeSnapshot.data!);
                  }

                  String monthYear = DateFormat('MMMM yyyy', 'ca').format(_focusedDay);
                  monthYear = '${monthYear[0].toUpperCase()}${monthYear.substring(1)}';

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        Divider(thickness: 2, height: 1, color: Color(0xFF25766B)),

                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                monthYear,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF25766B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Vista: ${_getCalendarFormatText()}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF25766B),
                                ),
                              ),
                              Text(
                                'Data Actual: ${DateFormat('dd/MM/yyyy', 'ca').format(DateTime.now())}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF25766B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Color(0xFFD4E7D9), 
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color.fromARGB(255, 45, 112, 103), width: 1.0),
                          ),
                          child: TableCalendar(
                            locale: 'ca',
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat,
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
                            daysOfWeekHeight: 40, 
                            rowHeight: 50, 
                            daysOfWeekStyle: DaysOfWeekStyle(
                              weekdayStyle: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF25766B)),
                              weekendStyle: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                            calendarStyle: CalendarStyle(
                              defaultTextStyle: TextStyle(color: Color(0xFF25766B)),
                              weekendTextStyle: const TextStyle(color: Colors.red),
                              outsideTextStyle: TextStyle(color: Color(0xFF9BB8A5)),
                              selectedDecoration: BoxDecoration(
                                color: Color(0xFF4FA095),
                                shape: BoxShape.circle,
                              ),
                              selectedTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              todayDecoration: BoxDecoration(
                                color: Color(0xFF4FA095).withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              todayTextStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF25766B),
                              ),
                              markersMaxCount: 3,
                              markersAnchor: 0.7,
                              
                              cellMargin: const EdgeInsets.all(2.0),
                              cellPadding: const EdgeInsets.all(0),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: true,
                              titleCentered: true,
                              titleTextStyle: const TextStyle(fontSize: 0),
                              formatButtonDecoration: BoxDecoration(
                                border: Border.all(color: Color(0xFF4FA095)),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              formatButtonTextStyle: TextStyle(color: Color(0xFF4FA095), fontWeight: FontWeight.w600),
                              leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF4FA095)),
                              rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF4FA095)),
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
                        ),

                        const SizedBox(height: 20),

                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 16.0),
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(61, 35, 224, 161),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total de tasques mes: $_monthlyTaskCount',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF25766B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total de recordatoris mes: $_monthlyReminderCount',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF25766B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total de reptes mes: $_monthlyChallengeCount',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF25766B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        Center(
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.7,
                            margin: const EdgeInsets.symmetric(vertical: 12.0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                backgroundColor: Color(0xFF25766B),
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
                              child: Text(
                                'Veure detall del dia',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (_selectedEvents.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No hi ha tasques per aquest dia',
                                style: TextStyle(
                                  color: Color(0xFF3A8B80),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: _selectedEvents.map((task) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Color(0xFF9BB8A5)),
                                  ),
                                  child: ListTile(
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
                                        color: task.isDone ? Color(0xFF9BB8A5) : Color(0xFF25766B),
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
                                          builder: (context) => TaskDetailScreen(
                                            task: task,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        const SizedBox(height: 100),
                      ],
                    ),
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