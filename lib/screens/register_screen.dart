import 'package:flutter/material.dart';
import '../database/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;

  void _register() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    String displayName = _displayNameController.text.trim();

    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El nom d\'usuari no pot estar buit'),
          backgroundColor: Color(0xFF25766B),
        ),
      );
      return;
    }

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Introdueix un correu electrònic vàlid'),
          backgroundColor: Color(0xFF25766B),
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La contrasenya ha de tenir almenys 6 caràcters'),
          backgroundColor: Color(0xFF25766B),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Les contrasenyes no coincideixen'),
          backgroundColor: Color(0xFF25766B),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? errorMessage = await _authService.registerUser(
      email: email,
      password: password,
      displayName: displayName,
    );

    setState(() {
      _isLoading = false;
    });

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Color(0xFF25766B),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compte creat amb èxit!'),
          backgroundColor: Color(0xFF25766B),
        ),
      );

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFBAD1C2),
      appBar: AppBar(
        backgroundColor: Color(0xFF4FA095),
        title: Text(
          'Registrar-se',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: 'Nom d\'usuari',
                labelStyle: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w500),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF25766B)),
                ),
              ),
              style: TextStyle(color: Color(0xFF25766B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Correu electrònic',
                labelStyle: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w500),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF25766B)),
                ),
              ),
              style: TextStyle(color: Color(0xFF25766B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Contrasenya',
                labelStyle: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w500),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF25766B)),
                ),
              ),
              style: TextStyle(color: Color(0xFF25766B)),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirmar Contrasenya',
                labelStyle: TextStyle(color: Color(0xFF25766B), fontWeight: FontWeight.w500),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF25766B)),
                ),
              ),
              style: TextStyle(color: Color(0xFF25766B)),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? CircularProgressIndicator(color: Color(0xFF4FA095))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF25766B),
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    onPressed: _register,
                    child: Text(
                      'Registrar-se',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: Text(
                'Ja tens compte? Inicia sessió',
                style: TextStyle(color: Color(0xFF3A8B80), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}