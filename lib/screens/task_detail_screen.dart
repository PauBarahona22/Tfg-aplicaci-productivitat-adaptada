import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../database/task_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel? task;
  const TaskDetailScreen({super.key, this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _taskService = TaskService();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  static const List<String> _allTypes = [
    'General',
    'Acadèmica',
    'Deportiva',
    'Musical',
    'Familiar',
    'Laboral',
    'Artística',
    'Mascota',
  ];
  String _type = _allTypes.first;

  List<String> _subtasks = [];
  List<bool>  _subtaskChecked = [];

  DateTime? _dueDate;
  bool _isDone   = false;
  int  _priority = 0;
  bool _remind   = false;
  late final String _uid;
  bool _editingTitle = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;

    if (widget.task != null) {
      // Subscripció en temps real al doc
      _docSub = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task!.id)
          .snapshots()
          .listen(_onRemoteUpdate);
    } else {
      // Nova tasca: mantenim valors per defecte
      _titleCtrl.text = '';
      _notesCtrl.text = '';
    }
  }

  void _onRemoteUpdate(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) return;
    final t = TaskModel.fromDoc(doc);
    setState(() {
      _titleCtrl.text = t.title;
      _notesCtrl.text = t.notes;
      _type = _allTypes.firstWhere(
        (e) => e.toLowerCase() == t.type.toLowerCase(),
        orElse: () => _allTypes.first,
      );
      _dueDate = t.dueDate;
      _isDone = t.isDone;
      _priority = t.priority;
      _remind = t.remind;
      _subtasks = List.from(t.subtasks);
      // Ajustem checks: tots fets si t.isDone és true, sinó tots a false
      _subtaskChecked = List<bool>.filled(_subtasks.length, t.isDone);
    });
  }

  @override
  void dispose() {
    _docSub?.cancel();
    super.dispose();
  }

  Future<void> _addSubtaskDialog() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nova subtasca'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Descripció'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel·lar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Afegir')),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      setState(() {
        _subtasks.add(res);
        _subtaskChecked.add(false);
      });
      await _save(quiet: true);
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final sel = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (sel != null) {
      setState(() => _dueDate = sel);
      await _save(quiet: true);
    }
  }

  String get _status {
    if (_isDone) return 'Completada';
    if (_dueDate != null && _dueDate!.isBefore(DateTime.now())) return 'Vencuda';
    return 'Pendent';
  }

  /// Guarda canvis a Firestore però **no** tanca la pantalla si `quiet=true`.
  Future<void> _save({bool quiet = false}) async {
    if (_titleCtrl.text.trim().isEmpty) {
      if (!quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El títol no pot estar buit')),
        );
      }
      return;
    }

    final isNew = widget.task == null;
    final model = TaskModel(
      id:        isNew ? '' : widget.task!.id,
      ownerId:   _uid,
      title:     _titleCtrl.text.trim(),
      notes:     _notesCtrl.text.trim(),
      createdAt: widget.task?.createdAt ?? DateTime.now(),
      dueDate:   _dueDate,
      isDone:    _isDone,
      priority:  _priority,
      type:      _type,
      remind:    _remind,
      subtasks:  _subtasks,
    );

    if (isNew) {
      await _taskService.addTask(model);
    } else {
      await _taskService.updateTask(model.copyWith(id: widget.task!.id));
    }

    if (!quiet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canvis desats')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar tasca?'),
        content: const Text('Estàs segur que vols eliminar aquesta tasca?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
        ],
      ),
    );
    if (ok == true) {
      await _taskService.deleteTask(widget.task!.id);
      Navigator.pop(context);
    }
  }

  void _toggleReminderSnackbar() {
    _save(quiet: true);
    final msg = _remind
      ? 'Recordatori 24 h activat'
      : 'Recordatori 24 h desactivat';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isNew      = widget.task == null;
    final appBarTitle = isNew ? 'Nova Tasca' : widget.task!.title;

    // Garantim coherència entre subtasques i checks
    if (_subtaskChecked.length != _subtasks.length) {
      _subtaskChecked = List<bool>.filled(_subtasks.length, _isDone);
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: _editingTitle
          ? TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(border: InputBorder.none),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              onSubmitted: (_) {
                setState(() => _editingTitle = false);
                _save();
              },
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    appBarTitle,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => setState(() => _editingTitle = true),
                ),
              ],
            ),
        actions: [
          IconButton(
            icon: Icon(
              _isDone ? Icons.check_box : Icons.check_box_outline_blank,
              size: 28,
            ),
            onPressed: () {
              setState(() => _isDone = !_isDone);
              _save(quiet: true);
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Subtasques
            Text('Parts de la tasca', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_subtasks.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addSubtaskDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Afegir subtasca'),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < _subtasks.length; i++)
                    ListTile(
                      leading: Checkbox(
                        value: _subtaskChecked[i],
                        onChanged: (v) {
                          setState(() {
                            _subtaskChecked[i] = v!;
                            _isDone = _subtaskChecked.every((c) => c);
                          });
                          _save(quiet: true);
                        },
                      ),
                      title: Text(_subtasks[i]),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () {
                          setState(() {
                            _subtasks.removeAt(i);
                            _subtaskChecked.removeAt(i);
                          });
                          _save(quiet: true);
                        },
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addSubtaskDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Afegir subtasca'),
                    ),
                  ),
                ],
              ),

            const Divider(height: 32),

            // Tipus + Estat + Mascota
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _type,
                        decoration: const InputDecoration(labelText: 'Tipus'),
                        items: _allTypes
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _type = v!);
                          _save(quiet: true);
                        },
                      ),
                      const SizedBox(height: 8),
                      Text('Estat: $_status'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text('D', style: TextStyle(fontSize: 24)),
                ),
              ],
            ),

            const Divider(height: 32),

            // Prioritat
            DropdownButtonFormField<int>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Prioritat'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Cap')),
                DropdownMenuItem(value: 1, child: Text('Baixa')),
                DropdownMenuItem(value: 2, child: Text('Mitjana')),
                DropdownMenuItem(value: 3, child: Text('Alta')),
              ],
              onChanged: (v) {
                setState(() => _priority = v!);
                _save(quiet: true);
              },
            ),

            const SizedBox(height: 16),

            // Data de venciment
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data de venciment'),
              subtitle: Text(_dueDate != null
                  ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                  : 'Cap'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDueDate,
            ),

            const SizedBox(height: 16),

            // Assignar dia calendari
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Assignar dia calendari'),
              trailing: const Icon(Icons.calendar_view_month),
              onTap: () {/* TODO */},
            ),

            // Assignar recordatori
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Assignar recordatori'),
              trailing: const Icon(Icons.notifications),
              onTap: () {/* TODO */},
            ),

            // Recordatori 24 h abans
            SwitchListTile(
              title: const Text('Recordar 24 h abans'),
              value: _remind,
              onChanged: (v) {
                setState(() => _remind = v);
                _toggleReminderSnackbar();
              },
            ),

            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Afegir nota',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onSubmitted: (_) => _save(quiet: true),
            ),
          ],
        ),
      ),

      // Barra de botons fixa a baix
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await _save();
                  // No fem Navigator.pop(); l’usuari pot prémer la fletxa
                },
                child: const Text('Guardar'),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: const BorderSide(color: Colors.grey),
                minimumSize: const Size(56, 56),
              ),
              onPressed: _confirmDelete,
              child: const Icon(Icons.delete),
            ),
          ],
        ),
      ),
    );
  }
}
