import 'package:obecno/features/auth/presentation/screens/enable_permission.dart';
import 'package:obecno/features/auth/presentation/screens/login_email.dart';
import 'package:obecno/features/auth/presentation/screens/login_pass.dart';
import 'package:obecno/features/employee_module/more/presentation/screens/device_blocked_screen.dart';

import 'package:obecno/demo/monotonic_clock/presentation/monotonic_clock_demo_screen.dart';
import 'package:obecno/features/launch/book_demo/presentation/book_demo.dart';
import 'package:obecno/features/launch/onboarding/onboarding.dart';
import 'package:obecno/features/launch/splash/splash.dart';
import 'package:obecno/features/manager_module/Manager_employees/presentation/screens/all_employees_screen.dart';
import 'package:obecno/features/manager_module/Manager_locations/presentation/screens/all_locations_screen.dart';
import 'package:obecno/main.dart';
import 'package:obecno/widgets/bottom_nav_bars/employee_nav.dart';
import 'package:obecno/widgets/bottom_nav_bars/manager_nav.dart';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: rootNavigatorKey,
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
      path: '/login/password',
      builder: (context, state) {
        final email = state.extra as String? ?? '';
        return LoginPasswordScreen(email: email);
      },
    ),
    GoRoute(
      path: '/enable_permissions',
      builder: (context, state) => const EnablePermissionsScreen(),
    ),
    GoRoute(
      path: '/device_blocked',
      builder: (context, state) => const DeviceBlockedScreen(),
    ),
    GoRoute(
      path: '/employee_nav',
      builder: (context, state) => const EmployeeBottomNavBar(),
    ),
    GoRoute(
      path: '/manager_nav',
      builder: (context, state) => const ManagerBottomNavBar(),
    ),
    GoRoute(
      path: '/manager/employees',
      builder: (context, state) => const AllEmployeesScreen(),
    ),
    GoRoute(
      path: '/manager/locations',
      builder: (context, state) => const AllLocationsScreen(),
    ),

    GoRoute(
      path: '/bookdemo',
      builder: (context, state) => const BookDemoScreen(),
    ),
    GoRoute(
      path: MonotonicClockDemoScreen.routePath,
      builder: (context, state) => const MonotonicClockDemoScreen(),
    ),
  ],
);
