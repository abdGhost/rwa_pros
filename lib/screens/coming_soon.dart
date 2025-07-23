import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ComingSoonScreen extends StatefulWidget {
  const ComingSoonScreen({super.key});

  @override
  State<ComingSoonScreen> createState() => _ComingSoonScreenState();
}

class _ComingSoonScreenState extends State<ComingSoonScreen> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 80,
              color: isDarkMode ? Colors.white70 : Colors.grey[800],
            ),
            const SizedBox(height: 20),
            Text(
              'Coming Soon',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            // const SizedBox(height: 10),
            // Text(
            //   'We\'re working hard to bring this feature to you!',
            //   textAlign: TextAlign.center,
            //   style: GoogleFonts.inter(
            //     fontSize: 16,
            //     color: isDarkMode ? Colors.white70 : Colors.black87,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
