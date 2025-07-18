import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rwa_app/screens/profile_screen.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showProfile;
  final Widget? trailing;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showProfile = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
      elevation: theme.appBarTheme.elevation ?? 1,
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: theme.textTheme.titleLarge?.color ?? Colors.black,
          ),
        ),
      ),
      actions: [
        if (trailing != null) trailing!,
        if (showProfile)
          IconButton(
            icon: SvgPicture.asset(
              'assets/profile_outline.svg',
              width: 30,
              color: theme.iconTheme.color ?? Colors.black,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}
