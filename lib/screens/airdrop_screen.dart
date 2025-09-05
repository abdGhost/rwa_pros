import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rwa_app/screens/airdrop_details_screen.dart';
import 'package:rwa_app/screens/coming_soon.dart';
import 'package:rwa_app/screens/profile_screen.dart';
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

  String stripHtml(String? input) {
    if (input == null) return '';
    final noTags = input.replaceAll(
      RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false),
      ' ',
    );
    return noTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> fetchAirdrops() async {
    final url = Uri.parse(
      'https://rwa-f1623a22e3ed.herokuapp.com/api/airdrops',
    );
    try {
      final response = await http.get(url);
      final data = json.decode(response.body);
      final List fetched = data["airdrops"];

      airdrops =
          fetched
              .map<Map<String, String>>((item) {
                try {
                  // Example raw: "16T12:09/07/2025" → use first 2 char of first segment as day
                  final startRaw = (item['airdropStart'] ?? '').toString();
                  final endRaw = (item['airdropEnd'] ?? '').toString();

                  final startParts = startRaw.split('/');
                  final endParts = endRaw.split('/');

                  final startString =
                      startParts.length >= 3
                          ? "${startParts[0].substring(0, 2)}/${startParts[1]}/${startParts[2]}"
                          : "01/01/1970";

                  final endString =
                      endParts.length >= 3
                          ? "${endParts[0].substring(0, 2)}/${endParts[1]}/${endParts[2]}"
                          : "01/01/1970";

                  final dateFormat = DateFormat('dd/MM/yyyy');
                  final start = dateFormat.parse(startString);
                  final end = dateFormat.parse(endString);
                  final now = DateTime.now();

                  final isLive = now.isAfter(start) && now.isBefore(end);
                  final isEnded = now.isAfter(end);
                  final category =
                      isLive ? "Live" : (isEnded ? "Ended" : "Upcoming");

                  return {
                    '_id': (item['_id'] ?? '').toString(),
                    'project': (item['tokenName'] ?? '').toString().trim(),
                    'token': (item['tokenTicker'] ?? '').toString(),
                    'chain': (item['chain'] ?? '').toString(),
                    'reward': (item['airdropAmt'] ?? '').toString(),
                    'image': (item['image'] ?? '').toString(),
                    // ✅ strip HTML here so cards don’t show tags
                    'description': stripHtml(
                      (item['tokenDescription'] ?? '').toString(),
                    ),
                    'date':
                        "${DateFormat('MMMM dd').format(start)} – ${DateFormat('MMMM dd, yyyy').format(end)}",
                    // Eligibility can be long; keep original (detail screen can strip/format as needed)
                    'eligibility':
                        (item['airdropEligibility'] ?? '').toString(),
                    'status': category,
                    'category': category,
                  };
                } catch (e) {
                  debugPrint('❌ Error parsing airdrop: $e');
                  return {};
                }
              })
              .where((m) => m.isNotEmpty)
              .toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error fetching airdrops: $e');
      if (mounted) setState(() => _isLoading = false);
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
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        toolbarHeight: 60,
        title: Row(
          children: [
            Text(
              'Airdrops',
              style: GoogleFonts.inter(
                textStyle: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/profile_outline.svg',
              width: 30,
              color: theme.iconTheme.color,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          onTap: () => setState(() => _selectedTab = tab),
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
                          color: Color(0xFFEBB411),
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
                                        // ✅ pass sanitized description key
                                        description:
                                            airdrop['description'] ?? '',
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
              MaterialPageRoute(builder: (context) => const ComingSoonScreen()),
            );
          },
          backgroundColor: const Color(0xFFEBB411),
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
