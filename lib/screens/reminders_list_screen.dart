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
          color: Color.fromARGB(255, 73, 148, 138),
          border: Border.all(color: Color.fromARGB(255, 36, 78, 73)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFBAD1C2),
      appBar: AppBar(
        backgroundColor: Color(0xFF4FA095),
        title: Text('Llistat de Recordatoris', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        
      ),
      body: Column(
        children: [
          Container(
            color: Color(0xFF9BB8A5),
            padding: const EdgeInsets.all(8),
            child: TextField(
              style: TextStyle(color: Color(0xFF25766B)),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: Color(0xFF4FA095)),
                hintText: 'Cerca pel títol',
                hintStyle: TextStyle(color: Color(0xFF25766B).withOpacity(0.7)),
                border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FA095))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF25766B))),
                fillColor: Colors.white,
                filled: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          Container(
            color: Color(0xFF9BB8A5),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                StreamBuilder<List<ReminderModel>>(
                  stream: _reminderService.streamReminders(_uid),
                  builder: (_, snap) {
                    if (snap.hasData) {
                      _pendingCount = snap.data!.where((r) => !r.isDone).length;
                    }
                    return _buildFilterChip(
                      Text('Pendents: $_pendingCount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    );
                  },
                ),
                const SizedBox(width: 8),
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
                Expanded(
                  child: _buildFilterChip(
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _orderCriterion,
                        dropdownColor: Color(0xFF7C9F88),
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        items: _allCriteria
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white)),
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
          Expanded(
            child: StreamBuilder<List<ReminderModel>>(
              stream: _reminderService.streamReminders(_uid),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)));
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
                  return Center(
                    child: Text(
                      'No hi ha recordatoris', 
                      style: TextStyle(color: Color(0xFF25766B), fontSize: 16, fontWeight: FontWeight.w500)
                    )
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: reminders.length,
                  itemBuilder: (_, i) {
                    final r = reminders[i];
                    return Card(
                      color: Color.fromARGB(61, 35, 224, 161),
                      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                        side: BorderSide(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
                      ),
                      child: ListTile(
                        leading: Icon(
                          r.notificationsEnabled
                              ? Icons.notifications_active
                              : Icons.notifications_off,
                          color: r.notificationsEnabled
                              ? Color.fromARGB(255, 34, 102, 93)
                              : const Color.fromARGB(255, 206, 245, 248),
                        ),
                        title: Text(r.title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(r.reminderTime != null
                            ? DateFormat('dd/MM/yyyy HH:mm')
                                .format(r.reminderTime!)
                            : 'Sense hora',
                            style: TextStyle(color: Colors.white.withOpacity(0.8))),
                        trailing: Icon(
                          r.isDone
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: r.isDone ? const Color.fromARGB(255, 19, 75, 21) : Colors.white.withOpacity(0.6),
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF25766B),
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReminderDetailScreen()),
        ),
      ),
    );
  }
}