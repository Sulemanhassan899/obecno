// ignore_for_file: non_constant_identifier_names

import 'dart:io';

import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/helpers/dialog.dart';

import 'package:Obecno/features/launch/onboarding/onboarding.dart';
import 'package:Obecno/core/generated/assets.dart';
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
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.read<ProfileProvider>();
    final authProvider = context.read<AuthProvider>();
    return Scaffold(
      backgroundColor: kbackground1,
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
                    const Padding(padding: EdgeInsets.only(top: 80))
                  else if (profileProvider.hasError && profile == null)
                    _errorState(
                      profileProvider.errorMessage ?? 'Failed to load profile.',
                      () => context.read<ProfileProvider>().loadProfile(),
                    )
                  else
                    _profileHeader(profile, profileProvider),

                  const SizedBox(height: 18),

                  /// ================= OFFICE CARD =================
                  ListenableBuilder(
                    listenable: authProvider,
                    builder: (context, _) {
                      final count = authProvider.locations.length;
                      return _tile(
                        title: "Offices & Locations",
                        count: count.toString().padLeft(2, '0'),
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

                    //   _divider(),
                    // _settingTile("Permission", Assets.imagesInfo, () {
                    //   Navigator.pushAndRemoveUntil(
                    //     context,
                    //     MaterialPageRoute(
                    //       builder: (_) => const PermissionScreen(),
                    //     ),
                    //     (route) => true,
                    //   );
                    // }),
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
                      DialogHelper.show(
                        context: context,
                        imagePath: Assets.imagesRedBgTriangleExclamation,
                        heightImage: 100,
                        subtitle: "Are you sure you want to logout?",

                        cancelButtonText: "No",
                        buttonText: "Yes",
                        ButtonBg: kredColor,
                        onButtonTap: () async {
                          await context.read<AuthProvider>().logout();

                          if (!context.mounted) return;

                          context.go('/onboarding');
                        },

                        barrierDismissible: true,
                      );
                    },

                    child: Container(
                      decoration: BoxDecoration(
                        color: kWhite,
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

  Future<File?> pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Pick image from gallery
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1280,
      );

      if (pickedImage == null) {
        return null;
      }

      return File(pickedImage.path);
    } catch (e) {
      return null;
    }
  }

  Widget _profileHeader(
    EmployeeProfileModel? profile,
    ProfileProvider profileProvider,
  ) {
    final photoUrl = profileProvider.displayPhotoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return Column(
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              hasPhoto
                  ? CommonImageView(
                      url: photoUrl,
                      height: 110,
                      width: 110,
                      radius: 500,
                      fit: BoxFit.cover,

                      /// Optional custom error image
                      errorImage: Assets.imagesUserimage,
                    )
                  : CommonImageView(
                      imagePath: Assets.imagesUserimage,
                      height: 110,
                      width: 110,
                      fit: BoxFit.contain,
                    ),

              // ADDED (Task 6): edit overlay, bottom-right of the avatar.
              Positioned(
                bottom: 0,
                right: 0,
                child: ButtonAnimations.press(
                  onTap: () => _onEditProfilePhoto(profileProvider),
                  child: CommonImageView(
                    imagePath: Assets.imagesProfileEditPen,
                    height: 40,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        AppText.h5(
          profile?.name.isNotEmpty == true ? profile!.name : "—",
          weight: FontWeight.w600,
        ),

        const SizedBox(height: 6),

        AppText.p2(
          profile?.departmentName?.isNotEmpty == true
              ? profile!.departmentName!
              : (profile?.designation?.isNotEmpty == true
                    ? profile!.designation!
                    : "—"),
          color: kGreyColor,
        ),
      ],
    );
  }

  Future<void> _onEditProfilePhoto(ProfileProvider profileProvider) async {
    debugPrint('[ProfileSettingsScreen] Edit-photo tapped, opening picker...');
    final File? picked = await pickProfileImage();
    if (picked == null) {
      debugPrint('[ProfileSettingsScreen] No image selected, aborting upload.');
      return;
    }
    final bytes = await picked.readAsBytes();
    debugPrint(
      '[ProfileSettingsScreen] Image picked (${picked.path}), '
      'calling ProfileProvider.updatePhoto()...',
    );
    final ok = await profileProvider.updatePhoto(
      photoBytes: bytes,
      fileName: picked.path.split('/').last,
    );
    debugPrint('[ProfileSettingsScreen] updatePhoto() result: $ok');
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
        color: kWhite,
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
        color: kWhite,
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
