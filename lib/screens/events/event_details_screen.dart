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
      final raw = data.firstWhere(
        (e) => e['_id'] == widget.eventId,
        orElse: () => {},
      );
      if (raw.isEmpty) {
        setState(() {
          event = {};
          isLoading = false;
        });
        return;
      }

      // Normalize + compute status
      final start =
          DateTime.tryParse((raw['startDate'] ?? '').toString())?.toLocal();
      final end =
          DateTime.tryParse((raw['endDate'] ?? '').toString())?.toLocal();
      final now = DateTime.now();
      String status = '';
      if (start != null && end != null) {
        if (now.isBefore(start)) {
          status = 'Upcoming';
        } else if (now.isAfter(end)) {
          status = 'Ended';
        } else {
          status = 'Ongoing';
        }
      }

      final registrationUrl =
          (raw['registrationUrl'] ??
                  raw['registrationLink'] ??
                  raw['registerLink'] ??
                  raw['eventLink'] ??
                  raw['link'] ??
                  '')
              .toString()
              .trim();

      event = {
        ...raw,
        'status': status,
        'registrationUrl': registrationUrl,
        'startDateLocal': start?.toIso8601String(),
        'endDateLocal': end?.toIso8601String(),
      };

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("❌ Error fetching event details: $e");
      setState(() => isLoading = false);
    }
  }

  // ===== Status badge style (same as card tag) =====
  Color _statusFillColor(String s) {
    switch (s.toLowerCase()) {
      case 'ongoing':
        return const Color(0xFF27AE60); // green
      case 'upcoming':
        return const Color(0xFFEBB411); // yellow
      case 'ended':
        return Colors.red; // red
      default:
        return Colors.grey;
    }
  }

  Widget _statusTag(String status) {
    final c = _statusFillColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.isEmpty ? '—' : status,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _typePill(String type, bool isDark) {
    if (type.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
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

  Future<void> _openRegistration() async {
    // Prefer registrationUrl; gracefully fall back to eventLink
    String raw = (event?['registrationUrl'] ?? '').toString().trim();
    if (raw.isEmpty) {
      raw = (event?['eventLink'] ?? '').toString().trim();
    }

    if (raw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration link not available')),
        );
      }
      return;
    }

    Uri? uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme.isEmpty) {
      uri = Uri.tryParse('https://$raw');
    }
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid registration link')),
        );
      }
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open registration link')),
      );
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
              : (event == null || event!.isEmpty)
              ? const Center(child: Text('Event not found'))
              : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMAGE + TAGS
                    if ((event!['image'] ?? '').toString().isNotEmpty)
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
                                // ✅ same style badge as card
                                _statusTag((event!['status'] ?? '').toString()),
                                if (event!['eventType'] != null &&
                                    (event!['eventType']).toString().isNotEmpty)
                                  _typePill(
                                    (event!['eventType']).toString(),
                                    isDark,
                                  ),
                                if (event!['eventTag'] != null &&
                                    event!['eventTag'] is List)
                                  ...List.generate(
                                    (event!['eventTag'] as List).length,
                                    (index) => _typePill(
                                      (event!['eventTag'][index]).toString(),
                                      isDark,
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

                    _iconText(
                      "📍",
                      (event!['eventLocation'] ?? '').toString(),
                      isDark,
                    ),
                    if ((event!['startDate'] ?? '').toString().isNotEmpty)
                      _iconText(
                        "🗓️",
                        "Start: ${_formatDate(event!['startDate'])}",
                        isDark,
                      ),
                    if ((event!['endDate'] ?? '').toString().isNotEmpty)
                      _iconText(
                        "🗓️",
                        "End: ${_formatDate(event!['endDate'])}",
                        isDark,
                      ),

                    const SizedBox(height: 18),

                    // DESCRIPTION (Rich HTML)
                    Html(
                      data: (event!['eventDescription'] ?? '').toString(),
                      onLinkTap: (url, _, __) {
                        if (url != null) {
                          launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                        }
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
                        ),
                        "h2": Style(
                          fontSize: FontSize(15),
                          fontWeight: FontWeight.bold,
                        ),
                        "h3": Style(
                          fontSize: FontSize(14),
                          fontWeight: FontWeight.bold,
                        ),
                      },
                    ),

                    const SizedBox(height: 10),

                    // Register / Website — always opens external browser
                    if ((event!['registrationUrl'] ?? '').toString().isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _openRegistration,
                        icon: const Icon(
                          Icons.event_available,
                          color: Colors.white,
                        ),
                        label: const Text("Register"),
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
                      )
                    else if ((event!['eventLink'] ?? '').toString().isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _openRegistration, // fallback to eventLink
                        icon: const Icon(
                          Icons.open_in_new,
                          color: Colors.white,
                        ),
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
    if ((value ?? '').isEmpty) return const SizedBox.shrink();
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
}
