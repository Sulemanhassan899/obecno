import 'package:obecno/features/auth/presentation/enable_permission.dart';
import 'package:obecno/features/auth/presentation/login_email.dart';
import 'package:obecno/features/auth/presentation/login_pass.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/more/presentation/screens/device_blocked_screen.dart';

import 'package:obecno/demo/monotonic_clock/presentation/monotonic_clock_demo_screen.dart';

import 'package:obecno/features/join/presentation/screens/youve_joined_screen.dart';
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

const _publicPaths = <String>{
  '/',
  '/onboarding',
  '/login',
  '/login/password',
  '/bookdemo',
};

bool _isPublicPath(String location) {
  if (_publicPaths.contains(location)) return true;
  if (location == MonotonicClockDemoScreen.routePath) return true;
  return false;
}

bool _isManagerPath(String location) {
  return location == '/manager_nav' || location.startsWith('/manager/');
}

bool _isProtectedPath(String location) {
  return location == '/employee_nav' ||
      _isManagerPath(location) ||
      location == '/enable_permissions' ||
      location == '/device_blocked' ||
      location == '/youve_joined';
}

/// Sync redirect using [bindings.authProvider] once DI is ready.
String? _authRedirect(BuildContext context, GoRouterState state) {
  final location = state.matchedLocation;
  if (_isPublicPath(location)) return null;
  if (!_isProtectedPath(location)) return null;

  AuthProvider auth;
  try {
    auth = bindings.authProvider;
  } catch (_) {
    // AppBindings not initialized yet (very early boot) — allow splash flow.
    return null;
  }

  if (!auth.isAuthenticated) {
    return '/login';
  }

  // Employees must not open manager shell or manager list routes.
  if (_isManagerPath(location) &&
      auth.homeTarget != AuthHomeTarget.manager) {
    return '/employee_nav';
  }

  return null;
}

final GoRouter router = GoRouter(
  navigatorKey: rootNavigatorKey,
  observers: [routeObserver],
  redirect: _authRedirect,
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
      path: '/youve_joined',
      builder: (context, state) {
        final company = state.extra as String? ?? 'Acme Corporation';
        return YouveJoinedScreen(companyName: company);
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
