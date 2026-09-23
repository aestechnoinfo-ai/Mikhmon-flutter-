import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/storage/app_storage.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/log_service.dart';
import 'state/app_state.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = AppStorage.instance;
  await storage.init();

  runApp(MikhmonApp(storage: storage));
}

class MikhmonApp extends StatelessWidget {
  final AppStorage storage;
  const MikhmonApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(storage, AuthService(storage), LogService(storage))
        ..initialize(),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (ctx) => VouchersProvider(ctx.read<AppState>().storage),
          ),
          ChangeNotifierProvider(
            create: (ctx) =>
                VoucherHistory(List.of(ctx.read<AppState>().storage.vouchers)),
          ),
        ],
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: themeController,
          builder: (context, mode, _) {
            return MaterialApp(
              title: 'Mikhmon Flutter',
              debugShowCheckedModeBanner: false,
              theme: buildLightTheme(),
              darkTheme: buildDarkTheme(),
              themeMode: mode,
              home: const SplashScreen(),
            );
          },
        ),
      ),
    );
  }
}