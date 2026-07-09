import 'package:flutter/material.dart';

import '../core/constants/all_colors.dart';
import '../core/constants/app_fonts.dart';

/// Light [ThemeData] built from the project's existing color constants
/// (`core/constants/all_colors.dart`) — no new colors introduced, so
/// existing screens keep their current look.
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: AppFonts.Poppins,
  scaffoldBackgroundColor: kWhite,
  colorScheme: const ColorScheme.light(
    primary: kPrimaryColor,

    secondary: kSecondaryColor,
    secondaryContainer: kGreyColor,
    surface: kWhite,
    error: kRed500,
    onPrimary: kWhite,
    onSecondary: kWhite,
    onSurface: kBlack,
    onError: kWhite,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kWhite,
    foregroundColor: kBlack,

    elevation: 0,
    centerTitle: true,
  ),
  cardColor: kWhite,
  dividerColor: kDividerColor,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: kBlack, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(color: kBlack, fontWeight: FontWeight.w500),
    bodySmall: TextStyle(color: kSubText, fontWeight: FontWeight.w400),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kWhite,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kBorderColor),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryColor,
      foregroundColor: kWhite,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: kBlack,
    contentTextStyle: TextStyle(color: kWhite),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: kBlack,
      backgroundColor: kWhite,
    ),
  ),
);
