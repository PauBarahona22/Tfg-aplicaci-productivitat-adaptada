import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
   bool _isSaving = false;

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
  List<bool> _subtaskChecked = [];

  DateTime? _dueDate;
  late DateTime _createdAt;
  bool _isDone = false;
  int _priority = 0;
  bool _remind = false;
  late final String _uid;
  bool _editingTitle = false;

  List<DateTime> _assignedDates = [];

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  IconData _getTypeIcon() {
    switch (_type) {
      case 'Acadèmica':
        return Icons.school;
      case 'Deportiva':
        return Icons.sports;
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
        return Icons.emoji_events;
    }
  }

  Color _getTypeColor() {
    switch (_type) {
      case 'Acadèmica':
        return Colors.blue;
      case 'Deportiva':
        return Colors.green;
      case 'Musical':
        return Colors.purple;
      case 'Familiar':
        return Colors.orange;
      case 'Laboral':
        return Colors.brown;
      case 'Artística':
        return Colors.pink;
      case 'Mascota':
        return Colors.teal;
      default:
        return Colors.yellow;
    }
  }

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;

    if (widget.task != null) {
      final t = widget.task!;
      _titleCtrl.text = t.title;
      _notesCtrl.text = t.notes;
      _type = t.type;
      _dueDate = t.dueDate;
      _createdAt = t.createdAt;
      _isDone = t.isDone;
      _priority = t.priority;
      _remind = t.remind;
      _subtasks = List.from(t.subtasks);
      _subtaskChecked = List<bool>.filled(_subtasks.length, _isDone);

      _assignedDates = List.from(t.assignedDates);

      _docSub = FirebaseFirestore.instance
          .collection('tasks')
          .doc(t.id)
          .snapshots()
          .listen(_onRemoteUpdate);
    } else {
      _createdAt = DateTime.now();
    }
  }

  void _onRemoteUpdate(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) return;
    final t = TaskModel.fromDoc(doc);
    setState(() {
      _titleCtrl.text = t.title;
      _notesCtrl.text = t.notes;
      _type = t.type;
      _dueDate = t.dueDate;
      _createdAt = t.createdAt;
      _isDone = t.isDone;
      _priority = t.priority;
      _remind = t.remind;
      _subtasks = List.from(t.subtasks);
      _subtaskChecked = List<bool>.filled(_subtasks.length, t.isDone);

      _assignedDates = List.from(t.assignedDates);
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
        backgroundColor: Color(0xFFBAD1C2),
        title: Text('Nova subtasca', style: TextStyle(color: Color(0xFF25766B))),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'Descripció',
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FA095))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Cancel·lar', style: TextStyle(color: Color(0xFF3A8B80)))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF25766B)),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()), 
            child: Text('Afegir', style: TextStyle(color: Colors.white))
          ),
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
    final selDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (selDate == null) return;

    final selTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );

    final candidate = DateTime(
      selDate.year,
      selDate.month,
      selDate.day,
      selTime?.hour ?? 23,
      selTime?.minute ?? 59,
    );

    if (candidate.isBefore(now)) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Color(0xFFBAD1C2),
          title: Text('Data passada', style: TextStyle(color: Color(0xFF25766B))),
          content: Text('No pots assignar un venciment en el passat.', style: TextStyle(color: Color(0xFF25766B))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text('D\'acord', style: TextStyle(color: Color(0xFF4FA095)))
            )
          ],
        ),
      );
      return;
    }

    setState(() => _dueDate = candidate);
    await _save(quiet: true);
  }

  int get _daysRemaining {
    if (_dueDate == null) return 0;
    final diff = _dueDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 1;
  }

  String get _status {
    if (_isDone) return 'Completada';
    if (_dueDate != null && _dueDate!.isBefore(DateTime.now())) return 'Vencuda';
    return 'Pendent';
  }

  Future<void> _save({bool quiet = false}) async {
    if (_titleCtrl.text.trim().isEmpty) {
      if (!quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El títol no pot estar buit'),
            backgroundColor: Color(0xFF3A8B80),
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    final isNew = widget.task == null;
    final model = TaskModel(
      id: isNew ? '' : widget.task!.id,
      ownerId: _uid,
      title: _titleCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      createdAt: _createdAt,
      dueDate: _dueDate,
      isDone: _isDone,
      priority: _priority,
      type: _type,
      remind: _remind,
      subtasks: _subtasks,
      assignedDates: _assignedDates,
    );

    try {
      if (isNew) {
        await _taskService.addTask(model);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tasca creada correctament'),
            backgroundColor: Color(0xFF4FA095),
          ),
        );
      } else {
        await _taskService.updateTask(model.copyWith(id: widget.task!.id));
        if (!quiet) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Canvis desats'),
              backgroundColor: Color(0xFF4FA095),
            ),
          );
        }
      }
    } catch (e) {
      if (!quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Color(0xFF3A8B80),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Color(0xFFBAD1C2),
        title: Text('Eliminar tasca?', style: TextStyle(color: Color(0xFF25766B))),
        content: Text('Estàs segur que la vols eliminar?', style: TextStyle(color: Color(0xFF25766B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text('No', style: TextStyle(color: Color(0xFF3A8B80)))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF25766B)),
            onPressed: () => Navigator.pop(context, true), 
            child: Text('Sí', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
    if (ok == true && widget.task != null) {
      await _taskService.deleteTask(widget.task!.id);
      Navigator.pop(context);
    }
  }

  void _toggleReminderSnackbar() {
    _save(quiet: true);
    final msg = _remind ? 'Recordatori 24 h activat' : 'Recordatori 24 h desactivat';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Color(0xFF4FA095),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.task == null;
    final titleText = isNew ? 'Nova Tasca' : widget.task!.title;

    if (_subtaskChecked.length != _subtasks.length) {
      _subtaskChecked = List<bool>.filled(_subtasks.length, _isDone);
    }

    return Scaffold(
      backgroundColor: Color(0xFFBAD1C2),
      appBar: AppBar(
        backgroundColor: Color(0xFF4FA095),
        leading: BackButton(color: Colors.white),
        title: _editingTitle
            ? TextField(
                controller: _titleCtrl,
                autofocus: true,
                maxLength: 50,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                onSubmitted: (_) {
                  setState(() => _editingTitle = false);
                  _save();
                },
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      titleText,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.white), 
                    onPressed: () => setState(() => _editingTitle = true)
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isDone ? Icons.check_box : Icons.check_box_outline_blank, size: 28, color: Colors.white),
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
            Text('Parts de la tasca', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF25766B))),
            const SizedBox(height: 8),
            if (_subtasks.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addSubtaskDialog,
                  icon: Icon(Icons.add, color: Color(0xFF4FA095)),
                  label: Text('Afegir subtasca', style: TextStyle(color: Color(0xFF4FA095))),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < _subtasks.length; i++)
                    Container(
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF7C9F88),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: _subtaskChecked[i],
                          activeColor: Color(0xFF4FA095),
                          onChanged: (v) {
                            setState(() => _subtaskChecked[i] = v!);
                            _isDone = _subtaskChecked.every((c) => c);
                            _save(quiet: true);
                          },
                        ),
                        title: Text(_subtasks[i], style: TextStyle(color: Colors.white)),
                        trailing: IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _subtasks.removeAt(i);
                              _subtaskChecked.removeAt(i);
                            });
                            _save(quiet: true);
                          },
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addSubtaskDialog,
                      icon: Icon(Icons.add, color: Color(0xFF4FA095)),
                      label: Text('Afegir subtasca', style: TextStyle(color: Color(0xFF4FA095))),
                    ),
                  ),
                ],
              ),
            const Divider(height: 32, color: Color(0xFF7C9F88)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _type,
                        decoration: InputDecoration(
                          labelText: 'Tipus',
                          labelStyle: TextStyle(color: Color(0xFF25766B)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FA095))),
                        ),
                        items: _allTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) {
                          setState(() => _type = v!);
                          _save(quiet: true);
                        },
                      ),
                      const SizedBox(height: 8),
                      Text('Estat: $_status', style: TextStyle(color: Color(0xFF25766B))),
                      if (_dueDate != null) ...[
                        const SizedBox(height: 4),
                        Text('Temps restant: $_daysRemaining ${_daysRemaining == 1 ? 'dia' : 'dies'}', style: TextStyle(color: Color(0xFF25766B))),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _getTypeColor().withOpacity(0.2),
                    border: Border.all(color: _getTypeColor()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_getTypeIcon(), size: 32, color: _getTypeColor()),
                ),
              ],
            ),
            const Divider(height: 32, color: Color(0xFF7C9F88)),
            DropdownButtonFormField<int>(
              value: _priority,
              decoration: InputDecoration(
                labelText: 'Prioritat',
                labelStyle: TextStyle(color: Color(0xFF25766B)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FA095))),
              ),
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
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF7C9F88),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text('Data de venciment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(_dueDate != null
                    ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year} '
                      '${_dueDate!.hour.toString().padLeft(2,'0')}:'
                      '${_dueDate!.minute.toString().padLeft(2,'0')}'
                    : 'Cap', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                trailing: Icon(Icons.calendar_today, color: Colors.white),
                onTap: _pickDueDate,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF7C9F88),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text('Data de creació', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${_createdAt.day}/${_createdAt.month}/${_createdAt.year} '
                  '${_createdAt.hour.toString().padLeft(2,'0')}:'
                  '${_createdAt.minute.toString().padLeft(2,'0')}',
                  style: TextStyle(color: Colors.white.withOpacity(0.8))
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4FA095),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.calendar_today),
              label: const Text('Assignar dia calendari'),
              onPressed: isNew
                  ? null
                  : () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: const Locale('ca'),
                      );
                      if (selectedDate != null && widget.task != null) {
                        await _taskService.assignTaskToCalendar(widget.task!, selectedDate);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Tasca assignada al dia ${DateFormat('dd/MM/yyyy','ca').format(selectedDate)}'
                            ),
                            backgroundColor: Color(0xFF4FA095),
                          ),
                        );
                      }
                    },
            ),
            if (!isNew && _assignedDates.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Dies assignats:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF25766B))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _assignedDates.map((date) {
                  return Chip(
                    backgroundColor: Color(0xFF7C9F88),
                    label: Text(DateFormat('dd/MM/yyyy','ca').format(date), style: TextStyle(color: Colors.white)),
                    deleteIcon: Icon(Icons.close, size: 18, color: Colors.white),
                    onDeleted: () async {
                      if (widget.task == null) return;
                      await _taskService.removeAssignedDate(widget.task!, date);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Assignació eliminada'),
                          backgroundColor: Color(0xFF4FA095),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
            const Divider(height: 32, color: Color(0xFF7C9F88)),
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF7C9F88),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                title: Text('Recordar 24 h abans', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                value: _remind,
                activeColor: Color(0xFF4FA095),
                onChanged: (v) {
                  setState(() => _remind = v);
                  _toggleReminderSnackbar();
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              maxLength: 200,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              style: TextStyle(color: Color(0xFF25766B)),
              decoration: InputDecoration(
                labelText: 'Afegir nota',
                labelStyle: TextStyle(color: Color(0xFF25766B)),
                border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF7C9F88))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FA095))),
                fillColor: Colors.white,
                filled: true,
              ),
              onSubmitted: (_) => _save(quiet: true),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF25766B),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await _save();
                },
                child: const Text('Guardar'),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF3A8B80),
                side: BorderSide(color: Color(0xFF3A8B80)),
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