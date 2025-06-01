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
  String _type = 'Personal';
  String _category = 'General';
  int _targetCount = 1;
  int _currentCount = 0;
  bool _isExpired = false;
  bool _isPredefined = false;
  bool _isSaving = false;
  late final String _uid;

  bool _medalPopupShown = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

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
    if (_isPredefined) return;

    final now = DateTime.now();
    final selectedDate = await showDatePicker(
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

    if (selectedDate == null) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate ?? DateTime(now.year, now.month, now.day, 23, 59)),
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
    if (_isPredefined) return;

    final selectedCategory = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Color(0xFFBAD1C2),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: _categoryOptions
            .map((category) => ListTile(
                  title: Text(category, style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600)),
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
    if (_isPredefined) return;
    if (_isCompleted) return;

    final bool wasCompleted = _isCompleted;

    setState(() {
      _currentCount++;
      if (_currentCount >= _targetCount) {
        _isCompleted = true;
      }
    });

    if (!wasCompleted && _isCompleted && !_medalPopupShown) {
      await _challengeService.updateUserMedals(
        _uid,
        _category,
        _isPredefined
      );

      _medalPopupShown = true;
      await _showMedalAchievedDialog();
    }
  }

  Future<void> _decrementProgress() async {
    if (_isPredefined) return;
    if (_currentCount <= 0) return;

    setState(() {
      _currentCount--;
      if (_currentCount < _targetCount) {
        _isCompleted = false;
        _medalPopupShown = false;
      }
    });
  }

  Future<void> _showMedalAchievedDialog() async {
    // ignore: unused_local_variable
    IconData medalIcon;
    // ignore: unused_local_variable
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
      builder: (context) => Dialog(
        backgroundColor: Color(0xFFBAD1C2),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¡Medalla aconseguida!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF25766B),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 180,
                height: 180,
                child: Image.asset(
                  'assets/images/mascot_celebration.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Has guanyat una medalla $_category',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF25766B), 
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Continua completant reptes per guanyar més medalles!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF3A8B80), 
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF25766B),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Genial!', 
                    style: TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
        color: Color.fromARGB(61, 35, 224, 161),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
      ),
      child: Column(
        children: [
          Text(
            'Medalla que s\'aconseguirà',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF25766B),
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
              color: Color(0xFF3A8B80),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El títol és obligatori'), backgroundColor: Color(0xFF3A8B80)),
      );
      return;
    }

    int? targetCount = int.tryParse(_targetCountCtrl.text.trim());
    if (targetCount == null || targetCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La quantitat objectiu ha de ser un número vàlid major o igual a 1'), backgroundColor: Color(0xFF3A8B80)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isNew = widget.challenge == null;
      _targetCount = targetCount;

      if (_isPredefined) {
        if (mounted) {
          setState(() => _isSaving = false);
          Navigator.of(context).pop();
        }
        return;
      }

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

      final bool wasCompleted = isNew ? false : widget.challenge!.isCompleted;
      final bool isNewlyCompleted = !wasCompleted && _isCompleted;

      if (isNew) {
        await _challengeService.addChallenge(challenge);
      } else {
        await _challengeService.updateChallenge(challenge);

        if (isNewlyCompleted && !_medalPopupShown) {
          await _challengeService.updateUserMedals(
            _uid,
            _category,
            _isPredefined
          );

          _medalPopupShown = true;
          await _showMedalAchievedDialog();
        }
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isNew ? 'Repte creat correctament' : 'Repte actualitzat correctament'), backgroundColor: Color(0xFF4FA095)),
        );

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
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Color(0xFF3A8B80)),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (_isPredefined) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No es poden eliminar els reptes predefinits'), backgroundColor: Color(0xFF3A8B80)),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFBAD1C2),
        title: Text('Eliminar repte', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600)),
        content: Text('Estàs segur que vols eliminar aquest repte?', style: TextStyle(color: Color(0xFF25766B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel·lar', style: TextStyle(color: Color(0xFF3A8B80), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF25766B)),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
          SnackBar(content: Text('Repte eliminat correctament'), backgroundColor: Color(0xFF4FA095)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el repte: ${e.toString()}'), backgroundColor: Color(0xFF3A8B80)),
        );
      }
    }
  }

  Future<void> _forceComplete() async {
    if (_isCompleted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFBAD1C2),
        title: Text('Marcar com a completat', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600)),
        content: Text('Segur que vols marcar aquest repte com a completat?', style: TextStyle(color: Color(0xFF25766B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel·lar', style: TextStyle(color: Color(0xFF3A8B80), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF25766B)),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Marcar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _currentCount = _targetCount;
      _isCompleted = true;
    });

    if (!_medalPopupShown) {
      await _challengeService.updateUserMedals(
        _uid,
        _category,
        _isPredefined
      );

      _medalPopupShown = true;
      await _showMedalAchievedDialog();
    }
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.challenge != null;
    final isPredefined = _isPredefined;

    return Scaffold(
      backgroundColor: Color(0xFFBAD1C2),
      appBar: AppBar(
        backgroundColor: Color(0xFF4FA095),
        leading: BackButton(color: Colors.white),
        title: Text(
          isEdit
              ? isPredefined
                  ? 'Detall del repte'
                  : 'Editar repte'
              : 'Nou repte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (isEdit && !isPredefined)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              onPressed: _delete,
            ),
        ],
      ),
      body: _isSaving
          ? Center(child: CircularProgressIndicator(color: Color(0xFF4FA095)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleCtrl,
                    style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Títol del repte',
                      labelStyle: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w500),
                      border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF25766B))),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FA095), width: 2)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF25766B))),
                    ),
                    readOnly: isPredefined,
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _descriptionCtrl,
                    style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w500, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Descripció (opcional)',
                      labelStyle: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w500),
                      border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF25766B))),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FA095), width: 2)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF25766B))),
                    ),
                    maxLines: 3,
                    readOnly: isPredefined,
                  ),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: isPredefined ? null : _selectCategory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFF25766B)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(_category),
                            color: _getCategoryColor(_category),
                          ),
                          const SizedBox(width: 8),
                          Text('Categoria: $_category', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (!isPredefined)
                            Icon(Icons.arrow_drop_down, color: Color(0xFF25766B)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _targetCountCtrl,
                          style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600, fontSize: 16),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantitat objectiu',
                            labelStyle: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w500),
                            border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF25766B))),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FA095), width: 2)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF25766B))),
                          ),
                          readOnly: isPredefined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (!isPredefined)
                    GestureDetector(
                      onTap: _pickDueDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFF25766B)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Color(0xFF25766B)),
                            const SizedBox(width: 8),
                            Text(
                              _dueDate == null
                                  ? 'Sense data límit'
                                  : 'Data límit: ${DateFormat('dd/MM/yyyy HH:mm').format(_dueDate!)}',
                              style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            if (_dueDate != null)
                              IconButton(
                                icon: Icon(Icons.clear, color: Color(0xFF25766B)),
                                onPressed: _removeDueDate,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ),

                  if (isEdit) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Progres actual:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF25766B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _targetCount > 0 ? _currentCount / _targetCount : 0,
                      minHeight: 15,
                      borderRadius: BorderRadius.circular(10),
                      backgroundColor: Color(0xFF9BB8A5),
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4FA095)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Completat: $_currentCount/$_targetCount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF25766B),
                          ),
                        ),
                        Text(
                          '${((_currentCount / _targetCount) * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF25766B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (!isPredefined && !_isCompleted)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _decrementProgress,
                            icon: const Icon(Icons.remove),
                            label: Text('Decrementar', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _incrementProgress,
                            icon: const Icon(Icons.add),
                            label: Text('Incrementar', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[400],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),

                    if (!_isCompleted)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: ElevatedButton.icon(
                          onPressed: _forceComplete,
                          icon: const Icon(Icons.check_circle),
                          label: Text('Marcar com completat', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4FA095),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ),

                    if (_isCompleted)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(61, 35, 224, 161),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Repte completat!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Has guanyat una medalla $_category!',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],

                  if (!_isCompleted) _buildMedalToAchieve(),

                  if (!isPredefined)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF25766B),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: Text(
                          isEdit ? 'Actualitzar repte' : 'Crear repte',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}