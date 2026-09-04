import 'dart:async';

import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/monitors/device_approval_guard.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/employee_module/more/providers/device_provider.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeviceBlockedScreen extends StatefulWidget {
  const DeviceBlockedScreen({super.key});

  @override
  State<DeviceBlockedScreen> createState() => _DeviceBlockedScreenState();
}

class _DeviceBlockedScreenState extends State<DeviceBlockedScreen>
    with WidgetsBindingObserver {
  bool _isRetrying = false;
  bool _isLoggingOut = false;
  bool _leaving = false;
  Timer? _pollTimer;
  DeviceProvider? _deviceProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _deviceProvider = context.read<DeviceProvider>();
      _deviceProvider?.addListener(_onDeviceChanged);
      unawaited(_checkApproved());
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        unawaited(_checkApproved());
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _deviceProvider?.removeListener(_onDeviceChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkApproved());
    }
  }

  void _onDeviceChanged() {
    if (_deviceProvider?.isDeviceApproved == true &&
        _deviceProvider?.isDeviceBlocked != true) {
      _goHome();
    }
  }

  Future<void> _checkApproved() async {
    if (!mounted || _leaving || _isLoggingOut) return;
    final deviceProvider = _deviceProvider ?? context.read<DeviceProvider>();
    await deviceProvider.refreshDevices();
    if (!mounted || _leaving) return;
    if (deviceProvider.isDeviceApproved && !deviceProvider.isDeviceBlocked) {
      _goHome();
    }
  }

  void _goHome() {
    if (!mounted || _leaving) return;
    _leaving = true;
    _pollTimer?.cancel();
    DeviceApprovalGuard.reset();
    final home =
        context.read<AuthProvider>().homeTarget == AuthHomeTarget.manager
        ? '/manager_nav'
        : '/employee_nav';
    context.go(home);
  }

  Future<void> _retry() async {
    if (_isRetrying || _leaving) return;
    setState(() => _isRetrying = true);

    final deviceProvider = context.read<DeviceProvider>();
    final sent = await deviceProvider.registerDevice();
    if (!mounted) return;
    if (sent) {
      ToastHelper.success(context, message: 'Request sent.');
    } else {
      ToastHelper.error(
        context,
        message: deviceProvider.errorMessage ?? 'Failed to send request.',
      );
    }
    await deviceProvider.refreshDevices();
    if (!mounted) return;

    setState(() => _isRetrying = false);

    if (deviceProvider.isDeviceApproved && !deviceProvider.isDeviceBlocked) {
      _goHome();
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut || _leaving) return;
    setState(() => _isLoggingOut = true);
    _pollTimer?.cancel();

    await context.read<AuthProvider>().logout();
    if (!mounted) return;

    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kbackground1,
        body: SafeArea(
          child: Padding(
            padding: AppSizes.DEFAULT,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.block_rounded, size: 64, color: kredColor),
                const SizedBox(height: 24),
                Center(child: AppText.h4("Device blocked")),
                const SizedBox(height: 12),
                Center(
                  child: AppText.p2(
                    "Please contact your manager or HR department to unblock this device.",
                    color: kBlack300,
                    align: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                MyButton(
                  buttonText: _isRetrying ? "Sending..." : "Send request",
                  backgroundColor: kBlack,
                  fontColor: kWhite,
                  isactive: !_isRetrying && !_leaving,
                  onTap: _retry,
                ),
                const SizedBox(height: 12),
                MyButton(
                  buttonText: _isLoggingOut ? "Logging out..." : "Log out",
                  backgroundColor: kBlack,
                  fontColor: kWhite,
                  isactive: !_isRetrying && !_leaving,
                  onTap: _isLoggingOut ? null : _logout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
