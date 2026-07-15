
// ignore_for_file: non_constant_identifier_names

import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/features/launch/onboarding/onboarding.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/features/employee_module/more/data/models/employee_profile_model.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/account_setting.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/change_password.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/linked_devices.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/office_location.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/policy.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/terms.dart';
import 'package:Obecno/features/employee_module/more/providers/profile_provider.dart';

import 'package:flutter/material.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:Obecno/shared/widgets/my_button.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // GET /api/employee/profile as soon as this tab is entered. Runs after
    // the first frame so `context.read` is safe even if this screen is
    // itself the very first widget built under ProfileProvider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => profileProvider.loadProfile(),
          child: ListenableBuilder(
            listenable: profileProvider,
            builder: (context, _) {
              final profile = profileProvider.profile;
              final isInitialLoad =
                  profileProvider.isLoading && profile == null;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  /// ================= HEADER =================
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: ButtonAnimations.press(
                      onTap: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountSetting(),
                          ),
                          (route) => true,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: kBorderColor),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              children: [
                                AppText.p2("Account Info", color: kBlack),
                                const SizedBox(width: 8),
                                CommonImageView(
                                  imagePath: Assets.imagesSetting,
                                  height: 14,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (isInitialLoad)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (profileProvider.hasError && profile == null)
                    _errorState(
                      profileProvider.errorMessage ?? 'Failed to load profile.',
                      () => context.read<ProfileProvider>().loadProfile(),
                    )
                  else
                    _profileHeader(profile),

              
                  const SizedBox(height: 18),

                  /// ================= OFFICE CARD =================
                  _tile(
                    title: "Offices & Locations",
                    count: "02",
                    icon: Assets.imagesOfficeLocationIcon,
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OfficeLocation(),
                        ),
                        (route) => true,
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  /// ================= SETTINGS =================
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText.h6("Settings", weight: FontWeight.w600),
                  ),

                  const SizedBox(height: 10),

                  _groupCard([
                    _settingTile(
                      "Linked Devices",
                      Assets.imagesLinkDevices,
                      () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LinkedDevices(),
                          ),
                          (route) => true,
                        );
                      },
                    ),
                    _divider(),
                    _settingTile("Change password", Assets.imagesKey, () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePassword(),
                        ),
                        (route) => true,
                      );
                    }),
                  ]),

                  const SizedBox(height: 14),

                  _groupCard([
                    _settingTile("Terms of use", Assets.imagesTerms, () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const TermsScreen()),
                        (route) => true,
                      );
                    }),
                    _divider(),
                    _settingTile("Privacy policy", Assets.imagesPrivacy, () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const PolicyScreen()),
                        (route) => true,
                      );
                    }),
                    _divider(),
                    _settingTile("Help & Feedback", Assets.imagesInfo, () {}),
                  ]),

                  const SizedBox(height: 14),

                  /// LOGOUT
                  ButtonAnimations.press(
                    onTap: () async {
                      await context.read<AuthProvider>().logout();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OnBoardingScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: kBorderColor),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CommonImageView(
                          imagePath: Assets.imagesLogout,
                          height: 24,
                        ),
                        title: AppText.p1(
                          "Logout",
                          color: kredColor,
                          align: TextAlign.left,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// ================= PROFILE HEADER =================
  /// Name/designation/photo straight from GET /api/employee/profile.
  /// Falls back to the placeholder asset whenever `photoUrl` is null/empty
  /// or fails to load, instead of leaving a blank circle.
  Widget _profileHeader(EmployeeProfileModel? profile) {
    final hasPhoto = profile?.photoUrl != null && profile!.photoUrl!.isNotEmpty;

    return Column(
      children: [
        Center(
          child: ClipOval(
            child: hasPhoto
                ?
                 Image.network(
                    profile!.photoUrl!,
                    height: 110,
                    width: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => CommonImageView(
                      imagePath: Assets.imagesProfileImage,
                      height: 110,
                      fit: BoxFit.contain,
                    ),
                  )
                : CommonImageView(
                    imagePath: Assets.imagesProfileImage,
                    height: 110,
                    fit: BoxFit.contain,
                  ),
          ),
        ),

        const SizedBox(height: 14),

        AppText.h5(
          profile?.name.isNotEmpty == true ? profile!.name : "—",
          weight: FontWeight.w600,
        ),

        const SizedBox(height: 6),

        AppText.p2(
          profile?.designation?.isNotEmpty == true
              ? profile!.designation!
              : "—",
          color: kGreyColor,
        ),
      ],
    );
  }

  Widget _errorState(String message, VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          AppText.p2(message, color: kredColor),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  /// ================= COMMON TILE =================
  Widget _tile({
    required String title,
    required String? count,
    required String icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ButtonAnimations.press(
        onTap: onTap,
        child: ListTile(
          title: Row(
            spacing: 5,
            children: [
              CommonImageView(imagePath: icon, height: 24),
              AppText.p1(title, align: TextAlign.left),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText.caption(count ?? "", color: kPurple),
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  Widget _groupCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingTile(String title, String icon, VoidCallback onTap) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: ListTile(
        leading: CommonImageView(imagePath: icon, height: 24),
        title: AppText.p1(title, align: TextAlign.left),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: const Divider(height: 1, color: kDividerColor),
    );
  }
}
