import 'package:flutter/material.dart';
import '../database/auth_service.dart';
import '../screens/register_screen.dart';
import '../screens/forgot_password_screen.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;

  void _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

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

    setState(() {
      _isLoading = true;
    });

    String? errorMessage = await _authService.loginUser(
      email: email,
      password: password,
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
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
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
          'Iniciar Sessió',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            const SizedBox(height: 24),
            _isLoading
                ? CircularProgressIndicator(color: Color(0xFF4FA095))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF25766B),
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    onPressed: _login,
                    child: Text(
                      'Iniciar Sessió',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                );
              },
              child: Text(
                'Has oblidat la contrasenya?',
                style: TextStyle(color: Color(0xFF3A8B80), fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              child: Text(
                'No tens compte? Registra\'t',
                style: TextStyle(color: Color(0xFF3A8B80), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}