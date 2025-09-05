import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rwa_app/screens/events/event_card.dart';
import 'package:rwa_app/screens/events/event_details_screen.dart';
import 'package:rwa_app/screens/profile_screen.dart';
import 'package:rwa_app/widgets/filter_tab_widget.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String _selectedTab = "Upcoming";
  bool _isLoading = true;

  List<Map<String, dynamic>> events = [];
  final List<String> tabs = ["Ongoing", "Upcoming", "Ended"];

  @override
  void initState() {
    super.initState();
    fetchEvents();
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
                  final start =
                      DateTime.parse(
                        (item['startDate'] ?? '').toString(),
                      ).toLocal();
                  final end =
                      DateTime.parse(
                        (item['endDate'] ?? '').toString(),
                      ).toLocal();

                  String status;
                  if (now.isAfter(end)) {
                    status = "Ended";
                  } else if (now.isAfter(start)) {
                    status = "Ongoing"; // ✅ normalized (not "Live")
                  } else {
                    status = "Upcoming";
                  }

                  // Be tolerant to various backend fields for registration
                  final registrationUrl =
                      (item['registrationUrl'] ??
                              item['registrationLink'] ??
                              item['registerLink'] ??
                              item['eventLink'] ??
                              item['link'] ??
                              '')
                          .toString()
                          .trim();

                  // Guard some fields
                  final eventTags =
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
                    "type": type, // webinar / seminar / hybrid
                    "tags": eventTags, // list of tags
                    "image": (item["image"] ?? '').toString(),
                    "status": status, // Ongoing / Upcoming / Ended
                    "registrationUrl": registrationUrl, // used by cards/details
                    "startDate": start.toIso8601String(),
                    "endDate": end.toIso8601String(),
                  };
                } catch (e) {
                  debugPrint("⚠️ Error parsing event: $e");
                  return {};
                }
              })
              .where((e) => e.isNotEmpty)
              .toList();

      // Optional: sort by start date ascending
      events.sort((a, b) {
        final ad = DateTime.tryParse(a['startDate'] ?? '') ?? DateTime.now();
        final bd = DateTime.tryParse(b['startDate'] ?? '') ?? DateTime.now();
        return ad.compareTo(bd);
      });
    } catch (e) {
      debugPrint("❌ Error fetching events: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get filteredEvents {
    return events
        .where(
          (e) =>
              (e['status'] as String).toLowerCase() ==
              _selectedTab.toLowerCase(),
        )
        .toList();
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
        toolbarHeight: 60,
        title: Row(
          children: [
            Text(
              'Events',
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
                            filteredEvents.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.event,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'No events available',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: filteredEvents.length,
                                  itemBuilder: (context, index) {
                                    final event = filteredEvents[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
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
                                    );
                                  },
                                ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
