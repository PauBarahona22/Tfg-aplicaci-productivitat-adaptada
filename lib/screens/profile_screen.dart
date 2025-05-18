import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../database/auth_service.dart';
import '../database/challenge_service.dart';
import '../database/task_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ChallengeService _challengeService = ChallengeService();
  final TaskService _taskService = TaskService();
  UserModel? _currentUser;
  bool _isLoading = true;
  
  // Para manejar las medallas
  Map<String, int> _medals = {};
  int _totalMedals = 0;
  
  // Para estadísticas de tareas
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
      // Cargar datos del usuario
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
        
        // Cargar estadísticas de tareas
        final tasks = await _taskService.streamTasks(user.uid).first;
        final now = DateTime.now();
        
        setState(() {
          _currentUser = UserModel.fromMap(snapshot.data()!);
          _medals = _currentUser?.medals ?? {};
          _totalMedals = _medals.values.fold(0, (sum, value) => sum + value);
          
          // Calcular estadísticas de tareas
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
          title: const Text('Editar nom d\'usuari'),
          content: TextField(
            controller: controller,
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
                String newName = controller.text.trim();
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
    final TextEditingController controller = TextEditingController(text: currentValue);

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
            controller: controller,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () async {
                String newValue = controller.text.trim();
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

    setState(() => _isLoading = true);

    try {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al pujar la imatge: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Devuelve el color de la medalla según la cantidad
  Color getMedalColor(int count) {
    if (count >= 100) return Colors.amber; // Oro
    if (count >= 30) return Colors.grey.shade400; // Plata
    if (count >= 10) return Colors.brown.shade300; // Bronce
    return Colors.grey.shade300; // Gris claro
  }
  
  // Icono para cada tipo de medalla
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
  
  // Construye una medalla individual
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
            color: Colors.grey.shade700,
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
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile photo - now larger and centered at the top
          GestureDetector(
            onTap: _pickAndUploadImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60, // Increased from 40
                  backgroundImage: _currentUser!.photoUrl.isNotEmpty
                      ? NetworkImage(_currentUser!.photoUrl)
                      : null,
                  child: _currentUser!.photoUrl.isEmpty
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
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
          
          // User information
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _currentUser!.displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: _editDisplayName,
              ),
            ],
          ),
          
          Text(
            _currentUser!.email,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          // Location row
          _buildInfoRow(
            Icons.location_on,
            _currentUser!.city.isEmpty ? 'Afegir ciutat' : _currentUser!.city,
            () => _editField('city', _currentUser!.city, 'Ciutat'),
          ),
          
          // Birthdate row
          _buildInfoRow(
            Icons.calendar_today,
            _currentUser!.birthDate.isEmpty ? 'Afegir data de naixement' : _currentUser!.birthDate,
            () => _editField('birthDate', _currentUser!.birthDate, 'Data de naixement'),
          ),
          
          // Bio row
          _buildInfoRow(
            Icons.work,
            _currentUser!.bio.isEmpty ? 'Afegir biografia' : _currentUser!.bio,
            () => _editField('bio', _currentUser!.bio, 'Biografia'),
          ),
        ],
      ),
    ),
  );
}
// Helper method for building the info rows
Widget _buildInfoRow(IconData icon, String text, VoidCallback onTap) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: text.startsWith('Afegir') ? Colors.grey[400] : Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 18),
          onPressed: onTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );
}
  
  // Construye la sección de estadísticas de tareas
  Widget _buildTaskStatsSection() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadístiques de tasques',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Tareas completadas
                Expanded(
                  child: _buildStatItem(
                    'Completades',
                    _completedTasks.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                // Tareas pendientes
                Expanded(
                  child: _buildStatItem(
                    'Pendents',
                    _pendingTasks.toString(),
                    Icons.access_time,
                    Colors.orange,
                  ),
                ),
                // Tareas expiradas
                Expanded(
                  child: _buildStatItem(
                    'Expirades',
                    _expiredTasks.toString(),
                    Icons.event_busy,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget para cada estadística
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
  
  // Construye la sección de medallas
  Widget _buildMedalsSection() {
    if (_currentUser == null) return const SizedBox.shrink();
    
    // Filtrar 'Predefined' para mostrarla al final
    final regularMedals = _medals.entries.where((e) => e.key != 'Predefined').toList();
    final predefinedMedal = _medals.entries.firstWhere((e) => e.key == 'Predefined', orElse: () => MapEntry('Predefined', 0));
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
            
            // Mostrar medallas en filas de 4
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.75,
                crossAxisSpacing: 8,
                mainAxisSpacing: 16,
              ),
              itemCount: regularMedals.length,
              itemBuilder: (context, index) {
                final entry = regularMedals[index];
                return _buildMedalItem(entry.key, entry.value);
              },
            ),
            
            // Mostrar medalla predefinida al final si tiene valor
            if (predefinedMedal.value > 0) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMedalItem('Predefined', predefinedMedal.value),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('El meu perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
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