import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../data/auth_api.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.authRepository,
    required this.onRegisterSuccess,
    required this.onLogin,
    super.key,
  });

  final AuthRepository authRepository;
  final VoidCallback onRegisterSuccess;
  final VoidCallback onLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();

  final _phoneController = TextEditingController();

  final _emailController = TextEditingController();

  final _passwordController = TextEditingController();

  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();

    final phone = _phoneController.text.trim();

    final email = _emailController.text.trim();

    final password = _passwordController.text;

    final confirmPassword = _confirmPasswordController.text;

    if (name.length < 3) {
      _showMessage('Ingresa tus nombres y apellidos.');
      return;
    }

    if (phone.length < 8) {
      _showMessage('Ingresa un número válido.');
      return;
    }

    if (!email.contains('@')) {
      _showMessage('Ingresa un correo válido.');
      return;
    }

    if (password.length < 8) {
      _showMessage(
        'La contraseña debe tener '
        'al menos 8 caracteres.',
      );
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await widget.authRepository.register(
        fullName: name,
        phone: phone,
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      widget.onRegisterSuccess();
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
              const SizedBox(height: 28),
              const Text(
                'Crea tu cuenta',
                style: TextStyle(
                  color: NexoraColors.softSand,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu cuenta MIGO será única. '
                'Podrás viajar como pasajero y '
                'solicitar convertirte en conductor.',
                style: TextStyle(
                  color: NexoraColors.mutedText,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              TextField(
                controller: _nameController,
                enabled: !_loading,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombres y apellidos',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
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
              TextField(
                controller: _confirmPasswordController,
                enabled: !_loading,
                obscureText: _obscurePassword,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('real-register-button'),
                  onPressed: _loading ? null : _register,
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
                          'Crear cuenta y continuar',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 17),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¿Ya tienes cuenta?',
                    style: TextStyle(color: NexoraColors.mutedText),
                  ),
                  TextButton(
                    onPressed: _loading ? null : widget.onLogin,
                    child: const Text('Iniciar sesión'),
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
