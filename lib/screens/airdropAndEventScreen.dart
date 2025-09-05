import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'package:rwa_app/screens/airdrop_details_screen.dart';
import 'package:rwa_app/screens/airdrop_screen.dart';
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

  // ---------- Logging helper ----------
  void _log(String msg) {
    // Throttled debug print, easy to grep by "[Discover]"
    debugPrint('🔎 [Discover] $msg');
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      await Future.wait([fetchEvents(), fetchAirdrops()]);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Small helper to sanitize HTML (for airdrop descriptions/snippets)
  String _stripHtml(String? input) {
    if (input == null) return '';
    final noTags = input.replaceAll(
      RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false),
      ' ',
    );
    return noTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> fetchEvents() async {
    final url = Uri.parse('https://rwa-f1623a22e3ed.herokuapp.com/api/events/');
    try {
      _log('GET /api/events start');
      final t0 = DateTime.now();

      final response = await http.get(url);

      final dt = DateTime.now().difference(t0).inMilliseconds;
      _log(
        '/api/events -> ${response.statusCode} (${response.bodyBytes.length} bytes) in ${dt}ms',
      );

      if (response.statusCode != 200) {
        _log('! Non-200 from /api/events: ${response.statusCode}');
        return;
      }

      final decoded = json.decode(response.body);
      final List data = decoded["events"] ?? [];
      _log('Raw events count: ${data.length}');

      final now = DateTime.now();

      final parsed =
          data
              .map<Map<String, dynamic>>((item) {
                try {
                  final startUtc = DateTime.tryParse(
                    (item['startDate'] ?? '').toString(),
                  );
                  final endUtc = DateTime.tryParse(
                    (item['endDate'] ?? '').toString(),
                  );
                  if (startUtc == null || endUtc == null) return {};

                  final start = startUtc.toLocal();
                  final end = endUtc.toLocal();

                  final status =
                      now.isAfter(end)
                          ? "Ended"
                          : now.isAfter(start)
                          ? "Ongoing" // normalized (no "Live")
                          : "Upcoming";

                  // Registration link (tolerant to multiple keys)
                  final registrationUrl =
                      (item['registrationUrl'] ??
                              item['registrationLink'] ??
                              item['registerLink'] ??
                              item['eventLink'] ??
                              item['link'] ??
                              '')
                          .toString()
                          .trim();

                  final tags =
                      (item["eventTag"] is List)
                          ? List<String>.from(item["eventTag"])
                          : <String>[];
                  final type = (item["eventType"] ?? '').toString();

                  return {
                    "_id": item["_id"],
                    "title": (item["title"] ?? '').toString(),
                    "location": (item["eventLocation"] ?? '').toString(),
                    "date":
                        "${DateFormat('MMMM dd').format(start)} – ${DateFormat('MMMM dd, yyyy').format(end)}",
                    "pricing": (item["pricing"] ?? "N/A").toString(),
                    "type": type,
                    "tags": tags,
                    "image": (item["image"] ?? '').toString(),
                    "status": status,
                    "registrationUrl": registrationUrl,
                    "startDate": start.toIso8601String(),
                    "endDate": end.toIso8601String(),
                  };
                } catch (e) {
                  _log('⚠️ parse error (event): $e');
                  return {};
                }
              })
              .where((e) => e.isNotEmpty)
              .toList();

      // Sort by start date
      parsed.sort((a, b) {
        final ad = DateTime.tryParse(a['startDate'] ?? '') ?? DateTime.now();
        final bd = DateTime.tryParse(b['startDate'] ?? '') ?? DateTime.now();
        return ad.compareTo(bd);
      });

      // Log a compact preview (first few)
      _log(
        'Parsed ${parsed.length} events (showing first ${min(6, parsed.length)})…',
      );
      for (int i = 0; i < min(6, parsed.length); i++) {
        final e = parsed[i];
        _log(
          '• Event[$i]: "${e['title']}" | status=${e['status']} | start=${e['startDate']} | end=${e['endDate']} | reg=${(e['registrationUrl'] ?? '').toString().isEmpty ? '—' : e['registrationUrl']}',
        );
      }

      events = parsed;
      _log('Events ready: ${events.length}');
    } catch (e) {
      _log('❌ Error fetching events: $e');
    }
  }

  Future<void> fetchAirdrops() async {
    final url = Uri.parse(
      'https://rwa-f1623a22e3ed.herokuapp.com/api/airdrops',
    );
    try {
      _log('GET /api/airdrops start');
      final t0 = DateTime.now();

      final response = await http.get(url);

      final dt = DateTime.now().difference(t0).inMilliseconds;
      _log(
        '/api/airdrops -> ${response.statusCode} (${response.bodyBytes.length} bytes) in ${dt}ms',
      );

      if (response.statusCode != 200) {
        _log('! Non-200 from /api/airdrops: ${response.statusCode}');
        return;
      }

      final decoded = json.decode(response.body);
      final List data = decoded["airdrops"] ?? [];
      _log('Raw airdrops count: ${data.length}');

      final now = DateTime.now();

      final parsed =
          data
              .map<Map<String, String>>((item) {
                try {
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

                  final isLive = now.isAfter(start) && now.isBefore(end);
                  final isEnded = now.isAfter(end);
                  final status =
                      isLive ? "Live" : (isEnded ? "Ended" : "Upcoming");

                  final mapped = {
                    '_id': (item['_id'] ?? '').toString(),
                    'project': (item['tokenName'] ?? '').toString().trim(),
                    'token': (item['tokenTicker'] ?? '').toString(),
                    'chain': (item['chain'] ?? '').toString(),
                    'reward': (item['airdropAmt'] ?? '').toString(),
                    'image': (item['image'] ?? '').toString(),
                    'description': _stripHtml(
                      (item['tokenDescription'] ?? '').toString(),
                    ),
                    'date':
                        "${DateFormat('MMMM dd').format(start)} – ${DateFormat('MMMM dd, yyyy').format(end)}",
                    'eligibility':
                        (item['airdropEligibility'] ?? '').toString(),
                    'status': status,
                  };

                  return mapped;
                } catch (e) {
                  _log('⚠️ parse error (airdrop): $e');
                  return {};
                }
              })
              .where((m) => m.isNotEmpty)
              .toList();

      _log(
        'Parsed ${parsed.length} airdrops (showing first ${min(6, parsed.length)})…',
      );
      for (int i = 0; i < min(6, parsed.length); i++) {
        final d = parsed[i];
        _log(
          '• Airdrop[$i]: "${d['project']}" | ticker=${d['token']} | status=${d['status']} | date=${d['date']}',
        );
      }

      airdrops = parsed;
      _log('Airdrops ready: ${airdrops.length}');
    } catch (e) {
      _log('❌ Error fetching airdrops: $e');
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
              color: const Color(0xFFEBB411),
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
              isDark
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
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFEBB411)),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 12, right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ====== Events ======
                      _buildSectionHeader("Events", () {
                        _log(
                          'Tap "View All" (Events) → navigate to EventsScreen',
                        );
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
                                    _log(
                                      'Open EventDetail: id=${event['_id']} | title=${event['title']} | status=${event['status']} | reg=${event['registrationUrl'] ?? ''}',
                                    );
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

                      // ====== Airdrops ======
                      _buildSectionHeader("Airdrops", () {
                        _log(
                          'Tap "View All" (Airdrops) → navigate to AirdropScreen',
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AirdropScreen(),
                          ),
                        );
                      }),
                      SizedBox(
                        height: 210,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: min(4, airdrops.length),
                          itemBuilder: (context, index) {
                            final airdrop = airdrops[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width: 300,
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
                                  // sanitized preview text
                                  description: airdrop['description'] ?? '',
                                  onTap: () {
                                    _log(
                                      'Open AirdropDetail: id=${airdrop['_id']} | project=${airdrop['project']} | status=${airdrop['status']}',
                                    );
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
                    ],
                  ),
                ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFEBB411),
        shape: const CircleBorder(),
        onPressed: () {
          _log('FAB tapped → navigate to EventsScreen');
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
