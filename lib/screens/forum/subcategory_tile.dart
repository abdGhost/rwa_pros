import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SubCategoryTile extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String contentTitle;
  final DateTime createdAt;
  final String author;
  final bool isLast;

  const SubCategoryTile({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.contentTitle,
    required this.createdAt,
    required this.author,
    this.isLast = false,
  });

  String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return '${diff.inHours} hr${diff.inHours > 1 ? 's' : ''} ago';
    }
    if (diff.inDays < 30) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    }

    final months = (diff.inDays / 30).floor();
    if (months < 12) return '$months month${months > 1 ? 's' : ''} ago';

    final years = (diff.inDays / 365).floor();
    return '$years year${years > 1 ? 's' : ''} ago';
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = formatTimeAgo(createdAt);
    final theme = Theme.of(context);

    return Column(
      children: [
        ListTile(
          leading: ClipOval(
            child: Image.network(
              imageUrl,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => const Icon(
                    Icons.broken_image,
                    size: 30,
                    color: Colors.grey,
                  ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color:
                      theme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                contentTitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1,
                  color:
                      theme.brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$timeAgo · $author',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, thickness: 0.4),
      ],
    );
  }
}
