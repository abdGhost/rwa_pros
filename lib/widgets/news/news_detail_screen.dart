import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';

class NewsDetailScreen extends StatelessWidget {
  final Map<String, dynamic> news;

  const NewsDetailScreen({super.key, required this.news});

  String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} minutes ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays == 1) return '1 day ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    if (difference.inDays < 30)
      return '${(difference.inDays / 7).floor()} weeks ago';
    if (difference.inDays < 365)
      return '${(difference.inDays / 30).floor()} months ago';
    return '${(difference.inDays / 365).floor()} years ago';
  }

  String? formatIsoDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      final parsedDate = DateTime.parse(iso).toLocal();
      return getRelativeTime(parsedDate);
    } catch (e) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📰 News Data: $news');

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground.withOpacity(0.85);

    final String? image = news['thumbnail'] ?? news['image'];
    final String? title = news['title'];
    final String? source = news['author'] ?? news['source'];
    final String? updatedAt = news['updatedAt'];
    final String? authorImage = news['authorImage'];
    final String? slug = news['slug'];
    final String? content = news['content'];
    final String? quote = news['quote'];
    final List<dynamic> tags = news['tags'] ?? [];
    final List<String> bulletPoints = List<String>.from(
      news['bulletPoints'] ?? [],
    );
    final String formattedUpdatedAt = formatIsoDate(updatedAt) ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: theme.appBarTheme.backgroundColor,
        leading: BackButton(color: theme.iconTheme.color),
        title: Text(
          (title ?? 'News').length > 30
              ? '${title!.substring(0, 30)}...'
              : title ?? 'News',
          style: GoogleFonts.inter(
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        children: [
          if (image != null && image.isNotEmpty)
            Image.network(
              image,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey.shade300,
                    child: const Icon(
                      Icons.broken_image,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title.isNotEmpty)
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                const SizedBox(height: 8),

                if (source != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage:
                            authorImage != null && authorImage.isNotEmpty
                                ? NetworkImage(authorImage)
                                : null,
                        child:
                            (authorImage == null || authorImage.isEmpty)
                                ? Text(
                                  source.substring(0, 1).toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0087E0),
                                  ),
                                )
                                : null,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source[0].toUpperCase() +
                                source.substring(1).toLowerCase(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0087E0),
                            ),
                          ),
                          if (formattedUpdatedAt.isNotEmpty)
                            Text(
                              formattedUpdatedAt,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                if (slug != null && slug.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      slug,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        tags.map<Widget>((tag) {
                          return Chip(
                            label: Text(tag.toString()),
                            backgroundColor:
                                isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                            labelStyle: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 12,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          );
                        }).toList(),
                  ),
                ],

                if (content != null && content.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  HtmlWidget(
                    content,
                    textStyle: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    customStylesBuilder: (element) {
                      switch (element.localName) {
                        case 'p':
                          return {'margin': '0 0 6px 0'};
                        case 'h2':
                          return {
                            'margin': '10px 0 6px 0',
                            'font-weight': 'bold',
                            'font-size': '18px',
                          };
                        case 'ul':
                        case 'ol':
                          return {'margin': '4px 0', 'padding-left': '16px'};
                        case 'li':
                          return {'margin': '0 0 4px 0'};
                      }
                      return null;
                    },
                  ),
                ],

                if (quote != null && quote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      border: const Border(
                        left: BorderSide(color: Color(0xFF1CB379), width: 4),
                      ),
                    ),
                    child: Text(
                      quote,
                      style: GoogleFonts.inter(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],

                if (bulletPoints.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    "Key Takeaways:",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...bulletPoints.map(
                    (point) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "• ",
                            style: TextStyle(fontSize: 14, height: 1.4),
                          ),
                          Expanded(
                            child: Text(
                              point,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                height: 1.4,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
