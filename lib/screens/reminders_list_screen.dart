import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/reminder_model.dart';
import '../database/reminder_service.dart';
import 'reminder_detail_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _reminderService = ReminderService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  String _searchQuery = '';
  String _orderCriterion = 'Data creació';
  bool _ascending = false;
  int _pendingCount = 0;

  static const List<String> _allCriteria = [
    'Data creació', 
    'Hora assignada',
    'Nom'
  ];

  void _toggleAscending() {
    setState(() => _ascending = !_ascending);
  }

  Widget _buildFilterChip(Widget child, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _reminderService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Llistat de Recordatoris')),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscador de recordatoris pel nom',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),

          // Fila de filtres
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pendents
                StreamBuilder<List<ReminderModel>>(
                  stream: _reminderService.streamReminders(_uid),
                  builder: (ctx, snap) {
                    if (snap.hasData) {
                      _pendingCount = snap.data!.where((r) => !r.isDone).length;
                    }
                    return _buildFilterChip(
                      Text('Recordatoris pendents: $_pendingCount'),
                    );
                  },
                ),

                const SizedBox(width: 8),

                // Ascendent/Descendent
                _buildFilterChip(
                  Image.asset(
                    _ascending
                        ? 'assets/iconodebaixcapadalt.PNG'
                        : 'assets/iconodedaltabaix.PNG',
                    width: 24,
                    height: 24,
                  ),
                  onTap: _toggleAscending,
                ),

                const SizedBox(width: 8),

                // Criteri d'ordenació
                Expanded(
                  child: _buildFilterChip(
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _orderCriterion,
                        items: _allCriteria
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _orderCriterion = v);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Llista de recordatoris
          Expanded(
            child: StreamBuilder<List<ReminderModel>>(
              stream: _reminderService.streamReminders(_uid),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Apliquem cerca i ordenació
                var reminders = snap.data!;

                if (_searchQuery.isNotEmpty) {
                  reminders = reminders
                      .where((r) => r.title.toLowerCase().contains(_searchQuery.toLowerCase()))
                      .toList();
                }

                reminders.sort((a, b) {
                  int cmp;
                  switch (_orderCriterion) {
                    case 'Data creació':
                      cmp = a.createdAt.compareTo(b.createdAt);
                      break;
                    case 'Hora assignada':
                      final timeA = a.reminderTime ?? DateTime(2100);
                      final timeB = b.reminderTime ?? DateTime(2100);
                      cmp = timeA.compareTo(timeB);
                      break;
                    case 'Nom':
                      cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
                      break;
                    default:
                      cmp = 0;
                  }
                  return _ascending ? cmp : -cmp;
                });

                if (reminders.isEmpty) {
                  return const Center(child: Text('No hi ha recordatoris'));
                }

                return ListView.builder(
                  itemCount: reminders.length,
                  itemBuilder: (ctx, i) {
                    final reminder = reminders[i];
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          reminder.notificationsEnabled 
                              ? Icons.notifications_active 
                              : Icons.notifications_off,
                          color: reminder.notificationsEnabled ? Colors.blue : Colors.grey,
                        ),
                        title: Text(reminder.title),
                        subtitle: Text(
                          reminder.reminderTime != null
                              ? 'Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(reminder.reminderTime!)}'
                              : 'Sense hora assignada',
                        ),
                        trailing: Icon(
                          reminder.isDone ? Icons.check_circle : Icons.circle_outlined,
                          color: reminder.isDone ? Colors.green : Colors.grey,
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
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // Botó per afegir nou recordatori
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReminderDetailScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}