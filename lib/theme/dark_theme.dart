import 'package:flutter/material.dart';

import '../core/constants/all_colors.dart';
import '../core/constants/app_fonts.dart';

/// Dark [ThemeData] built from the project's existing color constants
/// (`core/constants/all_colors.dart`).
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: AppFonts.Poppins,
  scaffoldBackgroundColor: scaffoldDark,

  colorScheme: const ColorScheme.dark(
    primary: kPrimaryColor,
    secondary: kSecondaryColor,
    secondaryContainer: kGreyColor200,
    surface: surfaceDark,
    error: kRed400,
    onPrimary: kWhite,
    onSecondary: kWhite,
    onSurface: kWhite,
    onError: kBlack,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: surfaceDark,
    foregroundColor: kWhite,
    elevation: 0,
    centerTitle: true,
  ),
  cardColor: surfaceDark,
  dividerColor: kGreyColor200,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: kWhite),
    bodyMedium: TextStyle(color: kWhite),
    bodySmall: TextStyle(color: kGreyColor50),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: surfaceDark,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: kGreyColor200),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryColor,
      foregroundColor: kWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: kWhite,
      backgroundColor: surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
);
