import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/demo/monotonic_clock/presentation/monotonic_clock_demo_screen.dart';
import 'package:obecno/demo/monotonic_clock/services/demo_employee_clock_bridge.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';

class MonotonicClockDemoEntry extends StatefulWidget {
  const MonotonicClockDemoEntry({super.key, required this.child});

  final Widget child;

  @override
  State<MonotonicClockDemoEntry> createState() =>
      _MonotonicClockDemoEntryState();
}

class _MonotonicClockDemoEntryState extends State<MonotonicClockDemoEntry> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureLogin());
  }

  void _captureLogin() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    if (auth.isAuthenticated && userId != null && userId.isNotEmpty) {
      unawaited(DemoEmployeeClockBridge.ensureLogin(userId: userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 12,
          bottom: 16,
          child: SafeArea(
            child: FloatingActionButton.extended(
              heroTag: 'monotonic_clock_demo_fab',
              backgroundColor: kBlack200,
              foregroundColor: kWhite,
              icon: const Icon(Icons.schedule, size: 18),
              label: const Text('TIME DEMO'),
              onPressed: () {
                context.push(MonotonicClockDemoScreen.routePath);
              },
            ),
          ),
        ),
      ],
    );
  }
}
