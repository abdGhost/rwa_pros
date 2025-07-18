import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TabBarSection extends StatelessWidget {
  final void Function(int)? onTap;

  const TabBarSection({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.center,
      child: TabBar(
        onTap: onTap,
        isScrollable: true,
        tabAlignment: TabAlignment.center, // 🔄 CHANGE THIS LINE
        labelPadding: const EdgeInsets.only(right: 12),
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(color: Color(0xFF0087E0), width: 2),
          insets: const EdgeInsets.only(bottom: 10),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelColor: isDark ? Colors.white : Colors.black,
        unselectedLabelColor: theme.textTheme.bodySmall?.color ?? Colors.grey,
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
        tabs: const [
          Tab(text: "All Coins"),
          Tab(text: "Top Coins"),
          Tab(text: "Watchlist"),
          Tab(text: "Trending"),
          Tab(text: "Top Gainers"),
          Tab(text: "Categories"),
        ],
      ),
    );
  }
}
