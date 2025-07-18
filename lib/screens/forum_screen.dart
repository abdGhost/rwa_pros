import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:readmore/readmore.dart';
import 'dart:convert';

import 'package:rwa_app/screens/form_thread_screen.dart';
import 'package:rwa_app/screens/profile_screen.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<Map<String, dynamic>> forumData = [];
  List<bool> isExpandedList = [];
  List<bool> showMoreButtonList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchForumData();
  }

  Future<void> fetchForumData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://rwa-f1623a22e3ed.herokuapp.com/api/forum-category?category=',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == true &&
            jsonResponse['categories'] != null) {
          final List<dynamic> data = jsonResponse['categories'];

          forumData =
              data.map<Map<String, dynamic>>((item) {
                return {
                  'id': item['_id'] ?? '',
                  'name': item['name'] ?? '',
                  'description': item['description'] ?? '',
                  'categoryImage': item['categoryImage'],
                  'createdAt': item['createdAt'],
                };
              }).toList();

          isExpandedList = List.filled(forumData.length, false);
          showMoreButtonList = List.filled(forumData.length, false);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkDescriptionOverflow();
          });
        } else {
          throw Exception('No categories found');
        }
      } else {
        throw Exception('Failed to load forum data');
      }
    } catch (e) {
      print('Error fetching forum data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _checkDescriptionOverflow() {
    final textStyle = GoogleFonts.inter(
      fontWeight: FontWeight.w400,
      color: Colors.grey,
      fontSize: 12,
    );

    const maxLines = 2;

    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = 12 + 16 + 16;
    final maxWidth = screenWidth - horizontalPadding;

    for (int i = 0; i < forumData.length; i++) {
      final description = forumData[i]['description'] ?? '';

      final tp = TextPainter(
        text: TextSpan(text: description, style: textStyle),
        maxLines: maxLines,
        textDirection: TextDirection.ltr,
      );

      tp.layout(maxWidth: maxWidth);

      if (tp.didExceedMaxLines) {
        showMoreButtonList[i] = true;
      }
    }

    setState(() {});
  }

  String formatDate(String isoDate) {
    final dateTime = DateTime.tryParse(isoDate);
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        toolbarHeight: 50,
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset('assets/condo_logo.png', width: 40, height: 40),
            const SizedBox(width: 8),
            Text(
              "Category",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: theme.textTheme.titleMedium?.color,
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
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0087E0)),
              )
              : RefreshIndicator(
                backgroundColor: Colors.white,
                color: Color(0xFF0087E0),
                onRefresh: fetchForumData,
                child: ListView.builder(
                  itemCount: forumData.length,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  itemBuilder: (context, index) {
                    final forum = forumData[index];
                    return Card(
                      color: theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0.02,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => ForumThreadScreen(forumData: forum),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: theme.primaryColor,
                                    backgroundImage:
                                        forum['categoryImage'] != null
                                            ? NetworkImage(
                                              forum['categoryImage'],
                                            )
                                            : null,
                                    child:
                                        forum['categoryImage'] != null
                                            ? null
                                            : Text(
                                              forum['name'].isNotEmpty
                                                  ? forum['name'][0]
                                                      .toUpperCase()
                                                  : '',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          forum['name'],
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color:
                                                theme
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.color,
                                          ),
                                        ),
                                        Text(
                                          formatDate(forum['createdAt']),
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 9,
                                            color:
                                                isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ReadMoreText(
                                forum['description'],
                                trimLines: 2,
                                colorClickableText: theme.primaryColor,
                                trimMode: TrimMode.Line,
                                trimCollapsedText: 'read more',
                                trimExpandedText: ' read less',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  color:
                                      isDark
                                          ? Colors.grey[300]
                                          : const Color(0xFF5F5F5F),
                                ),
                                moreStyle: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: theme.primaryColor,
                                ),
                                lessStyle: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
