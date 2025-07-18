import 'package:flutter/material.dart';

class SocialAuthButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final String? iconPath;

  const SocialAuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.iconPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = backgroundColor ?? (isDark ? theme.cardColor : Colors.white);
    final border = borderColor ?? theme.dividerColor.withOpacity(0.2);
    final text = textColor ?? theme.textTheme.bodyLarge?.color ?? Colors.black;

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.black12,
              offset: const Offset(0, 4),
              blurRadius: 6,
            ),
          ],
          borderRadius: BorderRadius.circular(5),
        ),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            side: BorderSide.none,
            shadowColor: Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconPath != null) ...[
                Image.asset(
                  iconPath!,
                  height: 20,
                  color:
                      iconPath!.contains('apple')
                          ? (isDark ? Colors.white : Colors.black)
                          : null,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: text,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
