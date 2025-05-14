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

  static const _allCriteria = ['Data creació', 'Hora assignada', 'Nom'];

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
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cerca pel títol',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                StreamBuilder<List<ReminderModel>>(
                  stream: _reminderService.streamReminders(_uid),
                  builder: (_, snap) {
                    if (snap.hasData) {
                      _pendingCount =
                          snap.data!.where((r) => !r.isDone).length;
                    }
                    return Chip(label: Text('Pendents: $_pendingCount'));
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(_ascending
                      ? Icons.arrow_downward
                      : Icons.arrow_upward),
                  onPressed: () =>
                      setState(() => _ascending = !_ascending),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _orderCriterion,
                  items: _allCriteria
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _orderCriterion = v);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ReminderModel>>(
              stream: _reminderService.streamReminders(_uid),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var reminders = snap.data!;
                if (_searchQuery.isNotEmpty) {
                  reminders = reminders
                      .where((r) => r.title
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()))
                      .toList();
                }
                reminders.sort((a, b) {
                  int cmp;
                  switch (_orderCriterion) {
                    case 'Data creació':
                      cmp = a.createdAt.compareTo(b.createdAt);
                      break;
                    case 'Hora assignada':
                      cmp = (a.reminderTime ?? DateTime(9999))
                          .compareTo(b.reminderTime ?? DateTime(9999));
                      break;
                    default:
                      cmp = a.title
                          .toLowerCase()
                          .compareTo(b.title.toLowerCase());
                  }
                  return _ascending ? cmp : -cmp;
                });
                if (reminders.isEmpty) {
                  return const Center(child: Text('No hi ha recordatoris'));
                }
                return ListView.builder(
                  itemCount: reminders.length,
                  itemBuilder: (_, i) {
                    final r = reminders[i];
                    return ListTile(
                      leading: Icon(
                        r.notificationsEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        color: r.notificationsEnabled
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      title: Text(r.title),
                      subtitle: Text(r.reminderTime != null
                          ? DateFormat('dd/MM/yyyy HH:mm')
                              .format(r.reminderTime!)
                          : 'Sense hora'),
                      trailing: Icon(
                        r.isDone
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: r.isDone ? Colors.green : Colors.grey,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ReminderDetailScreen(reminder: r),
                          ),
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
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReminderDetailScreen()),
        ),
      ),
    );
  }
}
