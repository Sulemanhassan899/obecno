
// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/employee_module/more/data/models/employee_profile_model.dart';
import 'package:Obecno/features/employee_module/more/providers/profile_provider.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/shared/widgets/back_button.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';

class AccountSetting extends StatefulWidget {
  const AccountSetting({super.key});

  @override
  State<AccountSetting> createState() => _AccountSettingState();
}

class _AccountSettingState extends State<AccountSetting> {
  @override
  void initState() {
    super.initState();
    // Only hit GET /api/employee/profile if nothing is loaded yet -- if
    // the user got here from ProfileSettingsScreen (which loads on entry
    // to the More tab), reuse that instead of firing a second request.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProfileProvider>();
      if (provider.profile == null) {
        provider.loadProfile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Grabbed once via `context.read` (the accessor already proven out by
    // every other screen in this codebase) and then rebuilt reactively
    // with Flutter's own `ListenableBuilder`, rather than assuming this
    // module's provider wrapper also exposes a `context.watch`.
    final profileProvider = context.read<ProfileProvider>();

    return Scaffold(
      body: Padding(
        padding: AppSizes.HORIZONTAL,
        child: RefreshIndicator(
          onRefresh: () => profileProvider.loadProfile(),
          child: ListenableBuilder(
            listenable: profileProvider,
            builder: (context, _) {
              final profile = profileProvider.profile;
              final isInitialLoad = profileProvider.isLoading && profile == null;

              return ListView(
                children: [
                  const SizedBox(height: 20),

                  /// HEADER
                  BackButtonBg(title: "Account Information"),

                  const SizedBox(height: 40),

                  /// INFO BOX
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kbackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CommonImageView(imagePath: Assets.imagesInfo, height: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppText.p2(
                            "Managed by your company administrator.",
                            color: kSubText,
                            align: TextAlign.left,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (isInitialLoad)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (profileProvider.hasError && profile == null)
                    _errorState(
                      profileProvider.errorMessage ?? 'Failed to load account information.',
                      () => profileProvider.loadProfile(),
                    )
                  else
                    _content(profile),

                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(EmployeeProfileModel? profile) {
    return Column(
      children: [
        /// EMAIL TILE
        _tile(
          title: "Email",
          status: "Primary",
          email: profile?.email.isNotEmpty == true ? profile!.email : "—",
        ),

        const SizedBox(height: 20),

        /// GROUP CARD
        _groupCard([
          _settingTile("Phone Number", _orDash(profile?.phone)),
          _divider(),
          _settingTile("Company ID", _orDash(profile?.employeeCode)),
          _divider(),
          _settingTile("Address", _orDash(profile?.address)),
        ]),
      ],
    );
  }

  String _orDash(String? value) => (value == null || value.isEmpty) ? "—" : value;

  Widget _errorState(String message, VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          AppText.p2(message, color: kredColor),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  /// ================= TILE =================
  Widget _tile({
    required String title,
    required String status,
    required String email,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: AppText.caption(title, align: TextAlign.left),

        /// RIGHT SIDE CONTENT
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AppText.caption(status, color: kPurple),
            ),
            const SizedBox(width: 8),
            AppText.caption(email),
          ],
        ),
      ),
    );
  }

  /// ================= GROUP CARD =================
  Widget _groupCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  /// ================= SETTING TILE =================
  Widget _settingTile(String title, String subtitle) {
    return ListTile(
      title: AppText.caption(title, align: TextAlign.left),
      trailing: AppText.caption(subtitle),
    );
  }

  /// ================= DIVIDER =================
  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Divider(height: 1, color: kDividerColor),
    );
  }
}
