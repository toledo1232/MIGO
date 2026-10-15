import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import 'app/app_session.dart';
import 'features/authentication/data/auth_repository.dart';
import 'features/authentication/login/login_screen.dart';
import 'features/authentication/register/register_screen.dart';
import 'features/shell/nexora_shell.dart';
import 'features/welcome/welcome_screen.dart';

class NexoraApp extends StatefulWidget {
  const NexoraApp({super.key});

  @override
  State<NexoraApp> createState() => _NexoraAppState();
}

class _NexoraAppState extends State<NexoraApp> {
  late final AppSession _session;
  late final AuthRepository _authRepository;

  bool _restoringSession = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();

    _session = AppSession();
    _authRepository = AuthRepository();

    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final user = await _authRepository.restoreSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _authenticated = user != null;

        _restoringSession = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authenticated = false;
        _restoringSession = false;
      });
    }
  }

  @override
  void dispose() {
    _session.dispose();
    _authRepository.dispose();
    super.dispose();
  }

  void _markAuthenticated() {
    setState(() {
      _authenticated = true;
    });
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return LoginScreen(
            authRepository: _authRepository,
            onLoginSuccess: () {
              Navigator.of(context).popUntil((route) => route.isFirst);

              _markAuthenticated();
            },
            onCreateAccount: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) {
                    return RegisterScreen(
                      authRepository: _authRepository,
                      onRegisterSuccess: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);

                        _markAuthenticated();
                      },
                      onLogin: () {
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return RegisterScreen(
            authRepository: _authRepository,
            onRegisterSuccess: () {
              Navigator.of(context).popUntil((route) => route.isFirst);

              _markAuthenticated();
            },
            onLogin: () {
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }

  void _googlePrototype(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Google se conectará después '
          'mediante autenticación segura.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: MigoBrand.name,
      debugShowCheckedModeBanner: false,
      theme: NexoraTheme.light,
      home: _restoringSession
          ? const _SessionLoadingScreen()
          : _authenticated
          ? NexoraShell(session: _session)
          : Builder(
              builder: (context) {
                return WelcomeScreen(
                  onLogin: () {
                    _openLogin(context);
                  },
                  onRegister: () {
                    _openRegister(context);
                  },
                  onGoogle: () {
                    _googlePrototype(context);
                  },
                );
              },
            ),
    );
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: NexoraColors.warmCream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MigoBrandMark(),
            SizedBox(height: 26),
            CircularProgressIndicator(color: NexoraColors.royalBlue),
          ],
        ),
      ),
    );
  }
}
