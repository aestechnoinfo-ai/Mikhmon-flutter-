import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Écran d'attente qui aiguille vers Login ou Shell selon l'état d'auth.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer<AppState>(
      builder: (context, app, _) {
        switch (app.status) {
          case AppStatus.init:
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_tethering, size: 72, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text('Mikhmon Flutter',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 20),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ],
                ),
              ),
            );
          case AppStatus.unauthenticated:
            return const LoginScreen();
          default:
            return const MainShell();
        }
      },
    );
  }
}