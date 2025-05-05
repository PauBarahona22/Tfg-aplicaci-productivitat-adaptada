import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _typeCtrl = TextEditingController();
  final _subtasksCtrl = TextEditingController();
  DateTime? _dueDate;
  bool _isDone = false;
  int _priority = 0;
  bool _remind = false;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
    final t = widget.task;
    if (t != null) {
      _titleCtrl.text = t.title;
      _typeCtrl.text = t.type;
      _subtasksCtrl.text = t.subtasks.join('\n');
      _dueDate = t.dueDate;
      _isDone = t.isDone;
      _priority = t.priority;
      _remind = t.remind;
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
    if (sel != null) setState(() => _dueDate = sel);
  }

  Future<void> _save() async {
    final isNew = widget.task == null;
    final model = TaskModel(
      id: isNew ? '' : widget.task!.id,
      ownerId: _uid,
      title: _titleCtrl.text.trim(),
      createdAt: widget.task?.createdAt ?? DateTime.now(),
      dueDate: _dueDate,
      isDone: _isDone,
      priority: _priority,
      type: _typeCtrl.text.trim(),
      remind: _remind,
      subtasks: _subtasksCtrl.text
          .trim()
          .split('\n')
          .where((s) => s.isNotEmpty)
          .toList(),
    );
    if (isNew) {
      await _taskService.addTask(model);
    } else {
      await _taskService.updateTask(model.copyWith(id: widget.task!.id));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.task == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Nova Tasca' : 'Detall Tasca'),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await _taskService.deleteTask(widget.task!.id);
                Navigator.pop(context);
              },
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Títol'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _typeCtrl,
              decoration: const InputDecoration(labelText: 'Tipus'),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Data de venciment'),
              subtitle: Text(_dueDate != null
                  ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                  : 'Cap'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDueDate,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Prioritat'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Cap')),
                DropdownMenuItem(value: 1, child: Text('Baixa')),
                DropdownMenuItem(value: 2, child: Text('Mitjana')),
                DropdownMenuItem(value: 3, child: Text('Alta')),
              ],
              onChanged: (v) => setState(() => _priority = v ?? 0),
            ),
            SwitchListTile(
              title: const Text('Completada'),
              value: _isDone,
              onChanged: (v) => setState(() => _isDone = v),
            ),
            SwitchListTile(
              title: const Text('Recordar 24 h abans'),
              value: _remind,
              onChanged: (v) => setState(() => _remind = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtasksCtrl,
              decoration: const InputDecoration(
                labelText: 'Subtasques (una línia cada una)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
