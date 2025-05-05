// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: uid == null
            ? const Text('Carregant...')
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Text('Carregant...');
                  final data = snap.data!.data()!;
                  final user = UserModel.fromMap(data);
                  return Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen()),
                          );
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: user.photoUrl.isNotEmpty
                              ? NetworkImage(user.photoUrl)
                              : null,
                          child: user.photoUrl.isEmpty
                              ? const Icon(Icons.person, size: 20)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(user.displayName, style: const TextStyle(fontSize: 18)),
                    ],
                  );
                },
              ),
      ),
      body: const Center(
        child: Text('Pantalla Home (Contingut futur)'),
      ),
    );
  }
}
