import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../database/auth_service.dart';
import '../database/task_service.dart';
import '../database/local_storage_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final TaskService _taskService = TaskService();
  UserModel? _currentUser;
  bool _isLoading = true;

  String? _localImagePath;
  Map<String, int> _medals = {};
  int _totalMedals = 0;
  int _completedTasks = 0;
  int _pendingTasks = 0;
  int _expiredTasks = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    User? user = _authService.currentUser;

    if (user != null) {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (snapshot.exists) {
        final userData = snapshot.data()!;

        if (!userData.containsKey('medals')) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
                'medals': {
                  'General': 0,
                  'Acadèmica': 0,
                  'Deportiva': 0,
                  'Musical': 0,
                  'Familiar': 0,
                  'Laboral': 0,
                  'Artística': 0,
                  'Mascota': 0,
                  'Predefined': 0,
                }
              });

          snapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
        }

        final localImagePath = await LocalStorageService.getProfileImagePath(user.uid);
        final tasks = await _taskService.streamTasks(user.uid).first;
        final now = DateTime.now();

        setState(() {
          _currentUser = UserModel.fromMap(snapshot.data()!);
          _localImagePath = localImagePath;
          _medals = _currentUser?.medals ?? {};
          _totalMedals = _medals.values.fold(0, (sum, value) => sum + value);

          _completedTasks = tasks.where((t) => t.isDone).length;
          _pendingTasks = tasks.where((t) => !t.isDone && (t.dueDate == null || t.dueDate!.isAfter(now))).length;
          _expiredTasks = tasks.where((t) => !t.isDone && t.dueDate != null && t.dueDate!.isBefore(now)).length;

          _isLoading = false;
        });
      }
    }
  }

  void _logout() async {
    await _authService.logoutUser();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _editDisplayName() async {
    final TextEditingController controller =
        TextEditingController(text: _currentUser?.displayName ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color(0xFFBAD1C2),
          title: Text('Editar nom d\'usuari', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: Color(0xFF25766B)),
            decoration: InputDecoration(
              labelText: 'Nou nom',
              labelStyle: TextStyle(color: Color(0xFF4FA095)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FA095))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel·lar', style: TextStyle(color: Color(0xFF25766B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4FA095)),
              onPressed: () async {
                String newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .update({'displayName': newName});
                  Navigator.pop(context);
                  await _loadUserData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Nom actualitzat correctament'),
                      backgroundColor: Color(0xFF4FA095),
                    ),
                  );
                }
              },
              child: Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editField(String fieldKey, String currentValue, String label) async {
    final TextEditingController controller = TextEditingController(text: currentValue);

    if (fieldKey == 'birthDate') {
      DateTime? selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(currentValue) ?? DateTime(2000),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
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

      if (selectedDate != null) {
        final formattedDate = '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .update({fieldKey: formattedDate});
        await _loadUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label actualitzat correctament'),
              backgroundColor: Color(0xFF4FA095),
            ),
          );
        }
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color(0xFFBAD1C2),
          title: Text('Editar $label', style: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w600)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: Color(0xFF25766B)),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Color(0xFF4FA095)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FA095))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel·lar', style: TextStyle(color: Color(0xFF25766B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4FA095)),
              onPressed: () async {
                String newValue = controller.text.trim();
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({fieldKey: newValue});
                Navigator.pop(context);
                await _loadUserData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label actualitzat correctament'),
                    backgroundColor: Color(0xFF4FA095),
                  ),
                );
              },
              child: Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndSaveImageLocally() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage == null) return;

    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await LocalStorageService.deleteProfileImage(user.uid);
      final localPath = await LocalStorageService.saveProfileImage(
        pickedImage.path,
        user.uid
      );

      if (localPath != null) {
        await _loadUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Foto de perfil actualitzada'),
              backgroundColor: Color(0xFF4FA095),
            ),
          );
        }
      } else {
        throw Exception('No s\'ha pogut guardar la imatge');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la imatge: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Color getMedalColor(int count) {
    if (count >= 100) return Colors.amber;
    if (count >= 30) return Colors.grey.shade400;
    if (count >= 10) return Colors.brown.shade300;
    return Colors.grey.shade300;
  }

  IconData getMedalIcon(String category) {
    switch (category) {
      case 'Acadèmica': return Icons.school;
      case 'Deportiva': return Icons.sports;
      case 'Musical': return Icons.music_note;
      case 'Familiar': return Icons.family_restroom;
      case 'Laboral': return Icons.work;
      case 'Artística': return Icons.palette;
      case 'Mascota': return Icons.pets;
      case 'Predefined': return Icons.star;
      default: return Icons.emoji_events;
    }
  }

  Widget _buildMedalItem(String category, int count) {
    final Color medalColor = getMedalColor(count);
    final IconData medalIcon = getMedalIcon(category);

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: medalColor,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: medalColor.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            medalIcon,
            size: 30,
            color: medalColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          category,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: medalColor,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoSection() {
    if (_currentUser == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: BorderSide(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C9F88), Color(0xFF4FA095)],
          ),
          borderRadius: BorderRadius.circular(15.0),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickAndSaveImageLocally,
              child: Stack(
                children: [
                  Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color.fromARGB(146, 40, 144, 170),
                        backgroundImage: _localImagePath != null
                            ? FileImage(File(_localImagePath!))
                            : (_currentUser!.photoUrl.isNotEmpty
                                ? NetworkImage(_currentUser!.photoUrl)
                                : null),
                        child: (_localImagePath == null && _currentUser!.photoUrl.isEmpty)
                            ? Icon(Icons.person, size: 40, color: Colors.white)
                            : null,
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Color(0xFF25766B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _currentUser!.displayName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, size: 20, color: Colors.white),
                  onPressed: _editDisplayName,
                ),
              ],
            ),
            Text(
              _currentUser!.email,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 16),
            _buildUserDetail(Icons.location_on, _currentUser!.city, 'city', 'Ciutat'),
            _buildUserDetail(Icons.cake, _currentUser!.birthDate, 'birthDate', 'Data de naixement'),
            _buildUserDetail(Icons.work, _currentUser!.bio, 'bio', 'Ocupació'),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDetail(IconData icon, String value, String key, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white.withOpacity(0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? label : value,
              style: TextStyle(
                fontSize: 16,
                color: value.isEmpty ? Colors.white.withOpacity(0.6) : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, size: 16, color: Colors.white),
            onPressed: () => _editField(key, value, label),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatsSection() {
    return Card(
      color: Color.fromARGB(183, 118, 192, 182),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: BorderSide(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadístiques de tasques',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF25766B),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  Icons.check_circle,
                  const Color.fromARGB(255, 52, 145, 55),
                  _completedTasks.toString(),
                  'Completades',
                ),
                _buildStatItem(
                  Icons.schedule,
                  const Color.fromARGB(118, 26, 89, 226),
                  _pendingTasks.toString(),
                  'Pendents',
                ),
                _buildStatItem(
                  Icons.error,
                  const Color.fromARGB(200, 244, 67, 54),
                  _expiredTasks.toString(),
                  'Vençudes',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String count, String label) {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color.fromARGB(155, 190, 219, 210),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      const SizedBox(height: 8),
      Text(
        count,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      Text(
        label,
        style: TextStyle(fontSize: 12, color: Color(0xFF25766B), fontWeight: FontWeight.w500),
      ),
    ],
  );
}

  Widget _buildMedalsSection() {
    return Card(
      color: Color.fromARGB(61, 35, 224, 161),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: BorderSide(color: Color.fromARGB(255, 45, 112, 103), width: 2.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Les meves medalles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF25766B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    'Total: $_totalMedals',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: _medals.entries.map((entry) {
                return _buildMedalItem(entry.key, entry.value);
              }).toList(),
              
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFBAD1C2),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4FA095))),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFBAD1C2),
      appBar: AppBar(
        backgroundColor: Color(0xFF4FA095),
        title: Text('El meu perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        leading: BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildUserInfoSection(),
            _buildTaskStatsSection(),
            _buildMedalsSection(),
          ],
        ),
      ),
    );
  }
}