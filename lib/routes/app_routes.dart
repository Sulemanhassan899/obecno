import 'package:Obecno/main.dart';
import 'package:Obecno/screens/book_demo/book_demo.dart';
import 'package:Obecno/screens/onboarding/onboarding.dart';
import 'package:Obecno/screens/splash/splash.dart';
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
      path: '/bookdemo',
      builder: (context, state) => const BookDemoScreen(),
    ),
  ],
);
