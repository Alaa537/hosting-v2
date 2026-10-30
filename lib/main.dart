import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'widgets/telegram_fab.dart';
import 'services/connectivity_service.dart';
import 'widgets/offline_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConnectivityService.I.init();
  runApp(const HostingApp());
}

class HostingApp extends StatelessWidget {
  const HostingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: MaterialApp(
        title: 'HOST PANEL',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const SplashScreen(),
        builder: (context, child) {
          // Global offline overlay + floating Telegram
          return ValueListenableBuilder<bool>(
            valueListenable: ConnectivityService.I.isOnline,
            builder: (ctx, online, _) {
              return Stack(
                children: [
                  // The actual app (blocked when offline)
                  if (child != null)
                    IgnorePointer(
                      ignoring: !online,
                      child: child,
                    ),

                  // Floating Telegram button (only when online)
                  if (online && child != null)
                    Positioned(
                      left: 16,
                      bottom: 100,
                      child: const TelegramFab(),
                    ),

                  // Offline overlay (when disconnected)
                  if (!online) const OfflineScreen(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
