
import 'package:Obecno/api/api.dart'; 
import 'package:Obecno/api/cookie_service.dart';
import 'package:Obecno/core/services/network_checker.dart';
import 'package:Obecno/core/services/token_service.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/features/auth/repositories/auth_repository.dart';
import 'package:Obecno/features/auth/services/auth_service.dart';
import 'package:Obecno/monitors/app_guard.dart';
import 'package:Obecno/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/state/change_notifier_provider.dart';
import 'core/theme/dark_theme.dart';
import 'core/theme/light_theme.dart';
import 'core/theme/theme_provider.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cookieService = await CookieService.init();
  final tokenService = TokenService();
  final networkChecker = NetworkCheckerImpl();

  // ✅ Use HttpApiClient (NOT ApiClient)
  final httpClient = HttpApiClient(
    cookieService: cookieService,
    networkChecker: networkChecker,
  );

  final authService = AuthService(
    AuthRepository(httpClient),
    tokenService,
  );

  final authProvider = AuthProvider(authService);

  runApp(MyApp(authProvider: authProvider));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.authProvider});

  final AuthProvider authProvider;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>(
      notifier: widget.authProvider,
      child: ChangeNotifierProvider<ThemeProvider>(
        notifier: _themeProvider,
        child: AnimatedBuilder(
          animation: _themeProvider,
          builder: (context, _) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              debugShowMaterialGrid: false,
              theme: lightTheme,
              themeMode: _themeProvider.themeMode,
              routerConfig: router,
            );
          },
        ),
      ),
    );
  }
}