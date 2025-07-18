import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primaryLight = Color(0xFF0087E0);
  static const primaryDark = Color(0xFF0087E0);
  static const scaffoldLight = Color(0xFFF7F7F7);
  static const scaffoldDark = Color(0xFF0D0D0D);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF1A1A1A);
  static const greyText = Color(0xFF9E9E9E);
}

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.scaffoldLight,
  primaryColor: AppColors.primaryLight,
  cardColor: AppColors.cardLight,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 1,
    iconTheme: IconThemeData(color: Colors.black),
    titleTextStyle: TextStyle(
      color: Colors.black,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),
  textTheme: GoogleFonts.interTextTheme().apply(
    bodyColor: Colors.black,
    displayColor: Colors.black,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    ),
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.scaffoldDark,
  primaryColor: AppColors.primaryDark,
  cardColor: AppColors.cardDark,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  ),
  textTheme: GoogleFonts.interTextTheme(
    ThemeData.dark().textTheme,
  ).apply(bodyColor: Colors.white, displayColor: Colors.white),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    ),
  ),
);
