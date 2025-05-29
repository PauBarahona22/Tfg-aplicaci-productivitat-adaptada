import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';
import '../database/task_service.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _taskService = TaskService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  String _searchQuery = '';
  String _selectedType = 'Totes';
  String _orderCriterion = 'Data venciment';
  bool _ascending = true;

  static const List<String> _allTypes = [
    'Totes',
    'Acadèmica',
    'Deportiva',
    'Musical',
    'Familiar',
    'Laboral',
    'Artística',
    'Mascota',
  ];

  static const List<String> _allCriteria = [
    'Data venciment',
    'Prioritat',
    'Data creació',
    'Nom',
  ];

  void _toggleAscending() {
    setState(() => _ascending = !_ascending);
  }

  Future<void> _pickType() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(50, 100, 50, 0),
      color: Color(0xFFBAD1C2),
      items: _allTypes
          .map((t) => PopupMenuItem(value: t, child: Text(t, style: TextStyle(color: Color(0xFF25766B)))))
          .toList(),
    );
    if (selected != null) setState(() => _selectedType = selected);
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

  IconData _getTaskTypeIcon(String type) {
    switch (type) {
      case 'Acadèmica':
        return Icons.school;
      case 'Deportiva':
        return Icons.sports_soccer;
      case 'Musical':
        return Icons.music_note;
      case 'Familiar':
        return Icons.family_restroom;
      case 'Laboral':
        return Icons.work;
      case 'Artística':
        return Icons.palette;
      case 'Mascota':
        return Icons.pets;
      default:
        return Icons.task;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFBAD1C2),
      appBar: AppBar(
        backgroundColor: Color(0xFF4FA095),
        title: Text('Llistat de Tasques', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        
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
                hintText: 'Buscador de tasques pel nom',
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
                StreamBuilder<List<TaskModel>>(
                  stream: _taskService.streamTasks(_uid),
                  builder: (ctx, snap) {
                    final pendents = snap.hasData
                        ? snap.data!.where((t) => !t.isDone).length
                        : 0;
                    return _buildFilterChip(
                      Text('Pendents: $pendents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  Image.asset(
                    'assets/filtratgepertipus.PNG',
                    width: 24,
                    height: 24,
                  ),
                  onTap: _pickType,
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
                        style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255), fontWeight: FontWeight.w600),
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
            child: StreamBuilder<List<TaskModel>>(
              stream: _taskService.streamTasks(_uid),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)));
                }

                var tasks = snap.data!;

                if (_searchQuery.isNotEmpty) {
                  tasks = tasks
                      .where((t) =>
                          t.title.toLowerCase().contains(_searchQuery.toLowerCase()))
                      .toList();
                }
                if (_selectedType != 'Totes') {
                  tasks = tasks.where((t) => t.type == _selectedType).toList();
                }
                tasks.sort((a, b) {
                  int cmp;
                  switch (_orderCriterion) {
                    case 'Data venciment':
                      final da = a.dueDate ?? DateTime(2100);
                      final db = b.dueDate ?? DateTime(2100);
                      cmp = da.compareTo(db);
                      break;
                    case 'Prioritat':
                      cmp = a.priority.compareTo(b.priority);
                      break;
                    case 'Data creació':
                      cmp = a.createdAt.compareTo(b.createdAt);
                      break;
                    case 'Nom':
                      cmp = a.title
                          .toLowerCase()
                          .compareTo(b.title.toLowerCase());
                      break;
                    default:
                      cmp = 0;
                  }
                  return _ascending ? cmp : -cmp;
                });

                if (tasks.isEmpty) {
                  return Center(
                    child: Text(
                      'No hi ha tasques', 
                      style: TextStyle(color: Color(0xFF25766B), fontSize: 16, fontWeight: FontWeight.w500)
                    )
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) {
                    final t = tasks[i];
                    final now = DateTime.now();
                    Color dotColor;
                    if (t.isDone) {
                      dotColor = Colors.green;
                    } else if (t.dueDate != null && t.dueDate!.isBefore(now)) {
                      dotColor = Colors.red;
                    } else {
                      dotColor = Colors.blue;
                    }
                    return Card(
                      color: Color.fromARGB(61, 35, 224, 161),
                      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                  side: BorderSide(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
                                ),
                      child: ListTile(
                        leading: GestureDetector(
                          onTap: () {
                            final updated = TaskModel(
                              id: t.id,
                              ownerId: t.ownerId,
                              title: t.title,
                              createdAt: t.createdAt,
                              dueDate: t.dueDate,
                              isDone: !t.isDone,
                              priority: t.priority,
                              type: t.type,
                              remind: t.remind,
                              subtasks: t.subtasks,
                            );
                            _taskService.updateTask(updated);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: dotColor,
                            ),
                          ),
                        ),
                        title: Text(t.title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          t.dueDate != null
                              ? 'Venciment: ${t.dueDate!.day.toString().padLeft(2, '0')}/${t.dueDate!.month.toString().padLeft(2, '0')}/${t.dueDate!.year}'
                              : 'Sense venciment',
                          style: TextStyle(color: Colors.white.withOpacity(0.8)),
                        ),
                        trailing: Icon(
                          _getTaskTypeIcon(t.type),
                          color: const Color.fromARGB(255, 160, 228, 224),
                          size: 28,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => TaskDetailScreen(task: t)),
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskDetailScreen()),
          );
        },
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}