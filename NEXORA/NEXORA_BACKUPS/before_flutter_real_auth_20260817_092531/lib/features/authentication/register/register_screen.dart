import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.onRegisterSuccess,
    required this.onLogin,
    super.key,
  });

  final VoidCallback onRegisterSuccess;
  final VoidCallback onLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
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

              const SizedBox(height: 30),

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
                'Empieza como pasajero. Si luego quieres conducir, '
                'podrás completar tu perfil de conductor.',
                style: TextStyle(
                  color: NexoraColors.mutedText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 28),

              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombres y apellidos',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),

              const SizedBox(height: 14),

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
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.onRegisterSuccess,
                  style: FilledButton.styleFrom(
                    backgroundColor: NexoraColors.royalBlue,
                    foregroundColor: NexoraColors.white,
                  ),
                  child: const Text('Crear cuenta y continuar'),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¿Ya tienes cuenta?',
                    style: TextStyle(color: NexoraColors.mutedText),
                  ),
                  TextButton(
                    onPressed: widget.onLogin,
                    child: const Text('Iniciar sesión'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NexoraColors.breezeBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'En el módulo de registro real añadiremos OTP, '
                  'documento de identidad, consentimiento, '
                  'contacto de confianza y verificación.',
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
      ),
    );
  }
}
