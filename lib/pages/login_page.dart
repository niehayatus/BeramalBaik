import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  String username = '';
  String password = '';
  String errorMessage = '';
  bool _showNotRegisteredMessage = false;
  bool _obscurePassword = true;

  String _mapErrorCodeToMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Username belum terdaftar, silakan daftar terlebih dahulu.';
      case 'wrong-password':
        return 'Password salah. Silakan coba lagi.';
      case 'invalid-email':
        return 'Format username salah.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      default:
        return 'Terjadi kesalahan: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        title: const Text('LOGIN'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/dashboard_public');
          },
        ),
      ),
      body: Stack(
        children: [
          // Banyak lingkaran besar dan semi transparan
          ..._buildCircleDecorations(),

          // Form Login
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.lock_outline, size: 80, color: Colors.green),
                  const SizedBox(height: 12),
                  const Text(
                    'Selamat Datang',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              setState(() {
                                username = val.trim();
                                _showNotRegisteredMessage = false;
                                errorMessage = '';
                              });
                            },
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Masukkan username' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
                            onChanged: (val) {
                              setState(() {
                                password = val.trim();
                                errorMessage = '';
                              });
                            },
                            validator: (val) => val == null || val.length < 6
                                ? 'Password minimal 6 karakter'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.login),
                            label: const Text('Login'),
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                String? result =
                                    await _authService.login(username, password);
                                if (result == null) {
                                  Navigator.pushReplacementNamed(context, '/home');
                                } else {
                                  setState(() {
                                    errorMessage = _mapErrorCodeToMessage(result);
                                    _showNotRegisteredMessage =
                                        result == 'user-not-found';
                                  });
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            text: TextSpan(
                              text: 'Belum punya akun? ',
                              style: const TextStyle(color: Colors.black),
                              children: [
                                TextSpan(
                                  text: 'Register',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.pushNamed(context, '/register');
                                    },
                                ),
                              ],
                            ),
                          ),
                          if (errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                errorMessage,
                                style: TextStyle(
                                  color: _showNotRegisteredMessage
                                      ? Colors.red[700]
                                      : Colors.red,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCircleDecorations() {
    final size = MediaQuery.of(context).size;
    final List<Offset> positions = List.generate(
      40,
      (index) => Offset(
        (index * 50 + 30) % size.width,
        (index * 80 + 70) % size.height,
      ),
    );
    return positions
        .map((pos) => Positioned(
              top: pos.dy,
              left: pos.dx,
              child: _circle(24, Colors.green.shade100.withOpacity(0.3)),
            ))
        .toList();
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
