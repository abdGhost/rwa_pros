import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:rwa_app/screens/airdrop_details_screen.dart';
import 'package:rwa_app/screens/airdrop_screen.dart';
import 'package:rwa_app/screens/coming_soon.dart';
import 'package:rwa_app/screens/events/event_card.dart';
import 'package:rwa_app/screens/events/event_details_screen.dart';
import 'package:rwa_app/screens/events/events_screen.dart';
import 'package:rwa_app/screens/profile_screen.dart';
import 'package:rwa_app/widgets/airdrop/airdrop_card.dart';

class AirdropAndEventScreen extends StatefulWidget {
  const AirdropAndEventScreen({super.key});

  @override
  State<AirdropAndEventScreen> createState() => _AirdropAndEventScreenState();
}

class _AirdropAndEventScreenState extends State<AirdropAndEventScreen> {
  List<Map<String, dynamic>> events = [];
  List<Map<String, String>> airdrops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    await Future.wait([fetchEvents(), fetchAirdrops()]);
    setState(() => _isLoading = false);
  }

  Future<void> fetchEvents() async {
    final url = Uri.parse('https://rwa-f1623a22e3ed.herokuapp.com/api/events/');
    try {
      final response = await http.get(url);
      final List data = json.decode(response.body)["events"];
      final now = DateTime.now();

      events =
          data
              .map<Map<String, dynamic>>((item) {
                try {
                  final startDate = DateTime.parse(item['startDate']);
                  final endDate = DateTime.parse(item['endDate']);
                  final status =
                      now.isAfter(endDate)
                          ? "Ended"
                          : now.isAfter(startDate)
                          ? "Live"
                          : "Upcoming";

                  return {
                    "_id": item["_id"],
                    "title": item["title"],
                    "location": item["eventLocation"],
                    "date":
                        "${DateFormat('MMMM dd').format(startDate)} – ${DateFormat('MMMM dd, yyyy').format(endDate)}",
                    "pricing":
                        "N/A", // Pricing not provided, use default or empty
                    "type": item["eventType"],
                    "tags": item["eventTag"],
                    "image": item["image"],
                    "status": status,
                  };
                } catch (_) {
                  return {};
                }
              })
              .where((e) => e.isNotEmpty)
              .toList();
    } catch (e) {
      debugPrint("❌ Error fetching events: $e");
    }
  }

  Future<void> fetchAirdrops() async {
    final url = Uri.parse(
      'https://rwa-f1623a22e3ed.herokuapp.com/api/airdrops',
    );
    try {
      final response = await http.get(url);
      final List data = json.decode(response.body)["airdrops"];
      final now = DateTime.now();

      airdrops =
          data
              .map<Map<String, String>>((item) {
                try {
                  final startRaw = item['airdropStart'] as String;
                  final endRaw = item['airdropEnd'] as String;
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
                  final status =
                      now.isAfter(end)
                          ? "Ended"
                          : now.isAfter(start)
                          ? "Live"
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
                    'status': status,
                  };
                } catch (_) {
                  return {};
                }
              })
              .where((item) => item.isNotEmpty)
              .toList();
    } catch (e) {
      debugPrint("❌ Error fetching airdrops: $e");
    }
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewMore) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: onViewMore,
          child: Text(
            "View All",
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFEBB411), // 🌟 Yellow color
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        title: Row(
          children: [
            Image.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/rwapros/logo-white.png'
                  : 'assets/rwapros/logo.png',
              width: 40,
              height: 40,
            ),

            const SizedBox(width: 8),
            Text(
              'Discover',
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
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
          ),
        ],
      ),

      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 12, right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader("Events", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EventsScreen(),
                          ),
                        );
                      }),

                      SizedBox(
                        height: 292,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: min(4, events.length),
                          itemBuilder: (context, index) {
                            final event = events[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width: 300,
                                child: EventCard(
                                  event: event,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => EventDetailScreen(
                                              eventId: event['_id'],
                                              title: event['title'],
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      _buildSectionHeader("Airdrops", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AirdropScreen(),
                          ),
                        );
                      }),

                      // const SizedBox(height: 8),
                      SizedBox(
                        height:
                            210, // Adjust height as needed based on AirdropCard design
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: min(4, airdrops.length),
                          itemBuilder: (context, index) {
                            final airdrop = airdrops[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width:
                                    300, // Set width for each horizontal card
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
                                  description: airdrop['description'] ?? '',
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
                              ),
                            );
                          },
                        ),
                      ),

                      // const SizedBox(height: 4),
                    ],
                  ),
                ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFEBB411),
        shape: const CircleBorder(),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EventsScreen()),
          );
        },
        child: SvgPicture.asset(
          'assets/bot_light.svg',
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }
}
