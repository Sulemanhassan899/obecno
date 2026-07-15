import 'package:Obecno/features/auth/presentation/screens/enable_permission.dart';
import 'package:Obecno/features/auth/presentation/screens/login_email.dart';
import 'package:Obecno/features/auth/wrapper/auth_wrapper.dart';
import 'package:Obecno/features/launch/book_demo/book_demo.dart';
import 'package:Obecno/features/launch/onboarding/onboarding.dart';
import 'package:Obecno/features/launch/splash/splash.dart';
import 'package:Obecno/main.dart';
import 'package:Obecno/shared/bottom_nav_bars/employee_nav.dart';

import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  observers: [routeObserver],
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnBoardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginEmailScreen(),
    ),
    GoRoute(
      path: '/enable_permissions',
      builder: (context, state) => const EnablePermissionsScreen(),
    ),
    GoRoute(
      path: '/employee_nav',
      builder: (context, state) => const EmployeeBottomNavBar(),
    ),

    GoRoute(
      path: '/bookdemo',
      builder: (context, state) => const BookDemoScreen(),
    ),
  ],
);
