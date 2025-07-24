import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rwa_app/screens/form_thread_screen.dart';
import 'package:rwa_app/screens/forum/category_modal.dart';
import 'package:rwa_app/screens/forum/hot_topic_modal.dart';
import 'package:rwa_app/screens/forum/recent_thread.dart';
import 'package:rwa_app/screens/forum/subcategory_tile.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:rwa_app/screens/profile_screen.dart';

class ForumCategory extends StatefulWidget {
  const ForumCategory({super.key});

  @override
  State<ForumCategory> createState() => _ForumCategoryState();
}

class _ForumCategoryState extends State<ForumCategory> {
  List<Category> categories = [];
  List<HotTopic> hotTopics = [];
  List<RecentThread> recentThreads = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
    fetchCategories();
    fetchHotTopics();
    fetchRecentThreads();
  }

  Future<void> fetchCategories() async {
    final url = Uri.parse(
      'https://rwa-f1623a22e3ed.herokuapp.com/api/admin/forum-category',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<Category> loaded =
          (data['allCategories'] as List)
              .map((json) => Category.fromJson(json))
              .toList();
      setState(() {
        categories = loaded;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchHotTopics() async {
    final url = Uri.parse(
      'https://rwa-f1623a22e3ed.herokuapp.com/api/forum/hot-topics',
    );
    final response = await http.get(url);
    print('Response hot topic -----, ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> list = data['hotTopics'];
      setState(() {
        hotTopics = list.map((json) => HotTopic.fromJson(json)).toList();
        print(hotTopics);
      });
    }
  }

  Future<void> fetchRecentThreads() async {
    final url = Uri.parse('https://rwa-f1623a22e3ed.herokuapp.com/api/forum');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['forums'];
      setState(() {
        recentThreads =
            list.map((json) => RecentThread.fromJson(json)).toList();
      });
    }
  }

  Widget buildHottestTodayCard() {
    return Container(
      color: Colors.white,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0.02,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Hottest today",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 14),
                ],
              ),
              const SizedBox(height: 10),
              ...hotTopics
                  .take(3)
                  .map(
                    (topic) => GestureDetector(
                      onTap: () {
                        print('Tapped HotTopic:');
                        print('ID: ${topic.id}');
                        print('Title: ${topic.title}');
                        print('User: ${topic.userName}');
                        print('Comments: ${topic.commentsCount}');
                        print('Category ID: ${topic.categoryId}');

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ForumThreadScreen(
                                  forumData: {
                                    'id': topic.categoryId,
                                    'name': topic.title,
                                    'description': topic.text ?? '',
                                    'categoryId': topic.id,
                                  },
                                ),
                          ),
                        );
                      },

                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFFEBB411),
                              child: Text(
                                topic.userName != null &&
                                        topic.userName!.isNotEmpty
                                    ? topic.userName![0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    topic.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${topic.commentsCount} replies"
                                    "${topic.userName != null ? ' · ${topic.userName}' : ''}",
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildRecentlyCard() {
    return Container(
      color: Colors.white,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0.02,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Recently Added",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: Colors.black,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...recentThreads
                  .take(10)
                  .map(
                    (thread) => GestureDetector(
                      onTap: () {
                        print('Tapped RecentThread:');
                        print('Subcategory: ${thread.id}');
                        print('Title: ${thread.title}');
                        print('User: ${thread.userName}');
                        print('Comments: ${thread.commentsCount}');
                        print('Category ID: ${thread.categoryId}');
                        print('Category Name: ${thread.categoryName}');
                        print('Text: ${thread.text}');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ForumThreadScreen(
                                  forumData: {
                                    'id': thread.categoryId,
                                    'name': thread.title,
                                    'description': thread.text,
                                    'categoryId': thread.id,
                                  },
                                ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.green,
                              child: Text(
                                thread.userName != null &&
                                        thread.userName!.isNotEmpty
                                    ? thread.userName![0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    thread.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${thread.commentsCount} replies"
                                    "${thread.userName != null ? ' · ${thread.userName}' : ''}",
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            Image.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/rwapros/logo-white.png'
                  : 'assets/rwapros/logo.png',
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 8),
            Text(
              "Forum",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 20,
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  children:
                      categories
                          .where(
                            (category) => category.subCategories.isNotEmpty,
                          )
                          .toList()
                          .asMap()
                          .entries
                          .expand((entry) {
                            final index = entry.key;
                            final category = entry.value;

                            final widgets = <Widget>[
                              // Category Title
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  category.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Subcategories
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                ),
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  elevation: 0.02,
                                  color: Colors.white,
                                  child: Column(
                                    children:
                                        category.subCategories.asMap().entries.map((
                                          subEntry,
                                        ) {
                                          final subIndex = subEntry.key;
                                          final sub = subEntry.value;

                                          return SubCategoryTile(
                                            imageUrl: sub.imageUrl,
                                            title: sub.name,
                                            contentTitle: sub.description,
                                            createdAt: sub.createdAt,
                                            author: "Admin",
                                            isLast:
                                                subIndex ==
                                                category.subCategories.length -
                                                    1,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) => ForumThreadScreen(
                                                        forumData: {
                                                          'id':
                                                              sub.id, // SubCategory ID
                                                          'name': sub.name,
                                                          'description':
                                                              sub.description,
                                                          'categoryId':
                                                              category
                                                                  .id, // Parent Category ID
                                                        },
                                                      ),
                                                ),
                                              );
                                            },
                                          );
                                        }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ];

                            // Hottest Today
                            if (index == 0) {
                              widgets.add(buildHottestTodayCard());
                              widgets.add(const SizedBox(height: 16));
                            }

                            // Recently
                            if (index == 0) {
                              widgets.add(buildRecentlyCard());
                              widgets.add(const SizedBox(height: 16));
                            }

                            return widgets;
                          })
                          .toList(),
                ),
              ),
    );
  }
}
