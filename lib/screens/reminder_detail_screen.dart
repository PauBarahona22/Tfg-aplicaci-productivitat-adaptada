import 'dart:async';
import 'package:flutter/material.dart';
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
  bool _isSaving = false;
  late final String _uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  List<TaskModel> _userTasks = [];
  TaskModel? _selectedTask;

  final List<String> _repetitionOptions = [
    'No repetir',
    'Diàriament',
    'Setmanalment',
    'Mensualment',
  ];

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
    });
  }

  Future<void> _loadUserTasks() async {
    _taskService.streamTasks(_uid).listen((tasks) {
      setState(() {
        _userTasks = tasks;
        _selectedTask = _userTasks.firstWhere(
          (t) => t.id == _taskId,
          orElse: () => null as TaskModel,
        );
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
    final sel = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF4FA095),
              onPrimary: Colors.white,
              surface: Color(0xFFBAD1C2),
              onSurface: Color(0xFF25766B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (sel != null) setState(() => _dueDate = sel);
  }

  Future<void> _pickReminderTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF4FA095),
              onPrimary: Colors.white,
              surface: Color(0xFFBAD1C2),
              onSurface: Color(0xFF25766B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;
    final tm = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminderTime ?? now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF4FA095),
              onPrimary: Colors.white,
              surface: Color(0xFFBAD1C2),
              onSurface: Color(0xFF25766B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (tm != null) {
      setState(() => _reminderTime = DateTime(
            date.year,
            date.month,
            date.day,
            tm.hour,
            tm.minute,
          ));
    }
  }

  Future<void> _selectTask() async {
    if (_userTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No tens tasques disponibles'),
          backgroundColor: Color(0xFF4FA095),
        ),
      );
      return;
    }
    final sel = await showModalBottomSheet<TaskModel?>(
      context: context,
      backgroundColor: Color(0xFFBAD1C2),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text('Cap tasca', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, null),
          ),
          ..._userTasks.map((t) => ListTile(
                title: Text(t.title, style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(context, t),
              ))
        ],
      ),
    );
    setState(() {
      _selectedTask = sel;
      _taskId = sel?.id;
    });
  }

  Future<void> _selectRepetitionPattern() async {
    final sel = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Color(0xFFBAD1C2),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: _repetitionOptions
            .map((o) => ListTile(
                  title: Text(o, style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context, o),
                ))
            .toList(),
      ),
    );
    if (sel != null) setState(() => _repetitionPattern = sel);
  }

  void _toggleDone() {
    setState(() => _isDone = !_isDone);

    if (widget.reminder != null) {
      _saveQuiet();
    }
  }

  Future<void> _saveQuiet() async {
    if (_titleCtrl.text.trim().isEmpty) return;

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
      assignedDates: [],
    );

    try {
      if (!isNew) {
        await _reminderService.updateReminder(model);
      }
    } catch (e) {
      print('Error al guardar: $e');
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El títol no pot estar buit'),
          backgroundColor: Color(0xFF3A8B80),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
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
      assignedDates: [],
    );

    try {
      if (isNew) {
        await _reminderService.addReminder(model);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recordatori creat correctament'),
            backgroundColor: Color(0xFF4FA095),
          ),
        );
      } else {
        await _reminderService.updateReminder(model);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Canvis desats'),
            backgroundColor: Color(0xFF4FA095),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Color(0xFF3A8B80),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Color(0xFFBAD1C2),
        title: Text('Eliminar recordatori?', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600)),
        content: Text('Estàs segur?', style: TextStyle(color: Color(0xFF25766B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text('No', style: TextStyle(color: Color(0xFF3A8B80), fontWeight: FontWeight.w600))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF25766B)),
            onPressed: () => Navigator.pop(context, true), 
            child: Text('Sí', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
          ),
        ],
      ),
    );
    if (ok == true && widget.reminder != null) {
      setState(() => _isSaving = true);
      await _reminderService.deleteReminder(widget.reminder!.id);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recordatori eliminat'),
          backgroundColor: Color(0xFF4FA095),
        ),
      );
    }
  }

  String get _reminderStatus {
    if (_isDone) return 'Completat';
    if (_dueDate == null) return 'Sense data de venciment';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);

    if (dueDate.isBefore(today)) {
      return 'Vençut';
    } else {
      return 'Vigent';
    }
  }

  Color get _statusColor {
    switch (_reminderStatus) {
      case 'Completat':
        return Colors.green;
      case 'Vençut':
        return Colors.red;
      case 'Vigent':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.reminder == null;
    return Scaffold(
      backgroundColor: Color(0xFFBAD1C2),
      appBar: AppBar(
        backgroundColor: Color(0xFF4FA095),
        leading: BackButton(color: Colors.white),
        title: Text(
          isNew ? 'Nou Recordatori' : 'Editar Recordatori',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!isNew)
            IconButton(
              icon: Icon(_isDone ? Icons.check_circle : Icons.radio_button_unchecked, size: 28),
              color: _isDone ? Colors.green : Colors.white,
              onPressed: _toggleDone,
            ),
        ],
      ),
      body: _isSaving
          ? Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Títol',
                      labelStyle: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w500),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FA095))),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF25766B))),
                    ),
                  ),
                  SwitchListTile(
                    title: Text('Notificacions', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600, fontSize: 16)),
                    value: _notificationsEnabled,
                    activeColor: Color(0xFF4FA095),
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                  ),
                  ListTile(
                    title: Text('Hora', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: Text(
                      _reminderTime == null
                          ? '—'
                          : DateFormat('dd/MM/yyyy HH:mm').format(_reminderTime!),
                      style: TextStyle(color: Color(0xFF3A8B80), fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.schedule, color: Color(0xFF25766B)), 
                      onPressed: _pickReminderTime
                    ),
                  ),
                  ListTile(
                    title: Text('Repetir', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: Text(_repetitionPattern, style: TextStyle(color: Color(0xFF3A8B80), fontWeight: FontWeight.w500, fontSize: 14)),
                    trailing: IconButton(
                      icon: Icon(Icons.repeat, color: Color(0xFF25766B)), 
                      onPressed: _selectRepetitionPattern
                    ),
                  ),
                  ListTile(
                    title: Text('Data venciment', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: Text(
                      _dueDate == null
                          ? '—'
                          : DateFormat('dd/MM/yyyy').format(_dueDate!),
                      style: TextStyle(color: Color(0xFF3A8B80), fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.calendar_today, color: Color(0xFF25766B)), 
                      onPressed: _pickDueDate
                    ),
                  ),
                  ListTile(
                    title: Text('Assignar tasca', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: Text(_selectedTask?.title ?? '—', style: TextStyle(color: Color(0xFF3A8B80), fontWeight: FontWeight.w500, fontSize: 14)),
                    trailing: IconButton(
                      icon: Icon(Icons.checklist, color: Color(0xFF25766B)), 
                      onPressed: _selectTask
                    ),
                  ),
                  if (!isNew || _dueDate != null)
                    ListTile(
                      title: Text('Estat', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600, fontSize: 16)),
                      subtitle: Text(
                        _reminderStatus,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      leading: Icon(
                        _isDone ? Icons.check_circle :
                        (_reminderStatus == 'Vençut' ? Icons.warning : Icons.info),
                        color: _statusColor,
                      ),
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
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF25766B)),
                onPressed: _save,
                child: Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
            if (!isNew) const SizedBox(width: 16),
            if (!isNew)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF25766B),
                ),
                onPressed: _confirmDelete,
                child: Icon(Icons.delete),
              ),
          ],
        ),
      ),
    );
  }
}