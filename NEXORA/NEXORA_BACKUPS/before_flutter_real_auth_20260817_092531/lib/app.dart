import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import 'app/app_session.dart';
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

  @override
  void initState() {
    super.initState();
    _session = AppSession();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return LoginScreen(
            onLoginSuccess: () {
              _openMainApp(context);
            },
            onCreateAccount: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) {
                    return RegisterScreen(
                      onRegisterSuccess: () {
                        _openMainApp(context);
                      },
                      onLogin: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) {
                              return LoginScreen(
                                onLoginSuccess: () {
                                  _openMainApp(context);
                                },
                                onCreateAccount: () {},
                              );
                            },
                          ),
                        );
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
            onRegisterSuccess: () {
              _openMainApp(context);
            },
            onLogin: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) {
                    return LoginScreen(
                      onLoginSuccess: () {
                        _openMainApp(context);
                      },
                      onCreateAccount: () {},
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

  void _openMainApp(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => NexoraShell(session: _session)),
      (route) => false,
    );
  }

  void _googlePrototype(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Google se conectará de forma segura '
          'en el módulo de autenticación.',
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
      home: Builder(
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
