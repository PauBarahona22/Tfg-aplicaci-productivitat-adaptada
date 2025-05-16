import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/challenge_model.dart';
import '../database/challenge_service.dart';
class ChallengeDetailScreen extends StatefulWidget {
  final ChallengeModel? challenge;
  const ChallengeDetailScreen({super.key, this.challenge});
  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}
class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final _challengeService = ChallengeService();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _targetCountCtrl = TextEditingController(text: '1');
  late DateTime _createdAt;
  DateTime? _dueDate;
  bool _isCompleted = false;
  String _type = 'Personal'; // Siempre será personal para retos nuevos
  String _category = 'General';
  int _targetCount = 1;
  int _currentCount = 0;
  bool _isExpired = false;
  bool _isPredefined = false; // Retos creados por la app
  bool _isSaving = false;
  late final String _uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  // Categorías disponibles (iguales a las de tareas)
  static const List<String> _categoryOptions = [
    'General',
    'Acadèmica',
    'Deportiva',
    'Musical',
    'Familiar',
    'Laboral',
    'Artística',
    'Mascota',
  ];
  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
    
    if (widget.challenge != null) {
      final c = widget.challenge!;
      _titleCtrl.text = c.title;
      _descriptionCtrl.text = c.description;
      _createdAt = c.createdAt;
      _dueDate = c.dueDate;
      _isCompleted = c.isCompleted;
      _type = c.type;
      _category = c.category;
      _targetCount = c.targetCount;
      _targetCountCtrl.text = _targetCount.toString();
      _currentCount = c.currentCount;
      _isExpired = c.isExpired;
      _isPredefined = c.isPredefined;
      
      // Solo escuchar actualizaciones para retos predefinidos
      if (c.isPredefined) {
        _docSub = FirebaseFirestore.instance
            .collection('challenges')
            .doc(c.id)
            .snapshots()
            .listen(_onRemoteUpdate);
      }
    } else {
      _createdAt = DateTime.now();
    }
  }
  void _onRemoteUpdate(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists || !mounted) return;
    final c = ChallengeModel.fromDoc(doc);
    setState(() {
      _currentCount = c.currentCount;
      _isCompleted = c.isCompleted;
    });
  }
  @override
  void dispose() {
    _docSub?.cancel();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _targetCountCtrl.dispose();
    super.dispose();
  }
  Future<void> _pickDueDate() async {
    // Solo permitir seleccionar fecha para retos personales
    if (_isPredefined) return;
    
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    
    if (selectedDate == null) return;
    
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate ?? DateTime(now.year, now.month, now.day, 23, 59)),
    );
    
    final dueDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime?.hour ?? 23,
      selectedTime?.minute ?? 59,
    );
    
    setState(() => _dueDate = dueDate);
  }
  Future<void> _removeDueDate() async {
    if (_isPredefined) return;
    setState(() => _dueDate = null);
  }
  Future<void> _selectCategory() async {
    // Solo permitir cambiar categoría para retos personales
    if (_isPredefined) return;
    
    final selectedCategory = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: _categoryOptions
            .map((category) => ListTile(
                  title: Text(category),
                  onTap: () => Navigator.pop(context, category),
                ))
            .toList(),
      ),
    );
    
    if (selectedCategory != null) {
      setState(() => _category = selectedCategory);
    }
  }
  Future<void> _incrementProgress() async {
    // Solo incrementar progreso de retos personales
    if (_isPredefined) return;
    
    // No incrementar si ya está completo
    if (_isCompleted) return;
    
    setState(() {
      _currentCount++;
      if (_currentCount >= _targetCount) {
        _isCompleted = true;
      }
    });
  }
  Future<void> _save() async {
    // Validación
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El títol és obligatori')),
      );
      return;
    }
    
    // Validar cantidad objetivo
    int? targetCount = int.tryParse(_targetCountCtrl.text.trim());
    if (targetCount == null || targetCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La quantitat objectiu ha de ser un número vàlid major o igual a 1')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final isNew = widget.challenge == null;
      
      // Actualizar valores
      _targetCount = targetCount;
      
      // Si es un reto predefinido, no permitir modificar ciertos campos
      if (_isPredefined) {
        // No modificar nada para retos predefinidos
        if (mounted) {
          setState(() => _isSaving = false);
          // Importante: Primero actualizar el estado y después navegar
          Navigator.of(context).pop();
        }
        return;
      }
      
      // Crear objeto Challenge
      final challenge = ChallengeModel(
        id: isNew ? 'temp' : widget.challenge!.id,
        ownerId: _uid,
        title: title,
        description: _descriptionCtrl.text.trim(),
        createdAt: _createdAt,
        dueDate: _dueDate,
        isCompleted: _isCompleted,
        type: _type,
        category: _category,
        targetCount: _targetCount,
        currentCount: _currentCount,
        isExpired: _isExpired,
        isPredefined: _isPredefined,
      );
      
      // Guardar en Firebase
      if (isNew) {
        await _challengeService.addChallenge(challenge);
      } else {
        await _challengeService.updateChallenge(challenge);
      }
      
      // Es crucial asegurarse que este código se ejecute
      if (mounted) {
        setState(() => _isSaving = false); // Desactivar estado de carga primero
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isNew ? 'Repte creat correctament' : 'Repte actualitzat correctament')),
        );
        
        // Usar Future.delayed para garantizar que la navegación se produce después de todo lo demás
        Future.delayed(Duration.zero, () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      // En caso de error, mostrar mensaje y permitir al usuario intentar de nuevo
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
  Future<void> _delete() async {
    // No permitir eliminar retos predefinidos
    if (_isPredefined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No es poden eliminar els reptes predefinits')),
      );
      return;
    }
    
    // Confirmar eliminación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar repte'),
        content: const Text('Estàs segur que vols eliminar aquest repte?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel·lar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isSaving = true);
    
    try {
      await _challengeService.deleteChallenge(widget.challenge!.id);
      
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repte eliminat correctament')),
        );
        
        // Usar Future.delayed para garantizar que la navegación se produce después de todo lo demás
        Future.delayed(Duration.zero, () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isNew = widget.challenge == null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Nou Repte' : 'Detalls del Repte'),
        actions: [
          // Icono de eliminar solo para retos existentes no predefinidos
          if (!isNew && !_isPredefined)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _delete,
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campo de título
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Títol del repte',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_isPredefined,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Campo de descripción
                  TextField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripció',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    enabled: !_isPredefined,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Tipo de reto (predefinido o personal)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isPredefined ? Colors.blue.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isPredefined ? Icons.auto_awesome : Icons.person,
                          color: _isPredefined ? Colors.blue : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPredefined ? 'Repte General' : 'Repte Personal',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isPredefined ? Colors.blue.shade800 : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Selección de categoría
                  ListTile(
                    title: const Text('Categoria'),
                    subtitle: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_category),
                      ],
                    ),
                    trailing: _isPredefined
                        ? null
                        : const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _isPredefined ? null : _selectCategory,
                  ),
                  
                  // Fecha límite (solo para retos personales)
                  if (!_isPredefined)
                    ListTile(
                      title: const Text('Data límit'),
                      subtitle: _dueDate == null
                          ? const Text('Sense data límit')
                          : Text(DateFormat('dd/MM/yyyy HH:mm').format(_dueDate!)),
                      trailing: _dueDate == null
                          ? const Icon(Icons.add_circle_outline)
                          : const Icon(Icons.edit),
                      onTap: _pickDueDate,
                      onLongPress: _dueDate == null ? null : _removeDueDate,
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Cantidad objetivo (solo editable para retos personales)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _targetCountCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Quantitat objectiu',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          enabled: !_isPredefined && isNew, // Solo editable en creación
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Progreso actual
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progrés: $_currentCount de $_targetCount',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _targetCount > 0 
                            ? _currentCount / _targetCount 
                            : 0,
                        backgroundColor: Colors.grey[300],
                        color: _isCompleted 
                            ? Colors.green 
                            : _isExpired 
                                ? Colors.red 
                                : Colors.blue,
                        minHeight: 20,
                      ),
                      
                      // Botón para incrementar progreso (solo para retos personales)
                      if (!_isPredefined && !isNew && !_isCompleted)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ElevatedButton.icon(
                            onPressed: _incrementProgress,
                            icon: const Icon(Icons.add),
                            label: const Text('Incrementar progrés (+1)'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _isSaving
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Botón para cancelar
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isNew ? 'Cancel·lar' : 'Tornar'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Botón para guardar (solo visible si no es predefinido)
                  if (!_isPredefined)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        child: Text(isNew ? 'Crear Repte' : 'Actualitzar'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}