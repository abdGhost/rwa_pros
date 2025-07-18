import 'package:flutter/material.dart';

class FilterTab extends StatelessWidget {
  final String text;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDarkMode;
  final double textSize;

  const FilterTab({
    super.key,
    required this.text,
    required this.isActive,
    required this.onTap,
    required this.isDarkMode,
    this.textSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    //  Color(0xFF0087E0) : Color.fromARGB(145, 8, 149, 243)
    final backgroundColor =
        isDarkMode
            ? (isActive ? Color(0xFF0087E0) : const Color(0xFF2A2A2A))
            : (isActive ? Color(0xFF0087E0) : const Color(0xFFF1F1F1));

    final textColor =
        isDarkMode
            ? (isActive ? Colors.white : Colors.grey[400]!)
            : (isActive ? Colors.white : const Color(0xFF888888));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                isActive
                    ? const Color.fromRGBO(52, 143, 108, 0.3)
                    : const Color.fromRGBO(0, 0, 0, 0.1),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: textSize,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
