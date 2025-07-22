import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NewsCardSide extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  const NewsCardSide({super.key, required this.item, this.onTap});

  String getRelativeTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    DateTime? dateTime;

    try {
      if (timeStr.contains('GMT')) {
        final cleaned = timeStr.split(' GMT').first;
        dateTime = DateFormat('EEE MMM dd yyyy HH:mm:ss').parse(cleaned);
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
    final hasSubtitle =
        item['subtitle'] != null && item['subtitle'].toString().isNotEmpty;
    final image = item['image']?.toString();
    final imageHeight = hasSubtitle ? 80.0 : 70.0;

    final titleColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor =
        theme.textTheme.bodySmall?.color?.withOpacity(0.7) ?? Colors.grey;
    final borderColor = theme.dividerColor.withOpacity(0.15);

    final String rawTime = item['updatedAt'] ?? item['time'] ?? '';
    final String relativeTime = getRelativeTime(rawTime);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (image != null && image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    image,
                    width: 70,
                    height: imageHeight,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 70,
                        height: imageHeight,
                        color: Colors.grey.shade300,
                        child: const Icon(
                          Icons.broken_image,
                          size: 30,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              if (image != null && image.isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        textStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          height: 1.25,
                          color: titleColor,
                        ),
                      ),
                    ),
                    if (hasSubtitle) ...[
                      const SizedBox(height: 4),
                      Text(
                        item['subtitle'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          textStyle: TextStyle(
                            fontSize: 10,
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
                            color: const Color(0xFFEBB411),
                            fontWeight: FontWeight.w400,
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
        ),
      ),
    );
  }
}
