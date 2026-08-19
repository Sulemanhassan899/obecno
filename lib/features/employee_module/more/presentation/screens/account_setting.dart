// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/data/models/permission_item_model.dart';
import 'package:Obecno/features/auth/providers/permission_provider.dart';
import 'package:Obecno/features/employee_module/more/data/models/employee_profile_model.dart';
import 'package:Obecno/features/employee_module/more/providers/profile_provider.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';

class AccountSetting extends StatefulWidget {
  const AccountSetting({super.key});

  @override
  State<AccountSetting> createState() => _AccountSettingState();
}

class _AccountSettingState extends State<AccountSetting> {
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProfileProvider>();
      if (provider.profile == null) {
        provider.loadProfile();
      }
      context.read<PermissionProvider>().load();
    });
  }

  void _toggle(String sectionKey) {
    setState(() {
      if (!_collapsed.add(sectionKey)) _collapsed.remove(sectionKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.read<ProfileProvider>();
    final permissionProvider = context.read<PermissionProvider>();

    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.HORIZONTAL,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              profileProvider.loadProfile(),
              permissionProvider.refresh(),
            ]);
          },
          child: ListenableBuilder(
            listenable: Listenable.merge([profileProvider, permissionProvider]),
            builder: (context, _) {
              final profile = profileProvider.profile;
              final isProfileInitialLoad =
                  profileProvider.isLoading && profile == null;

              final isPermissionInitialLoad =
                  permissionProvider.isLoading && permissionProvider.isEmpty;
              final showPermissionError =
                  !isPermissionInitialLoad &&
                  permissionProvider.hasError &&
                  permissionProvider.isEmpty;

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
                        CommonImageView(
                          imagePath: Assets.imagesInfo,
                          height: 20,
                        ),
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

                  /// ACCOUNT INFO CONTENT
                  if (isProfileInitialLoad)
                    const Padding(
                      padding: EdgeInsets.only(top: 40, bottom: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (profileProvider.hasError && profile == null)
                    _errorState(
                      profileProvider.errorMessage ??
                          'Failed to load account information.',
                      () => profileProvider.loadProfile(),
                    )
                  else
                    _content(profile),

                  const SizedBox(height: 30),
                  const Divider(color: kBorderColor, height: 1),
                  const SizedBox(height: 24),

                  /// PERMISSIONS CONTENT
                  _permissionHeader(permissionProvider),
                  const SizedBox(height: 20),

                  if (isPermissionInitialLoad)
                    const Padding(
                      padding: EdgeInsets.only(top: 40, bottom: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (showPermissionError)
                    _errorState(
                      "Failed to load your permissions.",
                      () => permissionProvider.refresh(),
                    )
                  else if (permissionProvider.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 20),
                      child: Center(
                        child: AppText.p2(
                          "No permissions available.",
                          color: kGreyColor,
                        ),
                      ),
                    )
                  else
                    ...permissionProvider.sections.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _sectionCard(entry.key, entry.value),
                      ),
                    ),

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
    final fields = profile?.profileFields ?? const [];
    debugPrint(
      'BDUI rendering ${fields.length} fields for profile=${profile?.id}',
    );

    if (fields.isEmpty) {
      return _emptyState();
    }

    ProfileField? primaryField;
    final remainingFields = <ProfileField>[];
    for (final field in fields) {
      if (primaryField == null && field.label.toLowerCase().contains('email')) {
        primaryField = field;
      } else {
        remainingFields.add(field);
      }
    }

    return Column(
      children: [
        if (primaryField != null) ...[
          _tile(
            title: primaryField.label,
            status: "Primary",
            email: primaryField.value,
          ),
          const SizedBox(height: 20),
        ],

        if (remainingFields.isNotEmpty)
          _groupCard([
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: remainingFields.length,
              itemBuilder: (context, index) {
                final item = remainingFields[index];
                return Column(
                  children: [
                    _settingTile(item.label, item.value),
                    if (index != remainingFields.length - 1) _divider(),
                  ],
                );
              },
            ),
          ]),
      ],
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      child: Center(child: AppText.p2("No Data Available", color: kSubText)),
    );
  }

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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 2,
              child: AppText.caption(title, align: TextAlign.left),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AppText.caption(status, color: kPurple),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 3,
              child: AppText.caption(
                email,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: AppText.caption(title, align: TextAlign.left),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: AppText.caption(
              subtitle,
              align: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// ================= DIVIDER =================
  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Divider(height: 1, color: kDividerColor),
    );
  }

  /// ================= PERMISSION HEADER =================
  Widget _permissionHeader(PermissionProvider provider) {
    final hasCompanyAndLocation =
        provider.companyName.isNotEmpty && provider.locationName.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.h6(
                "My Permissions",
                align: TextAlign.left,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 6),
              AppText.p2(
                hasCompanyAndLocation
                    ? "Rules that apply to you from ${provider.companyName} "
                          "settings, with ${provider.locationName} location "
                          "settings overriding where set."
                    : "Rules that apply to you, with any location-level "
                          "overrides shown below.",
                align: TextAlign.left,
                color: kGreyColor,
              ),
            ],
          ),
        ),
        if (provider.overrideCount > 0) ...[
          const SizedBox(width: 12),
          _pill(
            "${provider.overrideCount} location override"
            "${provider.overrideCount == 1 ? '' : 's'}",
            background: kGreyColor.withOpacity(0.12),
            textColor: kGreyColor,
          ),
        ],
      ],
    );
  }

  /// ================= PERMISSION SECTION CARD =================
  Widget _sectionCard(String sectionKey, List<PermissionItemModel> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    final sectionLabel = items.first.sectionLabel.isNotEmpty
        ? items.first.sectionLabel
        : sectionKey;
    final isCollapsed = _collapsed.contains(sectionKey);

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _toggle(sectionKey),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kGreyColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconFor(sectionKey),
                      size: 20,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText.h6(
                          sectionLabel,
                          align: TextAlign.left,
                          weight: FontWeight.w600,
                        ),
                        AppText.p2(
                          "${items.length} settings",
                          align: TextAlign.left,
                          color: kGreyColor,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kGreyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCollapsed ? Icons.add : Icons.remove,
                      size: 18,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isCollapsed)
            for (var i = 0; i < items.length; i++) ...[
              Divider(height: 1, color: kBorderColor),
              _permissionRow(items[i]),
            ],
        ],
      ),
    );
  }

  /// ================= PERMISSION ROW =================
  Widget _permissionRow(PermissionItemModel item) {
    final isLocationOverride =
        item.isOverride && item.sourceLevel == 'location';
    final sourceText = item.source?.isNotEmpty == true
        ? item.source!
        : (isLocationOverride ? 'From location' : 'From company');

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.h6(
                  item.label,
                  align: TextAlign.left,
                  weight: FontWeight.w600,
                ),
                const SizedBox(height: 4),
                AppText.p2(
                  item.value?.isNotEmpty == true ? item.value! : '—',
                  align: TextAlign.left,
                  color: kGreyColor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _pill(
            sourceText,
            background: isLocationOverride
                ? kPrimaryColor.withOpacity(0.12)
                : kGreyColor.withOpacity(0.12),
            textColor: isLocationOverride ? kPrimaryColor : kGreyColor,
          ),
        ],
      ),
    );
  }

  /// ================= PILL WIDGET =================
  Widget _pill(
    String text, {
    required Color background,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText.caption(text, color: textColor, align: TextAlign.center),
    );
  }

  /// ================= SECTION ICON =================
  IconData _iconFor(String sectionKey) {
    switch (sectionKey) {
      case 'attendance':
        return Icons.access_time;
      case 'leave_policies':
        return Icons.balance;
      case 'calendar':
        return Icons.calendar_month;
      case 'leave_quotas':
        return Icons.event_busy;
      default:
        return Icons.settings;
    }
  }
}
