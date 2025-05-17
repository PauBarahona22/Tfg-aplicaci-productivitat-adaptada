import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../database/auth_service.dart';
import '../database/challenge_service.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';
import '../models/challenge_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ChallengeService _challengeService = ChallengeService();
  UserModel? _currentUser;
  bool _isLoading = true;
  
  // Para manejar las medallas
  Map<String, int> _medals = {};
  int _totalMedals = 0;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = _authService.currentUser;

    if (user != null) {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (snapshot.exists) {
        final userData = snapshot.data()!;
        
        // Si el usuario no tiene medallas en su perfil, inicializarlas
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
          
          // Recargar para obtener los datos actualizados
          snapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
        }
        
        setState(() {
          _currentUser = UserModel.fromMap(snapshot.data()!);
          _medals = _currentUser?.medals ?? {};
          _totalMedals = _medals.values.fold(0, (sum, value) => sum + value);
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
    final TextEditingController _controller =
        TextEditingController(text: _currentUser?.displayName ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar nom d\'usuari'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Nou nom',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () async {
                String newName = _controller.text.trim();
                if (newName.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .update({'displayName': newName});
                  Navigator.pop(context);
                  await _loadUserData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nom actualitzat correctament')),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editField(String fieldKey, String currentValue, String label) async {
    final TextEditingController _controller = TextEditingController(text: currentValue);

    if (fieldKey == 'birthDate') {
      DateTime? selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(currentValue) ?? DateTime(2000),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
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
            SnackBar(content: Text('$label actualitzat correctament')),
          );
        }
      }

      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Editar $label'),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () async {
                String newValue = _controller.text.trim();
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({fieldKey: newValue});
                Navigator.pop(context);
                await _loadUserData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label actualitzat correctament')),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage == null) return;

    final File imageFile = File(pickedImage.path);
    final user = _authService.currentUser;
    final storageRef = FirebaseStorage.instance.ref().child('profile_pics/${user!.uid}.jpg');

    final uploadTask = await storageRef.putFile(imageFile);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'photoUrl': downloadUrl});

    await _loadUserData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualitzada')),
      );
    }
  }

  Widget _buildEditableCard(String title, String value, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text(value.isNotEmpty ? value : 'No especificat'),
        trailing: const Icon(Icons.edit),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text(value.isNotEmpty ? value : 'No especificat'),
      ),
    );
  }
  
  // NUEVO: Sección para mostrar las medallas
  Widget _buildMedalsSection() {
    if (_currentUser == null) return const SizedBox.shrink();
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Les meves medalles',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Total: $_totalMedals',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Fila de categorías con sus contadores
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: _medals.entries.map((entry) {
                // No mostrar categorías sin medallas
                if (entry.value <= 0) return const SizedBox.shrink();
                
                return _buildMedalItem(entry.key, entry.value);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedalItem(String category, int count) {
    IconData iconData;
    Color color;
    
    // Asignar icono según categoría
    switch (category) {
      case 'Acadèmica':
        iconData = Icons.school;
        color = Colors.blue;
        break;
      case 'Deportiva':
        iconData = Icons.sports;
        color = Colors.green;
        break;
      case 'Musical':
        iconData = Icons.music_note;
        color = Colors.purple;
        break;
      case 'Familiar':
        iconData = Icons.family_restroom;
        color = Colors.orange;
        break;
      case 'Laboral':
        iconData = Icons.work;
        color = Colors.brown;
        break;
      case 'Artística':
        iconData = Icons.palette;
        color = Colors.pink;
        break;
      case 'Mascota':
        iconData = Icons.pets;
        color = Colors.teal;
        break;
      case 'Predefined':
        iconData = Icons.auto_awesome;
        color = Colors.amber;
        break;
      default:
        iconData = Icons.emoji_events;
        color = Colors.amber;
    }
    
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(iconData, color: color, size: 36),
        ),
        const SizedBox(height: 8),
        Text(
          category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          '$count',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
  
  // NUEVO: Sección de estadísticas de retos
  Widget _buildChallengeStatsSection() {
    return StreamBuilder<List<ChallengeModel>>(
      stream: _challengeService.streamChallenges(_currentUser?.uid ?? ''),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final challenges = snapshot.data!;
        final completedCount = challenges.where((c) => c.isCompleted).length;
        final pendingCount = challenges.where((c) => !c.isCompleted && !c.isExpired).length;
        final expiredCount = challenges.where((c) => c.isExpired).length;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resum de reptes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Completats', completedCount.toString(), Colors.green),
                    _buildStatItem('Pendents', pendingCount.toString(), Colors.blue),
                    _buildStatItem('Expirats', expiredCount.toString(), Colors.red),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Sección de foto de perfil
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: _currentUser!.photoUrl.isNotEmpty
                              ? NetworkImage(_currentUser!.photoUrl)
                              : null,
                          child: _currentUser!.photoUrl.isEmpty
                              ? const Icon(Icons.person, size: 60)
                              : null,
                        ),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.blue,
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Información básica
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: const Text('Nom'),
                      subtitle: Text(_currentUser?.displayName.isNotEmpty == true
                          ? _currentUser!.displayName
                          : 'No especificat'),
                      trailing: const Icon(Icons.edit),
                      onTap: _editDisplayName,
                    ),
                  ),
                  
                  _buildInfoCard('Correu electrònic', _currentUser?.email ?? ''),
                  
                  _buildEditableCard('Ciutat', _currentUser?.city ?? '',
                      () => _editField('city', _currentUser?.city ?? '', 'Ciutat')),
                  
                  _buildEditableCard('Data de naixement', _currentUser?.birthDate ?? '',
                      () => _editField('birthDate', _currentUser?.birthDate ?? '', 'Data de naixement')),
                  
                  _buildEditableCard('Informació personal', _currentUser?.bio ?? '',
                      () => _editField('bio', _currentUser?.bio ?? '', 'Informació personal')),
                  
                  // NUEVO: Sección de estadísticas de retos
                  _buildChallengeStatsSection(),
                  
                  // NUEVO: Sección de medallas
                  _buildMedalsSection(),
                ],
              ),
            ),
    );
  }
}