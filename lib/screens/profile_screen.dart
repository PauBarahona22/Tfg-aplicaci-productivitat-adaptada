import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../database/auth_service.dart';
import 'login_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;

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
        setState(() {
          _currentUser = UserModel.fromMap(snapshot.data()!);
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
      child: ListTile(
        title: Text(title),
        subtitle: Text(value.isNotEmpty ? value : 'No especificat'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
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
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _currentUser!.photoUrl.isNotEmpty
                          ? NetworkImage(_currentUser!.photoUrl)
                          : null,
                      child: _currentUser!.photoUrl.isEmpty
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
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
                ],
              ),
            ),
    );
  }
}
