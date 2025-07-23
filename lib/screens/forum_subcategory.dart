import 'dart:convert';
import 'package:characters/characters.dart'; // Safe string character access
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rwa_app/screens/form_thread_screen.dart';

class ForumSubcategory extends StatefulWidget {
  final Map<String, dynamic> categoryData;

  const ForumSubcategory({super.key, required this.categoryData});

  @override
  State<ForumSubcategory> createState() => _ForumSubcategoryState();
}

class _ForumSubcategoryState extends State<ForumSubcategory> {
  List<Map<String, dynamic>> subcategories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSubcategories();
  }

  Future<void> fetchSubcategories() async {
    setState(() => isLoading = true);

    try {
      final categoryId = widget.categoryData['id'];
      final apiUrl =
          'https://rwa-f1623a22e3ed.herokuapp.com/api/admin/forum-sub-category?category=$categoryId';
      print('📡 Fetching Subcategories from: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('✅ API Response: ${jsonEncode(jsonResponse)}');

        if (jsonResponse is List) {
          subcategories = List<Map<String, dynamic>>.from(
            jsonResponse.map(
              (item) => {
                '_id': item['_id'],
                'name': item['name'],
                'description': item['description'],
                'subCategoryImage': item['subCategoryImage'],
                'createdAt': item['createdAt'],
                'totalLikes': item['totalLikes'] ?? 0,
                'totalComments': item['totalComments'] ?? 0,
                'totalDislikes': item['totalDislikes'] ?? 0,
              },
            ),
          );
        } else {
          print('⚠️ Unexpected response format. Expected a List.');
        }
      } else {
        print('❌ Failed to fetch. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching subcategories: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  String formatDate(String isoDate) {
    final dateTime = DateTime.tryParse(isoDate);
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    if (difference.inDays < 30) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    }
    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
    final years = (difference.inDays / 365).floor();
    return '$years year${years > 1 ? 's' : ''} ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryData['name'] ?? 'Subcategories',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0.2,
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFEBB411)),
              )
              : subcategories.isEmpty
              ? Center(
                child: Text(
                  'No subcategories found.',
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              )
              : ListView.builder(
                itemCount: subcategories.length,
                itemBuilder: (context, index) {
                  final sub = subcategories[index];
                  final likes = sub['totalLikes'] ?? 0;
                  final dislikes = sub['totalDislikes'] ?? 0;
                  final replies = sub['totalComments'] ?? 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    color: theme.cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: theme.primaryColor,
                        backgroundImage:
                            sub['subCategoryImage'] != null
                                ? NetworkImage(sub['subCategoryImage'])
                                : null,
                        child:
                            sub['subCategoryImage'] == null
                                ? Builder(
                                  builder: (_) {
                                    final name =
                                        sub['name']?.toString().trim() ?? '';
                                    if (name.isNotEmpty) {
                                      return Text(
                                        name.characters.first.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      );
                                    } else {
                                      return const Text(
                                        '?',
                                        style: TextStyle(color: Colors.white),
                                      );
                                    }
                                  },
                                )
                                : null,
                      ),
                      title: Text(
                        sub['name'] ?? '',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.thumb_up_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$likes',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color:
                                    isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[800],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.thumb_down_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$dislikes',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color:
                                    isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[800],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$replies',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color:
                                    isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[800],
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatDate(sub['createdAt'] ?? ''),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color:
                                    isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ForumThreadScreen(
                                  forumData: {
                                    'id': sub['_id'],
                                    'name': sub['name'],
                                    'description': sub['description'],
                                    'categoryImage': sub['subCategoryImage'],
                                    'createdAt': sub['createdAt'],
                                  },
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
    );
  }
}
