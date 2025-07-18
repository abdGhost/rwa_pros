import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';

class BlogDetailScreen extends StatelessWidget {
  final Map<String, dynamic> blog;

  const BlogDetailScreen({super.key, required this.blog});

  String formatTime(String rawTime) {
    try {
      final cleanTime = rawTime.split(' GMT')[0];
      final formatter = DateFormat('EEE MMM dd yyyy HH:mm:ss');
      final parsedDate = formatter.parse(cleanTime);
      return DateFormat('MMM d, yyyy').format(parsedDate);
    } catch (e) {
      return rawTime;
    }
  }

  void printFullBlog(Map<String, dynamic> blog) {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    final prettyBlog = encoder.convert(blog);
    debugPrint(prettyBlog);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    printFullBlog(blog);

    final String? image = blog['image'];
    final String? title = blog['title'];
    final String? subtitle = blog['subtitle'];
    final String? author = blog['author'];
    final String? time = blog['time'];
    final String? rawContent = blog['content'];
    final Map<String, dynamic>? blockQuote = blog['blockQuote'];
    final List<String> bulletPoints = List<String>.from(
      blog['bulletPoints'] ?? [],
    );

    final formattedTime = time != null ? formatTime(time) : '';

    // 🧹 Clean the HTML content by removing inline color styles
    final String cleanContent = (rawContent ?? '').replaceAll(
      RegExp(r'color:\s*rgb\(\d+,\s*\d+,\s*\d+\);?'),
      '',
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        leading: BackButton(color: theme.iconTheme.color),
        title: Text(
          (title ?? 'Blog').length > 40
              ? '${title!.substring(0, 40)}...'
              : title ?? 'Blog',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        children: [
          if (image != null && image.isNotEmpty)
            image.startsWith('http')
                ? Image.network(
                  image,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                )
                : Image.asset(
                  image,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? '',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                      height: 1.5,
                    ),
                  ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodySmall,
                    children: [
                      const TextSpan(text: 'Written by - '),
                      TextSpan(
                        text: author ?? '',
                        style: const TextStyle(
                          color: Color(0xFF1CB379),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: ' · $formattedTime'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (blockQuote != null && blockQuote.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color:
                          isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      border: const Border(
                        left: BorderSide(color: Color(0xFF1CB379), width: 4),
                      ),
                    ),
                    child: Text(
                      blockQuote['text'] ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                if (cleanContent.isNotEmpty) ...[
                  HtmlWidget(
                    cleanContent,
                    textStyle: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],

                if (bulletPoints.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    "Key Insights:",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...bulletPoints.map(
                    (point) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("• "),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              point,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
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
