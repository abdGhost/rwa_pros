import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BlogCard extends StatelessWidget {
  final Map<String, dynamic> blog;
  final VoidCallback? onTap;

  const BlogCard({super.key, required this.blog, this.onTap});

  String formatTime(String rawTime) {
    try {
      final cleanedTime = rawTime.split(' GMT')[0]; // Remove ' GMT+...' part
      final formatter = DateFormat('EEE MMM dd yyyy HH:mm:ss');
      final parsedDate = formatter.parse(cleanedTime);
      return DateFormat(
        'MMM d, yyyy',
      ).format(parsedDate); // Output: Oct 30, 2024
    } catch (e) {
      print('Error parsing date: $e');
      return rawTime; // fallback if error
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bool hasImage =
        blog['image'] != null && blog['image'].toString().isNotEmpty;
    final bool hasSubtitle =
        blog['subtitle'] != null && blog['subtitle'].toString().isNotEmpty;
    final String imageUrl = blog['image'] ?? '';
    final String formattedTime =
        blog['time'] != null ? formatTime(blog['time']) : '';

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        color: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child:
                          imageUrl.startsWith('http')
                              ? Image.network(
                                imageUrl,
                                width: 90,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => Container(
                                      width: 90,
                                      height: 60,
                                      color: Colors.grey.shade300,
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 24,
                                      ),
                                    ),
                              )
                              : Container(
                                width: 90,
                                height: 60,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image, size: 24),
                              ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        blog['title'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  blog['title'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              if (hasSubtitle) ...[
                const SizedBox(height: 6),
                Text(
                  blog['subtitle'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    blog['author'] ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF1CB379),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '·',
                    style: TextStyle(fontSize: 10, color: Color(0xFF1CB379)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF1CB379),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
