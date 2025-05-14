import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/reminder_model.dart';
import '../database/reminder_service.dart';
import '../database/task_service.dart';
import '../models/task_model.dart';

class ReminderDetailScreen extends StatefulWidget {
  final ReminderModel? reminder;
  const ReminderDetailScreen({super.key, this.reminder});

  @override
  State<ReminderDetailScreen> createState() => _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends State<ReminderDetailScreen> {
  final _reminderService = ReminderService();
  final _taskService = TaskService();
  final _titleCtrl = TextEditingController();

  late DateTime _createdAt;
  DateTime? _dueDate;
  DateTime? _reminderTime;
  bool _isDone = false;
  bool _notificationsEnabled = true;
  String? _taskId;
  String _repetitionPattern = 'No repetir';
  List<DateTime> _assignedDates = [];

  bool _editingTitle = false;
  late final String _uid;
  bool _isSaving = false;

  List<String> _repetitionOptions = [
    'No repetir',
    'Diàriament',
    'Setmanalment',
    'Mensualment',
  ];

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  List<TaskModel> _userTasks = [];
  TaskModel? _selectedTask;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;

    if (widget.reminder != null) {
      final r = widget.reminder!;
      _titleCtrl.text = r.title;
      _createdAt = r.createdAt;
      _dueDate = r.dueDate;
      _reminderTime = r.reminderTime;
      _isDone = r.isDone;
      _notificationsEnabled = r.notificationsEnabled;
      _taskId = r.taskId;
      _repetitionPattern = r.repetitionPattern;
      _assignedDates = List.from(r.assignedDates);

      _docSub = FirebaseFirestore.instance
          .collection('reminders')
          .doc(r.id)
          .snapshots()
          .listen(_onRemoteUpdate);
    } else {
      _createdAt = DateTime.now();
    }
    _loadUserTasks();
  }

  void _onRemoteUpdate(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) return;
    final r = ReminderModel.fromDoc(doc);
    setState(() {
      _titleCtrl.text = r.title;
      _createdAt = r.createdAt;
      _dueDate = r.dueDate;
      _reminderTime = r.reminderTime;
      _isDone = r.isDone;
      _notificationsEnabled = r.notificationsEnabled;
      _taskId = r.taskId;
      _repetitionPattern = r.repetitionPattern;
      _assignedDates = List.from(r.assignedDates);
    });
  }

  Future<void> _loadUserTasks() async {
    _taskService.streamTasks(_uid).listen((tasks) {
      setState(() {
        _userTasks = tasks;
        if (_taskId != null) {
          _selectedTask = _userTasks.firstWhere(
            (task) => task.id == _taskId,
            orElse: () => null as TaskModel,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _docSub?.cancel();
    _titleCtrl.dispose();
    super.dispose();
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
    setState(() => _dueDate = DateTime(
      selDate.year,
      selDate.month,
      selDate.day,
      _dueDate?.hour ?? 0,
      _dueDate?.minute ?? 0,
    ));
    await _save(quiet: true);
  }

  Future<void> _pickReminderTime() async {
    final now = DateTime.now();
    final selDate = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (selDate == null) return;
    final selTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminderTime ?? now),
    );
    if (selTime == null) return;
    setState(() => _reminderTime = DateTime(
      selDate.year,
      selDate.month,
      selDate.day,
      selTime.hour,
      selTime.minute,
    ));
    await _save(quiet: true);
  }

  Future<void> _selectTask() async {
    if (_userTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tens tasques disponibles')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Selecciona una tasca',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _userTasks.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      title: const Text('Cap tasca'),
                      onTap: () {
                        setState(() {
                          _taskId = null;
                          _selectedTask = null;
                        });
                        Navigator.pop(context);
                        _save(quiet: true);
                      },
                    );
                  }
                  final task = _userTasks[index - 1];
                  return ListTile(
                    title: Text(task.title),
                    subtitle: task.dueDate != null
                        ? Text('Venciment: ${DateFormat('dd/MM/yyyy').format(task.dueDate!)}')
                        : const Text('Sense venciment'),
                    onTap: () {
                      setState(() {
                        _taskId = task.id;
                        _selectedTask = task;
                      });
                      Navigator.pop(context);
                      _save(quiet: true);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectRepetitionPattern() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Patró de repetició',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _repetitionOptions.length,
              itemBuilder: (context, index) {
                final option = _repetitionOptions[index];
                return ListTile(
                  title: Text(option),
                  onTap: () {
                    setState(() => _repetitionPattern = option);
                    Navigator.pop(context);
                    _save(quiet: true);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int get _daysRemaining {
    if (_dueDate == null) return 0;
    final diff = _dueDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  Future<void> _save({bool quiet = false}) async {
    if (_titleCtrl.text.trim().isEmpty) {
      if (!quiet) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El títol no pot estar buit')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final isNew = widget.reminder == null;
      final model = ReminderModel(
        id: isNew ? '' : widget.reminder!.id,
        ownerId: _uid,
        title: _titleCtrl.text.trim(),
        createdAt: _createdAt,
        dueDate: _dueDate,
        reminderTime: _reminderTime,
        isDone: _isDone,
        notificationsEnabled: _notificationsEnabled,
        taskId: _taskId,
        repetitionPattern: _repetitionPattern,
        assignedDates: _assignedDates,
      );
      if (isNew) {
        await _reminderService.addReminder(model);
        if (!quiet && mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recordatori creat correctament')));
        }
      } else {
        await _reminderService.updateReminder(model);
        if (!quiet && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canvis desats')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Eliminar recordatori?'),
      content: const Text('Estàs segur que el vols eliminar?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
      ],
    ));
    if (ok == true && widget.reminder != null) {
      setState(() => _isSaving = true);
      try {
        await _reminderService.deleteReminder(widget.reminder!.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recordatori eliminat')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.reminder == null;
    final titleText = isNew ? 'Nou Recordatori' : widget.reminder!.title;
    final creationDateFormatted = DateFormat('dd/MM/yyyy', 'ca').format(_createdAt);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _isSaving ? null : () => Navigator.pop(context)),
        title: _editingTitle
            ? TextField(
                controller: _titleCtrl,
                autofocus: true,
                maxLength: 50,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                onSubmitted: (_) { setState(() => _editingTitle = false); _save(quiet: true); },
              )
            : Row(
                children: [
                  Expanded(child: Text(titleText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.edit), onPressed: _isSaving ? null : () => setState(() => _editingTitle = true)),
                ],
              ),
        actions: [
          if (!isNew)
            IconButton(
              icon: Icon(_isDone ? Icons.check_box : Icons.check_box_outline_blank, size: 28),
              onPressed: _isSaving ? null : () { setState(() => _isDone = !_isDone); _save(quiet: true); },
            ),
        ],
      ),
      body: _isSaving ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Data Creació: $creationDateFormatted'),
            if (_dueDate != null) Text('Temps Restant: $_daysRemaining ${_daysRemaining == 1 ? 'dia' : 'dies'}'),
            const Divider(height: 24),
            Row(
              children: [
                Text('Activar o desactivar notificacions:', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Switch(value: _notificationsEnabled, onChanged: (v) { setState(() => _notificationsEnabled = v); _save(quiet: true); }),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text('Tasca Assignada:', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(onPressed: _selectTask, child: Text(_selectedTask?.title ?? '—')),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              title: Text('Hora assignada:', style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(_reminderTime != null
                  ? DateFormat('EEEE, d MMMM | HH:mm', 'ca').format(_reminderTime!)
                  : '—'),
              trailing: IconButton(icon: const Icon(Icons.schedule), onPressed: _pickReminderTime),
            ),
            const Divider(height: 24),
            ListTile(
              title: Text('Repetir notificació:', style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(_repetitionPattern),
              trailing: IconButton(icon: const Icon(Icons.repeat), onPressed: _selectRepetitionPattern),
            ),
            const Divider(height: 24),
            ListTile(
              title: Text('Assignar data Venciment:', style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(_dueDate != null
                  ? DateFormat('dd/MM/yyyy').format(_dueDate!)
                  : '—'),
              trailing: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDueDate),
            ),
            const Divider(height: 24),
            ListTile(
              title: Text('Assignar Dia del calendari:', style: Theme.of(context).textTheme.titleMedium),
              trailing: IconButton(icon: const Icon(Icons.calendar_month), onPressed: () {}),
            ),
            const Divider(height: 24),
            ListTile(
              title: Text('Assignar tasca:', style: Theme.of(context).textTheme.titleMedium),
              trailing: IconButton(icon: const Icon(Icons.checklist), onPressed: _selectTask),
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
                onPressed: () async { await _save(); },
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
