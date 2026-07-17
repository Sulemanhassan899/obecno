
import 'package:Obecno/core/binding/app_binding.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/core/theme/theme_provider.dart';
import 'package:Obecno/core/theme/light_theme.dart';
import 'package:Obecno/core/theme/dark_theme.dart';
import 'package:Obecno/routes/app_routes.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/features/employee_module/more/providers/profile_provider.dart';
import 'package:Obecno/features/launch/book_demo/providers/book_demo_provider.dart';
import 'package:Obecno/monitors/app_guard.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

late final AppBindings bindings;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bindings = AppBindings();
  await bindings.init();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>(
      notifier: bindings.authProvider,
      child: ChangeNotifierProvider<ProfileProvider>(
        notifier: bindings.profileProvider,
        child: ChangeNotifierProvider<BookDemoProvider>(
          notifier: bindings.bookDemoProvider,
          child: ChangeNotifierProvider<ThemeProvider>(
            notifier: _themeProvider,
            child: AnimatedBuilder(
              animation: _themeProvider,
              builder: (context, _) {
                return MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: lightTheme,
                  darkTheme: darkTheme,
                  themeMode: _themeProvider.themeMode,
                  routerConfig: router,
                  builder: (context, child) {
                    return AppGuard(child: child ?? const SizedBox.shrink());
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
