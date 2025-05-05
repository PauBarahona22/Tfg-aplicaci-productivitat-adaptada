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
      items: _allTypes
          .map((t) => PopupMenuItem(value: t, child: Text(t)))
          .toList(),
    );
    if (selected != null) setState(() => _selectedType = selected);
  }

  Widget _buildFilterChip(Widget child, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,                      // ← altura fixa
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,     // centra el contingut verticalment
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Llistat de Tasques')),
      body: Column(
        children: [
          // 1) Buscador
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscador de tasques pel nom',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),

          // 2) Fila de filtres amb Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 2.1 Pendents
                StreamBuilder<List<TaskModel>>(
                  stream: _taskService.streamTasks(_uid),
                  builder: (ctx, snap) {
                    final pendents = snap.hasData
                        ? snap.data!.where((t) => !t.isDone).length
                        : 0;
                    return _buildFilterChip(
                      Text('Pendents: $pendents'),
                    );
                  },
                ),

                const SizedBox(width: 8),

                // 2.2 Filtrar per tipus
                _buildFilterChip(
                  Image.asset(
                    'assets/filtratgepertipus.PNG',
                    width: 24,
                    height: 24,
                  ),
                  onTap: _pickType,
                ),

                const SizedBox(width: 8),

                // 2.3 Ascendent/Descendent
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

                // 2.4 Criteri d'ordenació (s’expandeix per evitar overflow)
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

          // 3) Llista de tasques
          Expanded(
            child: StreamBuilder<List<TaskModel>>(
              stream: _taskService.streamTasks(_uid),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Apliquem cerca, filtre per tipus i orden
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
                  return const Center(child: Text('No hi ha tasques'));
                }

                return ListView.builder(
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
                      margin:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: dotColor,
                          ),
                        ),
                        title: Text(t.title),
                        subtitle: Text(
                          t.dueDate != null
                              ? 'Venciment: ${t.dueDate!.day.toString().padLeft(2, '0')}/${t.dueDate!.month.toString().padLeft(2, '0')}/${t.dueDate!.year}'
                              : 'Sense venciment',
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

      // 4) Botó de nova tasca
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskDetailScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
