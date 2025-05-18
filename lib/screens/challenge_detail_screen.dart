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
  // Variable para controlar si ya se mostró el popup de medalla
  bool _medalPopupShown = false;
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
    
    final bool wasCompleted = _isCompleted;
    
    setState(() {
      _currentCount++;
      if (_currentCount >= _targetCount) {
        _isCompleted = true;
      }
    });
    
    // If it just got completed, directly update the medals
    if (!wasCompleted && _isCompleted && !_medalPopupShown) {
      // Update medals in Firestore
      await _challengeService.updateUserMedals(
        _uid,
        _category,
        _isPredefined
      );
      
      // Marcar que ya se mostró el popup
      _medalPopupShown = true;
      
      // Show medal dialog
      await _showMedalAchievedDialog();
    }
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
        // Resetear la bandera del popup si se quita el estado de completado
        _medalPopupShown = false;
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
  
  // Método para construir el widget de medalla que se conseguirá
  Widget _buildMedalToAchieve() {
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
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          const Text(
            'Medalla que s\'aconseguirà',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: medalColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              medalIcon,
              size: 30,
              color: medalColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _category,
            style: TextStyle(
              fontSize: 14,
              color: medalColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _type,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
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
      
      // Determinar si es un reto recién completado
      final bool wasCompleted = isNew ? false : widget.challenge!.isCompleted;
      final bool isNewlyCompleted = !wasCompleted && _isCompleted;
      
      // Guardar en Firebase
      if (isNew) {
        await _challengeService.addChallenge(challenge);
      } else {
        // Actualizar el reto
        await _challengeService.updateChallenge(challenge);
        
        // Si el reto acaba de completarse y no se ha mostrado el popup, actualizar medallas
        if (isNewlyCompleted && !_medalPopupShown) {
          // Actualizar medallas en Firestore
          await _challengeService.updateUserMedals(
            _uid,
            _category,
            _isPredefined
          );
          
          // Marcar que ya se mostró el popup
          _medalPopupShown = true;
          
          // Mostrar diálogo de medalla
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
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el repte: ${e.toString()}')),
        );
      }
    }
  }
  
  Future<void> _forceComplete() async {
    if (_isCompleted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar com a completat'),
        content: const Text('Segur que vols marcar aquest repte com a completat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel·lar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Marcar'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() {
      _currentCount = _targetCount;
      _isCompleted = true;
    });
    
    // Si no se ha mostrado el popup, actualizar medallas
    if (!_medalPopupShown) {
      // Actualizar medallas en Firestore
      await _challengeService.updateUserMedals(
        _uid,
        _category,
        _isPredefined
      );
      
      // Marcar que ya se mostró el popup
      _medalPopupShown = true;
      
      // Mostrar diálogo de medalla
      await _showMedalAchievedDialog();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.challenge != null;
    final isPredefined = _isPredefined;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? isPredefined
                ? 'Detall del repte'
                : 'Editar repte'
            : 'Nou repte'),
        actions: [
          // Botón de eliminar solo para edición
          if (isEdit && !isPredefined)
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Campo título
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Títol del repte',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: isPredefined,
                  ),
                  const SizedBox(height: 16),
                  
                  // 2. Campo descripción
                  TextField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripció (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    readOnly: isPredefined,
                  ),
                  const SizedBox(height: 16),
                  
                  // 3. Sección de categoría
                  GestureDetector(
                    onTap: isPredefined ? null : _selectCategory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(_category),
                            color: _getCategoryColor(_category),
                          ),
                          const SizedBox(width: 8),
                          Text('Categoria: $_category'),
                          const Spacer(),
                          if (!isPredefined)
                            const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 4. Sección de cantidad objetivo
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _targetCountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantitat objectiu',
                            border: OutlineInputBorder(),
                          ),
                          readOnly: isPredefined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 5. Sección de fecha límite (solo para retos no predefinidos)
                  if (!isPredefined)
                    GestureDetector(
                      onTap: _pickDueDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 8),
                            Text(
                              _dueDate == null
                                  ? 'Sense data límit'
                                  : 'Data límit: ${DateFormat('dd/MM/yyyy HH:mm').format(_dueDate!)}',
                            ),
                            const Spacer(),
                            if (_dueDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _removeDueDate,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Sección de progreso (solo para edición)
                  if (isEdit) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Progres actual:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _targetCount > 0
                          ? _currentCount / _targetCount
                          : 0,
                      minHeight: 15,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Completat: $_currentCount/$_targetCount',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${((_currentCount / _targetCount) * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Botones de incremento/decremento para retos personales
                    if (!isPredefined && !_isCompleted)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _decrementProgress,
                            icon: const Icon(Icons.remove),
                            label: const Text('Decrementar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _incrementProgress,
                            icon: const Icon(Icons.add),
                            label: const Text('Incrementar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[400],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    
                    // Botón para marcar como completado
                    if (!_isCompleted)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: ElevatedButton.icon(
                          onPressed: _forceComplete,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Marcar com completat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ),
                    
                    // Mensaje de felicitación si está completo
                    if (_isCompleted)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Repte completat!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Has guanyat una medalla $_category!',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  
                  // Mostrar la sección de medalla a conseguir si el reto no está completado
                  if (!_isCompleted) 
                    _buildMedalToAchieve(),
                  
                  // Botón de guardar
                  if (!isPredefined)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: Text(isEdit ? 'Actualitzar' : 'Crear'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
  
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
}