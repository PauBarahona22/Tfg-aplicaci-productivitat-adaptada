import 'package:flutter/material.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Pantalla: Llistat de Tasques',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
