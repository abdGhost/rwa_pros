import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NewsCardMain extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  const NewsCardMain({super.key, required this.item, this.onTap});

  String getRelativeTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    DateTime? dateTime;

    try {
      if (timeStr.contains('GMT')) {
        final parts = timeStr.split(' ');
        if (parts.length >= 6) {
          final cleaned = '${parts[2]} ${parts[1]} ${parts[3]} ${parts[4]}';
          dateTime = DateFormat('d MMM yyyy HH:mm:ss').parse(cleaned);
        }
      } else {
        dateTime = DateTime.tryParse(timeStr);
      }
    } catch (e) {
      print('❌ Date parse error: $e');
    }

    if (dateTime == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor =
        theme.textTheme.bodySmall?.color?.withOpacity(0.6) ?? Colors.grey;

    final infoColor = const Color(0xFF0087E0);

    final bool hasSubtitle =
        item['subtitle'] != null && item['subtitle'].toString().isNotEmpty;

    final String imageUrl = item['image'] ?? '';
    final String updatedAt = item['updatedAt'] ?? item['time'] ?? '';
    final String relativeTime = getRelativeTime(updatedAt);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child:
                imageUrl.startsWith('http')
                    ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 140,
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                    : Container(
                      width: double.infinity,
                      height: 140,
                      color: Colors.grey.shade300,
                      child: const Icon(
                        Icons.image,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    textStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: textColor,
                    ),
                  ),
                ),
                if (hasSubtitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    item['subtitle'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      textStyle: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      item['source'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: infoColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (relativeTime.isNotEmpty) ...[
                      const SizedBox(width: 2),
                      Text(
                        '·',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        relativeTime,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
