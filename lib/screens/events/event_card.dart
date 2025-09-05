import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  Future<void> _openRegistration(BuildContext context) async {
    // Prefer registrationUrl; gracefully fall back to eventLink if present
    String raw = ((event['registrationUrl'] ?? '') as String).trim();
    if (raw.isEmpty) {
      raw = ((event['eventLink'] ?? '') as String).trim();
    }

    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration link not available')),
      );
      return;
    }

    Uri? uri = Uri.tryParse(raw);
    // If scheme is missing, assume https
    if (uri == null || uri.scheme.isEmpty) {
      uri = Uri.tryParse('https://$raw');
    }
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid registration link')),
      );
      return;
    }

    // Log for your console
    // ignore: avoid_print
    print('🔎 [Register] open: ${uri.toString()} | title=${event['title']}');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open registration link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List tags = event['tags'] ?? [];
    final String status = event['status'] ?? '';
    final Color statusColor = _getStatusColor(status);

    return InkWell(
      onTap: onTap,
      child: Container(
        width: 300,
        height: 300,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.network(
                    event['image'] ?? '',
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  bottom: -16,
                  left: 12,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (status.isNotEmpty) _buildTag(status, statusColor),
                      ...tags
                          .take(2)
                          .map(
                            (tag) => _buildTag(
                              tag.toString(),
                              isDark ? Colors.grey : Colors.grey.shade400,
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🎯 ${event['title'] ?? ''}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _iconText("📍", event['location'], isDark),
                    _iconText("🗓️", event['date'], isDark),
                    Row(
                      children: [
                        Expanded(child: _iconText("🧭", event['type'], isDark)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: onTap,
                          child: Text(
                            "🔍 View Details",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFEBB411),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _openRegistration(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEBB411),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 34),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Text(
                            "Register",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value ?? '',
              overflow: TextOverflow.ellipsis,
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ongoing':
        return Colors.green; // keep your UI as-is
      case 'upcoming':
        return const Color(0xFFEBB411); // yellow
      case 'ended':
        return Colors.red; // your current card UI uses red for Ended
      default:
        return Colors.grey;
    }
  }
}
