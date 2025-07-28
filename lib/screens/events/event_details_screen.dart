import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final String title;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    required this.title,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? event;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEventDetails();
  }

  Future<void> fetchEventDetails() async {
    final url = Uri.parse('https://rwa-f1623a22e3ed.herokuapp.com/api/events/');
    try {
      final response = await http.get(url);
      final List data = json.decode(response.body)["events"];
      event = data.firstWhere(
        (e) => e['_id'] == widget.eventId,
        orElse: () => {},
      );
      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("❌ Error fetching event details: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.inter()),
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFEBB411)),
              )
              : event == null || event!.isEmpty
              ? const Center(child: Text('Event not found'))
              : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMAGE + TAGS STACKED
                    if (event!['image'] != null)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              event!['image'],
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            bottom: -18,
                            left: 12,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                // Status tag
                                _buildTag(
                                  _getEventStatus(
                                    event!['startDate'],
                                    event!['endDate'],
                                  ),
                                  _getStatusColor(
                                    event!['startDate'],
                                    event!['endDate'],
                                  ),
                                ),
                                // Other tags
                                if (event!['eventTag'] != null &&
                                    event!['eventTag'] is List)
                                  ...List.generate(
                                    (event!['eventTag'] as List).length,
                                    (index) => _buildTag(
                                      (event!['eventTag'][index]).toString(),
                                      isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 30),

                    // TITLE
                    Text(
                      "🎯 ${event!['title'] ?? ''}",
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _iconText("📍", event!['eventLocation'], isDark),
                    _iconText(
                      "🗓️",
                      "Start: ${_formatDate(event!['startDate'])}",
                      isDark,
                    ),
                    _iconText(
                      "🗓️",
                      "End: ${_formatDate(event!['endDate'])}",
                      isDark,
                    ),

                    const SizedBox(height: 18),

                    // DESCRIPTION
                    Html(
                      data: event!['eventDescription'] ?? '',
                      onLinkTap: (url, _, __) {
                        if (url != null) _launchURL(url);
                      },
                      style: {
                        "*": Style(
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontSize: FontSize(13),
                          color: isDark ? Colors.white : Colors.black87,
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                        ),
                        "p": Style(
                          margin: Margins.only(bottom: 6),
                          lineHeight: LineHeight.number(1.4),
                        ),
                        "h1": Style(
                          fontSize: FontSize(16),
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        "h2": Style(
                          fontSize: FontSize(15),
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        "h3": Style(
                          fontSize: FontSize(14),
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      },
                    ),

                    if (event!['eventLink'] != null)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final link = event!['eventLink'];
                          if (link != null &&
                              await canLaunchUrl(Uri.parse(link))) {
                            await launchUrl(
                              Uri.parse(link),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        label: const Text("Visit Website"),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFFEBB411),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _iconText(String icon, String? value, bool isDark) {
    final Color textColor = isDark ? Colors.white70 : Colors.grey[800]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value ?? '',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final date = DateTime.parse(raw).toLocal();
      return DateFormat('MMM d, yyyy • hh:mm a').format(date);
    } catch (_) {
      return raw;
    }
  }

  String _getEventStatus(String startRaw, String endRaw) {
    try {
      final now = DateTime.now();
      final start = DateTime.parse(startRaw);
      final end = DateTime.parse(endRaw);
      if (now.isBefore(start)) return "Upcoming";
      if (now.isAfter(end)) return "Ended";
      return "Ongoing";
    } catch (_) {
      return "";
    }
  }

  Color _getStatusColor(String startRaw, String endRaw) {
    final status = _getEventStatus(startRaw, endRaw);
    switch (status.toLowerCase()) {
      case 'ongoing':
        return Colors.green;
      case 'upcoming':
        return const Color(0xFFEBB411);
      case 'ended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch $url");
    }
  }
}
