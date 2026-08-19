import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/features/employee_module/more/providers/device_provider.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeviceBlockedScreen extends StatefulWidget {
  const DeviceBlockedScreen({super.key});

  @override
  State<DeviceBlockedScreen> createState() => _DeviceBlockedScreenState();
}

class _DeviceBlockedScreenState extends State<DeviceBlockedScreen> {
  bool _isRetrying = false;
  bool _isLoggingOut = false;

  Future<void> _retry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);

    final deviceProvider = context.read<DeviceProvider>();
    // Scenario 3: resend registration request, then re-check status.
    await deviceProvider.registerDevice();
    if (!mounted) return;
    await deviceProvider.refreshDeviceApprovalState();
    if (!mounted) return;
    await deviceProvider.checkDeviceStatus(
      context,
      loginMessage: false,
      source: 'DEVICE_BLOCKED_RESEND',
      userId: context.read<AuthProvider>().user?.id,
    );
    if (!mounted) return;

    setState(() => _isRetrying = false);

    if (deviceProvider.isDeviceApproved) {
      context.go('/employee_nav');
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    await context.read<AuthProvider>().logout();
    if (!mounted) return;

    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  "Please contact HR/Manager. A registration request has been sent for this device.",
                  color: kBlack300,
                ),
              ),
              const SizedBox(height: 32),
              MyButton(
                buttonText: _isRetrying ? "Checking..." : "Resend request",
                backgroundColor: kBlack,
                fontColor: kWhite,
                isactive: !_isRetrying,
                onTap: _retry,
              ),
              const SizedBox(height: 12),
              MyButton(
                buttonText: _isLoggingOut ? "Logging out..." : "Log out",
                backgroundColor: kBlack,
                fontColor: kWhite,
                isactive: !_isRetrying,
                onTap: _isLoggingOut ? null : _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
