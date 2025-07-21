import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rwa_app/screens/airdrop_details_screen.dart';
import 'package:rwa_app/screens/chat_screen.dart';
import 'package:rwa_app/widgets/airdrop/airdrop_card.dart';
import 'package:rwa_app/widgets/filter_tab_widget.dart';

class AirdropScreen extends StatefulWidget {
  const AirdropScreen({super.key});

  @override
  State<AirdropScreen> createState() => _AirdropScreenState();
}

class _AirdropScreenState extends State<AirdropScreen> {
  String _selectedTab = "Recently Added";
  bool _isLoading = true;

  List<Map<String, String>> airdrops = [];

  final List<String> tabs = ["Recently Added", "Live", "Ended", "Upcoming"];

  @override
  void initState() {
    super.initState();
    fetchAirdrops();
  }

  Future<void> fetchAirdrops() async {
    final url = Uri.parse(
      'https://rwa-f1623a22e3ed.herokuapp.com/api/admin/airdrop/get/allAirdrop',
    );
    try {
      final response = await http.get(url);
      final data = json.decode(response.body);
      final List fetched = data["data"];
      print('airdrop Data $fetched');

      setState(() {
        airdrops =
            fetched.map<Map<String, String>>((item) {
              // Parse custom date format
              final dateFormat = DateFormat('dd/MM/yyyy');
              DateTime start = dateFormat.parse(item['airdropStart']);
              DateTime end = dateFormat.parse(item['airdropEnd']);
              final now = DateTime.now();

              bool isLive = now.isAfter(start) && now.isBefore(end);
              bool isEnded = now.isAfter(end);

              String category =
                  isLive
                      ? "Live"
                      : isEnded
                      ? "Ended"
                      : "Upcoming";

              return {
                '_id': item['_id'],
                'project': item['tokenName'].trim(),
                'token': item['tokenTicker'],
                'chain': item['chain'],
                'reward': item['airdropAmt'],
                'image': item['image'],
                'description': item['tokenDescription'],
                'date':
                    "${DateFormat('MMMM dd').format(start)} – ${DateFormat('MMMM dd, yyyy').format(end)}",
                'eligibility': item['airdropEligibility'],
                'status':
                    isLive
                        ? "Live"
                        : isEnded
                        ? "Ended"
                        : "Upcoming",
                'category': category,
              };
            }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching airdrops: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, String>> get filteredAirdrops {
    if (_selectedTab == "Recently Added") return airdrops;
    return airdrops.where((drop) => drop['category'] == _selectedTab).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Image.asset(
                'assets/airdrop.png',
                width: double.infinity,
                height: 210,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children:
                    tabs.map((tab) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterTab(
                          text: tab,
                          isActive: _selectedTab == tab,
                          onTap: () {
                            setState(() {
                              _selectedTab = tab;
                            });
                          },
                          isDarkMode: isDark,
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0087E0),
                        ),
                      )
                      : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child:
                            filteredAirdrops.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.air,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'No airdrop available',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: filteredAirdrops.length,
                                  itemBuilder: (context, index) {
                                    final airdrop = filteredAirdrops[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: AirdropCard(
                                        id: airdrop['_id']!,
                                        project: airdrop['project']!,
                                        token: airdrop['token']!,
                                        chain: airdrop['chain']!,
                                        reward: airdrop['reward']!,
                                        date: airdrop['date']!,
                                        eligibility: airdrop['eligibility']!,
                                        status: airdrop['status']!,
                                        isDarkMode: isDark,
                                        image: airdrop['image'] ?? '',
                                        description:
                                            airdrop['tokenDescription'] ?? '',
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => AirdropDetailScreen(
                                                    airdrop: airdrop,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            );
          },
          backgroundColor: const Color(0xFF0087E0),
          shape: const CircleBorder(),
          child: SvgPicture.asset(
            'assets/bot_light.svg',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
