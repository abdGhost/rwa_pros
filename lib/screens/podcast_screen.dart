import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PodcastScreen extends StatelessWidget {
  const PodcastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final podcastItems = [
      {
        'image': 'assets/images/defi.png',
        'title': 'US Treasuries on DeFi: The Ondo Finance Model',
        'author': 'Nathan Allen (Ondo)',
        'stats': '685K listens · 3 months ago',
      },
      {
        'image': 'assets/images/tradfi.png',
        'title': 'RWA Lending vs TradFi Lending',
        'author': 'David Feld (Goldfinch)',
        'stats': '387K listens · 1 month ago',
      },
      {
        'image': 'assets/images/ai_city.png',
        'title': 'Future Cities on Chain with AI + RWA',
        'author': 'SmartCity Alliance',
        'stats': '122K listens · 2 weeks ago',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: podcastItems.length,
          itemBuilder: (context, index) {
            final item = podcastItems[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(item['image']!, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['title']!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundImage: AssetImage('assets/images/avatar.png'),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item['author']} · ${item['stats']}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Market',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Podcast'),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard),
            label: 'Airdrop',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Portfolio',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
        ],
      ),
    );
  }
}
