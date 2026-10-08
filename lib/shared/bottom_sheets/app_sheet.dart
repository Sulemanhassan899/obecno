import 'package:obecno/shared/bottom_sheets/app_sheet_size.dart';
import 'package:flutter/material.dart';

/// One bottom sheet at a time.
///
/// A second tap while a sheet is still opening is ignored. The lock drops
/// on the next frame after the sheet is requested, so a sheet opened from
/// inside another one can still appear.
class AppSheet {
  AppSheet._();

  static bool _busy = false;

  static bool acquire() {
    if (_busy) return false;
    _busy = true;
    return true;
  }

  static void release() {
    _busy = false;
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool acquired = false,
    bool isScrollControlled = false,
    Color? backgroundColor,
    bool enableDrag = true,
    bool isDismissible = true,
    bool useRootNavigator = false,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
  }) {
    if (!acquired && !acquire()) return Future<T?>.value(null);
    final future = showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      enableDrag: enableDrag,
      isDismissible: isDismissible,
      useRootNavigator: useRootNavigator,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: AppSheetSize.modalConstraintsOf(context),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => release());
    return future;
  }
}
