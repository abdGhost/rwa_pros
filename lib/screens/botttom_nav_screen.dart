import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rwa_app/screens/airdrop_screen.dart';
import 'package:rwa_app/screens/forum_category.dart';
import 'package:rwa_app/screens/forum_screen.dart';
import 'package:rwa_app/screens/home_screen.dart';
import 'package:rwa_app/screens/news_screen.dart';
import 'package:rwa_app/screens/portfolio_screen.dart';
// import 'package:rwa_app/screens/treasury_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    NewsScreen(),
    AirdropScreen(),
    PortfolioScreen(),
    // TreasuryScreen(),
    // ForumScreen(),
    ForumCategory(),
  ];

  final List<String> _screenNames = [
    '/',
    '/news',
    '/airdrop',
    '/portfolio',
    '/forum',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: theme.primaryColor,
        unselectedItemColor: isDark ? Colors.white60 : const Color(0xFF818181),
        backgroundColor:
            theme.bottomNavigationBarTheme.backgroundColor ??
            theme.scaffoldBackgroundColor,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          // Delay the screen logging until after frame is rendered
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FirebaseAnalytics.instance.logScreenView(
              screenName: _screenNames[index],
              screenClass: _screenNames[index],
            );
          });
        },

        items: [
          BottomNavigationBarItem(
            icon: _buildIcon('market', 0, theme, isDark),
            label: 'Market',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon('news', 1, theme, isDark),
            label: 'Updates',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon('airdrop', 2, theme, isDark),
            label: 'Airdrop',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon('portfolio', 3, theme, isDark),
            label: 'Portfolio',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon('forum', 4, theme, isDark),
            label: 'Forum',
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(String name, int index, ThemeData theme, bool isDark) {
    return SvgPicture.asset(
      'assets/${name}_${_selectedIndex == index ? 'fill' : 'outline'}.svg',
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(
        _selectedIndex == index
            ? theme.primaryColor
            : (isDark ? Colors.white60 : const Color(0xFF818181)),
        BlendMode.srcIn,
      ),
    );
  }
}
