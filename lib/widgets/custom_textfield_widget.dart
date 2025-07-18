import 'package:flutter/material.dart';
import 'package:rwa_app/theme/theme.dart'; // For AppColors

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;
  final Color borderColor;
  final double borderWidth;

  const CustomTextField({
    super.key,
    this.controller,
    required this.hint,
    this.obscure = false,
    this.suffix,
    this.borderColor = Colors.black12,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        cursorColor: AppColors.primaryLight,
        cursorHeight: 20,
        cursorWidth: 1,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey,
            fontSize: 14,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          suffixIcon: suffix,
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primaryLight, width: 1.2),
            borderRadius: BorderRadius.all(Radius.circular(5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor, width: borderWidth),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
        ),
      ),
    );
  }
}
