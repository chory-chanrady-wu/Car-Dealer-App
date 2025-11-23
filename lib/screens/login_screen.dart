import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final String baseUrl = "http://localhost:3000";

  final _nameController = TextEditingController(); // NEW
  final _emailController = TextEditingController(text: '');
  final _passwordController = TextEditingController(text: '');

  bool _isLoading = false;
  bool _isLoginMode = true;

  Future<void> _authenticate() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessage('Please enter credentials', Colors.red);
      return;
    }

    // Validate Name if in Signup mode
    if (!_isLoginMode && _nameController.text.isEmpty) {
      _showMessage('Please enter your name', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    final endpoint = _isLoginMode ? "/login" : "/signup";

    try {
      final response = await http.post(
        Uri.parse(baseUrl + endpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": _nameController.text, // Send Name
          "email": _emailController.text,
          "password": _passwordController.text,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (_isLoginMode) {
          // LOGIN SUCCESS
          // Pass the ENTIRE user object (includes name, id, role)
          final Map user = data['user'];
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/dashboard',
            arguments: user,
          );
        } else {
          _showMessage("Account created! Please Login.", Colors.green);
          setState(() => _isLoginMode = true);
        }
      } else {
        _showMessage(data['error'] ?? 'Authentication Failed', Colors.red);
      }
    } catch (e) {
      _showMessage('Connection Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isLoginMode ? Icons.directions_car : Icons.person_add,
                size: 80,
                color: Colors.indigo,
              ),
              const SizedBox(height: 20),
              Text(
                _isLoginMode ? "Dealer Login" : "Create Account",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // Name Field (Only for Signup)
              if (!_isLoginMode) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLoginMode ? "Login" : "Sign Up",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                    _emailController.clear();
                    _passwordController.clear();
                    _nameController.clear();
                  });
                },
                child: Text(
                  _isLoginMode
                      ? "New here? Create an account"
                      : "Already have an account? Login",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
