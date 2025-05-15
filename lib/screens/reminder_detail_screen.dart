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
    );
    if (date == null) return;
    final tm = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminderTime ?? now),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No tens tasques disponibles')));
      return;
    }
    final sel = await showModalBottomSheet<TaskModel?>(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('Cap tasca'),
            onTap: () => Navigator.pop(context, null),
          ),
          ..._userTasks.map((t) => ListTile(
                title: Text(t.title),
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
      builder: (_) => ListView(
        shrinkWrap: true,
        children: _repetitionOptions
            .map((o) => ListTile(
                  title: Text(o),
                  onTap: () => Navigator.pop(context, o),
                ))
            .toList(),
      ),
    );
    if (sel != null) setState(() => _repetitionPattern = sel);
  }

  // Función para alternar el estado completado del recordatorio
  void _toggleDone() {
    setState(() => _isDone = !_isDone);
    // Si no es un recordatorio nuevo, guardar el cambio inmediatamente
    if (widget.reminder != null) {
      _saveQuiet();
    }
  }

  // Guardar cambios sin mostrar mensajes
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('El títol no pot estar buit')));
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
            const SnackBar(content: Text('Recordatori creat correctament')));
      } else {
        await _reminderService.updateReminder(model);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Canvis desats')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar recordatori?'),
        content: const Text('Estàs segur?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
        ],
      ),
    );
    if (ok == true && widget.reminder != null) {
      setState(() => _isSaving = true);
      await _reminderService.deleteReminder(widget.reminder!.id);
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Recordatori eliminat')));
    }
  }

  // Obtener el estado actual del recordatorio basado en la fecha de vencimiento
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

  // Obtener el color para el estado del recordatorio
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
      appBar: AppBar(
        title: Text(isNew ? 'Nou Recordatori' : 'Editar Recordatori'),
        actions: [
          // Botón para marcar como completado
          if (!isNew)
            IconButton(
              icon: Icon(_isDone ? Icons.check_circle : Icons.radio_button_unchecked, size: 28),
              color: _isDone ? Colors.green : Colors.grey,
              onPressed: _toggleDone,
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Títol'),
                  ),
                  SwitchListTile(
                    title: const Text('Notificacions'),
                    value: _notificationsEnabled,
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                  ),
                  ListTile(
                    title: const Text('Hora'),
                    subtitle: Text(_reminderTime == null
                        ? '—'
                        : DateFormat('dd/MM/yyyy HH:mm').format(_reminderTime!)),
                    trailing: IconButton(icon: const Icon(Icons.schedule), onPressed: _pickReminderTime),
                  ),
                  ListTile(
                    title: const Text('Repetir'),
                    subtitle: Text(_repetitionPattern),
                    trailing: IconButton(icon: const Icon(Icons.repeat), onPressed: _selectRepetitionPattern),
                  ),
                  ListTile(
                    title: const Text('Data venciment'),
                    subtitle: Text(_dueDate == null
                        ? '—'
                        : DateFormat('dd/MM/yyyy').format(_dueDate!)),
                    trailing: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDueDate),
                  ),
                  ListTile(
                    title: const Text('Assignar tasca'),
                    subtitle: Text(_selectedTask?.title ?? '—'),
                    trailing: IconButton(icon: const Icon(Icons.checklist), onPressed: _selectTask),
                  ),
                  // Estado del recordatorio (Vencido/Vigente)
                  if (!isNew || _dueDate != null)
                    ListTile(
                      title: const Text('Estat'),
                      subtitle: Text(
                        _reminderStatus,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.bold,
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
                onPressed: _save,
                child: const Text('Guardar'),
              ),
            ),
            if (!isNew) const SizedBox(width: 16),
            if (!isNew)
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