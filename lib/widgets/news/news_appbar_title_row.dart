import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rwa_app/screens/profile_screen.dart';

class NewsAppBarTitleRow extends StatelessWidget {
  final VoidCallback onSearchTap;

  const NewsAppBarTitleRow({super.key, required this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Text(
          'News',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onSearchTap,
          child: SvgPicture.asset(
            'assets/search_outline.svg',
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              theme.iconTheme.color ?? (isDark ? Colors.white : Colors.black),
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
          child: SvgPicture.asset(
            'assets/profile_outline.svg',
            width: 28,
            height: 28,
            colorFilter: ColorFilter.mode(
              theme.iconTheme.color ?? (isDark ? Colors.white : Colors.black),
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }
}
