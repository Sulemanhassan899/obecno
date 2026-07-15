import 'package:Obecno/core/constants/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/shared/widgets/text_widget.dart';
import 'package:Obecno/core/constants/all_colors.dart';

/// ===============================
/// APP TEXT STYLES (CENTRAL SYSTEM)
/// ===============================
class AppText {
  /// 🔥 H1 - 32
  static Widget h1(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w700,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 32,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  static Widget h2(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w700,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 28,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 H2 - 24
  static Widget h3(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w600,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 24,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 H3 - 22
  static Widget h4(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w600,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 22,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 H4 - 18
  static Widget h5(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w500,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 18,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 H5 - 16
  static Widget h6(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w500,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 16,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 H6 - 11
  static Widget h7(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w500,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 11,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 P1 - 16 (Body)
  static Widget p1(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w400,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 16,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 P2 - 14
  static Widget p2(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w400,
    TextAlign? align,
    TextOverflow? overflow,
  }) {
    return TextWidget(
      text: text,
      size: 14,
      textOverflow: overflow,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 P3 - 13
  static Widget p4(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w400,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 13,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 P3 - 18
  static Widget p3(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w400,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 18,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 P3 - 14
  static Widget p5(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w400,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 14,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 Caption - 12
  static Widget caption(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w400,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 12,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kGreyColor,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 Small / Tiny - 11
  static Widget small(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w400,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 11,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kGreyColor,
      textAlign: align ?? TextAlign.center,
    );
  }

  /// 🔥 Big Numbers
  static Widget bigNumber(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w700,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 32,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  static Widget bigNumber2(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w700,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 62,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }

  static Widget bigNumber3(
    String text, {
    Color? color,
    String? fontFamily,
    FontWeight weight = FontWeight.w700,
    TextAlign? align,
  }) {
    return TextWidget(
      text: text,
      size: 80,
      fontFamily: fontFamily ?? AppFonts.Poppins,
      weight: weight,
      color: color ?? kBlack,
      textAlign: align ?? TextAlign.center,
    );
  }
}
