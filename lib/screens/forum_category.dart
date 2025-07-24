import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rwa_app/screens/forum/category_modal.dart';
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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
    fetchCategories();
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
                          .map((category) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                          category.subCategories
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                                final index = entry.key;
                                                final sub = entry.value;
                                                return SubCategoryTile(
                                                  imageUrl: sub.imageUrl,
                                                  title: sub.name,
                                                  contentTitle: sub.description,
                                                  createdAt: sub.createdAt,
                                                  author: "Admin",
                                                  isLast:
                                                      index ==
                                                      category
                                                              .subCategories
                                                              .length -
                                                          1,
                                                );
                                              })
                                              .toList(),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),
                              ],
                            );
                          })
                          .toList(),
                ),
              ),
    );
  }
}
