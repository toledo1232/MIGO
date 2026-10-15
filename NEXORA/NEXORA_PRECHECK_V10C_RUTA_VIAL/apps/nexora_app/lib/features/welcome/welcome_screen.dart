import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onLogin,
    required this.onRegister,
    required this.onGoogle,
    super.key,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onGoogle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraColors.warmCream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(child: MigoBrandMark()),

                      const SizedBox(height: 30),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: AspectRatio(
                          aspectRatio: 2.15,
                          child: Image.asset(
                            'assets/branding/migo_brand_banner.png',
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: NexoraColors.royalBlue,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.route_rounded,
                                  color: NexoraColors.white,
                                  size: 64,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 34),

                      const Text(
                        'Tu viaje,\nmás simple.',
                        style: TextStyle(
                          color: NexoraColors.softSand,
                          fontSize: 38,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Muévete con confianza. Elige cómo viajar '
                        'y mantén el control desde una sola aplicación.',
                        style: TextStyle(
                          color: NexoraColors.mutedText,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),

                      const Spacer(),

                      const SizedBox(height: 34),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onLogin,
                          style: FilledButton.styleFrom(
                            backgroundColor: NexoraColors.royalBlue,
                            foregroundColor: NexoraColors.white,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: onRegister,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NexoraColors.softSand,
                            minimumSize: const Size.fromHeight(56),
                            side: const BorderSide(
                              color: NexoraColors.breezeBlue,
                              width: 1.5,
                            ),
                            backgroundColor: NexoraColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Crear cuenta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onGoogle,
                          icon: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: NexoraColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              'G',
                              style: TextStyle(
                                color: NexoraColors.royalBlue,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          label: const Text(
                            'Continuar con Google',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NexoraColors.softSand,
                            backgroundColor: NexoraColors.white,
                            minimumSize: const Size.fromHeight(56),
                            side: const BorderSide(
                              color: NexoraColors.breezeBlue,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Center(
                        child: Text(
                          'Al continuar aceptas los Términos de uso '
                          'y la Política de privacidad.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: NexoraColors.mutedText,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
