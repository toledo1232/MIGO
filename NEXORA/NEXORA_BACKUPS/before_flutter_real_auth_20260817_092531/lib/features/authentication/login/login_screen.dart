import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.onLoginSuccess,
    required this.onCreateAccount,
    super.key,
  });

  final VoidCallback onLoginSuccess;
  final VoidCallback onCreateAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
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

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.onLoginSuccess,
                  style: FilledButton.styleFrom(
                    backgroundColor: NexoraColors.royalBlue,
                    foregroundColor: NexoraColors.white,
                  ),
                  child: const Text('Entrar a MIGO'),
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
                    onPressed: widget.onCreateAccount,
                    child: const Text('Crear cuenta'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NexoraColors.breezeBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: NexoraColors.royalBlue,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Esta pantalla todavía es de prueba. '
                        'La autenticación real se conectará '
                        'al servidor en el módulo de seguridad.',
                        style: TextStyle(
                          color: NexoraColors.softSand,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
