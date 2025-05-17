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
        
        // Mostrar pop-up de medalla conseguida
        if (_isCompleted) {
          _showMedalAchievedDialog();
        }
      }
    });
  }
  
  // Nuevo método para decrementar el progreso
  Future<void> _decrementProgress() async {
    // Solo decrementar progreso de retos personales
    if (_isPredefined) return;
    
    // No decrementar si ya está en 0
    if (_currentCount <= 0) return;
    
    setState(() {
      _currentCount--;
      // Si estaba completado y ahora no, actualizamos el estado
      if (_currentCount < _targetCount) {
        _isCompleted = false;
      }
    });
  }
  
  // Nuevo método para mostrar el popup de medalla conseguida
  Future<void> _showMedalAchievedDialog() async {
    // Obtener icono según categoría
    IconData medalIcon;
    Color medalColor;
    
    switch (_category) {
      case 'Acadèmica':
        medalIcon = Icons.school;
        medalColor = Colors.blue;
        break;
      case 'Deportiva':
        medalIcon = Icons.sports;
        medalColor = Colors.green;
        break;
      case 'Musical':
        medalIcon = Icons.music_note;
        medalColor = Colors.purple;
        break;
      case 'Familiar':
        medalIcon = Icons.family_restroom;
        medalColor = Colors.orange;
        break;
      case 'Laboral':
        medalIcon = Icons.work;
        medalColor = Colors.brown;
        break;
      case 'Artística':
        medalIcon = Icons.palette;
        medalColor = Colors.pink;
        break;
      case 'Mascota':
        medalIcon = Icons.pets;
        medalColor = Colors.teal;
        break;
      default:
        medalIcon = Icons.emoji_events;
        medalColor = Colors.amber;
    }
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '¡Medalla aconseguida!', 
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: medalColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                medalIcon,
                size: 60,
                color: medalColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Has guanyat una medalla $_category',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Continua completant reptes per guanyar més medalles!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: medalColor,
              ),
              child: const Text('Genial!'),
            ),
          ),
        ],
      ),
    );
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
        // Usar método especial que también maneja medallas
        bool wasCompleted = widget.challenge!.isCompleted;
        await _challengeService.updateChallengeAndMedals(challenge);
        
        // Mostrar popup de medalla si se completa
        if (!wasCompleted && _isCompleted) {
          await _showMedalAchievedDialog();
        }
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
  
  // Función para obtener icono según categoría
  IconData _getCategoryIcon(String category) {
    switch (category) {
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
  
  // Función para obtener color según categoría
  Color _getCategoryColor(String category) {
    switch (category) {
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
        return Colors.amber;
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

                  // MOVIDO: Barra de progreso mejorada y más gruesa
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progrés actual: $_currentCount/$_targetCount',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          // Barra de progreso mejorada - más gruesa
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 18, // Más gruesa
                              width: double.infinity,
                              color: Colors.grey.shade200,
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOut,
                                    height: 18, // Más gruesa
                                    width: MediaQuery.of(context).size.width * 
                                        (_targetCount > 0 ? _currentCount / _targetCount : 0) * 0.75,
                                    decoration: BoxDecoration(
                                      color: _isCompleted
                                          ? Colors.green
                                          : _isExpired
                                              ? Colors.red
                                              : Colors.blue,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Completat: ${_targetCount > 0 ? ((_currentCount / _targetCount) * 100).toInt() : 0}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isCompleted ? Colors.green : Colors.grey[600],
                                ),
                              ),
                              if (!_isPredefined && !_isCompleted)
                                Row(
                                  children: [
                                    // Botón decrementar
                                    ElevatedButton.icon(
                                      onPressed: _currentCount > 0 ? _decrementProgress : null,
                                      icon: const Icon(Icons.remove),
                                      label: const Text(''),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Botón incrementar
                                    ElevatedButton.icon(
                                      onPressed: _incrementProgress,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Avançar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                            color: _getCategoryColor(_category),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_category),
                      ],
                    ),
                    trailing: !_isPredefined
                        ? const Icon(Icons.arrow_forward_ios, size: 16)
                        : null,
                    onTap: _isPredefined ? null : _selectCategory,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Fecha límite (solo para retos personales)
                  if (!_isPredefined)
                    ListTile(
                      title: const Text('Data límit'),
                      subtitle: _dueDate != null
                          ? Text(DateFormat('dd/MM/yyyy - HH:mm', 'ca')
                              .format(_dueDate!))
                          : const Text('Sense data límit'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_dueDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _removeDueDate,
                            ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _pickDueDate,
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Cantidad objetivo (solo editable para retos personales)
                  ListTile(
                    title: const Text('Quantitat objectiu'),
                    subtitle: !_isPredefined
                        ? TextField(
                            controller: _targetCountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Quantitat',
                              border: OutlineInputBorder(),
                            ),
                            enabled: !_isPredefined,
                          )
                        : Text('${_targetCount}'),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // NUEVO: Sección de medalla que se obtendrá (centrada)
                  Center(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Medalla que s\'aconseguirà',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: _getCategoryColor(_category).withOpacity(0.2),
                              child: Icon(
                                _getCategoryIcon(_category),
                                color: _getCategoryColor(_category),
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _category,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getCategoryColor(_category),
                              ),
                            ),
                            Text(
                              _isPredefined ? 'Repte General' : 'Repte Personal',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Guardar cambios (no disponible para retos predefinidos)
                  if (!_isPredefined)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar canvis'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}