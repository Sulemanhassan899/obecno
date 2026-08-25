import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_strings.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/snackbar_helper.dart';
import 'package:flutter/material.dart';

class ToastHelper {
  ToastHelper._();

  // =====================================================================
  // Primitives
  // =====================================================================

  /// Generic toast — use a named helper below when a dedicated message exists.
  static void show(
    BuildContext context, {
    required String message,
    String? imagePath,
    Color backgroundColor = const Color(0xFF2F3136),
    Color textColor = kWhite,
    Duration duration = const Duration(seconds: 4),
    bool isError = false,
  }) {
    SnackbarHelper.showTopToast(
      context,
      message: message,
      imagePath: imagePath,
      backgroundColor: isError ? kredColor : backgroundColor,
      textColor: textColor,
      duration: duration,
    );
  }

  /// Success-style dark pill toast with check icon.
  static void success(
    BuildContext context, {
    required String message,
    String? imagePath,
  }) {
    SnackbarHelper.showTopToast(
      context,
      message: message,
      imagePath: imagePath ?? Assets.imagesCircleCheckTick,
      backgroundColor: const Color(0xFF2F3136),
      textColor: kWhite,
    );
  }

  static void error(
    BuildContext context, {
    required String message,
  }) {
    SnackbarHelper.showTopToast(
      context,
      message: message,
      backgroundColor: kredColor,
      textColor: kWhite,
    );
  }

  // =====================================================================
  // lib/shared/bottom_sheets — device management (manager sheet)
  // =====================================================================

  static void deviceApproved(BuildContext context) {
    success(
      context,
      message: 'Device Approved',
    );
  }

  static void deviceRejected(BuildContext context) {
    success(
      context,
      message: 'Device Rejected',
    );
  }

  static void deviceBlocked(BuildContext context) {
    success(
      context,
      message: 'Device Blocked',
    );
  }

  static void deviceUnblocked(BuildContext context) {
    success(
      context,
      message: 'Device Unblocked',
    );
  }

  // =====================================================================
  // lib/shared/bottom_sheets — edit sheets / account / locations
  // (edit_account_field, working_days, break_timing, check_in_out,
  //  employee_default_locations)
  // =====================================================================

  static void changesSaved(BuildContext context) {
    success(
      context,
      message: 'Changes saved.',
    );
  }

  // =====================================================================
  // lib/shared/bottom_sheets — attendance fix request
  // (add_attendance_bottom_sheet)
  // =====================================================================

  static void attendanceRequestSent(
    BuildContext context, {
    required bool ok,
    String? message,
  }) {
    show(
      context,
      message: ok
          ? ((message != null && message.isNotEmpty)
                ? message
                : 'Request send')
          : ((message != null && message.isNotEmpty)
                ? message
                : 'Request not send'),
      backgroundColor: ok ? kYellowColor : kredColor,
      isError: !ok,
    );
  }

  // =====================================================================
  // lib/features/manager_module — locations
  // (location_setup_screen, setup_location_map_screen)
  // =====================================================================

  static void locationDeleted(BuildContext context) {
    success(
      context,
      message: 'Location deleted.',
    );
  }

  static void locationDeactivated(BuildContext context) {
    success(
      context,
      message: 'Location deactivated.',
    );
  }

  static void couldNotGetLocation(BuildContext context) {
    show(context, message: 'Could not get current location.');
  }

  // =====================================================================
  // lib/features/employee_module — linked devices
  // =====================================================================

  static void deviceDeleted(BuildContext context, {String? message}) {
    success(context, message: message ?? 'Device deleted.');
  }

  static void deviceDeleteFailed(BuildContext context, {String? message}) {
    error(context, message: message ?? 'Failed to delete device.');
  }

  // =====================================================================
  // Device approval guard / login device status
  // =====================================================================

  static void deviceBlockedAlert(
    BuildContext context, {
    bool isRejected = false,
  }) {
    error(
      context,
      message: isRejected ? 'Device rejected' : 'Device blocked',
    );
  }

  static void unregisteredDevice(BuildContext context) {
    show(
      context,
      message: 'you logged in from unregistered device',
      backgroundColor: kBlack,
    );
  }

  // =====================================================================
  // Clock / attendance action toasts
  // =====================================================================

  static void checkedIn(BuildContext context) {
    show(
      context,
      message: AppStrings.checkedIn,
      backgroundColor: kBlack,
      imagePath: Assets.imagesCircleCheckDown,
    );
  }

  static void checkedOut(BuildContext context) {
    show(
      context,
      message: AppStrings.checkedOut,
      backgroundColor: kBlack,
      imagePath: Assets.imagesCircleCheckUp,
    );
  }

  static void breakStarted(BuildContext context) {
    show(
      context,
      message: AppStrings.breakStarted,
      backgroundColor: kBlack,
      imagePath: Assets.imagesMugHotWhite,
    );
  }

  static void breakEnded(BuildContext context) {
    show(
      context,
      message: AppStrings.breakEnded,
      backgroundColor: kBlack,
      imagePath: Assets.imagesCircleCheckTick,
    );
  }

  static void syncing(BuildContext context) {
    show(context, message: AppStrings.syncing, backgroundColor: kBlack);
  }

  static void synced(BuildContext context, {required bool success}) {
    show(
      context,
      message: success ? AppStrings.synced : 'Sync failed',
      backgroundColor: success ? kBlack : kredColor,
    );
  }

  static void noInternet(BuildContext context) {
    error(context, message: AppStrings.noInternetConnection);
  }

  static void nonWorkingDay(BuildContext context) {
    error(context, message: AppStrings.nonWorkingDay);
  }

  static void breakLimitReached(BuildContext context) {
    error(context, message: 'Break limit reached');
  }

  static void locationRequiredForOffice(BuildContext context) {
    error(
      context,
      message:
          'Location permissions required to view office locations.',
    );
  }

  static void notificationReminder(BuildContext context) {
    show(
      context,
      message: 'Turn on notifications to get check-in/check-out reminders.',
      backgroundColor: kOrangeColor,
    );
  }

  // =====================================================================
  // Auth / permissions / account
  // =====================================================================

  static void passwordChanged(BuildContext context, {String? message}) {
    show(
      context,
      message: message ?? 'Password changed successfully.',
      backgroundColor: kOrangeColor,
    );
  }

  static void allPermissionsGranted(BuildContext context) {
    show(
      context,
      message: 'All permissions granted',
      backgroundColor: kgreenColor,
      duration: const Duration(seconds: 2),
    );
  }

  static void pleaseAllowPermissions(BuildContext context) {
    show(
      context,
      message: 'Please allow all permissions',
      backgroundColor: kOrangeColor,
      duration: const Duration(seconds: 3),
    );
  }

  static void permissionRequestError(BuildContext context) {
    error(context, message: 'Error requesting permissions');
  }
}
