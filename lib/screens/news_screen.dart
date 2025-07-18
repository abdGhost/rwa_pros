import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rwa_app/models/podcast.dart';
import 'package:rwa_app/screens/chat_screen.dart';
import 'package:rwa_app/screens/podcast_player_screen.dart';
import 'package:rwa_app/screens/profile_screen.dart';
import 'package:rwa_app/widgets/filter_tab_widget.dart';
import 'package:rwa_app/widgets/news/news_card_main.dart';
import 'package:rwa_app/widgets/news/news_card_side.dart';
import 'package:rwa_app/widgets/news/news_detail_screen.dart';
import 'package:rwa_app/widgets/search_appbar_field_widget.dart';
import 'package:timeago/timeago.dart' as timeago;

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  bool _isSearching = false;
  int _selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> newsItems = [];
  List<Map<String, dynamic>> filteredNews = [];
  List<Podcast> podcastItems = [];
  List<Podcast> filteredPodcasts = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  Future<void> fetchAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([fetchNews(), fetchPodcasts()]);
    setState(() => _isLoading = false);
  }

  Future<void> fetchNews() async {
    const url =
        'https://rwa-f1623a22e3ed.herokuapp.com/api/currencies/rwa/news';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List newsList = data['news'];
        print(newsList);
        newsItems =
            newsList.map<Map<String, dynamic>>((news) {
              return {
                'image': news['thumbnail'],
                'title': news['title'],
                'subtitle': news['subTitle'],
                'source': news['author'],
                'time': news['publishDate'],
                'content': news['content'],
                'quote': null,
                'bulletPoints': [],
                'updatedAt': news['updatedAt'],
              };
            }).toList();

        filteredNews = List.from(newsItems);
      }
    } catch (e) {
      print('❌ Error fetching news: $e');
    }
  }

  Future<void> fetchPodcasts() async {
    const url =
        'https://rwa-f1623a22e3ed.herokuapp.com/api/admin/podcast/get/allPodcasts';
    try {
      final response = await http.get(Uri.parse(url));
      print('🎧 Podcast API response: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'];
        podcastItems.clear();
        podcastItems = items.map((item) => Podcast.fromJson(item)).toList();

        // ✅ This ensures podcast tab is immediately populated
        filteredPodcasts = List.from(podcastItems);
      }
    } catch (e) {
      print('❌ Error fetching podcasts: $e');
    }
  }

  void _applySearch() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      filteredNews = List.from(newsItems);
      filteredPodcasts = List.from(podcastItems);
    } else {
      filteredNews =
          newsItems.where((item) {
            final title = (item['title'] ?? '').toLowerCase();
            final subtitle = (item['subtitle'] ?? '').toLowerCase();
            final source = (item['source'] ?? '').toLowerCase();
            return title.contains(query) ||
                subtitle.contains(query) ||
                source.contains(query);
          }).toList();

      filteredPodcasts =
          podcastItems.where((p) {
            final title = p.videoTitle.toLowerCase();
            final desc = p.founderName.toLowerCase();
            return title.contains(query) || desc.contains(query);
          }).toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: theme.appBarTheme.elevation ?? 1,
        toolbarHeight: 60,
        title: Row(
          children: [
            Image.asset('assets/condo_logo.png', width: 40, height: 40),
            const SizedBox(width: 8),
            if (!_isSearching)
              Text(
                'Updates',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            if (_isSearching)
              Expanded(
                child: SearchAppBarField(
                  controller: _searchController,
                  onChanged: (_) => _applySearch(),
                  onCancel: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                      _applySearch();
                    });
                  },
                ),
              ),
          ],
        ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: SvgPicture.asset(
                'assets/search_outline.svg',
                width: 24,
                color: theme.iconTheme.color,
              ),
              onPressed: () => setState(() => _isSearching = true),
            ),
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
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children:
                  ["News", "Podcasts"].asMap().entries.map((entry) {
                    final index = entry.key;
                    final label = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 160,
                        child: FilterTab(
                          textSize: 14,
                          text: label,
                          isActive: _selectedTab == index,
                          onTap:
                              () => setState(() {
                                print(index);
                                _selectedTab = index;
                              }),
                          isDarkMode: theme.brightness == Brightness.dark,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0087E0),
                      ),
                    )
                    : _selectedTab == 0
                    ? _buildNewsList()
                    : _buildPodcastLists(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0087E0),
        shape: const CircleBorder(),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
        },
        child: SvgPicture.asset(
          'assets/bot_light.svg',
          width: 40,
          height: 40,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }

  Widget _buildNewsList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children:
          filteredNews.isNotEmpty
              ? [
                GestureDetector(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => NewsDetailScreen(news: filteredNews.first),
                        ),
                      ),
                  child: NewsCardMain(item: filteredNews.first),
                ),
                const SizedBox(height: 10),
                ...filteredNews
                    .skip(1)
                    .map(
                      (item) => NewsCardSide(
                        item: item,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NewsDetailScreen(news: item),
                              ),
                            ),
                      ),
                    ),
              ]
              : [
                const SizedBox(height: 100),
                Center(
                  child: Text(
                    'No news found.',
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ],
    );
  }

  Widget _buildPodcastLists() {
    return filteredPodcasts.isEmpty
        ? const Center(
          child: Text(
            'No podcasts found.',
            style: TextStyle(color: Colors.grey),
          ),
        )
        : ListView.separated(
          itemCount: filteredPodcasts.length,
          separatorBuilder:
              (_, __) => const Divider(
                thickness: 0.2,
                height: 10,
                color: Color.fromARGB(255, 11, 11, 11),
              ),
          itemBuilder: (context, index) {
            final item = filteredPodcasts[index];
            final formattedDate = timeago.format(item.createdAt, locale: 'en');

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => PodcastPlayerScreen(
                                youtubeUrl: item.youtubeLink,
                              ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            item.thumbnail,
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => Container(
                                  height: 160,
                                  color: Colors.grey.shade300,
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 48,
                                  ),
                                ),
                          ),
                        ),
                        const Positioned.fill(
                          child: Center(
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(item.profileImg),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.videoTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.founderName} · $formattedDate',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
  }
}
