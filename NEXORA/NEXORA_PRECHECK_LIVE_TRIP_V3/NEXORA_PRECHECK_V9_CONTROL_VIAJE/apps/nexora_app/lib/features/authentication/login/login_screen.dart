import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../data/auth_api.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.authRepository,
    required this.onLoginSuccess,
    required this.onCreateAccount,
    super.key,
  });

  final AuthRepository authRepository;
  final VoidCallback onLoginSuccess;
  final VoidCallback onCreateAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();

  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();

    final password = _passwordController.text;

    if (phone.length < 8 || password.length < 8) {
      _showMessage('Completa teléfono y contraseña.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await widget.authRepository.login(phone: phone, password: password);

      if (!mounted) {
        return;
      }

      widget.onLoginSuccess();
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Error de conexión MIGO: $error. '
        'Verifica que el servidor esté encendido.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraColors.lightGray,
      appBar: AppBar(backgroundColor: NexoraColors.lightGray),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MigoBrandMark(compact: true),
              const SizedBox(height: 32),
              const Text(
                'Bienvenido de nuevo',
                style: TextStyle(
                  color: NexoraColors.softSand,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa a tu cuenta MIGO DRIVE.',
                style: TextStyle(color: NexoraColors.mutedText, fontSize: 15),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _phoneController,
                enabled: !_loading,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Número de teléfono',
                  hintText: '+51 999 999 999',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                enabled: !_loading,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          _showMessage(
                            'Recuperación de contraseña '
                            'se implementará junto con OTP.',
                          );
                        },
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('real-login-button'),
                  onPressed: _loading ? null : _login,
                  style: FilledButton.styleFrom(
                    backgroundColor: NexoraColors.royalBlue,
                    foregroundColor: NexoraColors.white,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: NexoraColors.white,
                          ),
                        )
                      : const Text(
                          'Entrar a MIGO',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¿Todavía no tienes cuenta?',
                    style: TextStyle(color: NexoraColors.mutedText),
                  ),
                  TextButton(
                    onPressed: _loading ? null : widget.onCreateAccount,
                    child: const Text('Crear cuenta'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
